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

if [ ! -f "$MARKETPLACES_FILE" ]; then
    log_with_level "WARN" "No known_marketplaces.json found in $CLAUDE_CONFIG_DIR"
else
    log_with_level "INFO" "Installing marketplaces..."

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
    done < <(jq -r 'to_entries[] | [.key, .value.source.repo] | @tsv' "$MARKETPLACES_FILE")
fi

# --- Plugins ---

PLUGINS_FILE="$CLAUDE_CONFIG_DIR/installed_plugins.json"

if [ ! -f "$PLUGINS_FILE" ]; then
    log_with_level "WARN" "No installed_plugins.json found in $CLAUDE_CONFIG_DIR"
else
    log_with_level "INFO" "Installing plugins..."

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
    done < <(jq -r '.plugins | keys[]' "$PLUGINS_FILE")
fi

log_with_level "SUCCESS" "Plugin installation complete"
if [ "$DRY_RUN" = false ]; then
    echo ""
    echo "Run /reload-plugins in Claude Code to activate, then verify with /help"
fi
