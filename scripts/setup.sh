#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

create_restoration_point
"$SCRIPT_DIR/setup-profile.sh" --skip-backup
"$SCRIPT_DIR/mac.sh" --skip-backup
"$SCRIPT_DIR/utils.sh" validate
