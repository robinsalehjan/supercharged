#!/bin/zsh

set -e
set -o pipefail

source "$(dirname "$0")/utils.sh"

cleanup() {
    return 0
}
trap cleanup EXIT

case "${1:-}" in
    ""|--dry-run) ;;
    -h|--help)
        echo "Usage: $(basename "$0") [--dry-run]"
        exit 0
        ;;
    *)
        log_with_level "ERROR" "Unknown option: $1"
        exit 2
        ;;
esac

setup_logging
setup_plannotator "$@"
