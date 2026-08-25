#!/bin/zsh

set -euo pipefail

source "$(dirname "$0")/utils.sh"

case "${1:-}" in
    "")
        setup_openwiki
        ;;
    --dry-run)
        setup_openwiki --dry-run
        ;;
    *)
        echo "Usage: $(basename "$0") [--dry-run]" >&2
        exit 2
        ;;
esac
