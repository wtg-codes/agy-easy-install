cleanup_ui() {
    if [ "${JSON_OUT:-0}" -eq 0 ] && [ "${QUIET:-0}" -eq 0 ] && [ -t 1 ]; then
        tput cnorm 2>/dev/null || true
        printf "\r\033[K" 2>/dev/null || true
    fi
    if [ -n "${GUM_DIR:-}" ] && [ -d "$GUM_DIR" ]; then
        rm -rf "$GUM_DIR"
    fi
    if [ "${VERSIONS_JSON_OWNED:-0}" -eq 1 ] && [ -n "${VERSIONS_JSON_CACHE:-}" ] && [ -f "$VERSIONS_JSON_CACHE" ]; then
        rm -f "$VERSIONS_JSON_CACHE"
    fi
    if [ -n "${ACTIVE_TMP_DIR:-}" ] && [ -d "$ACTIVE_TMP_DIR" ]; then
        rm -rf "$ACTIVE_TMP_DIR"
    fi
}

exit_handler() {
    local exit_code=$?
    cleanup_ui
    if [ "$JSON_OUT" -eq 1 ]; then
        if [ $exit_code -ne 0 ]; then
            JSON_STATUS="error"
        fi
        cat <<EOF
{
  "status": "$JSON_STATUS",
  "method": "$JSON_METHOD",
  "path": "$BIN_DIR"
}
EOF
    fi
}
trap exit_handler EXIT INT TERM

log_info() {
    local msg="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') INFO: $(echo "$msg" | sed -E 's/\x1B\[[0-9;]*[mK]//g')" >> "$LOG_FILE"
    if [ "$JSON_OUT" -eq 0 ] && [ "$QUIET" -eq 0 ]; then
        echo -e "$msg"
    fi
}

log_error() {
    local msg="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR: $(echo "$msg" | sed -E 's/\x1B\[[0-9;]*[mK]//g')" >> "$LOG_FILE"
    if [ "$JSON_OUT" -eq 0 ]; then
        echo -e "${C_RED}❌ $msg${C_RESET}"
    fi
}

log_warn() {
    local msg="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') WARN: $(echo "$msg" | sed -E 's/\x1B\[[0-9;]*[mK]//g')" >> "$LOG_FILE"
    if [ "$JSON_OUT" -eq 0 ] && [ "$QUIET" -eq 0 ]; then
        echo -e "${C_YELLOW}⚠ $msg${C_RESET}"
    fi
}

bootstrap_ui() {
    if command -v gum >/dev/null 2>&1; then
        return 0
    fi
    log_info "  ${C_DIM}Bootstrapping UI dependencies...${C_RESET}"
    GUM_DIR=$(mktemp -d)
    
    local GUM_VERSION="0.17.0"
    local OS="Linux"
    local ARCH="x86_64"
    
    [ "$PLATFORM" = "Darwin" ] && OS="Darwin"
    if [ "$(uname -m)" = "aarch64" ] || [ "$(uname -m)" = "arm64" ]; then
        ARCH="arm64"
    fi
    
    local TARBALL="gum_${GUM_VERSION}_${OS}_${ARCH}.tar.gz"
    
    if curl -fSsL "https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}/${TARBALL}" | tar -xzf - -C "$GUM_DIR" 2>/dev/null; then
        local GUM_BIN
        GUM_BIN=$(find "$GUM_DIR" -name "gum" -type f | head -n 1)
        if [ -n "$GUM_BIN" ]; then
            local gum_dir_path
            gum_dir_path=$(dirname "$GUM_BIN")
            export PATH="$gum_dir_path:$PATH"
        fi
    fi
}

run_cmd() {
    if [ "$VERBOSE" -eq 1 ]; then
        "$@" 2>&1 | tee -a "$LOG_FILE"
    else
        "$@" >> "$LOG_FILE" 2>&1
    fi
}

run_cmd_ui() {
    local msg="$1"
    shift
    if [ "$JSON_OUT" -eq 1 ] || [ "$VERBOSE" -eq 1 ] || [ "$QUIET" -eq 1 ]; then
        run_cmd "$@"
    elif command -v gum >/dev/null 2>&1; then
        gum spin --spinner dot --title "$msg" -- "$@"
    else
        log_info "  $msg"
        run_cmd "$@"
    fi
}

check_dependencies() {
    local deps=("curl" "tar" "awk" "grep")
    local missing=0
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            log_error "Missing required dependency: $dep"
            missing=1
        fi
    done
    if [ "$missing" -eq 1 ]; then
        log_error "Please install missing dependencies and try again."
        exit 1
    fi
    touch "$LOG_FILE" || true
}

fetch_versions_json() {
    if [ -n "${VERSIONS_JSON_CACHE:-}" ] && [ -s "$VERSIONS_JSON_CACHE" ]; then
        return 0
    fi

    if [ -z "${VERSIONS_JSON_CACHE:-}" ]; then
        VERSIONS_JSON_CACHE=$(mktemp "${TMPDIR:-/tmp}/agy-versions.XXXXXX.json")
        VERSIONS_JSON_OWNED=1
    fi

    local local_json=""
    if [ "$VERSIONS_JSON_URL" = "${DEFAULT_VERSIONS_JSON_URL:-}" ] && [ -f "$0" ]; then
        local script_dir
        script_dir=$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo "")
        case "$script_dir" in
            ""|/tmp|/tmp/*|/var/tmp|/var/tmp/*|"${TMPDIR:-/tmp}"|"${TMPDIR:-/tmp}"/*) ;;
            *)
                if [ -s "$script_dir/versions.json" ]; then
                    local_json="$script_dir/versions.json"
                fi
                ;;
        esac
    fi

    if [ -n "$local_json" ]; then
        cp "$local_json" "$VERSIONS_JSON_CACHE"
        return 0
    fi

    if curl -fSsL --connect-timeout 5 "$VERSIONS_JSON_URL" -o "$VERSIONS_JSON_CACHE" 2>/dev/null && [ -s "$VERSIONS_JSON_CACHE" ]; then
        return 0
    fi

    rm -f "$VERSIONS_JSON_CACHE" 2>/dev/null || true
    return 1
}

