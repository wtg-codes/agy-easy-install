ensure_log_file() {
    if [ "${LOG_INITIALIZED:-0}" -eq 1 ] && [ -n "${LOG_FILE:-}" ] && [ ! -L "$LOG_FILE" ]; then
        return 0
    fi

    local candidate="${LOG_FILE:-}"
    if [ -n "$candidate" ]; then
        local cdir
        cdir=$(dirname "$candidate")
        if [ ! -L "$candidate" ] && mkdir -p "$cdir" 2>/dev/null && (umask 077 && : >> "$candidate") 2>/dev/null; then
            LOG_FILE="$candidate"
            LOG_INITIALIZED=1
            return 0
        fi
    fi

    local state_log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/antigravity"
    local user_log="$state_log_dir/install.log"
    if [ -n "${HOME:-}" ] && (umask 077 && mkdir -p "$state_log_dir") 2>/dev/null; then
        chmod 700 "$state_log_dir" 2>/dev/null || true
        if [ ! -L "$user_log" ] && (umask 077 && : >> "$user_log") 2>/dev/null; then
            LOG_FILE="$user_log"
            LOG_INITIALIZED=1
            return 0
        fi
    fi

    LOG_FILE=$(umask 077 && mktemp "${TMPDIR:-/tmp}/antigravity-install.XXXXXX.log" 2>/dev/null || echo "/dev/null")
    LOG_INITIALIZED=1
}

verify_sha256() {
    local file_path="$1"
    local expected_raw="$2"
    if [ ! -f "$file_path" ]; then
        return 1
    fi
    local expected
    expected=$(printf '%s' "$expected_raw" | tr 'A-F' 'a-f')
    if [[ ! "$expected" =~ ^[0-9a-f]{64}$ ]]; then
        rm -f "$file_path" 2>/dev/null || true
        return 1
    fi
    local actual=""
    if command -v sha256sum >/dev/null 2>&1; then
        actual=$(sha256sum "$file_path" 2>/dev/null | awk '{print $1}' | tr 'A-F' 'a-f')
    elif command -v shasum >/dev/null 2>&1; then
        actual=$(shasum -a 256 "$file_path" 2>/dev/null | awk '{print $1}' | tr 'A-F' 'a-f')
    else
        rm -f "$file_path" 2>/dev/null || true
        log_error "sha256sum or shasum is required for checksum verification."
        return 1
    fi
    if [ "$actual" != "$expected" ]; then
        rm -f "$file_path" 2>/dev/null || true
        return 1
    fi
    return 0
}

cleanup_ui() {
    if [ "${JSON_OUT:-0}" -eq 0 ] && [ "${QUIET:-0}" -eq 0 ] && [ -t 1 ]; then
        tput cnorm 2>/dev/null || true
        printf "\r\033[K" 2>/dev/null || true
    fi
    if [ -n "${PENDING_ROLLBACK_BACKUP:-}" ] && [ -d "$PENDING_ROLLBACK_BACKUP" ] && [ -n "${PENDING_ROLLBACK_TARGET:-}" ] && [ ! -d "$PENDING_ROLLBACK_TARGET" ]; then
        mv "$PENDING_ROLLBACK_BACKUP" "$PENDING_ROLLBACK_TARGET" 2>/dev/null || cp -R "$PENDING_ROLLBACK_BACKUP" "$PENDING_ROLLBACK_TARGET" 2>/dev/null || true
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
        if [ "$exit_code" -ne 0 ]; then
            JSON_STATUS="error"
        fi
        if [ -n "${JSON_CUSTOM_PAYLOAD:-}" ]; then
            printf '%s\n' "$JSON_CUSTOM_PAYLOAD"
        else
            cat <<EOF
{
  "status": "$JSON_STATUS",
  "method": "$JSON_METHOD",
  "path": "$BIN_DIR"
}
EOF
        fi
    fi
}
trap exit_handler EXIT INT TERM

log_info() {
    local msg="$1"
    ensure_log_file
    echo "$(date '+%Y-%m-%d %H:%M:%S') INFO: $(echo "$msg" | sed -E 's/\x1B\[[0-9;]*[mK]//g')" >> "$LOG_FILE" 2>/dev/null || true
    if [ "$JSON_OUT" -eq 0 ] && [ "$QUIET" -eq 0 ]; then
        echo -e "$msg"
    fi
}

log_error() {
    local msg="$1"
    ensure_log_file
    echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR: $(echo "$msg" | sed -E 's/\x1B\[[0-9;]*[mK]//g')" >> "$LOG_FILE" 2>/dev/null || true
    if [ "$JSON_OUT" -eq 0 ]; then
        echo -e "${C_RED}❌ $msg${C_RESET}"
    fi
}

log_warn() {
    local msg="$1"
    ensure_log_file
    echo "$(date '+%Y-%m-%d %H:%M:%S') WARN: $(echo "$msg" | sed -E 's/\x1B\[[0-9;]*[mK]//g')" >> "$LOG_FILE" 2>/dev/null || true
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
    local expected_gum_sha=""

    [ "$PLATFORM" = "Darwin" ] && OS="Darwin"
    if [ "$(uname -m)" = "aarch64" ] || [ "$(uname -m)" = "arm64" ]; then
        ARCH="arm64"
    fi

    case "${OS}_${ARCH}" in
        Linux_x86_64) expected_gum_sha="$GUM_0_17_0_LINUX_X86_64_SHA256" ;;
        Linux_arm64) expected_gum_sha="$GUM_0_17_0_LINUX_ARM64_SHA256" ;;
        Darwin_x86_64) expected_gum_sha="$GUM_0_17_0_DARWIN_X86_64_SHA256" ;;
        Darwin_arm64) expected_gum_sha="$GUM_0_17_0_DARWIN_ARM64_SHA256" ;;
    esac

    local TARBALL="gum_${GUM_VERSION}_${OS}_${ARCH}.tar.gz"
    local gum_archive="$GUM_DIR/$TARBALL"
    local gum_base_url="${GUM_RELEASE_BASE_URL:-https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}}"

    if curl -fSsL "${gum_base_url}/${TARBALL}" -o "$gum_archive" 2>/dev/null && verify_sha256 "$gum_archive" "$expected_gum_sha"; then
        if tar -xzf "$gum_archive" -C "$GUM_DIR" 2>/dev/null; then
            rm -f "$gum_archive"
            local GUM_BIN
            GUM_BIN=$(find "$GUM_DIR" -name "gum" -type f | head -n 1)
            if [ -n "$GUM_BIN" ]; then
                local gum_dir_path
                gum_dir_path=$(dirname "$GUM_BIN")
                export PATH="$gum_dir_path:$PATH"
                return 0
            fi
        fi
    else
        log_warn "Could not verify ephemeral gum UI archive; falling back to standard text prompts."
    fi

    rm -rf "$GUM_DIR" 2>/dev/null || true
    GUM_DIR=""
    return 0
}

run_cmd() {
    ensure_log_file
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
    ensure_log_file
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
