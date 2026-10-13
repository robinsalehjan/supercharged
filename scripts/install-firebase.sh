#!/bin/zsh

set -euo pipefail

source "$(dirname "$0")/utils.sh"

cleanup() { :; }
trap cleanup EXIT

case "${1:-}" in
    "") setup_firebase ;;
    --dry-run) setup_firebase --dry-run ;;
    *) echo "Usage: $(basename "$0") [--dry-run]" >&2; exit 2 ;;
esac
