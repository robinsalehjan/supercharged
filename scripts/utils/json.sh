#!/bin/zsh

# Path portability helpers - make paths portable across machines
make_path_portable() {
    local input
    input=$(cat)
    if echo "$input" | jq empty 2>/dev/null; then
        echo "$input" | jq --arg home "$HOME" 'walk(if type == "string" then gsub($home; "$HOME") else . end)'
    else
        log_with_level "WARN" "jq validation failed; falling back to sed-based path substitution"
        echo "$input" | sed "s|$HOME|\$HOME|g"
    fi
}

expand_portable_path() {
    local input
    input=$(cat)
    if echo "$input" | jq empty 2>/dev/null; then
        echo "$input" | jq --arg home "$HOME" 'walk(if type == "string" then gsub("\\$HOME"; $home) else . end)'
    else
        log_with_level "WARN" "jq validation failed; falling back to sed-based path expansion"
        echo "$input" | sed "s|\\\$HOME|$HOME|g"
    fi
}

# Filter JSON entries by marketplace suffix
# Usage: filter_json_by_marketplace INPUT_JSON JQ_PATH MARKETPLACE1 MARKETPLACE2...
# Returns: JSON with entries matching @MARKETPLACE suffixes filtered out
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
