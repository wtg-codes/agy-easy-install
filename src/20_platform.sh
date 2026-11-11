inject_path() {
    if [[ ":$PATH:" == *":$BIN_DIR:"* ]]; then
        return
    fi

    local shell_rc=""
    if [ "$PLATFORM" = "Darwin" ]; then
        shell_rc="$HOME/.zprofile"
    elif [[ "$SHELL" == *"zsh"* ]]; then
        shell_rc="$HOME/.zshrc"
    elif [[ "$SHELL" == *"fish"* ]]; then
        shell_rc="$HOME/.config/fish/config.fish"
    else
        shell_rc="$HOME/.bashrc"
    fi

    local export_line="export PATH=\"\$HOME/.local/bin:\$PATH\""
    if [[ "$shell_rc" == *"fish"* ]]; then
        export_line="fish_add_path \$HOME/.local/bin"
    fi

    if grep -q "\$HOME/.local/bin" "$shell_rc" 2>/dev/null; then
        return
    fi

    if [ "$AUTO" -eq 1 ] || [ "$JSON_OUT" -eq 1 ]; then
        echo "$export_line" >> "$shell_rc"
        log_info "✅ Added ~/.local/bin to $shell_rc automatically."
    else
        log_warn "$BIN_DIR is not in your PATH."
        if command -v gum >/dev/null 2>&1; then
            if gum confirm "Would you like to automatically add it to $shell_rc?"; then
                add_path="y"
            else
                add_path="n"
            fi
        else
            echo -ne "${C_YELLOW}Would you like to automatically add it to $shell_rc? [Y/n]: ${C_RESET}"
            read -r add_path < /dev/tty
        fi
        case "$add_path" in
            [nN]*) log_info "Skipping PATH injection. Please add it manually." ;;
            *)
                echo "$export_line" >> "$shell_rc"
                log_info "✅ Added ~/.local/bin to $shell_rc."
                log_info "   Please run 'source $shell_rc' or restart your terminal later."
                ;;
        esac
    fi
}

find_chrome_binary() {
    # 1. Prioritize raw Flatpak binaries (required to bypass sandbox)
    local flatpak_sys="/var/lib/flatpak/app/com.google.Chrome/current/active/files/extra/chrome"
    local flatpak_user="$HOME/.local/share/flatpak/app/com.google.Chrome/current/active/files/extra/chrome"

    if [[ -x "$flatpak_sys" ]]; then
        echo "$flatpak_sys"
    elif [[ -x "$flatpak_user" ]]; then
        echo "$flatpak_user"
    else
        # 2. Fallback to standard system package binaries
        if [ "$PLATFORM" = "Darwin" ] && [ -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]; then
            echo "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
        elif [ "$PLATFORM" = "Crostini" ] && command -v garcon-url-handler >/dev/null 2>&1 && ! command -v google-chrome >/dev/null 2>&1 && ! command -v chromium >/dev/null 2>&1; then
            echo ""
        else
            for cmd in google-chrome-stable google-chrome chromium chromium-browser; do
                if command -v "$cmd" >/dev/null 2>&1; then
                    command -v "$cmd"
                    return 0
                fi
            done
        fi
    fi
}

