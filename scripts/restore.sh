#!/bin/zsh

# Restore from the most recent backup
# Usage: ./restore.sh [backup_dir]
#   If backup_dir is not provided, uses the last backup from ~/.supercharged_last_backup

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source utilities
source "$SCRIPT_DIR/utils.sh"

# Setup trap for cleanup (consistent wrapper used by mac.sh / update.sh)
cleanup() {
    standard_cleanup "Restore"
}
trap cleanup EXIT

# Call the restore function
restore_from_backup "$@"
