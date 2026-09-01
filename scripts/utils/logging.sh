#!/bin/zsh

# Guard: UTILS_LOG_FILE must be set by the parent loader (utils.sh)
if [[ -z "${UTILS_LOG_FILE:-}" ]]; then
    echo "[ERROR] logging.sh: UTILS_LOG_FILE is not set. Source utils.sh instead of submodules directly." >&2
    return 1
fi

# Every script run appends to UTILS_LOG_FILE and nothing ever truncated it, so
# the log grew without bound. Rotate once per load (not per log line) whenever
# the active log passes the size cap, keeping a single previous generation.
UTILS_LOG_MAX_BYTES="${UTILS_LOG_MAX_BYTES:-1048576}"

rotate_log_if_large() {
    local size
    [ -f "$UTILS_LOG_FILE" ] || return 0
    size=$(wc -c < "$UTILS_LOG_FILE" 2>/dev/null | tr -d ' ') || return 0
    [ -n "$size" ] || return 0
    [ "$size" -gt "$UTILS_LOG_MAX_BYTES" ] || return 0
    mv -f "$UTILS_LOG_FILE" "$UTILS_LOG_FILE.1" 2>/dev/null || return 0
}

rotate_log_if_large

# Colored output for better user experience
fancy_echo() {
    printf "\n\033[1;32m==> %s\033[0m\n" "$1"
}

# Enhanced logging with levels
log_with_level() {
    local level=$1
    local message=$2
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case $level in
        "ERROR")
            echo "[$timestamp] [❌ ERROR] $message" | tee -a "$UTILS_LOG_FILE" >&2
            ;;
        "WARN")
            echo "[$timestamp] [⚠️  WARN] $message" | tee -a "$UTILS_LOG_FILE"
            ;;
        "INFO")
            echo "[$timestamp] [ℹ️  INFO] $message" | tee -a "$UTILS_LOG_FILE"
            ;;
        "SUCCESS")
            echo "[$timestamp] [✅ SUCCESS] $message" | tee -a "$UTILS_LOG_FILE"
            ;;
        *)
            echo "[$timestamp] [DEBUG] $message" | tee -a "$UTILS_LOG_FILE"
            ;;
    esac
}

# Logging setup
setup_logging() {
    exec 1> >(tee -a "$UTILS_LOG_FILE")
    exec 2> >(tee -a "$UTILS_LOG_FILE" >&2)
    log_with_level "INFO" "Installation started"
}