configure_chrome_path() {
    local target_product="${1:-antigravity}"
    local settings_dirs=()
    if [ "$PLATFORM" = "Darwin" ]; then
        case "$target_product" in
            ide) settings_dirs=("$HOME/Library/Application Support/Antigravity IDE/User") ;;
            both)
                settings_dirs=(
                    "$HOME/Library/Application Support/Antigravity/User"
                    "$HOME/Library/Application Support/Antigravity IDE/User"
                )
                ;;
            *) settings_dirs=("$HOME/Library/Application Support/Antigravity/User") ;;
        esac
    else
        case "$target_product" in
            ide) settings_dirs=("$HOME/.config/Antigravity IDE/User") ;;
            both)
                settings_dirs=(
                    "$HOME/.config/Antigravity/User"
                    "$HOME/.config/Antigravity IDE/User"
                )
                ;;
            *) settings_dirs=("$HOME/.config/Antigravity/User") ;;
        esac
    fi
    local chrome_path=""

    log_info "${C_CYAN}🔍 Locating Chrome binary for Antigravity...${C_RESET}"
    chrome_path=$(find_chrome_binary)
    if [[ -n "$chrome_path" ]]; then
        log_info "  Located Chrome binary: $chrome_path"
    fi

    if [[ -n "$chrome_path" ]]; then
        local do_inject=0
        if [ "$AUTO" -eq 1 ] || [ "$JSON_OUT" -eq 1 ]; then
            do_inject=1
        else
            log_warn "Antigravity occasionally fails to find Chrome when installed via Brew or Binary."
            log_info "We found a valid Chrome binary at: ${C_BOLD}$chrome_path${C_RESET}"
            
            if command -v gum >/dev/null 2>&1; then
                if gum confirm "Would you like to automatically configure Antigravity to use this browser?"; then
                    set_chrome="y"
                else
                    set_chrome="n"
                fi
            else
                echo -ne "${C_YELLOW}Would you like to automatically configure Antigravity to use this browser? [Y/n]: ${C_RESET}"
                read -r set_chrome < /dev/tty
            fi
            case "$set_chrome" in
                [nN]*) log_info "Skipping Chrome configuration." ;;
                *) do_inject=1 ;;
            esac
        fi

        if [ "$do_inject" -eq 1 ]; then
            local sdir sfile
            for sdir in "${settings_dirs[@]}"; do
                sfile="$sdir/settings.json"
                mkdir -p "$sdir"
                [[ ! -f "$sfile" ]] && echo '{}' > "$sfile"

                if command -v jq >/dev/null 2>&1; then
                    jq --arg path "$chrome_path" \
                       '.["antigravity.browser.chromeBinaryPath"] = $path' \
                       "$sfile" > "${sfile}.tmp" && mv "${sfile}.tmp" "$sfile"
                    log_info "${C_GREEN}✅ Antigravity Chrome path mapped to $chrome_path ($sfile)${C_RESET}"
                elif command -v python3 >/dev/null 2>&1; then
                    if python3 -c '
import json, sys
p, chrome = sys.argv[1], sys.argv[2]
try:
    with open(p, "r", encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, dict):
        data = {}
except Exception:
    data = {}
data["antigravity.browser.chromeBinaryPath"] = chrome
with open(p, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
' "$sfile" "$chrome_path" 2>/dev/null; then
                        log_info "${C_GREEN}✅ Antigravity Chrome path mapped to $chrome_path ($sfile)${C_RESET}"
                    else
                        log_warn "Could not update $sfile automatically."
                    fi
                else
                    log_warn "Neither jq nor python3 found. Cannot automatically configure Chrome path."
                fi
            done
        fi
    else
        log_warn "Could not locate a valid Chrome or Chromium executable. Antigravity may complain it is not installed."
    fi
}

save_manager_locally() {
    log_info "${C_CYAN}💾 Saving Antigravity Manager to your system...${C_RESET}"
    mkdir -p "$BIN_DIR"

    local is_valid_self=0
    if [ -f "$0" ] && [ -r "$0" ]; then
        case "${0##*/}" in
            bash|sh|zsh|dash|ksh|fish|-*) is_valid_self=0 ;;
            *) is_valid_self=1 ;;
        esac
    fi

    if [ "$is_valid_self" -eq 1 ]; then
        if [ ! "$0" -ef "$BIN_DIR/antigravity-manager" ]; then
            cp "$0" "$BIN_DIR/antigravity-manager"
        fi
    else
        run_cmd curl -fSsL "$MANAGER_URL" -o "$BIN_DIR/antigravity-manager"
    fi
    
    chmod +x "$BIN_DIR/antigravity-manager"
    log_info "${C_GREEN}✅ Manager saved.${C_RESET} Run ${C_BOLD}antigravity-manager${C_RESET} anytime."
    inject_path
}

remove_manager_script() {
    log_info "${C_RED}🗑️  Removing Antigravity Manager script...${C_RESET}"
    if [ -f "$BIN_DIR/antigravity-manager" ]; then
        rm -f "$BIN_DIR/antigravity-manager"
        log_info "${C_GREEN}✅ Manager script removed from your system.${C_RESET}"
    else
        log_warn "Manager script was not found on your system."
    fi
}

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO="$ID"
        # shellcheck disable=SC2034
        DISTRO_LIKE="$ID_LIKE"
    else
        DISTRO="unknown"
    fi
}

check_brew() {
    command -v brew >/dev/null 2>&1
}

