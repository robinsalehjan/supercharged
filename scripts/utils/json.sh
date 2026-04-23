#!/bin/zsh

# Path portability helpers - make paths portable across machines
make_path_portable() {
    # Save stdin to temp file to avoid shell escape sequence interpretation
    local tmpfile
    tmpfile=$(mktemp)
    cat > "$tmpfile"

    # Check if input is valid JSON
    if jq empty "$tmpfile" 2>/dev/null; then
        # JSON-aware path portability using jq walk to preserve escape sequences
        # Uses walk to recursively process all string values in the JSON structure
        jq --arg home "$HOME" 'walk(if type == "string" then gsub($home; "$HOME") else . end)' "$tmpfile"
    else
        # Fall back to sed for non-JSON files
        sed "s|$HOME|\$HOME|g" "$tmpfile"
    fi

    rm -f "$tmpfile"
}

expand_portable_path() {
    # Save stdin to temp file to avoid shell escape sequence interpretation
    local tmpfile
    tmpfile=$(mktemp)
    cat > "$tmpfile"

    # Check if input is valid JSON
    if jq empty "$tmpfile" 2>/dev/null; then
        # JSON-aware path expansion using jq walk to preserve escape sequences
        # Uses walk to recursively process all string values in the JSON structure
        jq --arg home "$HOME" 'walk(if type == "string" then gsub("\\$HOME"; $home) else . end)' "$tmpfile"
    else
        # Fall back to sed for non-JSON files
        sed "s|\\\$HOME|$HOME|g" "$tmpfile"
    fi

    rm -f "$tmpfile"
}

# Filter JSON entries by marketplace suffix
# Usage: filter_json_by_marketplace INPUT_JSON JQ_PATH MARKETPLACE1 MARKETPLACE2...
# Returns: JSON with entries NOT matching @MARKETPLACE suffixes removed
# Example: filter_json_by_marketplace file.json ".plugins" "vend-plugins" "work-plugins"
filter_json_by_marketplace() {
    local input="$1"
    local jq_path="$2"
    shift 2
    local marketplaces=("$@")

    # Build jq filter with --arg for safe injection
    local jq_args=()
    local jq_filter="$jq_path | to_entries"
    local i=0

    for marketplace in "${marketplaces[@]}"; do
        jq_args+=(--arg "mp$i" "@$marketplace")
        jq_filter="$jq_filter | map(select(.key | endswith(\$mp$i) | not))"
        i=$((i + 1))
    done
    jq_filter="$jq_filter | from_entries"

    jq "${jq_args[@]}" "$jq_filter" <<< "$input"
}
