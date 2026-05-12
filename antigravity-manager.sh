#!/usr/bin/env bash
set -e

# Colors for a cooler terminal output
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'
C_MAG='\033[0;35m'
C_BOLD='\033[1m'
C_DIM='\033[2m'
C_RESET='\033[0m'

# Configuration
SCRIPT_VERSION="1.2.0"
KNOWN_SHA256="5232a4048ff4fa15685d9a981ba4fba573e297f3efc9b76f638e794baf775725"
DOWNLOAD_URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/1.23.2-4781536860569600/linux-x64/Antigravity.tar.gz"
MANAGER_URL="https://raw.githubusercontent.com/wtg-codes/agv-easy-install/main/antigravity-manager.sh"

# Directories (for Tarball install)
BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/.local/lib/antigravity"
WORKSPACE_DIR="$HOME/my-antigravity-work"
DESKTOP_DIR="$HOME/Desktop"

# State & Logging
STATE_DIR="$HOME/.config/antigravity"
STATE_FILE="$STATE_DIR/install.json"
LOG_FILE="/tmp/antigravity-install.log"
VERBOSE=0
QUIET=0
AUTO=0

log_info() {
    [ "$QUIET" -eq 1 ] && return
    echo -e "$1"
    # sed -E is supported on both macOS and Linux for extended regex
    echo "$(date '+%Y-%m-%d %H:%M:%S') INFO: $(echo "$1" | sed -E 's/\x1B\[[0-9;]*[mK]//g')" >> "$LOG_FILE"
}

log_error() {
    echo -e "${C_RED}❌ $1${C_RESET}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR: $(echo "$1" | sed -E 's/\x1B\[[0-9;]*[mK]//g')" >> "$LOG_FILE"
}

log_warn() {
    [ "$QUIET" -eq 1 ] && return
    echo -e "${C_YELLOW}⚠ $1${C_RESET}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') WARN: $(echo "$1" | sed -E 's/\x1B\[[0-9;]*[mK]//g')" >> "$LOG_FILE"
}

run_cmd() {
    if [ "$VERBOSE" -eq 1 ]; then
        "$@" 2>&1 | tee -a "$LOG_FILE"
    else
        "$@" >> "$LOG_FILE" 2>&1
    fi
}

check_dependencies() {
    local deps=("curl" "tar" "awk" "grep")
    local missing=0
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            echo -e "${C_RED}❌ Missing required dependency: $dep${C_RESET}"
            missing=1
        fi
    done
    if [ "$missing" -eq 1 ]; then
        echo -e "${C_RED}❌ Please install missing dependencies and try again.${C_RESET}"
        exit 1
    fi
    # Only touch log file if we pass basic checks
    touch "$LOG_FILE" || true
}

# Files
DESKTOP_FILE_SYS="$HOME/.local/share/applications/google-antigravity.desktop"
DESKTOP_FILE_USER="$DESKTOP_DIR/google-antigravity.desktop"
ICON_PATH="$APP_DIR/resources/app/out/vs/workbench/contrib/antigravityCustomAppIcon/browser/media/antigravity/antigravity.png"

verify_path() {
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        log_warn "$BIN_DIR is not in your PATH."
        if [ "$PLATFORM" = "Darwin" ] || [ -f "$HOME/.zshrc" ]; then
            log_info "  Add to ~/.zshrc:  ${C_BOLD}export PATH=\"\$HOME/.local/bin:\$PATH\"${C_RESET}"
        else
            log_info "  Add to ~/.bashrc: ${C_BOLD}export PATH=\"\$HOME/.local/bin:\$PATH\"${C_RESET}"
        fi
    fi
}

