#!/bin/zsh

# ============================================================================
# Claude Code Backup Script
# ============================================================================
# This script backs up non-sensitive Claude Code configuration files
# from ~/.claude to the repository's claude_config directory

set -e
set -o pipefail

source "$(dirname "$0")/utils.sh"

# Get the directory where this script is located (use pre-computed from utils.sh)
PROJECT_ROOT="$UTILS_PROJECT_ROOT"
CLAUDE_CONFIG_DIR="$PROJECT_ROOT/claude_config"
CLAUDE_HOME="$HOME/.claude"

# List of marketplaces to exclude from backup (work-related or sensitive plugins)
SANITIZE_MARKETPLACES=("vend-plugins")

# List of env var keys to exclude from backup (sensitive credentials)
SANITIZE_ENV_VARS=("GITHUB_PERSONAL_ACCESS_TOKEN")

# Validate that ~/.claude exists
if [ ! -d "$CLAUDE_HOME" ]; then
    log_with_level "ERROR" "Claude Code directory not found at $CLAUDE_HOME"
    log_with_level "INFO" "Please ensure Claude Code is installed first"
    exit 1
fi

# Validate jq is available for JSON manipulation
if ! command -v jq &> /dev/null; then
    log_with_level "ERROR" "jq is required for sanitizing JSON files"
    log_with_level "INFO" "Install with: brew install jq"
    exit 1
fi

log_with_level "INFO" "Backing up Claude Code configuration..."

# Create claude_config directory if it doesn't exist
mkdir -p "$CLAUDE_CONFIG_DIR"

# Backup settings.json (sanitize enabledPlugins from work-related marketplaces)
if [ -f "$CLAUDE_HOME/settings.json" ]; then
    # Build jq filter to remove enabledPlugins entries from sanitized marketplaces
    # Uses --arg to avoid jq filter injection from marketplace names
    jq_args=()
    jq_filter='.enabledPlugins | to_entries'
    i=0
    for marketplace in "${SANITIZE_MARKETPLACES[@]}"; do
        jq_args+=(--arg "mp$i" "@$marketplace")
        jq_filter="$jq_filter | map(select(.key | endswith(\$mp$i) | not))"
        i=$((i + 1))
    done
    jq_filter="$jq_filter | from_entries"

    # Build jq filter to remove sensitive env vars
    env_del_filter=""
    for env_var in "${SANITIZE_ENV_VARS[@]}"; do
        env_del_filter="${env_del_filter} | del(.env[\"${env_var}\"])"
        env_del_filter="${env_del_filter} | del(.mcpServers[]?.env[\"${env_var}\"])"
    done

    # Preserve all fields except enabledPlugins, then apply sanitized enabledPlugins and strip sensitive env vars
    # Write to temp file first to avoid corrupting output on pipeline failure
    if ! jq "${jq_args[@]}" "(. + {enabledPlugins: ($jq_filter)})${env_del_filter}" "$CLAUDE_HOME/settings.json" | \
        make_path_portable > "$CLAUDE_CONFIG_DIR/settings.json.tmp"; then
        rm -f "$CLAUDE_CONFIG_DIR/settings.json.tmp"
        log_with_level "ERROR" "Failed to sanitize settings.json - backup aborted"
        exit 1
    fi
    mv "$CLAUDE_CONFIG_DIR/settings.json.tmp" "$CLAUDE_CONFIG_DIR/settings.json"
    log_with_level "SUCCESS" "Backed up settings.json (sanitized ${#SANITIZE_MARKETPLACES[@]} marketplace(s) from enabledPlugins, stripped ${#SANITIZE_ENV_VARS[@]} env var(s), paths made portable)"
else
    log_with_level "WARN" "settings.json not found"
fi

# Backup plugin configuration files (strip home directory for portability and remove work-related marketplaces)
if [ -f "$CLAUDE_HOME/plugins/installed_plugins.json" ]; then
    # Build jq filter to remove all plugins from sanitized marketplaces
    # Uses --arg to avoid jq filter injection from marketplace names
    jq_args=()
    jq_filter='.plugins | to_entries'
    i=0
    for marketplace in "${SANITIZE_MARKETPLACES[@]}"; do
        jq_args+=(--arg "mp$i" "@$marketplace")
        jq_filter="$jq_filter | map(select(.key | endswith(\$mp$i) | not))"
        i=$((i + 1))
    done
    jq_filter="$jq_filter | from_entries"

    # Preserve version and update plugins
    # Write to temp file first to avoid corrupting output on pipeline failure
    if ! jq "${jq_args[@]}" "{version: .version, plugins: ($jq_filter)}" "$CLAUDE_HOME/plugins/installed_plugins.json" | \
        make_path_portable > "$CLAUDE_CONFIG_DIR/installed_plugins.json.tmp"; then
        rm -f "$CLAUDE_CONFIG_DIR/installed_plugins.json.tmp"
        log_with_level "ERROR" "Failed to sanitize installed_plugins.json - backup aborted"
        exit 1
    fi
    mv "$CLAUDE_CONFIG_DIR/installed_plugins.json.tmp" "$CLAUDE_CONFIG_DIR/installed_plugins.json"
    log_with_level "SUCCESS" "Backed up installed_plugins.json (sanitized ${#SANITIZE_MARKETPLACES[@]} marketplace(s), paths made portable)"
else
    log_with_level "WARN" "installed_plugins.json not found"
fi

if [ -f "$CLAUDE_HOME/plugins/known_marketplaces.json" ]; then
    # Build jq filter to remove sanitized marketplaces
    # Uses --arg to avoid jq filter injection from marketplace names
    jq_args=()
    jq_filter='.'
    i=0
    for marketplace in "${SANITIZE_MARKETPLACES[@]}"; do
        jq_args+=(--arg "mp$i" "$marketplace")
        jq_filter="$jq_filter | del(.[(\$mp$i)])"
        i=$((i + 1))
    done

    # Write to temp file first to avoid corrupting output on pipeline failure
    if ! jq "${jq_args[@]}" "$jq_filter" "$CLAUDE_HOME/plugins/known_marketplaces.json" | \
        make_path_portable > "$CLAUDE_CONFIG_DIR/known_marketplaces.json.tmp"; then
        rm -f "$CLAUDE_CONFIG_DIR/known_marketplaces.json.tmp"
        log_with_level "ERROR" "Failed to sanitize known_marketplaces.json - backup aborted"
        exit 1
    fi
    mv "$CLAUDE_CONFIG_DIR/known_marketplaces.json.tmp" "$CLAUDE_CONFIG_DIR/known_marketplaces.json"
    log_with_level "SUCCESS" "Backed up known_marketplaces.json (sanitized ${#SANITIZE_MARKETPLACES[@]} marketplace(s), paths made portable)"
else
    log_with_level "WARN" "known_marketplaces.json not found"
fi

log_with_level "SUCCESS" "Claude Code configuration backup completed!"
echo ""
echo "📦 Backed up files:"
echo "   - settings.json"
echo "   - installed_plugins.json"
echo "   - known_marketplaces.json"
echo ""
echo "💡 Commit these changes to git to save your Claude Code configuration"
