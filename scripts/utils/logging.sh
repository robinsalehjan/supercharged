#!/bin/zsh

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
