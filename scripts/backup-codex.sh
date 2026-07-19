#!/bin/zsh

# ============================================================================
# Codex Backup Script
# ============================================================================
# Backs up durable, non-sensitive Codex configuration from ~/.codex.

set -e
set -o pipefail

source "$(dirname "$0")/utils.sh"

PROJECT_ROOT="$UTILS_PROJECT_ROOT"
CODEX_CONFIG_DIR="$PROJECT_ROOT/codex_config"
AGENT_CONFIG_DIR="$PROJECT_ROOT/agent_config"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"

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
        "service_tier = "*|\
        "js_repl = "*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

filter_shared_codex_config() {
    local skip=false
    local emitted_content=false

    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" == \[* ]]; then
            skip=false
            if is_local_codex_config_table "$line"; then
                skip=true
            fi
        fi

        if [ "$skip" = false ] && ! is_local_codex_config_key "$line"; then
            if [ "$emitted_content" = false ] && [ -z "$line" ]; then
                continue
            fi

            printf '%s\n' "$line"
            [ -n "$line" ] && emitted_content=true
        fi
    done
}

filter_shared_codex_agents() {
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            "@$CODEX_HOME/RTK.md"|"@\$HOME/.codex/RTK.md"|"@RTK.md")
                continue
                ;;
        esac

        printf '%s\n' "$line"
    done
}

backup_codex_skills() {
    local src_dir="$CODEX_HOME/skills"
    local dest_dir="$CODEX_CONFIG_DIR/skills"
    local skill name copied=0

    if [ ! -d "$src_dir" ]; then
        return 0
    fi

    mkdir -p "$dest_dir"
    for skill in "$src_dir"/plannotator-*(N/); do
        name=$(basename "$skill")
        rm -rf "${dest_dir:?}/${name:?}"
        mkdir -p "$dest_dir/$name"
        cp -R "$skill/." "$dest_dir/$name/"
        copied=$((copied + 1))
    done

    if [ "$copied" -gt 0 ]; then
        log_with_level "SUCCESS" "Backed up $copied Codex Plannotator skill(s)"
    fi
}

main() {
    if [ ! -d "$CODEX_HOME" ]; then
        log_with_level "ERROR" "Codex directory not found at $CODEX_HOME"
        log_with_level "INFO" "Run 'codex login' first if Codex is not initialized"
        exit 1
    fi

    mkdir -p "$CODEX_CONFIG_DIR" "$AGENT_CONFIG_DIR"

    log_with_level "INFO" "Backing up Codex configuration..."

    if [ -f "$CODEX_HOME/config.toml" ]; then
        if ! filter_shared_codex_config < "$CODEX_HOME/config.toml" | \
            make_path_portable > "$CODEX_CONFIG_DIR/config.toml.tmp"; then
            rm -f "$CODEX_CONFIG_DIR/config.toml.tmp"
            log_with_level "ERROR" "Failed to process config.toml - backup aborted"
            exit 1
        fi
        mv "$CODEX_CONFIG_DIR/config.toml.tmp" "$CODEX_CONFIG_DIR/config.toml"
        log_with_level "SUCCESS" "Backed up config.toml (local runtime state excluded)"
    else
        log_with_level "WARN" "config.toml not found"
    fi

    if [ -f "$CODEX_HOME/AGENTS.md" ]; then
        if ! filter_shared_codex_agents < "$CODEX_HOME/AGENTS.md" | \
            make_path_portable > "$AGENT_CONFIG_DIR/AGENTS.md.tmp"; then
            rm -f "$AGENT_CONFIG_DIR/AGENTS.md.tmp"
            log_with_level "ERROR" "Failed to process AGENTS.md - backup aborted"
            exit 1
        fi
        mv "$AGENT_CONFIG_DIR/AGENTS.md.tmp" "$AGENT_CONFIG_DIR/AGENTS.md"
        log_with_level "SUCCESS" "Backed up AGENTS.md to shared agent_config"
    else
        log_with_level "WARN" "AGENTS.md not found; keeping existing shared agent_config/AGENTS.md"
    fi

    if [ -f "$CODEX_HOME/hooks.json" ]; then
        if ! make_path_portable < "$CODEX_HOME/hooks.json" > "$CODEX_CONFIG_DIR/hooks.json.tmp"; then
            rm -f "$CODEX_CONFIG_DIR/hooks.json.tmp"
            log_with_level "ERROR" "Failed to process hooks.json - backup aborted"
            exit 1
        fi
        mv "$CODEX_CONFIG_DIR/hooks.json.tmp" "$CODEX_CONFIG_DIR/hooks.json"
        log_with_level "SUCCESS" "Backed up hooks.json (paths made portable)"
    else
        log_with_level "WARN" "hooks.json not found"
    fi

    if [ -f "$CODEX_HOME/RTK.md" ]; then
        if ! make_path_portable < "$CODEX_HOME/RTK.md" > "$CODEX_CONFIG_DIR/RTK.md.tmp"; then
            rm -f "$CODEX_CONFIG_DIR/RTK.md.tmp"
            log_with_level "ERROR" "Failed to process RTK.md - backup aborted"
            exit 1
        fi
        mv "$CODEX_CONFIG_DIR/RTK.md.tmp" "$CODEX_CONFIG_DIR/RTK.md"
        log_with_level "SUCCESS" "Backed up RTK.md"
    else
        log_with_level "WARN" "RTK.md not found; keeping existing codex_config/RTK.md"
    fi

    backup_codex_skills

    log_with_level "SUCCESS" "Codex configuration backup completed!"
    echo ""
    echo "📦 Backed up files:"
    echo "   - codex_config/config.toml"
    echo "   - codex_config/hooks.json"
    echo "   - codex_config/RTK.md"
    echo "   - codex_config/skills/plannotator-*"
    echo "   - agent_config/AGENTS.md"
    echo ""
    echo "💡 Runtime files such as auth.json, history, logs, sessions, and SQLite databases are intentionally not backed up"
}

if [[ -n "${ZSH_EVAL_CONTEXT:-}" ]]; then
    if [[ "${ZSH_EVAL_CONTEXT}" != *file* ]]; then
        main "$@"
    fi
else
    if [[ "${BASH_SOURCE[0]:-$0}" == "${0}" ]]; then
        main "$@"
    fi
fi
