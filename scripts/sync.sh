#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

FORCE_SYNC=false
ONLY_MODE=false
SYNC_CLAUDE=true
SYNC_CODEX=true
SYNC_DOTFILES=true

show_help() {
    echo "Usage: $(basename "$0") [--force] [--only TARGET]..."
    echo ""
    echo "Apply repository-managed configuration with one rollback snapshot."
    echo ""
    echo "Targets: agents, claude, codex, dotfiles"
    echo ""
    echo "Options:"
    echo "  --force        Apply Claude and Codex config regardless of timestamps"
    echo "  --only TARGET  Sync only the selected target; may be repeated"
    echo "  -h, --help     Show this help message"
}

select_target() {
    local target="$1"

    if [ "$ONLY_MODE" != true ]; then
        ONLY_MODE=true
        SYNC_CLAUDE=false
        SYNC_CODEX=false
        SYNC_DOTFILES=false
    fi

    case "$target" in
        agents)
            SYNC_CLAUDE=true
            SYNC_CODEX=true
            ;;
        claude) SYNC_CLAUDE=true ;;
        codex) SYNC_CODEX=true ;;
        dotfiles) SYNC_DOTFILES=true ;;
        *)
            log_with_level "ERROR" "Unknown sync target: ${target:-<missing>}"
            echo "Valid targets: agents, claude, codex, dotfiles"
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
            --force)
                FORCE_SYNC=true
                shift
                ;;
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

    create_restoration_point

    local -a sync_args
    sync_args=(--skip-backup)
    if [ "$FORCE_SYNC" = true ]; then
        sync_args+=(--force)
    fi

    if [ "$SYNC_CLAUDE" = true ]; then
        "$SCRIPT_DIR/restore-claude.sh" "${sync_args[@]}"
    fi
    if [ "$SYNC_CODEX" = true ]; then
        "$SCRIPT_DIR/restore-codex.sh" "${sync_args[@]}"
    fi
    if [ "$SYNC_DOTFILES" = true ]; then
        "$SCRIPT_DIR/setup-profile.sh" --skip-backup
    fi
}

main "$@"
