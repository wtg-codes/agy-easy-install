install_brew() {
    local product_name="${1:-antigravity}"
    JSON_METHOD="brew"

    local app_title="Google Antigravity"
    local mac_cask="antigravity"
    local linux_cask="ublue-os/tap/antigravity-linux"
    local linux_cask_token="antigravity-linux"
    local bin_name="antigravity"
    local state_target="$STATE_FILE"

    if [ "$product_name" = "ide" ]; then
        app_title="Google Antigravity IDE"
        mac_cask="antigravity-ide"
        linux_cask="ublue-os/tap/antigravity-ide-linux"
        linux_cask_token="antigravity-ide-linux"
        bin_name="antigravity-ide"
        state_target="${STATE_DIR}/install-ide.json"
    fi

    log_info "${C_MAG}🚀 Installing $app_title via Homebrew...${C_RESET}"
    ensure_brew

    if [ "$PLATFORM" = "Darwin" ]; then
        if ! run_cmd_ui "Brewing $app_title..." brew install --cask "$mac_cask"; then
            log_error "Cask '$mac_cask' installation failed."
            log_warn "Falling back to official Binary installation..."
            do_install_binary "$product_name"
            return
        fi
        # Ensure CLI shim exists for Hub on macOS (cask only installs Antigravity.app)
        if [ "$product_name" = "antigravity" ] && [ -x "/Applications/Antigravity.app/Contents/MacOS/Antigravity" ] && ! command -v antigravity >/dev/null 2>&1; then
            mkdir -p "$BIN_DIR"
            ln -sf "/Applications/Antigravity.app/Contents/MacOS/Antigravity" "$BIN_DIR/antigravity"
        fi
    else
        # Linux Homebrew (Universal Blue official tap: ublue-os/tap)
        run_cmd_ui "Tapping ublue-os/tap..." brew tap ublue-os/tap
        if ! run_cmd_ui "Brewing $app_title ($linux_cask)..." brew install --cask "$linux_cask"; then
            log_error "Cask '$linux_cask' installation failed."
            log_warn "Falling back to official Binary installation..."
            do_install_binary "$product_name"
            return
        fi
        local brew_prefix
        brew_prefix=$(brew --prefix)
        if [ ! -x "$brew_prefix/bin/$bin_name" ]; then
            local exec_file
            exec_file=$(find "$brew_prefix/Caskroom/$linux_cask_token" -type f -name "$bin_name" 2>/dev/null | head -n 1)
            if [ -n "$exec_file" ]; then
                log_info "Creating missing binary symlink in Homebrew bin folder..."
                run_cmd ln -sf "$exec_file" "$brew_prefix/bin/$bin_name"
            fi
        fi
        if command -v xdg-mime >/dev/null 2>&1; then
            run_cmd xdg-mime default "${bin_name}-url-handler.desktop" "x-scheme-handler/${bin_name}" || true
        fi
        if command -v update-desktop-database >/dev/null 2>&1; then
            run_cmd update-desktop-database "$HOME/.local/share/applications" || true
        fi
    fi
    configure_chrome_path "$product_name"
    mkdir -p "$STATE_DIR"
    echo '{"method": "brew", "product": "'"$product_name"'", "version": "'"$SCRIPT_VERSION"'"}' > "$state_target"
}

install_repo() {
    JSON_METHOD="repo"
    if [ "${IS_ATOMIC:-no}" = "yes" ]; then
        log_error "Atomic/Immutable Linux detected (/usr is read-only). Use --install-brew or --install-binary instead."
        exit 1
    fi
    log_warn "Note: Upstream APT/RPM repositories currently publish legacy Antigravity 1.x. Use --install-binary or --install-brew for 2.x."
    local sudo_prefix=()
    if [ "$(id -u)" -ne 0 ]; then
        log_warn "This method requires sudo — you may be prompted for your password."
        sudo -v || { log_error "Sudo access required."; exit 1; }
        sudo_prefix=(sudo)
    fi
    detect_distro
    case "$DISTRO" in
        ubuntu|debian|kali|linuxmint|pop)
            log_info "${C_BLUE}🔑 Fetching repository keys...${C_RESET}"
            run_cmd "${sudo_prefix[@]}" mkdir -p /etc/apt/keyrings
            curl -fSsL "https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg" | \
                "${sudo_prefix[@]}" gpg --dearmor --yes -o /etc/apt/keyrings/antigravity-repo-key.gpg || { log_error "Failed to fetch keys"; exit 1; }
            
            log_info "${C_BLUE}📦 Configuring APT repository...${C_RESET}"
            echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" | \
                "${sudo_prefix[@]}" tee /etc/apt/sources.list.d/antigravity.list > /dev/null
            
            if ! run_cmd_ui "Updating package lists..." "${sudo_prefix[@]}" apt-get update || ! run_cmd_ui "Installing Antigravity..." "${sudo_prefix[@]}" apt-get install -y antigravity; then
                log_error "Installation failed! Rolling back repository changes..."
                run_cmd "${sudo_prefix[@]}" rm -f /etc/apt/sources.list.d/antigravity.list
                exit 1
            fi
            log_info "${C_GREEN}✅ Installation complete!${C_RESET} Launch with: ${C_BOLD}antigravity${C_RESET}"
            ;;
        fedora|rhel|centos|amzn|rocky|almalinux)
            log_info "${C_BLUE}📦 Setting up RPM repository...${C_RESET}"
            "${sudo_prefix[@]}" tee /etc/yum.repos.d/antigravity.repo > /dev/null << EOL
[antigravity-rpm]
name=Antigravity RPM Repository
baseurl=https://us-central1-yum.pkg.dev/projects/antigravity-auto-updater-dev/antigravity-rpm
enabled=1
gpgcheck=0
EOL
            if ! run_cmd_ui "Updating package cache..." "${sudo_prefix[@]}" dnf makecache || ! run_cmd_ui "Installing Antigravity..." "${sudo_prefix[@]}" dnf install -y antigravity; then
                log_error "Installation failed! Rolling back repository changes..."
                run_cmd "${sudo_prefix[@]}" rm -f /etc/yum.repos.d/antigravity.repo
                exit 1
            fi
            log_info "${C_GREEN}✅ Installation complete!${C_RESET} Launch with: ${C_BOLD}antigravity${C_RESET}"
            ;;
        *)
            log_error "Distribution $DISTRO not explicitly supported for repo install."
            if [ "$PLATFORM" = "Darwin" ]; then exit 1; fi
            log_warn "Falling back to official Binary installation..."
            do_install_binary "ide"
            return
            ;;
    esac
    configure_chrome_path "ide"
    mkdir -p "$STATE_DIR"
    echo '{"method": "repo", "version": "'"$SCRIPT_VERSION"'"}' > "$STATE_FILE"
}

get_ide_release_info() {
    get_product_release_info "ide" "$@"
}

get_product_release_info() {
    local product_name="$1"
    local version="$2"
    local platform_key="$3"
    local json_file="${VERSIONS_JSON_CACHE:-}"
    
    if [ -z "$json_file" ] || [ ! -s "$json_file" ]; then
        if [ "$product_name" = "antigravity" ] && [ "$version" = "$DEFAULT_AGY_VERSION" ]; then
            case "$platform_key" in
                LINUX_X64) echo "$AGY_LINUX_X64_URL|$AGY_LINUX_X64_SHA256" ;;
                LINUX_ARM64) echo "$AGY_LINUX_ARM64_URL|$AGY_LINUX_ARM64_SHA256" ;;
                MAC_X64) echo "$AGY_MAC_X64_URL|$AGY_MAC_X64_SHA256" ;;
                MAC_ARM64) echo "$AGY_MAC_ARM64_URL|$AGY_MAC_ARM64_SHA256" ;;
                WIN_X64) echo "$AGY_WIN_X64_URL|$AGY_WIN_X64_SHA256" ;;
                WIN_ARM64) echo "$AGY_WIN_ARM64_URL|$AGY_WIN_ARM64_SHA256" ;;
            esac
            return
        elif [ "$product_name" = "ide" ] && [ "$version" = "$DEFAULT_IDE_VERSION" ]; then
            case "$platform_key" in
                LINUX_X64) echo "$IDE_LINUX_X64_URL|$IDE_LINUX_X64_SHA256" ;;
                LINUX_ARM64) echo "$IDE_LINUX_ARM64_URL|$IDE_LINUX_ARM64_SHA256" ;;
                MAC_X64) echo "$IDE_MAC_X64_URL|$IDE_MAC_X64_SHA256" ;;
                MAC_ARM64) echo "$IDE_MAC_ARM64_URL|$IDE_MAC_ARM64_SHA256" ;;
                WIN_X64) echo "$IDE_WIN_X64_URL|$IDE_WIN_X64_SHA256" ;;
                WIN_ARM64) echo "$IDE_WIN_ARM64_URL|$IDE_WIN_ARM64_SHA256" ;;
            esac
            return
        fi
        echo "|"
        return
    fi
    
    local info
    info=$(awk -v prod="$product_name" -v ver="$version" -v plat="$platform_key" '
      BEGIN { in_prod=0; in_ver=0; in_plat=0 }
      $0 == "  \"" prod "\": {" { in_prod=1; next }
      in_prod && $0 ~ "^  }" { in_prod=0; next }
      in_prod && $0 == "    \"" ver "\": {" { in_ver=1; next }
      in_ver && $0 ~ "^    }" { in_ver=0; next }
      in_ver && $0 == "      \"" plat "\": {" { in_plat=1; next }
      in_plat && $0 ~ "^      }" { in_plat=0; next }
      in_plat && $0 ~ "\"url\":" { split($0, a, "\""); url=a[4] }
      in_plat && $0 ~ "\"sha256\":" { split($0, a, "\""); sha=a[4] }
      END { if (url != "" && sha != "") print url "|" sha }
    ' "$json_file" 2>/dev/null || true)
    
    if [ -n "$info" ]; then
        echo "$info"
    else
        if [ "$product_name" = "antigravity" ] && [ "$version" = "$DEFAULT_AGY_VERSION" ]; then
            case "$platform_key" in
                LINUX_X64) echo "$AGY_LINUX_X64_URL|$AGY_LINUX_X64_SHA256" ;;
                LINUX_ARM64) echo "$AGY_LINUX_ARM64_URL|$AGY_LINUX_ARM64_SHA256" ;;
                MAC_X64) echo "$AGY_MAC_X64_URL|$AGY_MAC_X64_SHA256" ;;
                MAC_ARM64) echo "$AGY_MAC_ARM64_URL|$AGY_MAC_ARM64_SHA256" ;;
                WIN_X64) echo "$AGY_WIN_X64_URL|$AGY_WIN_X64_SHA256" ;;
                WIN_ARM64) echo "$AGY_WIN_ARM64_URL|$AGY_WIN_ARM64_SHA256" ;;
            esac
        elif [ "$product_name" = "ide" ] && [ "$version" = "$DEFAULT_IDE_VERSION" ]; then
            case "$platform_key" in
                LINUX_X64) echo "$IDE_LINUX_X64_URL|$IDE_LINUX_X64_SHA256" ;;
                LINUX_ARM64) echo "$IDE_LINUX_ARM64_URL|$IDE_LINUX_ARM64_SHA256" ;;
                MAC_X64) echo "$IDE_MAC_X64_URL|$IDE_MAC_X64_SHA256" ;;
                MAC_ARM64) echo "$IDE_MAC_ARM64_URL|$IDE_MAC_ARM64_SHA256" ;;
                WIN_X64) echo "$IDE_WIN_X64_URL|$IDE_WIN_X64_SHA256" ;;
                WIN_ARM64) echo "$IDE_WIN_ARM64_URL|$IDE_WIN_ARM64_SHA256" ;;
            esac
        else
            echo "|"
        fi
    fi
}

