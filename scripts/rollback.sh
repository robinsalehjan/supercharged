#!/bin/zsh

# Roll back to the most recent configuration snapshot.
# Usage: ./rollback.sh [backup_dir]
#   If backup_dir is not provided, uses the last backup from ~/.supercharged_last_backup

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

cleanup() {
    local exit_code=$?
    if [ "$exit_code" -ne 0 ]; then
        log_with_level ERROR "Rollback failed with exit code $exit_code"
    fi
    exit "$exit_code"
}
trap cleanup EXIT

restore_from_backup "$@"
