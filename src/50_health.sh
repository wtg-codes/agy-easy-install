do_health_check() {
    JSON_METHOD="check"
    log_info "${C_MAG}🔍 Running Google Antigravity Health Check...${C_RESET}"
    if [ "$JSON_OUT" -eq 0 ] && [ "$QUIET" -eq 0 ]; then
        echo ""
    fi

    local passed=0
    local failed=0

    check_status() {
        if eval "$2" > /dev/null 2>&1; then
            if [ "$JSON_OUT" -eq 0 ] && [ "$QUIET" -eq 0 ]; then
                echo -e "  ${C_GREEN}✅ $1${C_RESET}"
            fi
            passed=$((passed + 1))
        else
            if [ "$JSON_OUT" -eq 0 ]; then
                echo -e "  ${C_RED}❌ $1${C_RESET}" >&2
            fi
            failed=$((failed + 1))
        fi
    }

    # 1. Detect installed products across Desktop (Hub/IDE) and Headless (CLI/SDK/agy-box)
    local agy_ver ide_ver cli_ver sdk_ver
    agy_ver=$(get_installed_agy_version 2>/dev/null || true)
    ide_ver=$(get_installed_ide_version 2>/dev/null || true)
    cli_ver=$(get_installed_cli_version 2>/dev/null || true)
    sdk_ver=$(get_installed_sdk_version 2>/dev/null || true)

    local desktop_installed=0
    local headless_installed=0
    local bin_path=""

    if command -v antigravity >/dev/null 2>&1; then
        bin_path=$(command -v antigravity)
        check_status "Antigravity binary found in PATH ($bin_path${agy_ver:+, v$agy_ver})" "true"
        desktop_installed=1
    elif [ -x "$BIN_DIR/antigravity" ]; then
        check_status "Antigravity binary found in $BIN_DIR ($BIN_DIR/antigravity${agy_ver:+, v$agy_ver})" "true"
        desktop_installed=1
    elif [ -d "/Applications/Antigravity.app" ]; then
        check_status "Antigravity app bundle found (/Applications/Antigravity.app${agy_ver:+, v$agy_ver})" "true"
        desktop_installed=1
    elif [ -d "/Applications/Google Antigravity.app" ]; then
        bin_path="/Applications/Google Antigravity.app/Contents/MacOS/Google Antigravity"
        check_status "Antigravity binary found in Applications" "test -x '$bin_path'"
        desktop_installed=1
    fi

    if command -v antigravity-ide >/dev/null 2>&1; then
        bin_path=$(command -v antigravity-ide)
        check_status "Antigravity IDE binary found in PATH ($bin_path${ide_ver:+, v$ide_ver})" "true"
        desktop_installed=1
    elif [ -x "$BIN_DIR/antigravity-ide" ]; then
        check_status "Antigravity IDE binary found in $BIN_DIR ($BIN_DIR/antigravity-ide${ide_ver:+, v$ide_ver})" "true"
        desktop_installed=1
    elif [ -d "/Applications/Antigravity IDE.app" ]; then
        check_status "Antigravity IDE app bundle found (/Applications/Antigravity IDE.app${ide_ver:+, v$ide_ver})" "true"
        desktop_installed=1
    fi

    # 2. Antigravity CLI, Python SDK, Google Jules CLI & agy-box Sandbox
    if command -v agy >/dev/null 2>&1; then
        check_status "Antigravity CLI found in PATH ($(command -v agy)${cli_ver:+, v$cli_ver})" "true"
        headless_installed=1
    elif [ -x "$BIN_DIR/agy" ]; then
        check_status "Antigravity CLI found ($BIN_DIR/agy${cli_ver:+, v$cli_ver})" "true"
        headless_installed=1
    fi

    if [ -n "$sdk_ver" ]; then
        check_status "Antigravity Python SDK found in Python environment (v$sdk_ver)" "true"
        headless_installed=1
    fi

    if command -v agy-box-manager >/dev/null 2>&1; then
        check_status "Antigravity Sandbox (agy-box-manager) found in PATH ($(command -v agy-box-manager))" "true"
        headless_installed=1
    elif [ -x "$BIN_DIR/agy-box-manager" ]; then
        check_status "Antigravity Sandbox (agy-box-manager) found ($BIN_DIR/agy-box-manager)" "true"
        headless_installed=1
    fi

    if command -v jules >/dev/null 2>&1; then
        if [ "$JSON_OUT" -eq 0 ] && [ "$QUIET" -eq 0 ]; then
            echo -e "  ${C_GREEN}✅ Google Jules CLI found in PATH ($(command -v jules))${C_RESET}"
        fi
    elif [ -x "$BIN_DIR/jules" ]; then
        if [ "$JSON_OUT" -eq 0 ] && [ "$QUIET" -eq 0 ]; then
            echo -e "  ${C_GREEN}✅ Google Jules CLI found ($BIN_DIR/jules)${C_RESET}"
        fi
    fi

    # If neither Desktop nor Headless products are present, flag missing installation
    if [ "$desktop_installed" -eq 0 ] && [ "$headless_installed" -eq 0 ]; then
        check_status "Antigravity installation detected (Hub, IDE, CLI, SDK, or agy-box)" "false"
    fi

    # 3. Desktop-specific checks (Chrome/Chromium, state file, workspace) when desktop app is expected
    local desktop_state_present=0
    if [ -f "$STATE_FILE" ] || [ -f "${STATE_DIR}/install-ide.json" ]; then
        desktop_state_present=1
    fi

    if [ "$desktop_installed" -eq 1 ] || [ "$desktop_state_present" -eq 1 ]; then
        local chrome_path
        chrome_path=$(find_chrome_binary)
        if [ -n "$chrome_path" ] && [ -x "$chrome_path" ]; then
            check_status "Chrome/Chromium found ($chrome_path)" "true"
        else
            check_status "Chrome/Chromium found" "false"
        fi

        if [ -f "$STATE_FILE" ]; then
            check_status "Installation state file exists ($STATE_FILE)" "true"
        elif [ -f "${STATE_DIR}/install-ide.json" ]; then
            check_status "Installation state file exists (${STATE_DIR}/install-ide.json)" "true"
        else
            check_status "Installation state file exists ($STATE_FILE)" "false"
        fi

        check_status "Default workspace exists ($WORKSPACE_DIR)" "test -d '$WORKSPACE_DIR'"
    elif [ "$headless_installed" -eq 1 ]; then
        if [ "$JSON_OUT" -eq 0 ] && [ "$QUIET" -eq 0 ]; then
            echo -e "  ${C_CYAN}ℹ️  Headless/CLI profile active — desktop GUI & Chrome checks skipped${C_RESET}"
        fi
    fi

    local overall_status="success"
    if [ "$failed" -gt 0 ]; then
        overall_status="error"
        JSON_STATUS="error"
    fi

    JSON_CUSTOM_PAYLOAD=$(cat <<EOF
{
  "status": "$overall_status",
  "method": "check",
  "path": "$BIN_DIR",
  "arch": "${ARCH:-unknown}",
  "passed": $passed,
  "failed": $failed,
  "versions": {
    "antigravity": "${agy_ver:-}",
    "ide": "${ide_ver:-}",
    "cli": "${cli_ver:-}",
    "sdk": "${sdk_ver:-}"
  }
}
EOF
)

    if [ "$JSON_OUT" -eq 0 ] && [ "$QUIET" -eq 0 ]; then
        echo ""
    fi
    if [ "$failed" -eq 0 ]; then
        log_info "${C_GREEN}${C_BOLD}🎉 Health check passed! Your installation is healthy.${C_RESET}"
        return 0
    else
        log_warn "${C_BOLD}$failed issue(s) detected.${C_RESET} You may need to run the installer again."
        exit 1
    fi
}