save_manager_locally() {
    log_info "${C_CYAN}💾 Saving Antigravity Manager to your system...${C_RESET}"
    mkdir -p "$BIN_DIR"
    
    # Smart copy: Prevent overwriting local tests with older GitHub versions
    if [ -f "$0" ] && [ -r "$0" ]; then
        cp "$0" "$BIN_DIR/antigravity-manager"
    else
        run_cmd curl -fSsL "$MANAGER_URL" -o "$BIN_DIR/antigravity-manager"
    fi
    
    chmod +x "$BIN_DIR/antigravity-manager"
    log_info "${C_GREEN}✅ Manager saved.${C_RESET} Run ${C_BOLD}antigravity-manager${C_RESET} anytime to manage the app."
    verify_path
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
    HAS_BREW="no"
    HAS_APT="no"
    HAS_DNF="no"
    DISTRO_PRETTY="Unknown"
    GLIBC_VERSION=""
    RECOMMENDED="3"  # default to tarball

    if check_brew; then
        HAS_BREW="yes"
    fi

    if [ "$PLATFORM" = "Darwin" ]; then
        DISTRO_PRETTY="macOS $(sw_vers -productVersion 2>/dev/null || echo '')"
        if [ "$HAS_BREW" = "yes" ]; then
            RECOMMENDED="1"
        else
            RECOMMENDED="3"
        fi
    else
        detect_distro
        if [ -f /etc/os-release ]; then
            # shellcheck disable=SC1091
            DISTRO_PRETTY=$(. /etc/os-release && echo "${PRETTY_NAME:-$ID}")
        fi

        if command -v apt >/dev/null 2>&1; then
            HAS_APT="yes"
        fi
        if command -v dnf >/dev/null 2>&1; then
            HAS_DNF="yes"
        fi

        GLIBC_VERSION=$(ldd --version 2>/dev/null | awk 'NR==1 {print $NF}' || true)

        if [ "$HAS_BREW" = "yes" ]; then
            RECOMMENDED="1"
        elif [ "$HAS_APT" = "yes" ] || [ "$HAS_DNF" = "yes" ]; then
            RECOMMENDED="2"
        else
            RECOMMENDED="3"
        fi
    fi
}

print_system_info() {
    local PKGS=""
    [ "$HAS_BREW" = "yes" ] && PKGS="${PKGS}brew "
    [ "$HAS_APT" = "yes" ]  && PKGS="${PKGS}apt "
    [ "$HAS_DNF" = "yes" ]  && PKGS="${PKGS}dnf "

    local PKG_DISPLAY
    if [ -z "$PKGS" ]; then
        PKG_DISPLAY="${C_YELLOW}none${C_RESET}"
    else
        PKG_DISPLAY="${C_GREEN}${PKGS}${C_RESET}"
    fi

    log_info "  ${C_CYAN}▸${C_RESET} ${C_BOLD}${DISTRO_PRETTY}${C_RESET} (${ARCH})$([ -n "$GLIBC_VERSION" ] && echo " · glibc ${GLIBC_VERSION}") · pkg: ${PKG_DISPLAY}"

    if [ -n "$GLIBC_VERSION" ]; then
        local MAJOR MINOR
        MAJOR=$(echo "$GLIBC_VERSION" | cut -d. -f1)
        MINOR=$(echo "$GLIBC_VERSION" | cut -d. -f2)
        if [ "$MAJOR" -lt 2 ] || { [ "$MAJOR" -eq 2 ] && [ "$MINOR" -lt 28 ]; }; then
            log_warn "glibc $GLIBC_VERSION < 2.28 — Antigravity may not work"
        fi
    fi
}

