#!/bin/zsh

# Generate Claude's flat project-skill compatibility files from the canonical
# agent_config/skills/<name>/SKILL.md inventory. Codex restores those canonical
# directories directly; this script is deliberately one-way.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CANONICAL_SKILLS_DIR="$PROJECT_ROOT/agent_config/skills"
CLAUDE_SKILLS_DIR="$PROJECT_ROOT/.claude/skills"
CHECK_ONLY=false

case "${1:-}" in
    "") ;;
    --check) CHECK_ONLY=true ;;
    -h|--help)
        echo "Usage: $(basename "$0") [--check]"
        exit 0
        ;;
    *)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
esac

if [ ! -d "$CANONICAL_SKILLS_DIR" ]; then
    echo "Canonical shared skills not found: $CANONICAL_SKILLS_DIR" >&2
    exit 1
fi

mkdir -p "$CLAUDE_SKILLS_DIR"
failed=false
expected_names=()

while IFS= read -r source; do
    name=$(basename "$(dirname "$source")")
    expected_names+=("$name")
    destination="$CLAUDE_SKILLS_DIR/$name.md"

    if [ "$CHECK_ONLY" = true ]; then
        if [ ! -f "$destination" ] || ! cmp -s "$source" "$destination"; then
            echo "Claude skill mirror drift: $name" >&2
            failed=true
        fi
    else
        cp "$source" "$destination"
        echo "Generated Claude skill mirror: $name"
    fi
done < <(find "$CANONICAL_SKILLS_DIR" -mindepth 2 -maxdepth 2 -type f -name 'SKILL.md' | sort)

while IFS= read -r destination; do
    name=$(basename "$destination" .md)
    if [[ " ${expected_names[*]} " != *" $name "* ]]; then
        echo "Unexpected Claude skill mirror: $name" >&2
        failed=true
    fi
done < <(find "$CLAUDE_SKILLS_DIR" -maxdepth 1 -type f -name '*.md' | sort)

if [ "$failed" = true ]; then
    exit 1
fi
