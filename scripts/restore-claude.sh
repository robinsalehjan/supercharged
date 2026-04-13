#!/bin/zsh

# ============================================================================
# Claude Code Restore Script
# ============================================================================
# This script restores Claude Code configuration files from the repository's
# claude_config directory to ~/.claude
#
# Usage:
#   ./restore-claude.sh          # Restore if repo config is newer
#   ./restore-claude.sh --force  # Force restore regardless of timestamps

set -e
set -o pipefail

source "$(dirname "$0")/utils.sh"

# Get the directory where this script is located
PROJECT_ROOT="$UTILS_PROJECT_ROOT"
CLAUDE_CONFIG_DIR="$PROJECT_ROOT/claude_config"
CLAUDE_HOME="$HOME/.claude"

# List of marketplaces to preserve locally (not overwritten during restore)
# These are work-related and should remain untouched
PRESERVE_MARKETPLACES=("vend-plugins")

# List of env vars to inject from ~/.secrets back into settings.json
# Must mirror SANITIZE_ENV_VARS in backup-claude.sh (what's stripped at backup, re-injected at restore)
INJECT_SETTINGS_ENV_VARS=("GITHUB_PERSONAL_ACCESS_TOKEN")

FORCE_RESTORE=false
SECRETS_LOADED=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_RESTORE=true
            shift
            ;;
        *)
            log_with_level "WARN" "Unknown option: $1"
            shift
            ;;
    esac
done

# Check if repository config exists
if [ ! -d "$CLAUDE_CONFIG_DIR" ]; then
    log_with_level "INFO" "No Claude configuration found in repository at $CLAUDE_CONFIG_DIR"
    exit 0
fi

# Check if any config files exist in repo
if [ ! -f "$CLAUDE_CONFIG_DIR/settings.json" ] && \
   [ ! -f "$CLAUDE_CONFIG_DIR/installed_plugins.json" ] && \
   [ ! -f "$CLAUDE_CONFIG_DIR/known_marketplaces.json" ]; then
    log_with_level "INFO" "No Claude configuration files found in repository"
    exit 0
fi

# Cross-platform stat wrapper for modification time
# Returns mtime in seconds since epoch
get_file_mtime() {
    local file="$1"
    local mtime

    # Try macOS/BSD stat first
    if mtime=$(stat -f %m "$file" 2>/dev/null); then
        echo "$mtime"
        return 0
    fi

    # Fall back to GNU/Linux stat
    if mtime=$(stat -c %Y "$file" 2>/dev/null); then
        echo "$mtime"
        return 0
    fi

    # If both fail, return 0
    echo "0"
    return 1
}

