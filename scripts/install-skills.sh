#!/bin/zsh

# ============================================================================
# Agent Skills Installer
# ============================================================================
# Installs, updates, or safely prunes git-based agent skills listed in
# agent_config/installed_skills.json into ~/.claude/skills/ and ~/.codex/skills/.
#
# Skills are auto-discovered from <agent-home>/skills/<name>/SKILL.md and do
# not require any CLI registration step.
#
# Usage:
#   ./install-skills.sh           # Reconcile all tracked and retired skills
#   ./install-skills.sh --dry-run # Preview installs, updates, and removals
#
# Optional override: agent_config/installed_skills.local.json (merged on top
# of installed_skills.json, local wins on active skills). Tracked
# removed_skills entries are tombstones and take precedence over both files.

set -e
set -u
set -o pipefail

source "$(dirname "$0")/utils.sh"

PROJECT_ROOT="$UTILS_PROJECT_ROOT"
AGENT_CONFIG_DIR="$PROJECT_ROOT/agent_config"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
CLAUDE_SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$CLAUDE_HOME/skills}"
CODEX_SKILLS_DIR="${CODEX_SKILLS_DIR:-$CODEX_HOME/skills}"
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

SKILLS_FILE="$AGENT_CONFIG_DIR/installed_skills.json"
SKILLS_LOCAL_FILE="$AGENT_CONFIG_DIR/installed_skills.local.json"

if [ ! -f "$SKILLS_FILE" ]; then
    log_with_level "INFO" "No installed_skills.json found — nothing to do"
    exit 0
fi

log_with_level "INFO" "Installing skills into:"
log_with_level "INFO" "  - Claude Code: $CLAUDE_SKILLS_DIR"
log_with_level "INFO" "  - Codex: $CODEX_SKILLS_DIR"