install_brew() {
    log_info "${C_MAG}🚀 Installing Antigravity via Homebrew...${C_RESET}"
    if ! check_brew; then
        log_error "Homebrew is not installed."
        if [ "$PLATFORM" = "Darwin" ]; then
            log_error "Tarball fallback is not supported on macOS. Exiting."
            exit 1
        else
            log_warn "Falling back to Tarball installation..."
            do_install_tarball
        fi
        return
    fi
    
    if [ "$PLATFORM" = "Darwin" ]; then
        if ! run_cmd brew install --cask antigravity; then
            log_error "Formula not found or installation failed."
            log_error "Tarball fallback is not supported on macOS. Exiting."
            exit 1
        fi
    else
        if ! run_cmd brew install antigravity; then
            log_error "Formula not found or installation failed."
            log_warn "Falling back to Tarball installation..."
            do_install_tarball
            return
        fi
    fi
    mkdir -p "$STATE_DIR"
    echo '{"method": "brew", "version": "'"$SCRIPT_VERSION"'"}' > "$STATE_FILE"
}

install_repo() {
    log_warn "This method requires sudo — you may be prompted for your password."
    detect_distro
    case "$DISTRO" in
        ubuntu|debian|kali|linuxmint)
            log_info "${C_BLUE}🔑 Fetching repository keys...${C_RESET}"
            run_cmd sudo mkdir -p /etc/apt/keyrings
            curl -fSsL "https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg" | \
                sudo gpg --dearmor --yes -o /etc/apt/keyrings/antigravity-repo-key.gpg || { log_error "Failed to fetch keys"; exit 1; }
            
            log_info "${C_BLUE}📦 Configuring APT repository...${C_RESET}"
            echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" | \
                sudo tee /etc/apt/sources.list.d/antigravity.list > /dev/null
            
            log_info "${C_BLUE}🔄 Updating package lists...${C_RESET}"
            if ! run_cmd sudo apt update || ! run_cmd sudo apt install -y antigravity; then
                log_error "Installation failed! Rolling back repository changes..."
                run_cmd sudo rm -f /etc/apt/sources.list.d/antigravity.list
                exit 1
            fi
            
            log_info "${C_GREEN}✅ Installation complete!${C_RESET} Launch with: ${C_BOLD}antigravity${C_RESET}"
            ;;
        fedora|rhel|centos|amzn)
            log_info "${C_BLUE}📦 Setting up RPM repository...${C_RESET}"
            sudo tee /etc/yum.repos.d/antigravity.repo > /dev/null << EOL
[antigravity-rpm]
name=Antigravity RPM Repository
baseurl=https://us-central1-yum.pkg.dev/projects/antigravity-auto-updater-dev/antigravity-rpm
enabled=1
# Set gpgcheck=0 because Artifact Registry doesn't support RPM upstream signing yet
gpgcheck=0
EOL
            if ! run_cmd sudo dnf makecache || ! run_cmd sudo dnf install -y antigravity; then
                log_error "Installation failed! Rolling back repository changes..."
                run_cmd sudo rm -f /etc/yum.repos.d/antigravity.repo
                exit 1
            fi
            log_info "${C_GREEN}✅ Installation complete!${C_RESET} Launch with: ${C_BOLD}antigravity${C_RESET}"
            ;;
        *)
            log_error "Distribution $DISTRO not explicitly supported for repo install."
            if [ "$PLATFORM" = "Darwin" ]; then
                log_error "Tarball fallback is not supported on macOS. Exiting."
                exit 1
            else
                log_warn "Falling back to Tarball installation..."
                do_install_tarball
                return
            fi
            ;;
    esac
    mkdir -p "$STATE_DIR"
    echo '{"method": "repo", "version": "'"$SCRIPT_VERSION"'"}' > "$STATE_FILE"
}

