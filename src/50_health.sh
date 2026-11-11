do_health_check() {
    log_info "${C_MAG}🔍 Running Google Antigravity Health Check...${C_RESET}"
    echo ""

    local passed=0
    local failed=0

    check_status() {
        if eval "$2" > /dev/null 2>&1; then
            echo -e "  ${C_GREEN}✅ $1${C_RESET}"
            passed=$((passed + 1))
        else
            echo -e "  ${C_RED}❌ $1${C_RESET}"
            failed=$((failed + 1))
        fi
    }

    # 1. Antigravity Hub & Antigravity IDE Binaries
    local agy_ver ide_ver cli_ver sdk_ver
    agy_ver=$(get_installed_agy_version 2>/dev/null || true)
    ide_ver=$(get_installed_ide_version 2>/dev/null || true)
    cli_ver=$(get_installed_cli_version 2>/dev/null || true)
    sdk_ver=$(get_installed_sdk_version 2>/dev/null || true)

    local any_app_found=0
    local bin_path=""
    if command -v antigravity >/dev/null 2>&1; then
        bin_path=$(command -v antigravity)
        check_status "Antigravity binary found in PATH ($bin_path${agy_ver:+, v$agy_ver})" "true"
        any_app_found=1
    elif [ -x "$BIN_DIR/antigravity" ]; then
        check_status "Antigravity binary found in $BIN_DIR ($BIN_DIR/antigravity${agy_ver:+, v$agy_ver})" "true"
        any_app_found=1
    elif [ -d "/Applications/Antigravity.app" ]; then
        check_status "Antigravity app bundle found (/Applications/Antigravity.app${agy_ver:+, v$agy_ver})" "true"
        any_app_found=1
    elif [ -d "/Applications/Google Antigravity.app" ]; then
        bin_path="/Applications/Google Antigravity.app/Contents/MacOS/Google Antigravity"
        check_status "Antigravity binary found in Applications" "test -x '$bin_path'"
        any_app_found=1
    fi

    if command -v antigravity-ide >/dev/null 2>&1; then
        bin_path=$(command -v antigravity-ide)
        check_status "Antigravity IDE binary found in PATH ($bin_path${ide_ver:+, v$ide_ver})" "true"
        any_app_found=1
    elif [ -x "$BIN_DIR/antigravity-ide" ]; then
        check_status "Antigravity IDE binary found in $BIN_DIR ($BIN_DIR/antigravity-ide${ide_ver:+, v$ide_ver})" "true"
        any_app_found=1
    elif [ -d "/Applications/Antigravity IDE.app" ]; then
        check_status "Antigravity IDE app bundle found (/Applications/Antigravity IDE.app${ide_ver:+, v$ide_ver})" "true"
        any_app_found=1
    fi

    if [ "$any_app_found" -eq 0 ]; then
        check_status "Antigravity binary found in PATH" "false"
    fi

    # 2. Chrome/Chromium installation
    local chrome_path
    chrome_path=$(find_chrome_binary)
    if [ -n "$chrome_path" ] && [ -x "$chrome_path" ]; then
        check_status "Chrome/Chromium found ($chrome_path)" "true"
    else
        check_status "Chrome/Chromium found" "false"
    fi

    # 3. State file
    if [ -f "$STATE_FILE" ]; then
        check_status "Installation state file exists ($STATE_FILE)" "true"
    elif [ -f "${STATE_DIR}/install-ide.json" ]; then
        check_status "Installation state file exists (${STATE_DIR}/install-ide.json)" "true"
    else
        check_status "Installation state file exists ($STATE_FILE)" "false"
    fi

    # 4. Workspace
    check_status "Default workspace exists ($WORKSPACE_DIR)" "test -d '$WORKSPACE_DIR'"

    # 5. Antigravity CLI (Optional)
    if command -v agy >/dev/null 2>&1; then
        echo -e "  ${C_GREEN}✅ Antigravity CLI found in PATH ($(command -v agy)${cli_ver:+, v$cli_ver})${C_RESET}"
    elif [ -x "$BIN_DIR/agy" ]; then
        echo -e "  ${C_GREEN}✅ Antigravity CLI found ($BIN_DIR/agy${cli_ver:+, v$cli_ver})${C_RESET}"
    fi

    # 6. Antigravity Python SDK (Optional)
    if command -v python3 >/dev/null 2>&1 && python3 -c 'import importlib.metadata; importlib.metadata.version("google-antigravity")' >/dev/null 2>&1; then
        echo -e "  ${C_GREEN}✅ Antigravity Python SDK found in Python environment${sdk_ver:+ (v$sdk_ver)}${C_RESET}"
    fi

    # 7. Google Jules CLI (Optional)
    if command -v jules >/dev/null 2>&1; then
        echo -e "  ${C_GREEN}✅ Google Jules CLI found in PATH ($(command -v jules))${C_RESET}"
    elif [ -x "$BIN_DIR/jules" ]; then
        echo -e "  ${C_GREEN}✅ Google Jules CLI found ($BIN_DIR/jules)${C_RESET}"
    fi

    echo ""
    if [ "$failed" -eq 0 ]; then
        log_info "${C_GREEN}${C_BOLD}🎉 Health check passed! Your installation is healthy.${C_RESET}"
    else
        log_warn "${C_BOLD}$failed issue(s) detected.${C_RESET} You may need to run the installer again."
    fi
}
