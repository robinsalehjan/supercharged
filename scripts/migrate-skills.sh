#!/bin/zsh
# Explicit machine upgrade; ordinary setup only installs into unclaimed destinations.
set -euo pipefail
source "$(dirname "$0")/utils.sh"
typeset -a mcp_args
mcp_args=()
ios_tools_selected && mcp_args+=(--ios)
if [[ ${1:-} == --dry-run && $# == 1 ]]; then
    "$UTILS_PROJECT_ROOT/scripts/install-skills.sh" --migrate --dry-run
    "$UTILS_PROJECT_ROOT/scripts/install-mcps.py" --dry-run "${mcp_args[@]}"
    exec python3 "$UTILS_PROJECT_ROOT/scripts/migrate-skill-plugins.py" --dry-run
fi
if (( $# )); then
    echo "Usage: migrate-skills.sh [--dry-run]" >&2
    exit 2
fi
# The standard rollback snapshot is scoped to the active account's default homes.
if [[ ${CODEX_HOME:-$HOME/.codex} != "$HOME/.codex" || ${CLAUDE_CONFIG_DIR:-$HOME/.claude} != "$HOME/.claude" ||
      ${CLAUDE_HOME:-$HOME/.claude} != "$HOME/.claude" || -n ${CODEX_SKILLS_DIR:-} || -n ${CLAUDE_SKILLS_DIR:-} ]]; then
    log_with_level ERROR "Migration requires the default agent directories for this HOME"
    exit 1
fi
"$UTILS_PROJECT_ROOT/scripts/install-mcps.py" --dry-run "${mcp_args[@]}"
python3 "$UTILS_PROJECT_ROOT/scripts/migrate-skill-plugins.py" --dry-run
create_restoration_point
snapshot=$(<"$HOME/.supercharged_last_backup")
log_with_level INFO "To recover the pre-migration configuration, run npm run rollback -- '$snapshot'"
"$UTILS_PROJECT_ROOT/scripts/install-skills.sh" --migrate
"$UTILS_PROJECT_ROOT/scripts/install-mcps.py" "${mcp_args[@]}"
python3 "$UTILS_PROJECT_ROOT/scripts/migrate-skill-plugins.py"
