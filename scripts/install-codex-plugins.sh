#!/bin/zsh

# Reconcile the portable Codex plugin registry without copying Codex's
# machine-local marketplace snapshots, plugin caches, credentials, or trust
# state. Axiom is intentionally the only managed third-party Codex plugin.

set -euo pipefail

source "$(dirname "$0")/utils.sh"

PROJECT_ROOT="$UTILS_PROJECT_ROOT"
CODEX_PLUGIN_REGISTRY="${CODEX_PLUGIN_REGISTRY:-$PROJECT_ROOT/codex_config/plugins.json}"
DRY_RUN=false

show_help() {
    echo "Usage: $(basename "$0") [--dry-run]"
    echo ""
    echo "Install or refresh managed Codex marketplaces and plugins."
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_with_level "ERROR" "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

if ! command_exists jq; then
    log_with_level "ERROR" "jq is required — install with: brew install jq"
    exit 1
fi

if [ ! -f "$CODEX_PLUGIN_REGISTRY" ]; then
    log_with_level "ERROR" "Managed Codex plugin registry not found: $CODEX_PLUGIN_REGISTRY"
    exit 1
fi

if ! jq -e '
    (.version == 1) and
    (.marketplaces | type == "array" and length > 0) and
    (.plugins | type == "array" and length > 0)
' "$CODEX_PLUGIN_REGISTRY" >/dev/null 2>&1; then
    log_with_level "ERROR" "Managed Codex plugin registry is malformed: $CODEX_PLUGIN_REGISTRY"
    exit 1
fi

marketplace_count=$(jq '.marketplaces | length' "$CODEX_PLUGIN_REGISTRY")
plugin_count=$(jq '.plugins | length' "$CODEX_PLUGIN_REGISTRY")

if [ "$DRY_RUN" = true ]; then
    log_with_level "INFO" "[dry-run] Would reconcile $marketplace_count Codex marketplace(s) and $plugin_count plugin(s)"
    jq -r '.marketplaces[] | "[dry-run] Would add or upgrade marketplace: \(.name) (\(.source))"' "$CODEX_PLUGIN_REGISTRY"
    jq -r '.plugins[] | select(.enabled == true) | "[dry-run] Would install or reinstall plugin: \(.id)"' "$CODEX_PLUGIN_REGISTRY"
    exit 0
fi

if ! command_exists codex; then
    log_with_level "ERROR" "Codex CLI is required — install or restore Codex before managed plugins"
    exit 1
fi

if ! marketplace_json=$(codex plugin marketplace list --json 2>&1); then
    log_with_level "ERROR" "Could not list Codex marketplaces: $marketplace_json"
    exit 1
fi

while IFS=$'\t' read -r name source; do
    [ -n "$name" ] || continue
    if ! jq -e --arg name "$name" '.marketplaces[]? | select(.name == $name)' <<<"$marketplace_json" >/dev/null; then
        log_with_level "INFO" "Adding Codex marketplace: $name"
        if ! codex plugin marketplace add "$source"; then
            log_with_level "ERROR" "Failed to add Codex marketplace: $name"
            exit 1
        fi
    else
        log_with_level "INFO" "Upgrading Codex marketplace: $name"
        if ! codex plugin marketplace upgrade "$name"; then
            log_with_level "ERROR" "Failed to upgrade Codex marketplace: $name"
            exit 1
        fi
    fi
done < <(jq -r '.marketplaces[] | [.name, .source] | @tsv' "$CODEX_PLUGIN_REGISTRY")

while IFS= read -r plugin; do
    [ -n "$plugin" ] || continue
    log_with_level "INFO" "Installing Codex plugin: $plugin"
    if ! codex plugin add "$plugin"; then
        log_with_level "ERROR" "Failed to install Codex plugin: $plugin"
        exit 1
    fi
done < <(jq -r '.plugins[] | select(.enabled == true) | .id' "$CODEX_PLUGIN_REGISTRY")

log_with_level "SUCCESS" "Managed Codex plugins are installed"
log_with_level "WARN" "Axiom's bundled hooks require Codex's one-time trust review on first run; approve only after reviewing the plugin source."