do_install_tarball() {
    if ! command -v sha256sum >/dev/null 2>&1; then
        log_error "sha256sum is required for tarball install but was not found."
        exit 1
    fi

    log_info "${C_MAG}🚀 Starting Google Antigravity Standalone (Tarball) Installation...${C_RESET}"

    log_info "${C_CYAN}📁 Preparing directories...${C_RESET}"
    mkdir -p "$BIN_DIR" "$APP_DIR" "$WORKSPACE_DIR" "$DESKTOP_DIR" "$(dirname "$DESKTOP_FILE_SYS")"

    TMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TMP_DIR"' EXIT

    log_info "${C_BLUE}⬇️  Downloading Antigravity (~218 MB)...${C_RESET}"
    if [ "$VERBOSE" -eq 1 ]; then
        curl -fSL "$DOWNLOAD_URL" -o "$TMP_DIR/Antigravity.tar.gz" 2>&1 | tee -a "$LOG_FILE"
    else
        curl -fSL --progress-bar "$DOWNLOAD_URL" -o "$TMP_DIR/Antigravity.tar.gz"
    fi

    log_info "${C_BLUE}🔐 Verifying checksum...${C_RESET}"
    if ! echo "$KNOWN_SHA256  $TMP_DIR/Antigravity.tar.gz" | sha256sum -c - >/dev/null 2>&1; then
        log_error "Checksum verification failed!"
        exit 1
    fi

    log_info "${C_BLUE}📦 Extracting archive...${C_RESET}"
    run_cmd tar -xzf "$TMP_DIR/Antigravity.tar.gz" -C "$APP_DIR" --strip-components=1

    log_info "${C_BLUE}🔗 Creating symlink...${C_RESET}"
    ln -sf "$APP_DIR/antigravity" "$BIN_DIR/antigravity"

    log_info "${C_BLUE}🖼️  Registering application icon...${C_RESET}"
    cat << EOF > "$DESKTOP_FILE_SYS"
[Desktop Entry]
Version=1.0
Name=Google Antigravity
Comment=Secure Agentic Development IDE
Exec=$BIN_DIR/antigravity %F
Icon=$ICON_PATH
Terminal=false
Type=Application
Categories=Development;IDE;
EOF

    if [ "$PLATFORM" != "Darwin" ]; then
        log_info "${C_CYAN}🖥️  Adding shortcut to Desktop...${C_RESET}"
        if command -v xdg-user-dir &> /dev/null; then
            DESKTOP_DIR=$(xdg-user-dir DESKTOP)
        else
            DESKTOP_DIR="$HOME/Desktop"
        fi
        DESKTOP_FILE_USER="$DESKTOP_DIR/google-antigravity.desktop"
        cp "$DESKTOP_FILE_SYS" "$DESKTOP_FILE_USER"
        chmod +x "$DESKTOP_FILE_USER"
        
        if command -v gio &> /dev/null; then
            run_cmd gio set "$DESKTOP_FILE_USER" metadata::trusted true || true
        fi

        # Refresh app menu
        if command -v update-desktop-database &> /dev/null; then
            run_cmd update-desktop-database "$HOME/.local/share/applications" || true
        fi
    fi

    echo ""
    log_info "${C_GREEN}${C_BOLD}🎉 Installation Complete!${C_RESET}"
    log_info "  ${C_CYAN}▸${C_RESET} Launch:    ${C_BOLD}antigravity${C_RESET}"
    log_info "  ${C_CYAN}▸${C_RESET} Workspace: ${C_BOLD}$WORKSPACE_DIR${C_RESET}"
    log_info "  ${C_CYAN}▸${C_RESET} Manager:   ${C_BOLD}antigravity-manager${C_RESET}"
    
    mkdir -p "$STATE_DIR"
    echo '{"method": "tarball", "version": "'"$SCRIPT_VERSION"'"}' > "$STATE_FILE"
}

