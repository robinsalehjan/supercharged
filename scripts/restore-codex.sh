#!/bin/zsh

# ============================================================================
# Codex Restore Script
# ============================================================================
# Restores shared Codex configuration from the repository to ~/.codex.

set -e
set -o pipefail

source "$(dirname "$0")/utils.sh"

PROJECT_ROOT="$UTILS_PROJECT_ROOT"
CODEX_CONFIG_DIR="$PROJECT_ROOT/codex_config"
AGENT_CONFIG_DIR="$PROJECT_ROOT/agent_config"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"

FORCE_RESTORE=false

show_help() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Restore Codex configuration from the repository"
    echo ""
    echo "Options:"
    echo "  --force      Force restore regardless of timestamps"
    echo "  -h, --help   Show this help message"
}

get_file_mtime() {
    local file="$1"
    local mtime

    if mtime=$(stat -f %m "$file" 2>/dev/null); then
        echo "$mtime"
        return 0
    fi

    if mtime=$(stat -c %Y "$file" 2>/dev/null); then
        echo "$mtime"
        return 0
    fi

    echo "0"
    return 1
}

extract_local_codex_tables() {
    local keep=false

    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" == \[* ]]; then
            keep=false
            if [[ "$line" == "[projects."* ]] || \
               [[ "$line" == "[tui.model_availability_nux]" ]] || \
               [[ "$line" == "[notice.model_migrations]" ]]; then
                keep=true
            fi
        fi

        if [ "$keep" = true ]; then
            printf '%s\n' "$line"
        fi
    done
}

restore_config_file() {
    local src="$1"
    local dest="$2"
    local name="$3"

    if [ -f "$src" ]; then
        mkdir -p "$(dirname "$dest")"
        expand_portable_path < "$src" > "$dest"
        log_with_level "SUCCESS" "Restored $name"
    fi
}

restore_codex_config() {
    local src="$CODEX_CONFIG_DIR/config.toml"
    local dest="$CODEX_HOME/config.toml"
    local local_tables=""

    if [ ! -f "$src" ]; then
        log_with_level "WARN" "codex_config/config.toml not found"
        return
    fi

    mkdir -p "$CODEX_HOME"

    if [ -f "$dest" ]; then
        local_tables=$(extract_local_codex_tables < "$dest")
    fi

    expand_portable_path < "$src" > "$dest.tmp"
    if [ -n "$local_tables" ]; then
        {
            printf '\n'
            printf '%s\n' "$local_tables"
        } >> "$dest.tmp"
        log_with_level "INFO" "Preserved local Codex project trust and UI notices"
    fi

    mv "$dest.tmp" "$dest"
    log_with_level "SUCCESS" "Restored config.toml"
}

is_repo_newer() {
    local repo_mtime=0
    local home_mtime=0
    local mtime

    if [ -f "$CODEX_CONFIG_DIR/config.toml" ]; then
        repo_mtime=$(get_file_mtime "$CODEX_CONFIG_DIR/config.toml")
    fi
    if [ -f "$AGENT_CONFIG_DIR/AGENTS.md" ]; then
        mtime=$(get_file_mtime "$AGENT_CONFIG_DIR/AGENTS.md")
        [ "$mtime" -gt "$repo_mtime" ] && repo_mtime="$mtime"
    fi

    if [ -f "$CODEX_HOME/config.toml" ]; then
        home_mtime=$(get_file_mtime "$CODEX_HOME/config.toml")
    fi
    if [ -f "$CODEX_HOME/AGENTS.md" ]; then
        mtime=$(get_file_mtime "$CODEX_HOME/AGENTS.md")
        [ "$mtime" -gt "$home_mtime" ] && home_mtime="$mtime"
    fi

    if [ "$home_mtime" -eq 0 ]; then
        return 0
    fi

    [ "$repo_mtime" -gt "$home_mtime" ]
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)
                FORCE_RESTORE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_with_level "WARN" "Unknown option: $1"
                shift
                ;;
        esac
    done

    if [ ! -f "$CODEX_CONFIG_DIR/config.toml" ] && [ ! -f "$AGENT_CONFIG_DIR/AGENTS.md" ]; then
        log_with_level "INFO" "No Codex configuration found in repository"
        exit 0
    fi

    if [ "$FORCE_RESTORE" = true ]; then
        log_with_level "INFO" "Force restoring Codex configuration..."
    elif is_repo_newer; then
        log_with_level "INFO" "Repository config is newer, restoring Codex configuration..."
    else
        log_with_level "INFO" "Local Codex config is up-to-date, skipping restore"
        exit 0
    fi

    mkdir -p "$CODEX_HOME"

    restore_codex_config
    restore_config_file \
        "$AGENT_CONFIG_DIR/AGENTS.md" \
        "$CODEX_HOME/AGENTS.md" \
        "AGENTS.md"

    log_with_level "SUCCESS" "Codex configuration restored!"
    echo ""
    echo "📥 Restored files to ~/.codex:"
    echo "   - config.toml"
    echo "   - AGENTS.md"
    echo ""
    echo "💡 Restart Codex for changes to take effect"
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
