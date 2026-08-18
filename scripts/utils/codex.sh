#!/bin/zsh

# Machine-local Codex configuration is intentionally preserved at restore time
# and excluded from repository backups. Keep this inventory centralized so the
# two directions cannot drift.
is_local_codex_config_table() {
    local line="$1"

    case "$line" in
        "[projects."*|\
        "[tui.model_availability_nux]"|\
        "[notice]"|\
        "[notice."*|\
        "[hooks.state]"|\
        "[hooks.state."*|\
        "[desktop]"|\
        "[marketplaces."*|\
        "[plugins."*|\
        "[apps.connector_"*|\
        "[mcp_servers.plugin_"*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# These legacy runtime tables are neither tracked nor restored. Keeping this
# separate from local-state preservation ensures a backup cannot reintroduce
# the retired Node REPL bridge or its machine-specific trust hashes.
is_removed_codex_config_table() {
    local line="$1"

    case "$line" in
        "[mcp_servers.node_repl]"|"[mcp_servers.node_repl."*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

is_removed_codex_feature_key() {
    local line="$1"
    local trimmed key

    trimmed="${line#"${line%%[![:space:]]*}"}"
    [[ "$trimmed" == *=* ]] || return 1
    key="${trimmed%%=*}"
    key="${key//[[:space:]]/}"
    [ "$key" = "js_repl" ]
}

is_local_codex_config_key() {
    local line="$1"

    case "$line" in
        "notify = "*|\
        "service_tier = "*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

extract_local_codex_top_level() {
    local in_top_level=true

    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" == \[* ]]; then
            in_top_level=false
        fi

        if [ "$in_top_level" = true ] && is_local_codex_config_key "$line"; then
            printf '%s\n' "$line"
        fi
    done
}

extract_local_codex_tables() {
    local keep=false

    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" == \[* ]]; then
            keep=false
            if is_local_codex_config_table "$line"; then
                keep=true
            fi
        fi

        if [ "$keep" = true ]; then
            printf '%s\n' "$line"
        fi
    done
}