detect_platform() {
    PLATFORM=$(uname -s)
    ARCH=$(uname -m)
    
    # Proper Apple Silicon detection (handles terminal running under Rosetta 2)
    if [ "$PLATFORM" = "Darwin" ] && [ "$ARCH" = "x86_64" ]; then
        if [ "$(sysctl -in sysctl.proc_translated)" = "1" ]; then
            ARCH="arm64"
        fi
    fi

    HAS_BREW="no"
    HAS_APT="no"
    HAS_DNF="no"
    DISTRO_PRETTY="Unknown"
    GLIBC_VERSION=""
    RECOMMENDED="3"  # default to binary

    if check_brew; then
        HAS_BREW="yes"
    fi

    if [ "$PLATFORM" = "Darwin" ]; then
        DISTRO_PRETTY="macOS $(sw_vers -productVersion 2>/dev/null || echo '')"
        if [ "$HAS_BREW" = "yes" ]; then RECOMMENDED="1"; else RECOMMENDED="3"; fi
    else
        detect_distro
        if [ -f /etc/os-release ]; then
            # shellcheck disable=SC1091
            DISTRO_PRETTY=$(. /etc/os-release && echo "${PRETTY_NAME:-$ID}")
        fi
        
        if [ "$(uname -o 2>/dev/null)" = "Msys" ] || [[ "$(uname -s 2>/dev/null)" == "MINGW"* ]]; then
            echo "ERROR: Git Bash / MSYS2 is not supported."
            echo "Please install WSL2 (wsl --install) and run this script from an Ubuntu terminal."
            exit 1
        fi

        if grep -qi "microsoft" /proc/version 2>/dev/null; then
            DISTRO_PRETTY="${DISTRO_PRETTY} (WSL)"
        elif [ -f /dev/.cros_milestone ]; then
            PLATFORM="Crostini"
            local MILESTONE=""
            MILESTONE=$(cat /dev/.cros_milestone 2>/dev/null || echo "Unknown")
            DISTRO_PRETTY="ChromeOS Crostini M${MILESTONE} (${DISTRO_PRETTY})"
        fi

        if command -v apt >/dev/null 2>&1; then HAS_APT="yes"; fi
        if command -v dnf >/dev/null 2>&1; then HAS_DNF="yes"; fi

        GLIBC_VERSION=$(ldd --version 2>/dev/null | awk 'NR==1 {print $NF}' || true)

        IS_ATOMIC="no"
        if [ -d /run/ostree-booted ] || [ "$DISTRO" = "bluefin" ] || [ "$DISTRO" = "bazzite" ]; then
            IS_ATOMIC="yes"
            DISTRO_PRETTY="${DISTRO_PRETTY} (Atomic)"
        fi

        if [ "$HAS_BREW" = "yes" ]; then
            RECOMMENDED="1"
        else
            # Official 2.x releases on Linux are distributed as tarballs / Homebrew casks
            # (legacy APT/RPM repos remain available manually but stopped at 1.23.2).
            RECOMMENDED="3"
        fi
    fi
}

read_asar_version() {
    local asar_path="$1"
    if [ ! -f "$asar_path" ]; then
        return 1
    fi
    if command -v python3 >/dev/null 2>&1; then
        python3 -c '
import json, struct, sys
try:
    with open(sys.argv[1], "rb") as f:
        hdr = f.read(16)
        if len(hdr) == 16:
            _, h_sz, _, j_sz = struct.unpack("<IIII", hdr)
            meta = json.loads(f.read(j_sz).decode("utf-8"))
            info = meta.get("files", {}).get("package.json")
            if info and "offset" in info and "size" in info:
                f.seek(8 + h_sz + int(info["offset"]))
                pkg = json.loads(f.read(int(info["size"])).decode("utf-8"))
                if pkg.get("version"):
                    print(pkg["version"])
except Exception:
    pass
' "$asar_path" 2>/dev/null || true
    fi
}

get_installed_agy_version() {
    local v=""
    # 1. User-space Hub 2.x binary install (app.asar)
    if [ -f "$APP_DIR/resources/app.asar" ]; then
        v=$(read_asar_version "$APP_DIR/resources/app.asar")
        if [ -n "$v" ]; then echo "$v"; return; fi
    fi
    # 2. macOS Antigravity.app bundle
    if [ -f "/Applications/Antigravity.app/Contents/Resources/app.asar" ]; then
        v=$(read_asar_version "/Applications/Antigravity.app/Contents/Resources/app.asar")
        if [ -n "$v" ]; then echo "$v"; return; fi
    fi
    if [ -f "/Applications/Antigravity.app/Contents/Info.plist" ] && command -v defaults >/dev/null 2>&1; then
        v=$(defaults read "/Applications/Antigravity.app/Contents/Info" CFBundleShortVersionString 2>/dev/null || true)
        if [ -n "$v" ]; then echo "$v"; return; fi
    fi
    # 3. Homebrew cask (only if actually installed locally)
    if command -v brew >/dev/null 2>&1; then
        v=$(brew list --cask --versions antigravity antigravity-linux 2>/dev/null | awk 'NR==1 {sub(/,.*/, "", $2); print $2}' || true)
        if [ -n "$v" ]; then echo "$v"; return; fi
    fi
    # 4. Fallback to state file if binary exists
    if [ -x "$BIN_DIR/antigravity" ] && [ -f "$STATE_FILE" ]; then
        v=$(awk -F'"' '/"version":/ {print $4; exit}' "$STATE_FILE" 2>/dev/null || true)
        if [ -n "$v" ]; then echo "$v"; return; fi
    fi
    echo ""
}