do_remove() {
    if [ "$AUTO" -ne 1 ]; then
        echo -ne "${C_RED}⚠ Are you sure you want to uninstall Antigravity? [y/N]: ${C_RESET}"
        read confirm < /dev/tty
        case "$confirm" in
            [yY]|[yY][eE][sS]) ;;
            *) log_warn "Cancelled."; return ;;
        esac
    fi
    log_info "${C_RED}🧹 Removing Google Antigravity...${C_RESET}"
    
    # Deterministic uninstall using STATE_FILE
    if [ -f "$STATE_FILE" ]; then
        local method
        method=$(grep -o '"method": "[^"]*' "$STATE_FILE" | grep -o '[^"]*$')
        log_info "Found installation state. Method used: $method"
        
        case "$method" in
            "brew")
                if [ "$PLATFORM" = "Darwin" ]; then
                    run_cmd brew uninstall --cask antigravity || true
                else
                    run_cmd brew uninstall antigravity || true
                fi
                ;;
            "repo")
                detect_distro
                if command -v apt &> /dev/null && [ -f /etc/apt/sources.list.d/antigravity.list ]; then
                    run_cmd sudo apt remove -y antigravity || true
                    sudo rm -f /etc/apt/sources.list.d/antigravity.list
                elif command -v dnf &> /dev/null && [ -f /etc/yum.repos.d/antigravity.repo ]; then
                    run_cmd sudo dnf remove -y antigravity || true
                    sudo rm -f /etc/yum.repos.d/antigravity.repo
                fi
                ;;
            "tarball")
                # Tarball cleanup happens for all as fallback below
                ;;
        esac
        rm -f "$STATE_FILE"
    else
        log_warn "No state file found. Using heuristic removal..."
        # Heuristic fallback
        detect_distro
        if command -v apt &> /dev/null && [ -f /etc/apt/sources.list.d/antigravity.list ]; then
            run_cmd sudo apt remove -y antigravity || true
            sudo rm -f /etc/apt/sources.list.d/antigravity.list
        elif command -v dnf &> /dev/null && [ -f /etc/yum.repos.d/antigravity.repo ]; then
            run_cmd sudo dnf remove -y antigravity || true
            sudo rm -f /etc/yum.repos.d/antigravity.repo
        elif check_brew; then
            if [ "$PLATFORM" = "Darwin" ]; then
                run_cmd brew uninstall --cask antigravity || true
            else
                run_cmd brew uninstall antigravity || true
            fi
        fi
    fi

    # Cleanup standalone files (always run to be safe)
    rm -rf "$APP_DIR"
    rm -f "$BIN_DIR/antigravity"
    rm -f "$DESKTOP_FILE_SYS"
    rm -f "$DESKTOP_FILE_USER"
    
    if command -v update-desktop-database &> /dev/null; then
        run_cmd update-desktop-database "$HOME/.local/share/applications" || true
    fi
    
    log_info "${C_GREEN}✅ Uninstalled successfully.${C_RESET} (Note: Your code in $WORKSPACE_DIR was kept safe)."
}

print_usage() {
    echo -e "${C_BOLD}Antigravity Manager v${SCRIPT_VERSION}${C_RESET}"
    echo -e "${C_DIM}Usage:${C_RESET} $0 [OPTION]"
    echo "  --install         Interactive installation wizard (default)"
    echo "  --auto            Headless auto-install (picks recommended method)"
    echo "  --install-brew    Headless Homebrew install"
    echo "  --install-repo    Headless System Repo install"
    echo "  --install-tarball Headless Tarball install"
    echo "  --remove          Uninstall Antigravity"
    echo "  --verbose         Enable verbose logging (outputs to terminal and $LOG_FILE)"
    echo "  --quiet           Suppress non-error output"
    echo "  --version         Show version"
    echo "  --help            Show this help"
}

# Parse CLI arguments
ACTION=""
for arg in "$@"; do
    case "$arg" in
        --install) ACTION="install" ;;
        --auto) ACTION="auto"; AUTO=1 ;;
        --install-brew) ACTION="brew"; AUTO=1 ;;
        --install-repo) ACTION="repo"; AUTO=1 ;;
        --install-tarball) ACTION="tarball"; AUTO=1 ;;
        --remove) ACTION="remove" ;;
        --verbose) VERBOSE=1 ;;
        --quiet) QUIET=1 ;;
        --version) ACTION="version" ;;
        --help) ACTION="help" ;;
    esac
done

