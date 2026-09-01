#!/bin/zsh

# ============================================================================
# asdf Pin Updater
# ============================================================================
# Proposes newer asdf runtime pins for dot_files/.tool-versions, honouring the
# per-plugin policy in agent_config/asdf_policy.json.
#
# `asdf latest` is deliberately not used: it resolves Node.js to the current
# (non-LTS) major and Python to the freethreaded `t` build, neither of which
# matches what setup should install. Candidates come from `asdf list all`
# filtered by the plugin's `match` pattern and optional `line` prefix.
#
# Usage:
#   ./update-asdf-pins.sh            # Report drift only
#   ./update-asdf-pins.sh --apply    # Rewrite dot_files/.tool-versions
#
# Test hook: ASDF_LIST_FIXTURE_DIR=<dir> reads <dir>/<plugin>.txt instead of
# invoking asdf, so the resolution logic is testable without the runtimes.

set -euo pipefail

source "$(dirname "$0")/utils.sh"

TOOL_VERSIONS="${ASDF_TOOL_VERSIONS:-$UTILS_PROJECT_ROOT/dot_files/.tool-versions}"
POLICY="${ASDF_POLICY_MANIFEST:-$UTILS_PROJECT_ROOT/agent_config/asdf_policy.json}"
APPLY=false
[ "${1:-}" = "--apply" ] && APPLY=true
if [ -n "${1:-}" ] && [ "${1:-}" != "--apply" ]; then
    echo "Usage: $(basename "$0") [--apply]" >&2
    exit 2
fi

for required in "$TOOL_VERSIONS" "$POLICY"; do
    if [ ! -f "$required" ]; then
        echo "Required file not found: $required" >&2
        exit 1
    fi
done

# Every candidate version a plugin publishes, newest last.
list_all_versions() {
    local plugin="$1"
    if [ -n "${ASDF_LIST_FIXTURE_DIR:-}" ]; then
        cat "$ASDF_LIST_FIXTURE_DIR/$plugin.txt" 2>/dev/null || true
        return 0
    fi
    asdf list all "$plugin" 2>/dev/null || true
}

current_pin() {
    local plugin="$1"
    awk -v plugin="$plugin" '$1 == plugin { print $2; exit }' "$TOOL_VERSIONS"
}

# Newest version matching the plugin's shape, restricted to its tracked line.
resolve_candidate() {
    local plugin="$1" match="$2" line="$3" versions
    versions=$(list_all_versions "$plugin" | tr -d ' \r')
    [ -n "$versions" ] || return 1
    if [ -n "$line" ]; then
        versions=$(printf '%s\n' "$versions" | grep -E "^${line//./\\.}\\.") || return 1
    fi
    printf '%s\n' "$versions" | grep -E "$match" | tail -1
}

updates=()
held=()
plugins=$(jq -r '.plugins | keys[]' "$POLICY")

while IFS= read -r plugin; do
    [ -n "$plugin" ] || continue
    policy=$(jq -r --arg p "$plugin" '.plugins[$p].policy' "$POLICY")
    current=$(current_pin "$plugin")

    if [ -z "$current" ]; then
        echo "warning: $plugin has a policy but no pin in $TOOL_VERSIONS" >&2
        continue
    fi

    if [ "$policy" = "hold" ]; then
        held+=("$plugin $current")
        continue
    fi

    match=$(jq -r --arg p "$plugin" '.plugins[$p].match' "$POLICY")
    line=$(jq -r --arg p "$plugin" '.plugins[$p].line // ""' "$POLICY")

    if ! candidate=$(resolve_candidate "$plugin" "$match" "$line") || [ -z "$candidate" ]; then
        echo "warning: could not resolve a $plugin version (is the asdf plugin added?)" >&2
        continue
    fi

    [ "$candidate" = "$current" ] && continue
    updates+=("$plugin $current $candidate")
done <<< "$plugins"

for entry in "${held[@]}"; do
    read -r plugin pin <<< "$entry"
    echo "held:  $plugin $pin (manual policy)"
done

if [ "${#updates[@]}" -eq 0 ]; then
    echo "asdf pins are current"
    exit 0
fi

for entry in "${updates[@]}"; do
    read -r plugin from to <<< "$entry"
    echo "$plugin: $from -> $to"
done

if ! $APPLY; then
    echo "Run: npm run update:asdf-pins -- --apply"
    exit 0
fi

tmp=$(mktemp "${TOOL_VERSIONS}.XXXXXX")
# shellcheck disable=SC2064  # $tmp must be expanded now, not when signalled.
trap "rm -f ${(q)tmp}" EXIT
cp "$TOOL_VERSIONS" "$tmp"
for entry in "${updates[@]}"; do
    read -r plugin _ to <<< "$entry"
    # Only the pin line changes; comments and layout are preserved.
    awk -v plugin="$plugin" -v version="$to" \
        '$1 == plugin && NF == 2 { print plugin, version; next } { print }' \
        "$tmp" > "$tmp.next"
    mv "$tmp.next" "$tmp"
done
mv "$tmp" "$TOOL_VERSIONS"
trap - EXIT
echo "Updated $TOOL_VERSIONS"