do_install_binary() {
    local product_name="${1:-antigravity}"
    local target_version="$2"
    if [ -z "$target_version" ]; then
        if [ "$product_name" = "ide" ]; then
            target_version="$DEFAULT_IDE_VERSION"
        else
            target_version="$DEFAULT_AGY_VERSION"
        fi
    fi

    JSON_METHOD="binary"
    local target_url=""
    local target_sha=""
    local install_type=""
    local file_ext=""
    local platform_key=""

    # Set up correct directories and symlinks depending on the product
    local app_dir_var="$APP_DIR"
    local bin_name="antigravity"
    local desktop_file_sys_var="$DESKTOP_FILE_SYS"
    local desktop_file_user_var="$DESKTOP_FILE_USER"
    local icon_path_var="$ICON_PATH"
    local app_title="Google Antigravity"
    local state_file_var="$STATE_FILE"

    if [ "$product_name" = "ide" ]; then
        app_dir_var="${APP_DIR}-ide"
        bin_name="antigravity-ide"
        desktop_file_sys_var="$HOME/.local/share/applications/google-antigravity-ide.desktop"
        if command -v xdg-user-dir &> /dev/null; then DESKTOP_DIR=$(xdg-user-dir DESKTOP); else DESKTOP_DIR="$HOME/Desktop"; fi
        desktop_file_user_var="$DESKTOP_DIR/google-antigravity-ide.desktop"
        icon_path_var="${app_dir_var}/resources/icon.png"
        app_title="Google Antigravity IDE"
        state_file_var="${STATE_DIR}/install-ide.json"
    fi

    # Determine target based on platform and architecture
    if [ "$PLATFORM" = "Darwin" ]; then
        install_type="dmg"
        file_ext="dmg"
        if [ "$ARCH" = "arm64" ]; then
            platform_key="MAC_ARM64"
        else
            platform_key="MAC_X64"
        fi
    elif [ "$WSL_DISTRO_NAME" != "" ] || [ "$OSTYPE" = "msys" ] || [ "$OSTYPE" = "cygwin" ]; then
        install_type="exe"
        file_ext="exe"
        if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
            platform_key="WIN_ARM64"
        else
            platform_key="WIN_X64"
        fi
    elif [ "$PLATFORM" = "Linux" ] || [ "$PLATFORM" = "Crostini" ]; then
        if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
            platform_key="LINUX_ARM64"
        else
            platform_key="LINUX_X64"
        fi
        install_type="tarball"
        file_ext="tar.gz"
    else
        log_error "Unsupported platform for binary installation."
        exit 1
    fi

    # Fetch release details dynamically
    fetch_versions_json || true
    local info
    info=$(get_product_release_info "$product_name" "$target_version" "$platform_key")
    target_url=$(echo "$info" | cut -d'|' -f1)
    target_sha=$(echo "$info" | cut -d'|' -f2)

    if { [ -z "$target_url" ] || [ -z "$target_sha" ]; } && [ "$platform_key" = "LINUX_ARM64" ]; then
        log_warn "No native ARM64 package found for $app_title $target_version; checking x64 fallback..."
        platform_key="LINUX_X64"
        info=$(get_product_release_info "$product_name" "$target_version" "$platform_key")
        target_url=$(echo "$info" | cut -d'|' -f1)
        target_sha=$(echo "$info" | cut -d'|' -f2)
    fi

    if [ -z "$target_url" ] || [ -z "$target_sha" ]; then
        log_error "Could not find package details for $app_title version $target_version ($platform_key)."
        exit 1
    fi

    local sha_cmd=""
    if command -v sha256sum >/dev/null 2>&1; then
        sha_cmd="sha256sum"
    elif command -v shasum >/dev/null 2>&1; then
        sha_cmd="shasum -a 256"
    else
        log_error "sha256sum or shasum is required but was not found."
        exit 1
    fi

    log_info "${C_MAG}🚀 Starting $app_title Official Binary Installation ($target_version)...${C_RESET}"
    
    ACTIVE_TMP_DIR=$(mktemp -d)
    local dl_target="$ACTIVE_TMP_DIR/Antigravity.$file_ext"

    if [ "$JSON_OUT" -eq 1 ] || [ "$QUIET" -eq 1 ] || [ ! -t 2 ]; then
        run_cmd curl -fSsL "$target_url" -o "$dl_target"
    else
        log_info "${C_BLUE}⬇️  Downloading $app_title...${C_RESET}"
        curl -fSL --progress-bar "$target_url" -o "$dl_target"
    fi

    log_info "${C_BLUE}🔐 Verifying checksum...${C_RESET}"
    if ! echo "$target_sha  $dl_target" | $sha_cmd -c - >/dev/null 2>&1; then
        log_error "Checksum verification failed!"
        rm -rf "$ACTIVE_TMP_DIR"
        ACTIVE_TMP_DIR=""
        exit 1
    fi

    if [ "$install_type" = "tarball" ]; then
        log_info "${C_CYAN}📁 Preparing directories...${C_RESET}"
        rm -rf "${app_dir_var:?}"
        mkdir -p "$BIN_DIR" "$app_dir_var" "$WORKSPACE_DIR" "$(dirname "$desktop_file_sys_var")" "$HOME/.local/share/icons/hicolor/512x512/apps"

        if [ "$JSON_OUT" -eq 0 ] && [ "$QUIET" -eq 0 ] && [ -t 1 ] && command -v gum >/dev/null 2>&1; then
            gum spin --spinner dot --title "Extracting archive..." -- tar -xzf "$dl_target" -C "$app_dir_var" --strip-components=1
        else
            tar -xzf "$dl_target" -C "$app_dir_var" --strip-components=1
        fi

        # Disable Electron built-in auto-update descriptor for standalone tarball installs
        rm -f "$app_dir_var/resources/app-update.yml"

        log_info "${C_BLUE}🔗 Creating symlink...${C_RESET}"
        local target_exec="$app_dir_var/antigravity"
        if [ "$product_name" = "ide" ]; then
            if [ -x "$app_dir_var/bin/antigravity-ide" ]; then
                target_exec="$app_dir_var/bin/antigravity-ide"
            elif [ -x "$app_dir_var/antigravity-ide" ]; then
                target_exec="$app_dir_var/antigravity-ide"
            elif [ -x "$app_dir_var/bin/antigravity" ]; then
                target_exec="$app_dir_var/bin/antigravity"
            fi
            ln -sf "$target_exec" "$BIN_DIR/agy-ide"
        else
            if [ -x "$app_dir_var/bin/antigravity" ]; then
                target_exec="$app_dir_var/bin/antigravity"
            elif [ -x "$app_dir_var/antigravity" ]; then
                target_exec="$app_dir_var/antigravity"
            fi
        fi
        ln -sf "$target_exec" "$BIN_DIR/$bin_name"

        # Extract/Copy application icon
        log_info "${C_CYAN}🎨 Extracting application icon...${C_RESET}"
        local extracted_icon=0
        
        # 1. Try copying unpacked icon from IDE 2.x or legacy 1.x locations
        local ide_v2_icon="${app_dir_var}/resources/app/resources/linux/code.png"
        local old_icon_location="${app_dir_var}/resources/app/out/vs/workbench/contrib/antigravityCustomAppIcon/browser/media/antigravity/antigravity.png"
        if [ -f "$ide_v2_icon" ]; then
            mkdir -p "$(dirname "$icon_path_var")"
            cp "$ide_v2_icon" "$icon_path_var"
            extracted_icon=1
        elif [ -f "$old_icon_location" ]; then
            mkdir -p "$(dirname "$icon_path_var")"
            cp "$old_icon_location" "$icon_path_var"
            extracted_icon=1
        fi

        # 2. Try extracting from app.asar (for 2.x Google Antigravity Hub)
        # Chromium Pickle ASAR header: <IIII = (pickle_size=4, header_size, header_str_size, json_size)
        # File data payload starts at byte offset (8 + header_size + file_offset).
        if [ "$extracted_icon" -eq 0 ] && [ -f "${app_dir_var}/resources/app.asar" ] && command -v python3 >/dev/null 2>&1; then
            if python3 -c '
import struct, json, os, sys
asar_path, icon_out = sys.argv[1], sys.argv[2]
try:
    with open(asar_path, "rb") as f:
        header = f.read(16)
        if len(header) == 16:
            _, header_size, _, json_size = struct.unpack("<IIII", header)
            header_json = json.loads(f.read(json_size).decode("utf-8"))
            info = header_json.get("files", {}).get("icon.png")
            if info and "offset" in info and "size" in info:
                f.seek(8 + header_size + int(info["offset"]))
                data = f.read(int(info["size"]))
                if data[:8] == b"\x89PNG\r\n\x1a\n":
                    os.makedirs(os.path.dirname(icon_out), exist_ok=True)
                    with open(icon_out, "wb") as out:
                        out.write(data)
                    print("OK")
except Exception:
    pass
' "${app_dir_var}/resources/app.asar" "$icon_path_var" 2>/dev/null | grep -q "OK"; then
                extracted_icon=1
            fi
        fi

        if [ "$extracted_icon" -eq 0 ] && [ -f "${app_dir_var}/resources/app.asar" ] && command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
            if (
                cd "$ACTIVE_TMP_DIR" || exit 1
                if npx --yes @electron/asar extract-file "${app_dir_var}/resources/app.asar" icon.png 2>/dev/null; then
                    mkdir -p "$(dirname "$icon_path_var")"
                    mv icon.png "$icon_path_var"
                elif npx --yes asar extract-file "${app_dir_var}/resources/app.asar" icon.png 2>/dev/null; then
                    mkdir -p "$(dirname "$icon_path_var")"
                    mv icon.png "$icon_path_var"
                else
                    exit 1
                fi
            ); then
                extracted_icon=1
            fi
        fi

        if [ "$extracted_icon" -eq 1 ]; then
            cp "$icon_path_var" "$HOME/.local/share/icons/hicolor/512x512/apps/${bin_name}.png" 2>/dev/null || true
        else
            log_warn "Could not extract application icon. Desktop shortcut will use a default icon."
        fi

        local wm_class="Antigravity"
        local mime_types="x-scheme-handler/antigravity;"
        local url_exec="\"$BIN_DIR/$bin_name\" \"%U\""
        if [ "$product_name" = "ide" ]; then
            wm_class="Antigravity IDE"
            mime_types="text/plain;inode/directory;application/x-code-workspace;x-scheme-handler/antigravity-ide;"
            url_exec="\"$BIN_DIR/$bin_name\" --open-url \"%U\""
        fi

        cat << EOF > "$desktop_file_sys_var"
[Desktop Entry]
Version=1.0
Name=$app_title
Comment=Secure Agentic Development Environment
Exec="$BIN_DIR/$bin_name" %F
Icon=$icon_path_var
Terminal=false
Type=Application
StartupWMClass=$wm_class
Categories=Development;IDE;
MimeType=$mime_types
EOF

        local url_handler_desktop="$HOME/.local/share/applications/${bin_name}-url-handler.desktop"
        cat << EOF > "$url_handler_desktop"
[Desktop Entry]
Version=1.0
Name=$app_title - URL Handler
Comment=Secure Agentic Development Environment
Exec=$url_exec
Icon=$icon_path_var
NoDisplay=true
Terminal=false
StartupNotify=true
StartupWMClass=$wm_class
Type=Application
Categories=Utility;Development;IDE;
MimeType=x-scheme-handler/${bin_name};
EOF

        if ! grep -qi "microsoft" /proc/version 2>/dev/null; then
            if [ -d "$DESKTOP_DIR" ]; then
                log_info "${C_CYAN}🖥️  Adding shortcut to Desktop...${C_RESET}"
                cp "$desktop_file_sys_var" "$desktop_file_user_var"
                chmod +x "$desktop_file_user_var"
                if command -v gio >/dev/null 2>&1; then run_cmd gio set "$desktop_file_user_var" metadata::trusted true || true; fi
            fi
            if command -v xdg-mime >/dev/null 2>&1; then
                run_cmd xdg-mime default "${bin_name}-url-handler.desktop" "x-scheme-handler/${bin_name}" || true
            fi
            if command -v update-desktop-database >/dev/null 2>&1; then
                run_cmd update-desktop-database "$HOME/.local/share/applications" || true
            fi
        fi

        echo ""
        if [ "$JSON_OUT" -eq 0 ] && [ "$QUIET" -eq 0 ] && command -v gum >/dev/null 2>&1; then
            gum style --border double --border-foreground 46 --padding "1 2" "🎉 Installation Complete!
Launch: $bin_name
Workspace: $WORKSPACE_DIR"
        else
            log_info "${C_GREEN}${C_BOLD}🎉 Installation Complete!${C_RESET}"
            log_info "  ${C_CYAN}▸${C_RESET} Launch:    ${C_BOLD}$bin_name${C_RESET}"
            log_info "  ${C_CYAN}▸${C_RESET} Workspace: ${C_BOLD}$WORKSPACE_DIR${C_RESET}"
        fi

    elif [ "$install_type" = "dmg" ]; then
        log_info "${C_CYAN}💿 Mounting DMG...${C_RESET}"
        run_cmd hdiutil attach "$dl_target" -mountpoint /Volumes/Antigravity -nobrowse -quiet
        log_info "${C_BLUE}📦 Copying to /Applications...${C_RESET}"
        
        # Dynamically find the .app bundle inside the DMG safely
        APP_NAME=""
        for app_dir in /Volumes/Antigravity/*.app; do
            if [ -d "$app_dir" ]; then
                APP_NAME="$(basename "$app_dir")"
                break
            fi
        done
        
        if [ -z "$APP_NAME" ]; then
            log_error "Could not find any .app bundle inside the mounted DMG!"
            log_info "Contents of /Volumes/Antigravity:"
            ls -la /Volumes/Antigravity >> "$LOG_FILE" 2>&1 || true
            run_cmd hdiutil detach /Volumes/Antigravity -quiet || true
            rm -rf "$ACTIVE_TMP_DIR"
            ACTIVE_TMP_DIR=""
            exit 1
        fi
        
        log_info "  ${C_DIM}Found app bundle: $APP_NAME${C_RESET}"
        
        if [ -d "/Applications/$APP_NAME" ]; then
            run_cmd rm -rf "/Applications/$APP_NAME"
        fi
        
        if ! cp -R "/Volumes/Antigravity/$APP_NAME" /Applications/ >> "$LOG_FILE" 2>&1; then
            log_error "Failed to copy $APP_NAME to /Applications. Check /tmp/antigravity-install.log for details."
            run_cmd hdiutil detach /Volumes/Antigravity -quiet || true
            rm -rf "$ACTIVE_TMP_DIR"
            ACTIVE_TMP_DIR=""
            exit 1
        fi
        
        run_cmd hdiutil detach /Volumes/Antigravity -quiet || true

        echo ""
        log_warn "macOS Gatekeeper may block the standalone binary from running."
        log_info "If you see 'cannot be opened because the developer cannot be verified',"
        log_info "run this command to clear the quarantine flag:"
        log_info "  ${C_BOLD}xattr -rd com.apple.quarantine '/Applications/$APP_NAME'${C_RESET}"

        # Create CLI shim for terminal launch (avoid GNU-only 'find -executable' on BSD/macOS)
        mkdir -p "$BIN_DIR"
        local mac_bin_path=""
        if [ "$product_name" = "ide" ] && [ -x "/Applications/$APP_NAME/Contents/Resources/app/bin/antigravity-ide" ]; then
            mac_bin_path="/Applications/$APP_NAME/Contents/Resources/app/bin/antigravity-ide"
            run_cmd ln -sf "$mac_bin_path" "$BIN_DIR/agy-ide"
        else
            local candidate
            for candidate in "/Applications/$APP_NAME/Contents/MacOS/"*; do
                if [ -f "$candidate" ] && [ -x "$candidate" ]; then
                    mac_bin_path="$candidate"
                    break
                fi
            done
        fi
        
        if [ -n "$mac_bin_path" ] && [ -f "$mac_bin_path" ]; then
            run_cmd ln -sf "$mac_bin_path" "$BIN_DIR/$bin_name"
        else
            log_warn "Could not create terminal shortcut (executable not found inside $APP_NAME)."
        fi

        log_info "${C_GREEN}${C_BOLD}🎉 Installation Complete!${C_RESET} Launch from Applications folder or type '$bin_name' in terminal."

    elif [ "$install_type" = "exe" ]; then
        log_info "${C_CYAN}🚀 Launching Windows Installer...${C_RESET}"
        if command -v cmd.exe >/dev/null 2>&1; then
            # Convert WSL path to Windows path for cmd.exe
            win_path=$(wslpath -w "$dl_target")
            cmd.exe /c start "" "$win_path"
        else
            log_error "Could not find cmd.exe to launch installer."
            rm -rf "$ACTIVE_TMP_DIR"
            ACTIVE_TMP_DIR=""
            exit 1
        fi
        log_info "${C_GREEN}${C_BOLD}🎉 Please complete the installation in the Windows UI!${C_RESET}"
    fi

    rm -rf "$ACTIVE_TMP_DIR"
    ACTIVE_TMP_DIR=""
    configure_chrome_path "$product_name"
    inject_path
    mkdir -p "$STATE_DIR"
    echo "{\"method\": \"binary\", \"product\": \"$product_name\", \"version\": \"$target_version\"}" > "$state_file_var"
}

do_remove() {
    JSON_METHOD="remove"
    if [ "$AUTO" -ne 1 ] && [ "$JSON_OUT" -ne 1 ]; then
        echo -ne "${C_RED}⚠ Are you sure you want to uninstall Antigravity? [y/N]: ${C_RESET}"
        read confirm < /dev/tty
        case "$confirm" in
            [yY]|[yY][eE][sS]) ;;
            *) log_warn "Cancelled."; return ;;
        esac
    fi
    log_info "${C_RED}🧹 Removing Google Antigravity...${C_RESET}"
    
    # Remove agy-box sandbox if installed
    uninstall_agy_box || true

    # Remove CLI and other shared files
    rm -f "$BIN_DIR/agy" "$BIN_DIR/jules"
    if command -v npm >/dev/null 2>&1; then
        npm uninstall -g @google/jules >/dev/null 2>&1 || sudo npm uninstall -g @google/jules >/dev/null 2>&1 || true
    fi

    # Remove Google Antigravity (Binary/Tarball)
    rm -rf "$APP_DIR" "$BIN_DIR/antigravity" "$DESKTOP_FILE_SYS" "$DESKTOP_FILE_USER" \
           "$HOME/.local/share/applications/antigravity-url-handler.desktop" \
           "$HOME/.local/share/icons/hicolor/512x512/apps/antigravity.png"
    if [ "$PLATFORM" = "Darwin" ]; then
        rm -rf "/Applications/Google Antigravity.app"
        rm -rf "/Applications/Antigravity.app"
        rm -rf "/Applications/Antigravity IDE.app"
    fi

    # Remove IDE (Binary/Tarball)
    rm -rf "${APP_DIR}-ide" "$BIN_DIR/antigravity-ide" "$BIN_DIR/agy-ide" \
           "$HOME/.local/share/applications/google-antigravity-ide.desktop" \
           "$HOME/.local/share/applications/antigravity-ide-url-handler.desktop" \
           "$HOME/.local/share/icons/hicolor/512x512/apps/antigravity-ide.png"
    if command -v xdg-user-dir >/dev/null 2>&1; then DESKTOP_DIR=$(xdg-user-dir DESKTOP); else DESKTOP_DIR="$HOME/Desktop"; fi
    rm -f "$DESKTOP_DIR/google-antigravity-ide.desktop"

    if command -v update-desktop-database >/dev/null 2>&1; then run_cmd update-desktop-database "$HOME/.local/share/applications" || true; fi

    # Also check other install methods (brew, repo) across both state files
    local st_file
    for st_file in "$STATE_FILE" "${STATE_DIR}/install-ide.json"; do
        if [ -f "$st_file" ]; then
            local method
            method=$(grep -o '"method": "[^"]*' "$st_file" | grep -o '[^"]*$' || true)
            log_info "Found installation state ($st_file). Method used: $method"
            
            case "$method" in
                "brew")
                    if [ "$PLATFORM" = "Darwin" ]; then 
                        run_cmd brew uninstall --cask antigravity || true
                        run_cmd brew uninstall --cask antigravity-ide || true
                    else 
                        local brew_prefix
                        brew_prefix=$(brew --prefix 2>/dev/null || echo "/home/linuxbrew/.linuxbrew")
                        run_cmd rm -f "$brew_prefix/bin/antigravity" "$brew_prefix/bin/antigravity-ide" "$brew_prefix/bin/agy-ide" || true
                        run_cmd brew uninstall --cask ublue-os/tap/antigravity-linux || true
                        run_cmd brew uninstall --cask ublue-os/tap/antigravity-ide-linux || true
                        run_cmd brew uninstall ublue-os/experimental-tap/antigravity-linux || true
                        if command -v update-desktop-database >/dev/null 2>&1; then
                            run_cmd update-desktop-database "$HOME/.local/share/applications" || true
                        fi
                    fi ;;
                "repo")
                    detect_distro
                    local sudo_prefix=()
                    if [ "$(id -u)" -ne 0 ]; then sudo_prefix=(sudo); fi
                    if command -v apt-get >/dev/null 2>&1 && [ -f /etc/apt/sources.list.d/antigravity.list ]; then
                        run_cmd "${sudo_prefix[@]}" apt-get remove -y antigravity || true
                        "${sudo_prefix[@]}" rm -f /etc/apt/sources.list.d/antigravity.list
                    elif command -v dnf >/dev/null 2>&1 && [ -f /etc/yum.repos.d/antigravity.repo ]; then
                        run_cmd "${sudo_prefix[@]}" dnf remove -y antigravity || true
                        "${sudo_prefix[@]}" rm -f /etc/yum.repos.d/antigravity.repo
                    fi ;;
            esac
            rm -f "$st_file"
        fi
    done

    log_info "${C_GREEN}✅ Uninstalled successfully.${C_RESET} (Note: Your code in $WORKSPACE_DIR was kept safe)."
}

get_cli_release_info() {
    local version="$1"
    local platform_key="$2"
    local json_file="${VERSIONS_JSON_CACHE:-}"
    
    if [ -z "$json_file" ] || [ ! -s "$json_file" ]; then
        echo "|"
        return
    fi
    
    local info
    info=$(awk -v ver="$version" -v plat="$platform_key" '
      BEGIN { in_cli=0; in_ver=0; in_plat=0 }
      $0 == "  \"cli\": {" { in_cli=1; next }
      in_cli && $0 ~ "^  }" { in_cli=0; next }
      in_cli && $0 == "    \"" ver "\": {" { in_ver=1; next }
      in_ver && $0 ~ "^    }" { in_ver=0; next }
      in_ver && $0 == "      \"" plat "\": {" { in_plat=1; next }
      in_plat && $0 ~ "^      }" { in_plat=0; next }
      in_plat && $0 ~ "\"url\":" { split($0, a, "\""); url=a[4] }
      in_plat && $0 ~ "\"sha512\":" { split($0, a, "\""); sha=a[4] }
      END { if (url != "" && sha != "") print url "|" sha }
    ' "$json_file" 2>/dev/null || true)
    
    echo "$info"
}

install_cli() {
    local target_version="${1:-$DEFAULT_CLI_VERSION}"
    JSON_METHOD="cli"
    log_info "${C_MAG}🚀 Installing Antigravity CLI version $target_version...${C_RESET}"
    
    fetch_versions_json || true
    
    local cli_os=""
    case "$PLATFORM" in
        Darwin) cli_os="darwin" ;;
        Linux) cli_os="linux" ;;
        *) cli_os="linux" ;;
    esac
    
    local cli_arch=""
    case "$ARCH" in
        x86_64|amd64) cli_arch="amd64" ;;
        arm64|aarch64) cli_arch="arm64" ;;
        *) cli_arch="amd64" ;;
    esac
    
    local platform_key="${cli_os}_${cli_arch}"
    if [ "$cli_os" = "linux" ]; then
        if (command -v ldd >/dev/null 2>&1 && ldd --version 2>&1 | grep -qi "musl") || compgen -G "/lib/ld-musl-*" >/dev/null 2>&1; then
            local musl_info
            musl_info=$(get_cli_release_info "$target_version" "${platform_key}_musl")
            if [ -n "$(echo "$musl_info" | cut -d'|' -f1)" ]; then
                platform_key="${platform_key}_musl"
            fi
        fi
    fi
    
    local info
    info=$(get_cli_release_info "$target_version" "$platform_key")
    local target_url
    target_url=$(echo "$info" | cut -d'|' -f1)
    local target_sha
    target_sha=$(echo "$info" | cut -d'|' -f2)
    
    if [ -z "$target_url" ] || [ -z "$target_sha" ]; then
        if [ "$target_version" = "$DEFAULT_CLI_VERSION" ]; then
            log_warn "Release details not found in versions.json. Falling back to official bootstrap installer..."
            ACTIVE_TMP_DIR=$(mktemp -d)
            local install_script="$ACTIVE_TMP_DIR/install.sh"
            
            if [ "$JSON_OUT" -eq 1 ] || [ "$QUIET" -eq 1 ]; then
                if ! run_cmd curl -fSsL "$CLI_INSTALL_URL" -o "$install_script" || ! run_cmd bash "$install_script" --dir "$BIN_DIR"; then
                    log_error "Antigravity CLI installation failed."
                    rm -rf "$ACTIVE_TMP_DIR"
                    ACTIVE_TMP_DIR=""
                    exit 1
                fi
            else
                log_info "${C_BLUE}⬇️  Downloading CLI installer...${C_RESET}"
                if ! curl -fSsL "$CLI_INSTALL_URL" -o "$install_script"; then
                    log_error "Failed to download CLI installer."
                    rm -rf "$ACTIVE_TMP_DIR"
                    ACTIVE_TMP_DIR=""
                    exit 1
                fi
                log_info "${C_BLUE}📦 Executing CLI installer...${C_RESET}"
                if ! bash "$install_script" --dir "$BIN_DIR"; then
                    log_error "CLI installer execution failed."
                    rm -rf "$ACTIVE_TMP_DIR"
                    ACTIVE_TMP_DIR=""
                    exit 1
                fi
            fi
            
            rm -rf "$ACTIVE_TMP_DIR"
            ACTIVE_TMP_DIR=""
            inject_path
            log_info "${C_GREEN}✅ Antigravity CLI installation complete!${C_RESET}"
            return
        else
            log_error "Could not find package details for Antigravity CLI version $target_version ($platform_key)."
            exit 1
        fi
    fi
    
    ACTIVE_TMP_DIR=$(mktemp -d)
    
    local is_tar_gz=false
    local file_ext="bin"
    case "$target_url" in
        *.tar.gz*) is_tar_gz=true; file_ext="tar.gz" ;;
    esac
    
    local dl_target="$ACTIVE_TMP_DIR/cli.$file_ext"
    
    if [ "$JSON_OUT" -eq 1 ] || [ "$QUIET" -eq 1 ] || [ ! -t 2 ]; then
        run_cmd curl -fSsL "$target_url" -o "$dl_target"
    else
        log_info "${C_BLUE}⬇️  Downloading CLI package...${C_RESET}"
        curl -fSL --progress-bar "$target_url" -o "$dl_target"
    fi
    
    log_info "${C_BLUE}🔐 Verifying checksum (SHA-512)...${C_RESET}"
    local sha_cmd=""
    if command -v sha512sum >/dev/null 2>&1; then
        sha_cmd="sha512sum"
    elif command -v shasum >/dev/null 2>&1; then
        sha_cmd="shasum -a 512"
    else
        log_error "sha512sum or shasum is required but was not found."
        rm -rf "$ACTIVE_TMP_DIR"
        ACTIVE_TMP_DIR=""
        exit 1
    fi
    
    if ! echo "$target_sha  $dl_target" | $sha_cmd -c - >/dev/null 2>&1; then
        log_error "Checksum verification failed!"
        rm -rf "$ACTIVE_TMP_DIR"
        ACTIVE_TMP_DIR=""
        exit 1
    fi
    
    mkdir -p "$BIN_DIR"
    local binary_dest="$BIN_DIR/agy"
    
    if [ "$is_tar_gz" = "true" ]; then
        log_info "${C_BLUE}📦 Extracting CLI...${C_RESET}"
        tar -xzf "$dl_target" -C "$ACTIVE_TMP_DIR" antigravity
        cp "$ACTIVE_TMP_DIR/antigravity" "$binary_dest"
    else
        cp "$dl_target" "$binary_dest"
    fi
    
    chmod +x "$binary_dest"
    if [ "$PLATFORM" = "Darwin" ]; then
        xattr -d com.apple.quarantine "$binary_dest" 2>/dev/null || true
    fi
    
    log_info "${C_BLUE}⚙️  Configuring environment...${C_RESET}"
    "$binary_dest" install --dir "$BIN_DIR" >/dev/null 2>&1 || "$binary_dest" install >/dev/null 2>&1 || true
    inject_path
    
    rm -rf "$ACTIVE_TMP_DIR"
    ACTIVE_TMP_DIR=""
    log_info "${C_GREEN}✅ Antigravity CLI installation complete!${C_RESET}"
}

install_sdk() {
    local target_version="${1:-$DEFAULT_SDK_VERSION}"
    JSON_METHOD="sdk"
    log_info "${C_MAG}🚀 Installing Antigravity Python SDK...${C_RESET}"
    
    if ! command -v python3 >/dev/null 2>&1; then
        log_error "python3 is required but was not found on your system."
        exit 1
    fi
    
    local pkg="google-antigravity"
    if [ -n "$target_version" ] && [ "$target_version" != "latest" ]; then
        pkg="google-antigravity==$target_version"
    fi

    local pip_runner=()
    if python3 -m pip --version >/dev/null 2>&1; then
        pip_runner=(python3 -m pip)
    else
        log_warn "pip module not found for python3; bootstrapping ephemeral pip zipapp..."
        python3 -m ensurepip --user >/dev/null 2>&1 || true
        if python3 -m pip --version >/dev/null 2>&1; then
            pip_runner=(python3 -m pip)
        else
            ACTIVE_TMP_DIR=$(mktemp -d)
            local pip_pyz="$ACTIVE_TMP_DIR/pip.pyz"
            if ! curl -fSsL "https://bootstrap.pypa.io/pip/pip.pyz" -o "$pip_pyz"; then
                log_error "Failed to bootstrap pip for python3."
                rm -rf "$ACTIVE_TMP_DIR"
                ACTIVE_TMP_DIR=""
                exit 1
            fi
            pip_runner=(python3 "$pip_pyz")
        fi
    fi

    local pip_flags=(--upgrade)
    if [ -z "${VIRTUAL_ENV:-}" ]; then
        pip_flags+=(--user)
        if "${pip_runner[@]}" install --help 2>&1 | grep -q -- '--break-system-packages'; then
            pip_flags+=(--break-system-packages)
        fi
    fi

    log_info "${C_BLUE}📦 Installing package '$pkg' via pip...${C_RESET}"
    local sdk_ok=0
    if [ "$JSON_OUT" -eq 1 ] || [ "$QUIET" -eq 1 ]; then
        if run_cmd "${pip_runner[@]}" install "${pip_flags[@]}" "$pkg"; then
            sdk_ok=1
        fi
    else
        if "${pip_runner[@]}" install "${pip_flags[@]}" "$pkg"; then
            sdk_ok=1
        fi
    fi

    if [ -n "${ACTIVE_TMP_DIR:-}" ] && [ -d "$ACTIVE_TMP_DIR" ]; then
        rm -rf "$ACTIVE_TMP_DIR"
        ACTIVE_TMP_DIR=""
    fi

    if [ "$sdk_ok" -ne 1 ]; then
        log_error "Failed to install Google Antigravity SDK."
        exit 1
    fi

    inject_path
    log_info "${C_GREEN}✅ Antigravity SDK installation complete!${C_RESET}"
}

ensure_brew() {
    if check_brew; then
        return 0
    fi
    
    log_warn "Homebrew is required but not installed."
    local install_now=true
    if [ "$AUTO" -eq 0 ] && command -v gum >/dev/null 2>&1; then
        if ! gum confirm "Would you like the installer to set up Homebrew now?"; then
            install_now=false
        fi
    elif [ "$AUTO" -eq 0 ]; then
        read -r -p "Would you like the installer to set up Homebrew now? [Y/n]: " choice < /dev/tty
        case "$choice" in
            [nN]*) install_now=false ;;
        esac
    fi
    
    if [ "$install_now" = false ]; then
        log_error "Homebrew installation declined. Cannot proceed with Homebrew installation."
        exit 1
    fi
    
    log_info "${C_BLUE}⬇️  Installing Homebrew...${C_RESET}"
    if ! /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
        log_error "Homebrew installation failed."
        exit 1
    fi
    
    # Try to load brew into current session
    local brew_path=""
    if [ -f "/opt/homebrew/bin/brew" ]; then
        brew_path="/opt/homebrew/bin/brew"
    elif [ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
        brew_path="/home/linuxbrew/.linuxbrew/bin/brew"
    elif [ -f "/usr/local/bin/brew" ]; then
        brew_path="/usr/local/bin/brew"
    fi
    
    if [ -n "$brew_path" ]; then
        eval "$("$brew_path" shellenv)"
        
        # Also write to profile
        local profile_file=""
        if [ "$PLATFORM" = "Darwin" ]; then
            profile_file="$HOME/.zprofile"
        else
            profile_file="$HOME/.bashrc"
        fi
        
        if [ -f "$profile_file" ] && ! grep -q "shellenv" "$profile_file"; then
            log_info "Adding Homebrew configuration to $profile_file..."
            echo "eval \"\$($brew_path shellenv)\"" >> "$profile_file"
        fi
    fi
    
    if ! check_brew; then
        log_error "Homebrew was installed but is still not found in PATH."
        exit 1
    fi
    
    log_info "${C_GREEN}✅ Homebrew installed and configured successfully!${C_RESET}"
}

ensure_node() {
    if command -v npm >/dev/null 2>&1; then
        return 0
    fi
    
    log_warn "Node.js & NPM are required to install Jules CLI."
    local install_now=true
    if [ "$AUTO" -eq 0 ] && command -v gum >/dev/null 2>&1; then
        if ! gum confirm "Would you like the installer to set up Node.js and NPM now?"; then
            install_now=false
        fi
    elif [ "$AUTO" -eq 0 ]; then
        read -r -p "Would you like the installer to set up Node.js and NPM now? [Y/n]: " choice < /dev/tty
        case "$choice" in
            [nN]*) install_now=false ;;
        esac
    fi
    
    if [ "$install_now" = false ]; then
        log_error "Node.js installation declined. Cannot proceed with Jules CLI installation."
        exit 1
    fi
    
    # Try using brew if available
    if check_brew; then
        log_info "${C_BLUE}📦 Installing Node.js via Homebrew...${C_RESET}"
        if [ "$JSON_OUT" -eq 1 ] || [ "$QUIET" -eq 1 ]; then
            run_cmd brew install node
        else
            brew install node
        fi
        if command -v npm >/dev/null 2>&1; then
            log_info "${C_GREEN}✅ Node.js and NPM installed successfully via Homebrew!${C_RESET}"
            return 0
        fi
    fi
    
    # Standalone binary fallback install
    log_info "${C_BLUE}⬇️  Setting up standalone Node.js and NPM in user space...${C_RESET}"
    
    local node_url=""
    local node_dir_name=""
    
    case "$PLATFORM" in
        Darwin)
            if [ "$ARCH" = "arm64" ]; then
                node_url="https://nodejs.org/dist/v20.11.1/node-v20.11.1-darwin-arm64.tar.gz"
                node_dir_name="node-v20.11.1-darwin-arm64"
            else
                node_url="https://nodejs.org/dist/v20.11.1/node-v20.11.1-darwin-x64.tar.gz"
                node_dir_name="node-v20.11.1-darwin-x64"
            fi
            ;;
        Linux|Crostini)
            if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
                node_url="https://nodejs.org/dist/v20.11.1/node-v20.11.1-linux-arm64.tar.xz"
                node_dir_name="node-v20.11.1-linux-arm64"
            else
                node_url="https://nodejs.org/dist/v20.11.1/node-v20.11.1-linux-x64.tar.xz"
                node_dir_name="node-v20.11.1-linux-x64"
            fi
            ;;
        *)
            log_error "Unsupported platform for standalone Node.js installation."
            exit 1
            ;;
    esac
    
    local node_lib_dir="$HOME/.local/lib/node"
    mkdir -p "$node_lib_dir" "$BIN_DIR"
    
    local dl_temp
    dl_temp=$(mktemp -d)
    local archive_ext="tar.gz"
    case "$node_url" in
        *.tar.xz) archive_ext="tar.xz" ;;
    esac
    
    local dl_target="$dl_temp/node.$archive_ext"
    
    if [ "$JSON_OUT" -eq 1 ] || [ "$QUIET" -eq 1 ]; then
        run_cmd curl -fSL "$node_url" -o "$dl_target"
    else
        curl -fSL --progress-bar "$node_url" -o "$dl_target"
    fi
    
    log_info "${C_CYAN}📁 Extracting Node.js...${C_RESET}"
    tar -xf "$dl_target" -C "$dl_temp"
    
    # Copy files to permanent location
    rm -rf "$node_lib_dir"
    mv "$dl_temp/$node_dir_name" "$node_lib_dir"
    rm -rf "$dl_temp"
    
    # Symlink binaries to $BIN_DIR
    ln -sf "$node_lib_dir/bin/node" "$BIN_DIR/node"
    ln -sf "$node_lib_dir/bin/npm" "$BIN_DIR/npm"
    ln -sf "$node_lib_dir/bin/npx" "$BIN_DIR/npx"
    
    # Ensure BIN_DIR is in PATH for current execution
    export PATH="$BIN_DIR:$PATH"
    
    # Force profile config reload for the user
    # Add to shell configuration profile
    local profile_file=""
    if [ "$PLATFORM" = "Darwin" ]; then
        profile_file="$HOME/.zprofile"
    else
        profile_file="$HOME/.bashrc"
    fi
    
    if [ -f "$profile_file" ] && ! grep -q "$BIN_DIR" "$profile_file"; then
        log_info "Adding $BIN_DIR to PATH in $profile_file..."
        echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$profile_file"
    fi
    
    if ! command -v npm >/dev/null 2>&1; then
        log_error "Node.js was installed but npm is still not found in PATH."
        exit 1
    fi
    
    log_info "${C_GREEN}✅ Standalone Node.js and NPM setup complete!${C_RESET}"
}

install_jules() {
    local target_version="${1:-$DEFAULT_JULES_VERSION}"
    JSON_METHOD="jules"
    log_info "${C_MAG}🚀 Installing Google Jules CLI...${C_RESET}"
    
    ensure_node
    
    local pkg="@google/jules"
    if [ -n "$target_version" ] && [ "$target_version" != "latest" ]; then
        pkg="@google/jules@$target_version"
    fi
    
    log_info "${C_BLUE}📦 Installing package '$pkg' via npm...${C_RESET}"
    
    local install_ok=false
    if [ "$JSON_OUT" -eq 1 ] || [ "$QUIET" -eq 1 ]; then
        if run_cmd npm install -g "$pkg" 2>/dev/null; then
            install_ok=true
        elif command -v sudo >/dev/null 2>&1 && run_cmd sudo npm install -g "$pkg"; then
            install_ok=true
        fi
    else
        if npm install -g "$pkg"; then
            install_ok=true
        elif command -v sudo >/dev/null 2>&1; then
            log_warn "Permission denied. Retrying with sudo..."
            if sudo npm install -g "$pkg"; then
                install_ok=true
            fi
        fi
    fi
    
    if [ "$install_ok" = false ]; then
        log_error "Failed to install Google Jules CLI package."
        exit 1
    fi
    
    # If we installed to a local or custom path, link it to BIN_DIR
    local npm_prefix
    npm_prefix=$(npm config get prefix 2>/dev/null || echo "")
    if [ -n "$npm_prefix" ] && [ -f "$npm_prefix/bin/jules" ]; then
        ln -sf "$npm_prefix/bin/jules" "$BIN_DIR/jules"
    fi
    
    log_info "${C_GREEN}✅ Google Jules CLI installation complete!${C_RESET}"
}

get_agy_box_release_url() {
    local version="$1"
    local json_file="${VERSIONS_JSON_CACHE:-}"
    
    if [ -z "$version" ] || [ -z "$json_file" ] || [ ! -s "$json_file" ]; then
        echo ""
        return
    fi
    
    local url
    url=$(sed 's#{#{\n#g; s#}#\n}\n#g' "$json_file" 2>/dev/null | awk -v ver="$version" '
      BEGIN { in_agy=0; in_ver=0; agy_depth=0; ver_depth=0; url="" }
      !in_agy && index($0, "\"agy-box\"") > 0 && $0 ~ /:[[:space:]]*\{/ {
        in_agy = 1
        agy_depth = 1
        next
      }
      in_agy {
        if (!in_ver) {
          if (index($0, "\"" ver "\"") > 0 && $0 ~ /:[[:space:]]*\{/) {
            in_ver = 1
            ver_depth = 1
          }
        } else {
          if ($0 ~ /"url"[[:space:]]*:/) {
            split($0, a, "\"")
            url = a[4]
          }
          for (i = 1; i <= length($0); i++) {
            c = substr($0, i, 1)
            if (c == "{") ver_depth++
            else if (c == "}") {
              ver_depth--
              if (ver_depth <= 0) {
                in_ver = 0
                break
              }
            }
          }
        }
        for (i = 1; i <= length($0); i++) {
          c = substr($0, i, 1)
          if (c == "{") agy_depth++
          else if (c == "}") {
            agy_depth--
            if (agy_depth <= 0) {
              in_agy = 0
              break
            }
          }
        }
      }
      END { if (url != "") print url }
    ' 2>/dev/null || true)
    
    echo "$url"
}

get_vscode_vsix_url() {
    local json_file="${VERSIONS_JSON_CACHE:-}"
    if [ -z "$json_file" ] || [ ! -s "$json_file" ]; then
        echo "https://open-vsx.org/api/Google/google-antigravity/latest/file/Google.google-antigravity.vsix"
        return
    fi
    local url
    url=$(awk '
      BEGIN { in_ext=0; in_vsc=0 }
      $0 == "  \"extensions\": {" { in_ext=1; next }
      in_ext && $0 ~ "^  }" { in_ext=0; next }
      in_ext && $0 == "    \"vscode\": {" { in_vsc=1; next }
      in_vsc && $0 ~ "^    }" { in_vsc=0; next }
      in_vsc && $0 ~ "\"vsix_url\":" { split($0, a, "\""); url=a[4] }
      END { if (url != "") print url }
    ' "$json_file" 2>/dev/null || true)
    if [ -n "$url" ]; then
        echo "$url"
    else
        echo "https://open-vsx.org/api/Google/google-antigravity/latest/file/Google.google-antigravity.vsix"
    fi
}

install_vscode_ext() {
    JSON_METHOD="vscode_ext"
    log_info "${C_MAG}🚀 Installing Google Antigravity VS Code Extension...${C_RESET}"
    local installed=0
    local found_any=0
    for cmd in code codium code-insiders; do
        if command -v "$cmd" >/dev/null 2>&1; then
            found_any=1
            log_info "Found $cmd in PATH. Installing Google.google-antigravity extension..."
            local extra_flags=()
            if [ "$(id -u)" -eq 0 ]; then
                mkdir -p "$HOME/.vscode-root"
                extra_flags+=(--no-sandbox --user-data-dir "$HOME/.vscode-root")
            fi
            if "$cmd" "${extra_flags[@]}" --install-extension Google.google-antigravity --force; then
                log_info "${C_GREEN}✅ Installed Google Antigravity extension for $cmd.${C_RESET}"
                installed=1
            else
                log_warn "Direct marketplace lookup failed for $cmd; attempting OpenVSX VSIX fallback..."
                fetch_versions_json || true
                local vsix_url
                vsix_url=$(get_vscode_vsix_url)
                ACTIVE_TMP_DIR=$(mktemp -d)
                local vsix_file="$ACTIVE_TMP_DIR/Google.google-antigravity.vsix"
                if curl -fSsL "$vsix_url" -o "$vsix_file" && "$cmd" "${extra_flags[@]}" --install-extension "$vsix_file" --force; then
                    log_info "${C_GREEN}✅ Installed Google Antigravity extension for $cmd via VSIX.${C_RESET}"
                    installed=1
                fi
                rm -rf "$ACTIVE_TMP_DIR"
                ACTIVE_TMP_DIR=""
            fi
        fi
    done

    if [ "$found_any" -eq 0 ]; then
        log_warn "None of 'code', 'codium', or 'code-insiders' was found in PATH."
        echo -e "${C_YELLOW}💡 Install Visual Studio Code first (https://code.visualstudio.com), then re-run.${C_RESET}"
        return 1
    fi
    if [ "$installed" -eq 0 ]; then
        log_error "Failed to install Google.google-antigravity extension."
        return 1
    fi
    return 0
}

install_jetbrains_ext() {
    JSON_METHOD="jetbrains_ext"
    log_info "${C_MAG}🚀 Installing Google Antigravity JetBrains Plugin...${C_RESET}"

    local jb_commands=("idea" "pycharm" "webstorm" "goland" "clion" "rider" "rustrover" "studio")
    local found_executables=()

    # 1. Check commands in PATH
    for cmd in "${jb_commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            local full_path
            full_path=$(command -v "$cmd")
            found_executables+=("$full_path")
        fi
    done

    # 2. Check Toolbox script paths
    local toolbox_script_dirs=(
        "$HOME/.local/share/JetBrains/Toolbox/scripts"
        "$HOME/Library/Application Support/JetBrains/Toolbox/scripts"
    )
    for dir in "${toolbox_script_dirs[@]}"; do
        if [ -d "$dir" ]; then
            for cmd in "${jb_commands[@]}"; do
                if [ -x "$dir/$cmd" ]; then
                    found_executables+=("$dir/$cmd")
                fi
            done
        fi
    done

    # 3. Check Toolbox application directories
    local toolbox_app_dirs=(
        "$HOME/.local/share/JetBrains/Toolbox/apps"
        "$HOME/Library/Application Support/JetBrains/Toolbox/apps"
    )
    for app_dir in "${toolbox_app_dirs[@]}"; do
        if [ -d "$app_dir" ]; then
            while IFS= read -r bin_file; do
                if [ -n "$bin_file" ] && [ -x "$bin_file" ]; then
                    found_executables+=("$bin_file")
                fi
            done < <(find "$app_dir" -maxdepth 5 -type f \( -name "idea" -o -name "idea.sh" -o -name "pycharm" -o -name "pycharm.sh" -o -name "webstorm" -o -name "webstorm.sh" -o -name "goland" -o -name "goland.sh" -o -name "clion" -o -name "clion.sh" -o -name "rider" -o -name "rider.sh" -o -name "rustrover" -o -name "rustrover.sh" -o -name "studio" -o -name "studio.sh" \) 2>/dev/null || true)
        fi
    done

    # 4. Check macOS /Applications bundle binaries
    if [ "$PLATFORM" = "Darwin" ]; then
        while IFS= read -r mac_bin; do
            if [ -n "$mac_bin" ] && [ -x "$mac_bin" ]; then
                found_executables+=("$mac_bin")
            fi
        done < <(find /Applications -maxdepth 4 -path "*Contents/MacOS/*" -type f \( -name "idea" -o -name "pycharm" -o -name "webstorm" -o -name "goland" -o -name "clion" -o -name "rider" -o -name "rustrover" -o -name "studio" \) 2>/dev/null || true)
    fi

    # Deduplicate discovered executables
    local unique_executables=()
    local seen_paths=" "
    for exe in "${found_executables[@]}"; do
        local real_exe
        real_exe=$(readlink -f "$exe" 2>/dev/null || echo "$exe")
        if [[ "$seen_paths" != *" $real_exe "* ]]; then
            seen_paths="${seen_paths}${real_exe} "
            unique_executables+=("$exe")
        fi
    done

    if [ ${#unique_executables[@]} -eq 0 ]; then
        log_warn "No JetBrains IDE commands or Toolbox installations detected."
        echo -e "${C_YELLOW}💡 Guidance:${C_RESET}"
        echo -e "  To manually install the Google Antigravity plugin in JetBrains:"
        echo -e "  1. Open your JetBrains IDE (IntelliJ IDEA, PyCharm, WebStorm, etc.)."
        echo -e "  2. Go to ${C_BOLD}Settings / Preferences -> Plugins -> Marketplace${C_RESET}."
        echo -e "  3. Search for ${C_BOLD}Antigravity${C_RESET} and click ${C_BOLD}Install${C_RESET}."
        echo -e "  4. Optionally configure via ${C_BOLD}Settings -> Tools -> AI -> Agents${C_RESET}."
        return 1
    fi

    log_info "Detected ${#unique_executables[@]} JetBrains IDE installation(s)."
    local installed=0
    for exe in "${unique_executables[@]}"; do
        local ide_name
        ide_name=$(basename "$exe")
        log_info "Installing Antigravity plugin for $ide_name ($exe)..."
        if "$exe" installPlugins Antigravity; then
            log_info "${C_GREEN}✅ Successfully installed Antigravity plugin for $ide_name.${C_RESET}"
            installed=1
        else
            log_warn "Command '$exe installPlugins Antigravity' encountered an issue."
            echo -e "${C_YELLOW}💡 Note: If $ide_name is currently running, close the IDE and retry.${C_RESET}"
            echo -e "${C_YELLOW}   Alternatively, install via Settings -> Plugins -> Marketplace -> 'Antigravity'.${C_RESET}"
        fi
    done

    echo ""
    log_info "${C_BLUE}ℹ️  JetBrains Plugin Guidance:${C_RESET}"
    log_info "  - If your IDE was running during installation, restart it to activate the plugin."
    log_info "  - Manual install or agent configuration: ${C_BOLD}Settings -> AI -> Agents${C_RESET}."

    if [ "$installed" -eq 1 ]; then
        return 0
    else
        return 1
    fi
}

install_zed_ext() {
    JSON_METHOD="zed_ext"
    log_info "${C_MAG}🚀 Configuring Google Antigravity Zed Extension...${C_RESET}"

    local zed_dir=""
    if [ "$PLATFORM" = "Darwin" ]; then
        if [ -d "$HOME/Library/Application Support/Zed" ]; then
            zed_dir="$HOME/Library/Application Support/Zed"
        elif [ -d "$HOME/.config/zed" ]; then
            zed_dir="$HOME/.config/zed"
        else
            zed_dir="$HOME/Library/Application Support/Zed"
        fi
    else
        zed_dir="$HOME/.config/zed"
    fi

    mkdir -p "$zed_dir"
    local settings_file="$zed_dir/settings.json"
    log_info "Targeting Zed configuration: $settings_file"

    local configured=0
    if command -v python3 >/dev/null 2>&1; then
        if python3 -c '
import sys, os, json, re

path = sys.argv[1]
data = {}
if os.path.exists(path) and os.path.getsize(path) > 0:
    try:
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
        try:
            data = json.loads(content)
        except Exception:
            cleaned = re.sub(r"//.*?\n", "\n", content)
            cleaned = re.sub(r"/\*.*?\*/", "", cleaned, flags=re.DOTALL)
            cleaned = re.sub(r",\s*([}\]])", r"\1", cleaned)
            data = json.loads(cleaned)
    except Exception as e:
        print(f"Warning: Could not parse existing JSON: {e}", file=sys.stderr)
        data = {}

if not isinstance(data, dict):
    data = {}

if "auto_install_extensions" not in data or not isinstance(data["auto_install_extensions"], dict):
    data["auto_install_extensions"] = {}

data["auto_install_extensions"]["antigravity"] = True

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
print("OK")
' "$settings_file" 2>/dev/null | grep -q "OK"; then
            configured=1
        fi
    elif command -v jq >/dev/null 2>&1; then
        if [ -f "$settings_file" ] && [ -s "$settings_file" ]; then
            local tmp_file
            tmp_file=$(mktemp)
            if jq '.auto_install_extensions.antigravity = true' "$settings_file" > "$tmp_file" 2>/dev/null; then
                mv "$tmp_file" "$settings_file"
                configured=1
            else
                rm -f "$tmp_file"
            fi
        else
            echo '{"auto_install_extensions": {"antigravity": true}}' | jq '.' > "$settings_file"
            configured=1
        fi
    fi

    if [ "$configured" -eq 1 ]; then
        log_info "${C_GREEN}✅ Configured Zed settings for Antigravity in $settings_file.${C_RESET}"
        log_info "  ${C_CYAN}▸${C_RESET} Zed will auto-install 'antigravity' extension on startup."
        return 0
    else
        log_error "Failed to update $settings_file (python3 or jq required)."
        return 1
    fi
}