if [ "$ACTION" = "version" ]; then
    echo "Antigravity Manager v$SCRIPT_VERSION"
    exit 0
elif [ "$ACTION" = "help" ]; then
    print_usage
    exit 0
fi

# We only check dependencies for commands that do work
check_dependencies
detect_platform

case "$ACTION" in
    remove)
        do_remove
        exit 0
        ;;
    auto)
        log_info "${C_MAG}🚀 Starting headless auto-install...${C_RESET}"
        if [ "$RECOMMENDED" = "1" ]; then install_brew; save_manager_locally
        elif [ "$RECOMMENDED" = "2" ]; then install_repo; save_manager_locally
        else do_install_tarball; save_manager_locally
        fi
        exit 0
        ;;
    brew)
        install_brew; save_manager_locally
        exit 0
        ;;
    repo)
        install_repo; save_manager_locally
        exit 0
        ;;
    tarball)
        do_install_tarball; save_manager_locally
        exit 0
        ;;
    install|"")
        log_info "${C_BLUE}${C_BOLD}========== 🚀 Google Antigravity Setup v${SCRIPT_VERSION} ==========${C_RESET}"
        print_system_info
        echo ""
        echo -e "${C_BOLD}Select an install method${C_RESET} ${C_GREEN}(★ = recommended)${C_RESET}"
        echo -e "  ${C_CYAN}1)${C_RESET} Homebrew      $([ "$RECOMMENDED" = "1" ] && echo -e "${C_GREEN}★${C_RESET}  ") ${C_GREEN}cross-platform, no sudo${C_RESET}"
        echo -e "  ${C_CYAN}2)${C_RESET} System Repo   $([ "$RECOMMENDED" = "2" ] && echo -e "${C_GREEN}★${C_RESET}  ") ${C_GREEN}APT/DNF, auto-updates, needs sudo${C_RESET}"
        echo -e "  ${C_CYAN}3)${C_RESET} Tarball       $([ "$RECOMMENDED" = "3" ] && echo -e "${C_GREEN}★${C_RESET}  ") ${C_YELLOW}manual, installs to ~/.local${C_RESET}"
        echo -e "  ${C_CYAN}4)${C_RESET} Save manager  ${C_CYAN}add 'antigravity-manager' command${C_RESET}"
        echo -e "  ${C_CYAN}5)${C_RESET} Uninstall     ${C_RED}remove Antigravity${C_RESET}"
        echo -e "  ${C_CYAN}6)${C_RESET} Remove manager"
        echo -e "  ${C_CYAN}7)${C_RESET} Cancel"
        echo -ne "${C_BOLD}Pick [1-7]: ${C_RESET}"
        read choice < /dev/tty
    
        echo "" # Add a blank line for breathing room
    
        case "$choice" in
            1) install_brew; echo ""; save_manager_locally ;;
            2) install_repo; echo ""; save_manager_locally ;;
            3) do_install_tarball; echo ""; save_manager_locally ;;
            4) save_manager_locally ;;
            5) do_remove ;;
            6) remove_manager_script ;;
            "Google"|"google"|"GOOGLE")
                log_info "${C_MAG}🎓 Easter Egg Found! Opening the Course Catalog Lab...${C_RESET}"
                if [ "$PLATFORM" = "Darwin" ]; then
                    open "https://wtg-codes.github.io/course-catalog/" >/dev/null 2>&1 || log_warn "Please open this link in your browser: https://wtg-codes.github.io/course-catalog/"
                elif command -v xdg-open >/dev/null 2>&1; then
                    xdg-open "https://wtg-codes.github.io/course-catalog/" >/dev/null 2>&1 || log_warn "Please open this link in your browser: https://wtg-codes.github.io/course-catalog/"
                else
                    log_warn "Please open this link in your browser: https://wtg-codes.github.io/course-catalog/"
                fi
                ;;
            *) log_warn "Cancelled."; exit 0 ;;
        esac
        ;;
esac
