#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

WITH_BACKUP=false
DRY_RUN=false
typeset -a UPDATE_ARGS=()

show_help() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Sync managed configuration, reconcile agent tooling, and update dependencies."
    echo ""
    echo "Options:"
    echo "  --backup          Capture agent configuration before updating"
    echo "  --dry-run         Preview agent-tool and dependency updates"
    echo "  --only COMPONENT  Update only brew, asdf, zsh, npm, or pip; may be repeated"
    echo "  --skip-brew       Skip Homebrew formula updates"
    echo "  --skip-cask       Skip Homebrew cask updates"
    echo "  --skip-asdf       Skip asdf plugin and version updates"
    echo "  --skip-zsh        Skip zsh plugin updates"
    echo "  --skip-npm        Skip npm global package updates"
    echo "  --skip-pip        Skip pip package updates"
    echo "  -h, --help        Show this help message"
}

cleanup() {
    :
}
trap cleanup EXIT

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --backup)
                WITH_BACKUP=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                UPDATE_ARGS+=("$1")
                shift
                ;;
            --only)
                UPDATE_ARGS+=("$1")
                shift
                case "${1:-}" in
                    brew|asdf|zsh|npm|pip) UPDATE_ARGS+=("$1") ;;
                    *)
                        log_with_level "ERROR" "Unknown update component: ${1:-<missing>}"
                        echo "Valid components: brew, asdf, zsh, npm, pip"
                        return 1
                        ;;
                esac
                shift
                ;;
            --skip-brew|--skip-cask|--skip-asdf|--skip-zsh|--skip-npm|--skip-pip)
                UPDATE_ARGS+=("$1")
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

    if [ "$WITH_BACKUP" = true ] && [ "$DRY_RUN" = true ]; then
        log_with_level "ERROR" "--backup cannot be combined with --dry-run"
        return 1
    fi

    if [ "$WITH_BACKUP" = true ]; then
        "$SCRIPT_DIR/backup-all.sh"
    fi

    if [ "$DRY_RUN" = true ]; then
        "$SCRIPT_DIR/install-agent-tooling.sh" --dry-run
    else
        "$SCRIPT_DIR/sync.sh" --only dotfiles
        "$SCRIPT_DIR/install-agent-tooling.sh"
    fi

    "$SCRIPT_DIR/update.sh" "${UPDATE_ARGS[@]}"
}

main "$@"