# Function to get the newest modification time from a directory's JSON files
get_newest_mtime() {
    local dir="$1"
    local newest=0

    for file in "$dir"/*.json; do
        if [ -f "$file" ]; then
            local mtime
            mtime=$(get_file_mtime "$file")
            if [ "$mtime" -gt "$newest" ]; then
                newest=$mtime
            fi
        fi
    done

    echo "$newest"
}

# Function to check if repo config is newer than home config
is_repo_newer() {
    local repo_mtime
    repo_mtime=$(get_newest_mtime "$CLAUDE_CONFIG_DIR")

    # If Claude home doesn't exist, repo is considered newer
    if [ ! -d "$CLAUDE_HOME" ]; then
        return 0
    fi

    local home_mtime=0
    local mtime

    # Check settings.json
    if [ -f "$CLAUDE_HOME/settings.json" ]; then
        mtime=$(get_file_mtime "$CLAUDE_HOME/settings.json")
        if [ "$mtime" -gt "$home_mtime" ]; then
            home_mtime=$mtime
        fi
    fi

    # Check plugin files
    if [ -f "$CLAUDE_HOME/plugins/installed_plugins.json" ]; then
        mtime=$(get_file_mtime "$CLAUDE_HOME/plugins/installed_plugins.json")
        if [ "$mtime" -gt "$home_mtime" ]; then
            home_mtime=$mtime
        fi
    fi

    if [ -f "$CLAUDE_HOME/plugins/known_marketplaces.json" ]; then
        mtime=$(get_file_mtime "$CLAUDE_HOME/plugins/known_marketplaces.json")
        if [ "$mtime" -gt "$home_mtime" ]; then
            home_mtime=$mtime
        fi
    fi

    # If home has no config files, repo is newer
    if [ "$home_mtime" -eq 0 ]; then
        return 0
    fi

    # Compare timestamps
    if [ "$repo_mtime" -gt "$home_mtime" ]; then
        return 0
    else
        return 1
    fi
}

# Function to restore a single config file
restore_config_file() {
    local src="$1"
    local dest="$2"
    local name="$3"

    if [ -f "$src" ]; then
        # Create destination directory if needed
        mkdir -p "$(dirname "$dest")"

        # Replace $HOME placeholder with actual home directory
        expand_portable_path < "$src" > "$dest"
        log_with_level "SUCCESS" "Restored $name"
    fi
}

# Function to merge plugin configs, preserving local plugins from protected marketplaces
# The file structure is: {"version": N, "plugins": {...}}
merge_plugin_config() {
    local src="$1"
    local dest="$2"
    local name="$3"

    if [ ! -f "$src" ]; then
        return
    fi

    # Create destination directory if needed
    mkdir -p "$(dirname "$dest")"

    # Expand $HOME placeholder in source
    local repo_content
    repo_content=$(expand_portable_path < "$src")

    # If destination doesn't exist, just copy
    if [ ! -f "$dest" ]; then
        echo "$repo_content" > "$dest"
        log_with_level "SUCCESS" "Restored $name"
        return
    fi

    # Check if jq is available for merging
    if ! command -v jq &> /dev/null; then
        log_with_level "ERROR" "jq is required for restore operations"
        return 1
    fi

    # Extract local plugins from preserved marketplaces (from .plugins object)
    local local_content
    local_content=$(cat "$dest")
    local preserved_plugins="{}"

    for marketplace in "${PRESERVE_MARKETPLACES[@]}"; do
        # Extract plugins ending with @marketplace from the .plugins object
        # Uses --arg to avoid jq filter injection from marketplace names
        local marketplace_plugins
        marketplace_plugins=$(echo "$local_content" | jq --arg mp "@$marketplace" '.plugins // {} | to_entries | map(select(.key | endswith($mp))) | from_entries') || {
            log_with_level "WARN" "Failed to extract plugins for marketplace $marketplace"
            continue
        }
        if [ -n "$marketplace_plugins" ] && [ "$marketplace_plugins" != "{}" ]; then
            preserved_plugins=$(echo "$preserved_plugins" | jq --argjson mp "$marketplace_plugins" '. + $mp') || {
                log_with_level "WARN" "Failed to merge preserved plugins for $marketplace"
                continue
            }
            log_with_level "INFO" "Found plugins from $marketplace to preserve"
        fi
    done

    # Get repo plugins and merge with preserved local plugins
    local repo_plugins
    if ! repo_plugins=$(echo "$repo_content" | jq '.plugins // {}' 2>/dev/null); then
        log_with_level "ERROR" "Failed to extract plugins from repository configuration"
        return 1
    fi
    local merged_plugins
    if ! merged_plugins=$(echo "$repo_plugins" | jq --argjson preserved "$preserved_plugins" '. + $preserved' 2>/dev/null); then
        log_with_level "ERROR" "Failed to merge plugins: preserved_plugins=$preserved_plugins"
        return 1
    fi

    # Validate merge succeeded and produced valid JSON
    if [ -z "$merged_plugins" ] || ! echo "$merged_plugins" | jq empty 2>/dev/null; then
        log_with_level "ERROR" "Failed to merge plugins configuration"
        return 1
    fi

    # Get version from repo (or local if repo doesn't have it)
    local version
    if ! version=$(echo "$repo_content" | jq '.version // 2' 2>/dev/null); then
        log_with_level "ERROR" "Failed to read version from repository configuration"
        return 1
    fi

    # Build final merged object
    local merged
    merged=$(jq -n --argjson version "$version" --argjson plugins "$merged_plugins" '{version: $version, plugins: $plugins}')
    echo "$merged" > "$dest"

    local preserved_count
    preserved_count=$(echo "$preserved_plugins" | jq 'keys | length' 2>/dev/null || echo "0")
    if [ "$preserved_count" -gt 0 ]; then
        log_with_level "SUCCESS" "Restored $name (preserved $preserved_count local plugin(s))"
    else
        log_with_level "SUCCESS" "Restored $name"
    fi
}

# Function to merge marketplace configs, preserving local marketplaces
merge_marketplace_config() {
    local src="$1"
    local dest="$2"
    local name="$3"

    if [ ! -f "$src" ]; then
        return
    fi

    # Create destination directory if needed
    mkdir -p "$(dirname "$dest")"

    # Expand $HOME placeholder in source
    local repo_content
    repo_content=$(expand_portable_path < "$src")

    # If destination doesn't exist, just copy
    if [ ! -f "$dest" ]; then
        echo "$repo_content" > "$dest"
        log_with_level "SUCCESS" "Restored $name"
        return
    fi

    # Check if jq is available for merging
    if ! command -v jq &> /dev/null; then
        log_with_level "ERROR" "jq is required for restore operations"
        return 1
    fi

    # Extract preserved marketplaces from local config
    local local_content
    local_content=$(cat "$dest")
    local preserved_marketplaces="{}"

    for marketplace in "${PRESERVE_MARKETPLACES[@]}"; do
        # Uses --arg to avoid jq filter injection from marketplace names
        local marketplace_entry
        marketplace_entry=$(echo "$local_content" | jq --arg mp "$marketplace" 'if has($mp) then {($mp): .[$mp]} else {} end') || {
            log_with_level "WARN" "Failed to extract marketplace $marketplace"
            continue
        }
        if [ -n "$marketplace_entry" ] && [ "$marketplace_entry" != "{}" ]; then
            preserved_marketplaces=$(echo "$preserved_marketplaces" | jq --argjson entry "$marketplace_entry" '. + $entry') || {
                log_with_level "WARN" "Failed to merge marketplace $marketplace"
                continue
            }
            log_with_level "INFO" "Found marketplace $marketplace to preserve"
        fi
    done

    # Merge: repo content + preserved local marketplaces (local takes precedence)
    local merged
    if ! merged=$(echo "$repo_content" | jq --argjson preserved "$preserved_marketplaces" '. + $preserved' 2>/dev/null); then
        log_with_level "ERROR" "Failed to merge marketplaces: preserved_marketplaces=$preserved_marketplaces"
        return 1
    fi

    # Validate merge succeeded and produced valid JSON
    if [ -z "$merged" ] || ! echo "$merged" | jq empty 2>/dev/null; then
        log_with_level "ERROR" "Failed to merge marketplaces configuration"
        return 1
    fi

    echo "$merged" > "$dest"

    local preserved_count
    preserved_count=$(echo "$preserved_marketplaces" | jq 'keys | length' 2>/dev/null || echo "0")
    if [ "$preserved_count" -gt 0 ]; then
        log_with_level "SUCCESS" "Restored $name (preserved $preserved_count local marketplace(s))"
    else
        log_with_level "SUCCESS" "Restored $name"
    fi
}

# Load ~/.secrets once; sets SECRETS_LOADED=true on success
load_secrets() {
    local secrets_file="$HOME/.secrets"
    if [ ! -f "$secrets_file" ]; then
        log_with_level "WARN" "No secrets file found at $secrets_file - credentials will not be injected"
        log_with_level "WARN" "Copy dot_files/.secrets to ~/.secrets and fill in your values"
        return 1
    fi
    # shellcheck source=/dev/null
    source "$secrets_file" 2>/dev/null || { log_with_level "WARN" "Failed to source $secrets_file"; return 1; }
    SECRETS_LOADED=true
}

# Function to inject global env vars from ~/.secrets back into settings.json
restore_settings_env() {
    local settings_json="$CLAUDE_HOME/settings.json"

    if [ ! -f "$settings_json" ]; then
        log_with_level "WARN" "settings.json not found, skipping env var injection"
        return
    fi

    # Count vars that are actually set
    local injected_count=0
    for var in "${INJECT_SETTINGS_ENV_VARS[@]}"; do
        if printenv "$var" > /dev/null 2>&1; then
            injected_count=$((injected_count + 1))
        fi
    done

    if [ "$injected_count" -eq 0 ]; then
        log_with_level "INFO" "No env vars to inject (not found in ~/.secrets)"
        return
    fi

    # Build JSON array of var names, then use jq env[] to read their values
    local vars_json
    vars_json=$(printf '%s\n' "${INJECT_SETTINGS_ENV_VARS[@]}" | jq -R . | jq -s .)

    local updated
    if ! updated=$(jq -a --argjson vars "$vars_json" '
        .env = (.env // {}) + (
            $vars |
            map(select(env[.] != null)) |
            map({(.): env[.]}) |
            add // {}
        )
    ' "$settings_json" 2>/dev/null); then
        log_with_level "ERROR" "Failed to inject env vars into settings.json"
        return 1
    fi

    local tmp="${settings_json}.tmp.$$"
    if echo "$updated" > "$tmp" && mv "$tmp" "$settings_json"; then
        log_with_level "SUCCESS" "Injected $injected_count env var(s) into settings.json from ~/.secrets"
    else
        rm -f "$tmp"
        log_with_level "ERROR" "Failed to write settings.json"
        return 1
    fi
}

# Function to restore global MCP server configs into ~/.claude/settings.json
# Sources ~/.secrets to substitute $VAR_NAME placeholders with actual env values
# MCPs are injected globally so they work across all projects
restore_mcp_servers() {
    local src="$CLAUDE_CONFIG_DIR/mcp_servers.json"
    local settings_json="$CLAUDE_HOME/settings.json"

    if [ ! -f "$src" ]; then
        log_with_level "INFO" "No MCP server configuration found in repository"
        return
    fi

    if [ ! -f "$settings_json" ]; then
        log_with_level "WARN" "settings.json not found, skipping MCP server restore"
        return
    fi

    if [ "$SECRETS_LOADED" = false ]; then
        log_with_level "WARN" "Skipping MCP server restore - API key placeholders would remain unsubstituted"
        return 1
    fi

    # Expand $HOME placeholders and substitute $VAR_NAME env placeholders via jq env object
    local mcp_with_secrets
    if ! mcp_with_secrets=$(expand_portable_path < "$src" | jq -a 'to_entries | map(
        .value.env = (.value.env // {} | to_entries | map(
            if (.value | type == "string") and (.value | startswith("$")) then
                .value = (env[.value[1:]] // .value)
            else . end
        ) | from_entries)
    ) | from_entries' 2>/dev/null); then
        log_with_level "ERROR" "Failed to process MCP server configuration"
        return 1
    fi

    # Merge MCP servers into settings.json (repo servers take precedence, local extras preserved)
    local updated
    if ! updated=$(jq -a --argjson mcp "$mcp_with_secrets" '
        .mcpServers = ((.mcpServers // {}) + $mcp)
    ' "$settings_json" 2>/dev/null); then
        log_with_level "ERROR" "Failed to merge MCP servers into settings.json"
        return 1
    fi

    local tmp="${settings_json}.tmp.$$"
    if echo "$updated" > "$tmp" && mv "$tmp" "$settings_json"; then
        local server_count
        server_count=$(echo "$mcp_with_secrets" | jq 'keys | length' 2>/dev/null || echo "?")
        log_with_level "SUCCESS" "Restored $server_count global MCP server(s) to settings.json"
    else
        rm -f "$tmp"
        log_with_level "ERROR" "Failed to write settings.json"
        return 1
    fi
}

# Main restore logic
if [ "$FORCE_RESTORE" = true ]; then
    log_with_level "INFO" "Force restoring Claude Code configuration..."
elif is_repo_newer; then
    log_with_level "INFO" "Repository config is newer, restoring Claude Code configuration..."
else
    log_with_level "INFO" "Local Claude config is up-to-date, skipping restore"
    exit 0
fi

# Create Claude directories if needed
mkdir -p "$CLAUDE_HOME"
mkdir -p "$CLAUDE_HOME/plugins"

# Restore settings.json (simple overwrite, no sensitive data)
restore_config_file \
    "$CLAUDE_CONFIG_DIR/settings.json" \
    "$CLAUDE_HOME/settings.json" \
    "settings.json"

# Load ~/.secrets once — used by both restore_settings_env and restore_mcp_servers
load_secrets || true

# Re-inject sensitive env vars stripped at backup time (sourced from ~/.secrets)
restore_settings_env

# Restore installed_plugins.json (merge to preserve local work plugins)
merge_plugin_config \
    "$CLAUDE_CONFIG_DIR/installed_plugins.json" \
    "$CLAUDE_HOME/plugins/installed_plugins.json" \
    "installed_plugins.json"

# Restore known_marketplaces.json (merge to preserve local work marketplaces)
merge_marketplace_config \
    "$CLAUDE_CONFIG_DIR/known_marketplaces.json" \
    "$CLAUDE_HOME/plugins/known_marketplaces.json" \
    "known_marketplaces.json"

# Restore MCP server configurations into ~/.claude.json (env vars sourced from ~/.secrets)
restore_mcp_servers

log_with_level "SUCCESS" "Claude Code configuration restored!"
echo ""
echo "📥 Restored files to ~/.claude:"
echo "   - settings.json"
echo "   - plugins/installed_plugins.json"
echo "   - plugins/known_marketplaces.json"
echo "   - settings.json MCP servers (global, env vars from ~/.secrets)"
echo ""
echo "💡 Restart Claude Code for changes to take effect"
