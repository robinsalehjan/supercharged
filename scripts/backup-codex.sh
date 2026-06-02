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

filter_shared_codex_config() {
    local skip=false

    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" == \[* ]]; then
            skip=false
            if [[ "$line" == "[projects."* ]] || \
               [[ "$line" == "[tui.model_availability_nux]" ]] || \
               [[ "$line" == "[notice.model_migrations]" ]]; then
                skip=true
            fi
        fi

        if [ "$skip" = false ]; then
            printf '%s\n' "$line"
        fi
    done
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
        log_with_level "SUCCESS" "Backed up config.toml (local project trust and UI notices excluded)"
    else
        log_with_level "WARN" "config.toml not found"
    fi

    if [ -f "$CODEX_HOME/AGENTS.md" ]; then
        if ! make_path_portable < "$CODEX_HOME/AGENTS.md" > "$AGENT_CONFIG_DIR/AGENTS.md.tmp"; then
            rm -f "$AGENT_CONFIG_DIR/AGENTS.md.tmp"
            log_with_level "ERROR" "Failed to process AGENTS.md - backup aborted"
            exit 1
        fi
        mv "$AGENT_CONFIG_DIR/AGENTS.md.tmp" "$AGENT_CONFIG_DIR/AGENTS.md"
        log_with_level "SUCCESS" "Backed up AGENTS.md to shared agent_config"
    else
        log_with_level "WARN" "AGENTS.md not found; keeping existing shared agent_config/AGENTS.md"
    fi

    log_with_level "SUCCESS" "Codex configuration backup completed!"
    echo ""
    echo "📦 Backed up files:"
    echo "   - codex_config/config.toml"
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
