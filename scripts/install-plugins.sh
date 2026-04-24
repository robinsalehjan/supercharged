#!/bin/zsh

# ============================================================================
# Claude Code Plugin Installer
# ============================================================================
# Reads backed-up marketplace and plugin configs from claude_config/ and
# installs them via the `claude` CLI. Run after restore-claude.sh to fully
# activate plugins on a new machine.
#
# Usage:
#   ./install-plugins.sh          # Install all marketplaces and plugins
#   ./install-plugins.sh --dry-run  # Show what would be installed

set -e
set -o pipefail

source "$(dirname "$0")/utils.sh"

PROJECT_ROOT="$UTILS_PROJECT_ROOT"
CLAUDE_CONFIG_DIR="$PROJECT_ROOT/claude_config"
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            log_with_level "WARN" "Unknown option: $1"
            shift
            ;;
    esac
done

# Verify prerequisites
if ! command_exists claude; then
    log_with_level "ERROR" "claude CLI not found — install Claude Code first"
    exit 1
fi

if ! command_exists jq; then
    log_with_level "ERROR" "jq is required — install with: brew install jq"
    exit 1
fi

# --- Marketplaces ---

MARKETPLACES_FILE="$CLAUDE_CONFIG_DIR/known_marketplaces.json"
MARKETPLACES_LOCAL_FILE="$CLAUDE_CONFIG_DIR/known_marketplaces.local.json"

if [ ! -f "$MARKETPLACES_FILE" ]; then
    log_with_level "WARN" "No known_marketplaces.json found in $CLAUDE_CONFIG_DIR"
else
    log_with_level "INFO" "Installing marketplaces..."

    # Merge repo + local marketplace configs (local overrides repo on conflict)
    MARKETPLACES_JSON=$(jq -s '.[0] * (.[1] // {})' "$MARKETPLACES_FILE" \
        ${MARKETPLACES_LOCAL_FILE:+$([ -f "$MARKETPLACES_LOCAL_FILE" ] && echo "$MARKETPLACES_LOCAL_FILE" || echo "/dev/null")} \
        2>/dev/null || cat "$MARKETPLACES_FILE")

    if [ -f "$MARKETPLACES_LOCAL_FILE" ]; then
        local_count=$(jq 'length' "$MARKETPLACES_LOCAL_FILE" 2>/dev/null || echo 0)
        log_with_level "INFO" "Merged $local_count local marketplace(s) from known_marketplaces.local.json"
    fi

    # Read each marketplace name and its GitHub repo
    while IFS=$'\t' read -r name repo; do
        if [ "$DRY_RUN" = true ]; then
            log_with_level "INFO" "[dry-run] Would add marketplace: $repo ($name)"
        else
            if claude plugin marketplace add "$repo" 2>/dev/null; then
                log_with_level "SUCCESS" "Added marketplace: $repo ($name)"
            else
                log_with_level "INFO" "Marketplace already configured or failed: $name"
            fi
        fi
    done < <(echo "$MARKETPLACES_JSON" | jq -r 'to_entries[] | [.key, .value.source.repo] | @tsv')
fi

# --- Plugins ---

PLUGINS_FILE="$CLAUDE_CONFIG_DIR/installed_plugins.json"
PLUGINS_LOCAL_FILE="$CLAUDE_CONFIG_DIR/installed_plugins.local.json"

if [ ! -f "$PLUGINS_FILE" ]; then
    log_with_level "WARN" "No installed_plugins.json found in $CLAUDE_CONFIG_DIR"
else
    log_with_level "INFO" "Installing plugins..."

    # Merge repo + local plugin configs (local overrides repo on conflict)
    PLUGINS_JSON=$(jq -s '{ version: .[0].version, plugins: (.[0].plugins * ((.[1] // {}).plugins // {})) }' \
        "$PLUGINS_FILE" \
        ${PLUGINS_LOCAL_FILE:+$([ -f "$PLUGINS_LOCAL_FILE" ] && echo "$PLUGINS_LOCAL_FILE" || echo "/dev/null")} \
        2>/dev/null || cat "$PLUGINS_FILE")

    if [ -f "$PLUGINS_LOCAL_FILE" ]; then
        local_count=$(jq '.plugins | length' "$PLUGINS_LOCAL_FILE" 2>/dev/null || echo 0)
        log_with_level "INFO" "Merged $local_count local plugin(s) from installed_plugins.local.json"
    fi

    # Read each plugin key (e.g., "hookify@claude-plugins-official")
    while IFS= read -r plugin; do
        if [ "$DRY_RUN" = true ]; then
            log_with_level "INFO" "[dry-run] Would install plugin: $plugin"
        else
            if claude plugin install "$plugin" 2>/dev/null; then
                log_with_level "SUCCESS" "Installed plugin: $plugin"
            else
                log_with_level "INFO" "Plugin already installed or failed: $plugin"
            fi
        fi
    done < <(echo "$PLUGINS_JSON" | jq -r '.plugins | keys[]')
fi

log_with_level "SUCCESS" "Plugin installation complete"
if [ "$DRY_RUN" = false ]; then
    echo ""
    echo "Run /reload-plugins in Claude Code to activate, then verify with /help"
fi
