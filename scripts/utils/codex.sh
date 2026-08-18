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
        "[mcp_servers.plugin_"*|\
        "[mcp_servers.node_repl]"|\
        "[mcp_servers.node_repl."*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
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

is_local_codex_feature_key() {
    local line="$1"
    local trimmed key

    trimmed="${line#"${line%%[![:space:]]*}"}"
    [[ "$trimmed" == *=* ]] || return 1
    key="${trimmed%%=*}"
    key="${key//[[:space:]]/}"
    [ "$key" = "js_repl" ]
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

extract_local_codex_features() {
    local in_features=false
    local found=false

    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" == \[* ]]; then
            if [ "$line" = "[features]" ]; then
                in_features=true
            else
                in_features=false
            fi
            continue
        fi

        if [ "$in_features" = true ] && [ "$found" = false ] && is_local_codex_feature_key "$line"; then
            printf '%s\n' "$line"
            found=true
        fi
    done
}

# Remove repository js_repl values and inject the machine-local value into the
# restored [features] table. If the repository has no [features] table, create
# one. At most one js_repl key is emitted.
merge_local_codex_features() {
    local feature_state="${1:-}"

    awk -v feature_state="$feature_state" '
        BEGIN { in_features = 0; saw_features = 0; injected = 0 }

        function inject_feature_state() {
            if (feature_state != "" && !injected) {
                print feature_state
                injected = 1
            }
        }

        /^\[features\]$/ {
            if (in_features) inject_feature_state()
            print
            in_features = 1
            saw_features = 1
            next
        }

        /^\[/ {
            if (in_features) inject_feature_state()
            in_features = 0
        }

        in_features && /^[[:space:]]*js_repl[[:space:]]*=/ { next }

        { print }

        END {
            if (in_features) inject_feature_state()
            if (!saw_features && feature_state != "") {
                print ""
                print "[features]"
                print feature_state
            }
        }
    '
}
