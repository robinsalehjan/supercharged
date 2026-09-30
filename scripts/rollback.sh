#!/bin/zsh

# Roll back to the most recent configuration snapshot.
# Usage: ./rollback.sh [backup_dir]
#   If backup_dir is not provided, uses the last backup from ~/.supercharged_last_backup

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

cleanup() {
    standard_cleanup "Rollback"
}
trap cleanup EXIT

restore_from_backup "$@"
