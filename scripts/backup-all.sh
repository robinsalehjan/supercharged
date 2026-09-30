#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

ONLY_MODE=false
BACKUP_CLAUDE=true
BACKUP_CODEX=true

show_help() {
    echo "Usage: $(basename "$0") [--only TARGET]..."
    echo ""
    echo "Capture sanitized agent configuration in the repository."
    echo ""
    echo "Targets: claude, codex"
    echo ""
    echo "Options:"
    echo "  --only TARGET  Back up only the selected target; may be repeated"
    echo "  -h, --help     Show this help message"
}

select_target() {
    local target="$1"

    if [ "$ONLY_MODE" != true ]; then
        ONLY_MODE=true
        BACKUP_CLAUDE=false
        BACKUP_CODEX=false
    fi

    case "$target" in
        claude) BACKUP_CLAUDE=true ;;
        codex) BACKUP_CODEX=true ;;
        *)
            log_with_level "ERROR" "Unknown backup target: ${target:-<missing>}"
            echo "Valid targets: claude, codex"
            return 1
            ;;
    esac
}

cleanup() {
    :
}
trap cleanup EXIT

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --only)
                shift
                select_target "${1:-}" || return 1
                shift
                ;;
            -h|--help)
                show_help
                return 0
                ;;
            *)
                log_with_level "ERROR" "Unknown option: $1"
                return 1
                ;;
        esac
    done

    if [ "$BACKUP_CLAUDE" = true ]; then
        "$SCRIPT_DIR/backup-claude.sh"
    fi
    if [ "$BACKUP_CODEX" = true ]; then
        "$SCRIPT_DIR/backup-codex.sh"
    fi
}

main "$@"