install_all_ide_extensions() {
    JSON_METHOD="all_extensions"
    log_info "${C_MAG}🔍 Scanning for supported IDEs (VS Code, JetBrains, Zed)...${C_RESET}"
    local detected_any=0
    local vscode_present=0
    local jetbrains_present=0
    local zed_present=0

    # 1. Detect VS Code / VSCodium
    for cmd in code codium code-insiders; do
        if command -v "$cmd" >/dev/null 2>&1; then
            vscode_present=1
            break
        fi
    done

    # 2. Detect JetBrains IDEs
    local jb_commands=("idea" "pycharm" "webstorm" "goland" "clion" "rider" "rustrover" "studio")
    for cmd in "${jb_commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            jetbrains_present=1
            break
        fi
    done
    if [ "$jetbrains_present" -eq 0 ]; then
        local toolbox_dirs=(
            "$HOME/.local/share/JetBrains/Toolbox"
            "$HOME/Library/Application Support/JetBrains/Toolbox"
        )
        for td in "${toolbox_dirs[@]}"; do
            if [ -d "$td" ]; then
                jetbrains_present=1
                break
            fi
        done
    fi

    # 3. Detect Zed
    local zed_dirs=(
        "$HOME/.config/zed"
        "$HOME/Library/Application Support/Zed"
    )
    if command -v zed >/dev/null 2>&1 || command -v zed-editor >/dev/null 2>&1 || [ -d "/Applications/Zed.app" ]; then
        zed_present=1
    else
        for zd in "${zed_dirs[@]}"; do
            if [ -d "$zd" ]; then
                zed_present=1
                break
            fi
        done
    fi

    if [ "$vscode_present" -eq 1 ]; then
        log_info "Found VS Code / VSCodium environment."
        install_vscode_ext || true
        detected_any=1
        echo ""
    fi

    if [ "$jetbrains_present" -eq 1 ]; then
        log_info "Found JetBrains environment."
        install_jetbrains_ext || true
        detected_any=1
        echo ""
    fi

    if [ "$zed_present" -eq 1 ]; then
        log_info "Found Zed environment."
        install_zed_ext || true
        detected_any=1
        echo ""
    fi

    if [ "$detected_any" -eq 0 ]; then
        log_warn "No supported IDEs (VS Code, JetBrains, Zed) detected on this host."
        echo -e "${C_YELLOW}💡 You can install extensions individually once your IDE is installed:${C_RESET}"
        echo -e "  - VS Code:    ${C_BOLD}$0 --install-vscode${C_RESET}"
        echo -e "  - JetBrains:  ${C_BOLD}$0 --install-jetbrains${C_RESET}"
        echo -e "  - Zed:        ${C_BOLD}$0 --install-zed${C_RESET}"
        return 1
    fi

    log_info "${C_GREEN}${C_BOLD}🎉 Completed IDE extension configuration for all detected editors!${C_RESET}"
    return 0
}

