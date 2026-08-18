#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

FORCE_RESTORE=false
AGENTS_ONLY=false

show_help() {
    echo "Usage: $(basename "$0") [--force] [--agents-only]"
    echo ""
    echo "Restore managed configuration with one pre-restore snapshot."
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)
                FORCE_RESTORE=true
                shift
                ;;
            --agents-only)
                AGENTS_ONLY=true
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

    create_restoration_point

    local -a restore_args
    restore_args=(--skip-backup)
    if [ "$FORCE_RESTORE" = true ]; then
        restore_args+=(--force)
    fi

    "$SCRIPT_DIR/restore-claude.sh" "${restore_args[@]}"
    "$SCRIPT_DIR/restore-codex.sh" "${restore_args[@]}"
    if [ "$AGENTS_ONLY" != true ]; then
        "$SCRIPT_DIR/setup-profile.sh" --skip-backup
    fi
}

main "$@"