# Merge repo + local (local wins on conflict). Surface jq parse errors instead
# of silently dropping local overrides — a typo in installed_skills.local.json
# should be visible, not invisible.
local_source="/dev/null"
[ -f "$SKILLS_LOCAL_FILE" ] && local_source="$SKILLS_LOCAL_FILE"
if ! SKILLS_JSON=$(jq -s '
    (.[0] // {}) as $base |
    (.[1] // {}) as $local |
    (($base.removed_skills // {}) * ($local.removed_skills // {})) as $removed |
    {
        version: $base.version,
        skills: (($base.skills // {}) * ($local.skills // {})),
        removed_skills: $removed
    } |
    .skills |= with_entries(.key as $name | select(($removed | has($name)) | not))
' \
    "$SKILLS_FILE" "$local_source" 2>&1); then
    log_with_level "WARN" "Failed to merge skills JSON ($SKILLS_JSON) — falling back to $SKILLS_FILE"
    SKILLS_JSON=$(cat "$SKILLS_FILE")
fi

if [ -f "$SKILLS_LOCAL_FILE" ]; then
    if ! local_count=$(jq '.skills | length' "$SKILLS_LOCAL_FILE" 2>&1); then
        log_with_level "WARN" "Could not count local skills ($local_count)"
        local_count=0
    fi
    log_with_level "INFO" "Merged $local_count local skill(s) from installed_skills.local.json"
fi

remove_skill_for_destination() {
    local name="$1"
    local expected_repo="$2"
    local destination_name="$3"
    local skills_dir="$4"
    local target="$skills_dir/$name"
    local actual_repo=""
    local worktree_status=""

    case "$name" in
        ""|.*|*/*|*\\*)
            log_with_level "WARN" "Skipping unsafe removed skill name for $destination_name: $name"
            return 0
            ;;
    esac

    if [ -z "$expected_repo" ] || [ "$expected_repo" = "null" ]; then
        log_with_level "WARN" "Skipping removal of $name for $destination_name — retired skill has no managed origin"
        return 0
    fi

    if [ ! -e "$target" ]; then
        return 0
    fi

    if [ ! -d "$target/.git" ]; then
        log_with_level "WARN" "Skipping removal of $name for $destination_name — $target is not a managed git checkout"
        return 0
    fi

    actual_repo=$(git -C "$target" remote get-url origin 2>/dev/null || true)
    if [ "$actual_repo" != "$expected_repo" ]; then
        log_with_level "WARN" "Skipping removal of $name for $destination_name — origin does not match the retired managed skill"
        return 0
    fi

    if ! worktree_status=$(git -C "$target" status --porcelain --untracked-files=all 2>/dev/null); then
        log_with_level "WARN" "Skipping removal of $name for $destination_name — could not verify checkout cleanliness"
        return 0
    fi

    if [ -n "$worktree_status" ]; then
        log_with_level "WARN" "Skipping removal of $name for $destination_name — managed checkout has local changes"
        return 0
    fi

    if [ "$DRY_RUN" = true ]; then
        log_with_level "INFO" "[dry-run] Would remove retired skill for $destination_name: $name"
        return 0
    fi

    rm -rf -- "$target"
    log_with_level "SUCCESS" "Removed retired skill for $destination_name: $name"
}

install_skill_for_destination() {
    local name="$1"
    local repo="$2"
    local ref="$3"
    local destination_name="$4"
    local skills_dir="$5"
    local target="$skills_dir/$name"

    case "$name" in
        ""|.*|*/*|*\\*)
            log_with_level "WARN" "Skipping unsafe active skill name for $destination_name: $name"
            return 0
            ;;
    esac

    if [ "$DRY_RUN" = true ]; then
        if [ -d "$target/.git" ]; then
            log_with_level "INFO" "[dry-run] Would update skill for $destination_name: $name ($repo @ $ref)"
        else
            log_with_level "INFO" "[dry-run] Would clone skill for $destination_name: $name ($repo @ $ref)"
        fi
        return 0
    fi

    mkdir -p "$skills_dir"

    if [ -d "$target/.git" ]; then
        log_with_level "INFO" "Updating skill for $destination_name: $name"
        if git_err=$(git -C "$target" fetch origin "$ref" 2>&1 \
                  && git -C "$target" checkout "$ref" 2>&1 \
                  && git -C "$target" pull --ff-only origin "$ref" 2>&1); then
            log_with_level "SUCCESS" "Updated skill for $destination_name: $name"
        else
            log_with_level "WARN" "Failed to update skill for $destination_name: $name (continuing) — $git_err"
        fi
    elif [ -e "$target" ]; then
        log_with_level "WARN" "Skipping $name for $destination_name — $target exists but is not a git checkout"
    else
        log_with_level "INFO" "Cloning skill for $destination_name: $name from $repo"
        # Try branch-specific clone first; fall back to default branch. Capture
        # stderr from the final attempt so users see the actual git error.
        if git clone --quiet --branch "$ref" "$repo" "$target" 2>/dev/null; then
            log_with_level "SUCCESS" "Installed skill for $destination_name: $name"
        elif git_err=$(git clone "$repo" "$target" 2>&1); then
            log_with_level "SUCCESS" "Installed skill for $destination_name: $name (default branch)"
        else
            log_with_level "WARN" "Failed to clone skill for $destination_name: $name (continuing) — $git_err"
        fi
    fi
}

# Remove explicitly retired managed skills before installing the active set.
# The origin check protects unrelated local directories with the same name.
while IFS=$'\t' read -r name repo; do
    [ -z "$name" ] && continue

    remove_skill_for_destination \
        "$name" \
        "$repo" \
        "Claude Code" \
        "$CLAUDE_SKILLS_DIR"

    remove_skill_for_destination \
        "$name" \
        "$repo" \
        "Codex" \
        "$CODEX_SKILLS_DIR"
done < <(echo "$SKILLS_JSON" | jq -r '.removed_skills // {} | to_entries[] | [.key, (.value.repo // "")] | @tsv')

# Iterate over each tracked skill
while IFS=$'\t' read -r name repo ref; do
    [ -z "$name" ] && continue
    ref="${ref:-main}"

    if [ -z "$repo" ] || [ "$repo" = "null" ]; then
        log_with_level "WARN" "Skipping $name — repo is not configured"
        continue
    fi

    install_skill_for_destination \
        "$name" \
        "$repo" \
        "$ref" \
        "Claude Code" \
        "$CLAUDE_SKILLS_DIR"

    install_skill_for_destination \
        "$name" \
        "$repo" \
        "$ref" \
        "Codex" \
        "$CODEX_SKILLS_DIR"
done < <(echo "$SKILLS_JSON" | jq -r '.skills // {} | to_entries[] | [.key, .value.repo, (.value.ref // "main")] | @tsv')

log_with_level "SUCCESS" "Skill installation complete"
if [ "$DRY_RUN" = false ]; then
    echo ""
    echo "Restart Claude Code and Codex to pick up newly installed skills"
fi
