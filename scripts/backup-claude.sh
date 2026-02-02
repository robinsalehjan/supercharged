#!/bin/zsh

# ============================================================================
# Claude Code Backup Script
# ============================================================================
# This script backs up non-sensitive Claude Code configuration files
# from ~/.claude to the repository's claude_config directory

set -e

source "$(dirname "$0")/utils.sh"

# Get the directory where this script is located (use pre-computed from utils.sh)
PROJECT_ROOT="$UTILS_PROJECT_ROOT"
CLAUDE_CONFIG_DIR="$PROJECT_ROOT/claude_config"
CLAUDE_HOME="$HOME/.claude"

# List of marketplaces to exclude from backup (work-related or sensitive plugins)
SANITIZE_MARKETPLACES=("vend-plugins")

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

# Backup settings.json
if [ -f "$CLAUDE_HOME/settings.json" ]; then
    cp "$CLAUDE_HOME/settings.json" "$CLAUDE_CONFIG_DIR/settings.json"
    log_with_level "SUCCESS" "Backed up settings.json"
else
    log_with_level "WARN" "settings.json not found"
fi

# Backup plugin configuration files (strip home directory for portability and remove work-related marketplaces)
if [ -f "$CLAUDE_HOME/plugins/installed_plugins.json" ]; then
    # Build jq filter to remove all plugins from sanitized marketplaces
    # The file structure is: {"version": N, "plugins": {...}}
    jq_filter='.plugins | to_entries'
    for marketplace in "${SANITIZE_MARKETPLACES[@]}"; do
        jq_filter="$jq_filter | map(select(.key | endswith(\"@$marketplace\") | not))"
    done
    jq_filter="$jq_filter | from_entries"

    # Preserve version and update plugins
    jq "{version: .version, plugins: ($jq_filter)}" "$CLAUDE_HOME/plugins/installed_plugins.json" | \
        sed "s|$HOME|\$HOME|g" > "$CLAUDE_CONFIG_DIR/installed_plugins.json"
    log_with_level "SUCCESS" "Backed up installed_plugins.json (sanitized ${#SANITIZE_MARKETPLACES[@]} marketplace(s), paths made portable)"
else
    log_with_level "WARN" "installed_plugins.json not found"
fi

if [ -f "$CLAUDE_HOME/plugins/known_marketplaces.json" ]; then
    # Build jq filter to remove sanitized marketplaces
    jq_filter='.'
    for marketplace in "${SANITIZE_MARKETPLACES[@]}"; do
        jq_filter="$jq_filter | del(.\"$marketplace\")"
    done

    jq "$jq_filter" "$CLAUDE_HOME/plugins/known_marketplaces.json" | \
        sed "s|$HOME|\$HOME|g" > "$CLAUDE_CONFIG_DIR/known_marketplaces.json"
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