get_installed_ide_version() {
    local v=""
    local prod_json=""
    # 1. Check IDE 2.x binary install directory (~/.local/lib/antigravity-ide)
    for prod_json in "${APP_DIR}-ide/resources/app/product.json" \
                     "/Applications/Antigravity IDE.app/Contents/Resources/app/product.json" \
                     "/Applications/Google Antigravity.app/Contents/Resources/app/product.json" \
                     "$APP_DIR/resources/app/product.json"; do
        if [ -f "$prod_json" ]; then
            v=$(awk -F'"' '/"ideVersion":/ {print $4; exit}' "$prod_json")
            if [ -z "$v" ]; then
                v=$(awk -F'"' '/"version":/ {print $4; exit}' "$prod_json")
            fi
            if [ -n "$v" ]; then echo "$v"; return; fi
        fi
    done
    for prod_json in "${APP_DIR}-ide/resources/app/package.json" \
                     "/Applications/Antigravity IDE.app/Contents/Resources/app/package.json" \
                     "/Applications/Google Antigravity.app/Contents/Resources/app/package.json" \
                     "$APP_DIR/resources/app/package.json"; do
        if [ -f "$prod_json" ]; then
            v=$(awk -F'"' '/"version":/ {print $4; exit}' "$prod_json")
            if [ -n "$v" ]; then echo "$v"; return; fi
        fi
    done
    # 2. Check package managers (only actually installed packages)
    if command -v dpkg-query >/dev/null 2>&1; then
        v=$(dpkg-query -W -f='${Status} ${Version}\n' antigravity 2>/dev/null | awk '/^install ok installed/ {print $4}' || true)
        if [ -n "$v" ]; then echo "$v"; return; fi
    fi
    if command -v rpm >/dev/null 2>&1; then
        if rpm -q antigravity >/dev/null 2>&1; then
            v=$(rpm -q --qf "%{VERSION}" antigravity 2>/dev/null || true)
            if [ -n "$v" ]; then echo "$v"; return; fi
        fi
    fi
    if command -v brew >/dev/null 2>&1; then
        v=$(brew list --cask --versions antigravity-ide antigravity-ide-linux 2>/dev/null | awk 'NR==1 {sub(/,.*/, "", $2); print $2}' || true)
        if [ -n "$v" ]; then echo "$v"; return; fi
    fi
    echo ""
}

get_installed_cli_version() {
    if command -v agy >/dev/null 2>&1; then
        agy --version 2>/dev/null | awk '{print $NF}' || echo "Installed"
    elif [ -f "$BIN_DIR/agy" ]; then
        "$BIN_DIR/agy" --version 2>/dev/null | awk '{print $NF}' || echo "Installed"
    else
        echo ""
    fi
}

get_installed_sdk_version() {
    if command -v python3 >/dev/null 2>&1; then
        python3 -c 'import importlib.metadata; print(importlib.metadata.version("google-antigravity"))' 2>/dev/null || \
        python3 -m pip show google-antigravity 2>/dev/null | awk -F': ' '/^Version:/ {print $2}' || \
        echo ""
    else
        echo ""
    fi
}

