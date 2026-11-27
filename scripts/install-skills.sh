#!/bin/zsh
set -euo pipefail
source "$(dirname "$0")/utils.sh"
exec python3 "$UTILS_PROJECT_ROOT/scripts/shared_skills.py" "$@"
