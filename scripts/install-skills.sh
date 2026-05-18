#!/bin/zsh

# ============================================================================
# Claude Code Skills Installer
# ============================================================================
# Clones (or updates) git-based Claude Code skills listed in
# claude_config/installed_skills.json into ~/.claude/skills/.
#
# Skills are auto-discovered by Claude Code from ~/.claude/skills/<name>/SKILL.md
# and do not require any CLI registration step.
#
# Usage:
#   ./install-skills.sh           # Clone or update all tracked skills
#   ./install-skills.sh --dry-run # Show what would be installed
#
# Optional override: claude_config/installed_skills.local.json (merged on top
# of installed_skills.json, local wins on conflict).

set -e
set -o pipefail

source "$(dirname "$0")/utils.sh"

PROJECT_ROOT="$UTILS_PROJECT_ROOT"
CLAUDE_CONFIG_DIR="$PROJECT_ROOT/claude_config"
SKILLS_DIR="$HOME/.claude/skills"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            log_with_level "WARN" "Unknown option: $1"
            shift
            ;;
    esac
done

if ! command_exists git; then
    log_with_level "ERROR" "git is required"
    exit 1
fi

if ! command_exists jq; then
    log_with_level "ERROR" "jq is required — install with: brew install jq"
    exit 1
fi

SKILLS_FILE="$CLAUDE_CONFIG_DIR/installed_skills.json"
SKILLS_LOCAL_FILE="$CLAUDE_CONFIG_DIR/installed_skills.local.json"

if [ ! -f "$SKILLS_FILE" ]; then
    log_with_level "INFO" "No installed_skills.json found — nothing to do"
    exit 0
fi

log_with_level "INFO" "Installing skills into $SKILLS_DIR..."
mkdir -p "$SKILLS_DIR"

# Merge repo + local (local wins on conflict)
SKILLS_JSON=$(jq -s '{ version: .[0].version, skills: (.[0].skills * ((.[1] // {}).skills // {})) }' \
    "$SKILLS_FILE" \
    "$([ -f "$SKILLS_LOCAL_FILE" ] && echo "$SKILLS_LOCAL_FILE" || echo "/dev/null")" \
    2>/dev/null || cat "$SKILLS_FILE")

if [ -f "$SKILLS_LOCAL_FILE" ]; then
    local_count=$(jq '.skills | length' "$SKILLS_LOCAL_FILE" 2>/dev/null || echo 0)
    log_with_level "INFO" "Merged $local_count local skill(s) from installed_skills.local.json"
fi

# Iterate over each tracked skill
while IFS=$'\t' read -r name repo ref; do
    [ -z "$name" ] && continue
    target="$SKILLS_DIR/$name"
    ref="${ref:-main}"

    if [ "$DRY_RUN" = true ]; then
        if [ -d "$target/.git" ]; then
            log_with_level "INFO" "[dry-run] Would update skill: $name ($repo @ $ref)"
        else
            log_with_level "INFO" "[dry-run] Would clone skill: $name ($repo @ $ref)"
        fi
        continue
    fi

    if [ -d "$target/.git" ]; then
        log_with_level "INFO" "Updating skill: $name"
        if git -C "$target" fetch --quiet origin "$ref" 2>/dev/null \
           && git -C "$target" checkout --quiet "$ref" 2>/dev/null \
           && git -C "$target" pull --ff-only --quiet origin "$ref" 2>/dev/null; then
            log_with_level "SUCCESS" "Updated skill: $name"
        else
            log_with_level "WARN" "Failed to update skill: $name (continuing)"
        fi
    elif [ -e "$target" ]; then
        log_with_level "WARN" "Skipping $name — $target exists but is not a git checkout"
    else
        log_with_level "INFO" "Cloning skill: $name from $repo"
        if git clone --quiet --branch "$ref" "$repo" "$target" 2>/dev/null \
           || git clone --quiet "$repo" "$target" 2>/dev/null; then
            log_with_level "SUCCESS" "Installed skill: $name"
        else
            log_with_level "WARN" "Failed to clone skill: $name (continuing)"
        fi
    fi
done < <(echo "$SKILLS_JSON" | jq -r '.skills | to_entries[] | [.key, .value.repo, (.value.ref // "main")] | @tsv')

log_with_level "SUCCESS" "Skill installation complete"
if [ "$DRY_RUN" = false ]; then
    echo ""
    echo "Restart Claude Code to pick up newly installed skills"
fi