print_system_info() {
    # --- Detect dynamic current versions ---
    local inst_agy
    inst_agy=$(get_installed_agy_version)
    local inst_ide
    inst_ide=$(get_installed_ide_version)
    local inst_cli
    inst_cli=$(get_installed_cli_version)
    local inst_sdk
    inst_sdk=$(get_installed_sdk_version)

    local agy_status
    if [ -n "$inst_agy" ]; then
        agy_status="${C_GREEN}✓ $inst_agy${C_RESET}"
    else
        agy_status="${C_YELLOW}Not Installed${C_RESET}"
    fi

    local ide_status
    if [ -n "$inst_ide" ]; then
        ide_status="${C_GREEN}✓ $inst_ide${C_RESET}"
    else
        ide_status="${C_YELLOW}Not Installed${C_RESET}"
    fi

    local cli_status
    if [ -n "$inst_cli" ]; then
        cli_status="${C_GREEN}✓ $inst_cli${C_RESET}"
    else
        cli_status="${C_YELLOW}Not Installed${C_RESET}"
    fi

    local sdk_status
    if [ -n "$inst_sdk" ]; then
        sdk_status="${C_GREEN}✓ $inst_sdk${C_RESET}"
    else
        sdk_status="${C_YELLOW}Not Installed${C_RESET}"
    fi

    # --- Build recommendation label ---
    local REC_LABEL=""
    case "$RECOMMENDED" in
        1) REC_LABEL="${C_GREEN}★ Homebrew${C_RESET} ${C_DIM}(best for this system)${C_RESET}" ;;
        2) REC_LABEL="${C_GREEN}★ System Repo${C_RESET} ${C_DIM}(best for this system)${C_RESET}" ;;
        3) REC_LABEL="${C_GREEN}★ Official Binary${C_RESET} ${C_DIM}(best for this system)${C_RESET}" ;;
    esac

    # --- Print dashboard ---
    log_info "  ${C_CYAN}OS:${C_RESET}                 ${C_BOLD}${DISTRO_PRETTY}${C_RESET} ${C_DIM}(${ARCH})${C_RESET}"
    log_info "  ${C_CYAN}Installed Products:${C_RESET}"
    log_info "    ${C_BOLD}Google Antigravity:${C_RESET}      ${agy_status} ${C_DIM}[Latest: $DEFAULT_AGY_VERSION]${C_RESET}"
    log_info "    ${C_BOLD}Google Antigravity IDE:${C_RESET}  ${ide_status} ${C_DIM}[Latest: $DEFAULT_IDE_VERSION]${C_RESET}"
    log_info "    ${C_BOLD}Antigravity CLI (agy):${C_RESET}   ${cli_status} ${C_DIM}[Latest: $DEFAULT_CLI_VERSION]${C_RESET}"
    log_info "    ${C_BOLD}Antigravity SDK (Python):${C_RESET} ${sdk_status} ${C_DIM}[Latest: $DEFAULT_SDK_VERSION]${C_RESET}"
    log_info "  ${C_CYAN}Best Install Method:${C_RESET}        ${REC_LABEL}"

    # --- Warnings (only shown when relevant) ---
    if [ -n "$GLIBC_VERSION" ]; then
        local MAJOR MINOR
        MAJOR=$(echo "$GLIBC_VERSION" | cut -d. -f1)
        MINOR=$(echo "$GLIBC_VERSION" | cut -d. -f2)
        if [ "$MAJOR" -lt 2 ] || { [ "$MAJOR" -eq 2 ] && [ "$MINOR" -lt 28 ]; }; then
            log_warn "glibc $GLIBC_VERSION < 2.28 — Antigravity may not work"
        fi
    fi
}

print_banner() {
    local mode="$1"
    echo ""
    cat << 'BANNER_EOF'
    [0;34m    _    [0;31m     _ [1;33m  _  [0;34m___[0;32m       [0;31m      [0;34m    _ _[0;31m      [1;33m   [0;34m    [0;32m       [0m
    [0;34m   / \   [0;31m_ __| |[1;33m_(_)/[0;34m __[0;32m|_ __ _[0;31m_ ___ [0;34m  _(_) [0;31m|_ _  [1;33m _ [0;34m    [0;32m       [0m
    [0;34m  / _ \ |[0;31m '_ \ _[1;33m_| | [0;34m|  [0;32m_| '__/[0;31m _` \ [0;34m\ / / |[0;31m __| |[1;33m | [0;34m|   [0;32m       [0m
    [0;34m / ___ \|[0;31m | | | [1;33m|_| |[0;34m |_[0;32m| | | |[0;31m (_| |[0;34m\ V /| [0;31m| |_| [1;33m|_|[0;34m |  [0;32m       [0m
    [0;34m/_/   \_\[0;31m_| |_|\[1;33m__|_|[0;34m\__[0;32m__|_|  [0;31m\__,_|[0;34m \_/ |_[0;31m|\__|\[1;33m__,[0;34m |  [0;32m       [0m
    [0;34m         [0;31m       [1;33m     [0;34m   [0;32m       [0;31m      [0;34m       [0;31m     |[1;33m___[0;34m/   [0;32m       [0m
BANNER_EOF
    echo -e "      ${C_BOLD}AGY Easy Install v${SCRIPT_VERSION}${C_RESET} ${mode}"
    echo -e "      ${C_DIM}github.com/wtg-codes/agy-easy-install${C_RESET}"
    echo -e "      ${C_DIM}──────────────────────────────────────────────────${C_RESET}"
}