install_agy_box() {
    log_info "Verifying container sandboxing prerequisites..."

    # 1. Check unsupported platform macOS
    if [ "$PLATFORM" = "Darwin" ]; then
        log_error "agy-box is not natively supported on macOS."
        echo -e "${C_YELLOW}💡 Guidance: To run agy-box on macOS:${C_RESET}"
        echo -e "  1. Install Podman Desktop or Docker Desktop on macOS."
        echo -e "  2. Install distrobox using Homebrew: ${C_BOLD}brew install distrobox${C_RESET}"
        echo -e "  3. Ensure the podman machine or docker daemon is running."
        echo -e "  After completing these steps, re-run this installer."
        return 1
    fi

    # 2. Check WSL/Windows or standard Linux
    # Check distrobox
    if ! command -v distrobox &>/dev/null; then
        log_warn "distrobox is not installed on the host."
        if { [ "$PLATFORM" = "Linux" ] || [ "$PLATFORM" = "Crostini" ]; } && [ "${HAS_APT:-no}" = "yes" ]; then
            if [ "$AUTO" -eq 1 ]; then
                log_info "Headless mode: automatically installing distrobox and podman..."
                sudo apt update && sudo apt install -y distrobox podman
            else
                if gum confirm "Would you like to install distrobox and podman now?"; then
                    sudo apt update && sudo apt install -y distrobox podman
                elif command -v podman &>/dev/null || command -v docker &>/dev/null; then
                    if ! gum confirm "distrobox is missing. Proceed with standalone container sandbox mode?"; then
                        log_error "Sandbox installation cannot proceed without distrobox."
                        return 1
                    fi
                else
                    log_error "Sandbox installation cannot proceed without distrobox."
                    return 1
                fi
            fi
        elif [ "$PLATFORM" = "Linux" ] && [ "${HAS_DNF:-no}" = "yes" ]; then
            if [ "$AUTO" -eq 1 ]; then
                log_info "Headless mode: automatically installing distrobox and podman..."
                sudo dnf install -y distrobox podman
            else
                if gum confirm "Would you like to install distrobox and podman now?"; then
                    sudo dnf install -y distrobox podman
                elif command -v podman &>/dev/null || command -v docker &>/dev/null; then
                    if ! gum confirm "distrobox is missing. Proceed with standalone container sandbox mode?"; then
                        log_error "Sandbox installation cannot proceed without distrobox."
                        return 1
                    fi
                else
                    log_error "Sandbox installation cannot proceed without distrobox."
                    return 1
                fi
            fi
        else
            if [ "$PLATFORM" = "Crostini" ]; then
                log_error "distrobox is missing in your ChromeOS Crostini environment."
                echo -e "${C_YELLOW}💡 Guidance: To run agy-box on ChromeOS (Crostini):${C_RESET}"
                echo -e "  1. Open Terminal in ChromeOS."
                echo -e "  2. Install distrobox and podman: ${C_BOLD}sudo apt update && sudo apt install -y distrobox podman${C_RESET}"
                echo -e "  3. Re-run this installer once installed."
                return 1
            elif grep -qi "microsoft" /proc/version 2>/dev/null; then
                log_error "distrobox is missing in your WSL2 environment."
                echo -e "${C_YELLOW}💡 Guidance: To run agy-box on WSL2 (Windows):${C_RESET}"
                echo -e "  1. Install Podman or Docker inside your WSL2 distro (e.g., Ubuntu)."
                echo -e "  2. Install distrobox: ${C_BOLD}curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/install | sh${C_RESET}"
                echo -e "  Alternatively, follow the official WSL2 container setup instructions."
                return 1
            elif command -v podman &>/dev/null || command -v docker &>/dev/null; then
                if [ "$AUTO" -eq 0 ]; then
                    if ! gum confirm "distrobox is missing, but a container engine is available. Proceed with standalone sandbox mode?"; then
                        return 1
                    fi
                fi
            else
                log_error "Please install distrobox and a container manager (podman/docker) first."
                return 1
            fi
        fi
    fi

    # Check podman/docker existence
    if ! command -v podman &>/dev/null && ! command -v docker &>/dev/null; then
        log_error "No container manager (podman or docker) detected."
        if { [ "$PLATFORM" = "Linux" ] || [ "$PLATFORM" = "Crostini" ]; } && [ "${HAS_APT:-no}" = "yes" ]; then
            if [ "$AUTO" -eq 1 ]; then
                log_info "Headless mode: automatically installing podman..."
                sudo apt update && sudo apt install -y podman
            else
                if gum confirm "Would you like to install podman now?"; then
                    sudo apt update && sudo apt install -y podman
                fi
            fi
        elif [ "$PLATFORM" = "Linux" ] && [ "${HAS_DNF:-no}" = "yes" ]; then
            if [ "$AUTO" -eq 1 ]; then
                log_info "Headless mode: automatically installing podman..."
                sudo dnf install -y podman
            else
                if gum confirm "Would you like to install podman now?"; then
                    sudo dnf install -y podman
                fi
            fi
        fi
        if ! command -v podman &>/dev/null && ! command -v docker &>/dev/null; then
            log_error "Sandbox installation cannot proceed without podman or docker."
            return 1
        fi
    fi

    # Verify active container service/socket access
    local socket_ok=no
    if command -v podman &>/dev/null; then
        if podman info &>/dev/null; then
            socket_ok=yes
        fi
    elif command -v docker &>/dev/null; then
        if docker info &>/dev/null; then
            socket_ok=yes
        fi
    fi

    if [ "$socket_ok" = "no" ]; then
        log_warn "Container runtime is installed but the socket/service is not running or accessible."
        echo -e "${C_YELLOW}💡 Troubleshooting Guidance:${C_RESET}"
        if command -v docker &>/dev/null; then
            echo -e "  - Docker daemon might be stopped. Run: ${C_BOLD}sudo systemctl start docker${C_RESET}"
            echo -e "  - You may need group permissions. Run: ${C_BOLD}sudo usermod -aG docker \$USER${C_RESET} and restart your shell."
        else
            echo -e "  - Podman socket may be unreachable. If using rootless, verify subuid/subgid mapping."
            echo -e "  - On Atomic Linux hosts, verify group configurations or run: ${C_BOLD}ujust dx-group${C_RESET}"
        fi
        if [ "$AUTO" -eq 1 ]; then
            log_error "Sandbox installation cannot proceed with unresponsive container socket in headless mode."
            return 1
        else
            if ! gum confirm "Would you like to attempt installation anyway?"; then
                return 1
            fi
        fi
    fi

    # 3. Download and install agy-box-manager globally from tag version
    log_info "Fetching agy-box version details..."
    fetch_versions_json || true
    local agy_ver="${DEFAULT_AGY_BOX_VERSION:-v0.7.0}"
    local remote_url="${AGY_BOX_MANAGER_URL:-}"
    if [ -z "$remote_url" ]; then
        remote_url=$(get_agy_box_release_url "$agy_ver")
    fi
    
    if [ -z "$remote_url" ]; then
        log_warn "Release version $agy_ver not found in versions.json. Falling back to official release tag URL..."
        remote_url="https://raw.githubusercontent.com/wtg-codes/agy-box/${agy_ver}/agy-box-manager"
    fi
    
    log_info "Downloading agy-box-manager CLI ($agy_ver)..."
    local target_dir="$HOME/.local/bin"
    mkdir -p "$target_dir"
    
    if ! curl -fSsL "$remote_url" -o "$target_dir/agy-box-manager"; then
        log_error "Failed to download agy-box-manager from $remote_url"
        return 1
    fi
    chmod +x "$target_dir/agy-box-manager"

    # 4. Trigger sandbox installation
    log_info "Starting agy-box container setup ($agy_ver) — live progress below..."
    if [ "$AUTO" -eq 1 ]; then
        if ! AGY_NONINTERACTIVE=1 "$target_dir/agy-box-manager" install < /dev/null; then
            log_error "agy-box container setup failed during execution of agy-box-manager install."
            return 1
        fi
    else
        if [ ! -t 0 ] && [ -t 1 ] && [ -r /dev/tty ]; then
            if ! "$target_dir/agy-box-manager" install < /dev/tty; then
                log_error "agy-box container setup failed during execution of agy-box-manager install."
                return 1
            fi
        else
            if ! "$target_dir/agy-box-manager" install; then
                log_error "agy-box container setup failed during execution of agy-box-manager install."
                return 1
            fi
        fi
    fi

    # 5. Check if ~/.local/bin is in PATH
    case ":$PATH:" in
        *:"$HOME/.local/bin":*) ;;
        *)
            echo -e "${C_YELLOW}⚠️  Warning: '$HOME/.local/bin' is not in your current PATH.${C_RESET}"
            echo -e "  To run agy-box-manager easily, add it to your profile or execute:"
            echo -e "  ${C_BOLD}export PATH=\"\$HOME/.local/bin:\$PATH\"${C_RESET}"
            ;;
    esac

    log_info "${C_GREEN}✅ agy-box sandbox installation completed successfully.${C_RESET}"
}

uninstall_agy_box() {
    local manager_bin="$HOME/.local/bin/agy-box-manager"
    if [ -f "$manager_bin" ]; then
        log_info "Uninstalling agy-box environment..."
        if ! "$manager_bin" clean; then
            log_warn "agy-box clean command encountered an error."
        fi
        if ! "$manager_bin" uninstall-global; then
            log_warn "agy-box uninstall-global command encountered an error."
        fi
        rm -f "$manager_bin"
        log_info "${C_GREEN}✅ agy-box uninstalled successfully.${C_RESET}"
    else
        log_warn "agy-box-manager is not installed globally."
    fi
}


