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

source "$(dirname "$0")/utils.sh"

# Get the directory where this script is located
PROJECT_ROOT="$UTILS_PROJECT_ROOT"
CLAUDE_CONFIG_DIR="$PROJECT_ROOT/claude_config"
CLAUDE_HOME="$HOME/.claude"

# List of marketplaces to preserve locally (not overwritten during restore)
# These are work-related and should remain untouched
PRESERVE_MARKETPLACES=("vend-plugins")
FORCE_RESTORE=false

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

# Function to get the newest modification time from a directory's JSON files
get_newest_mtime() {
    local dir="$1"
    local newest=0

    for file in "$dir"/*.json; do
        if [ -f "$file" ]; then
            local mtime=$(stat -f %m "$file" 2>/dev/null || echo 0)
            if [ "$mtime" -gt "$newest" ]; then
                newest=$mtime
            fi
        fi
    done

    echo "$newest"
}

# Function to check if repo config is newer than home config
is_repo_newer() {
    local repo_mtime=$(get_newest_mtime "$CLAUDE_CONFIG_DIR")

    # If Claude home doesn't exist, repo is considered newer
    if [ ! -d "$CLAUDE_HOME" ]; then
        return 0
    fi

    local home_mtime=0

    # Check settings.json
    if [ -f "$CLAUDE_HOME/settings.json" ]; then
        local mtime=$(stat -f %m "$CLAUDE_HOME/settings.json" 2>/dev/null || echo 0)
        if [ "$mtime" -gt "$home_mtime" ]; then
            home_mtime=$mtime
        fi
    fi

    # Check plugin files
    if [ -f "$CLAUDE_HOME/plugins/installed_plugins.json" ]; then
        local mtime=$(stat -f %m "$CLAUDE_HOME/plugins/installed_plugins.json" 2>/dev/null || echo 0)
        if [ "$mtime" -gt "$home_mtime" ]; then
            home_mtime=$mtime
        fi
    fi

    if [ -f "$CLAUDE_HOME/plugins/known_marketplaces.json" ]; then
        local mtime=$(stat -f %m "$CLAUDE_HOME/plugins/known_marketplaces.json" 2>/dev/null || echo 0)
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
        sed "s|\\\$HOME|$HOME|g" "$src" > "$dest"
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
    local repo_content=$(sed "s|\\\$HOME|$HOME|g" "$src")

    # If destination doesn't exist, just copy
    if [ ! -f "$dest" ]; then
        echo "$repo_content" > "$dest"
        log_with_level "SUCCESS" "Restored $name"
        return
    fi

    # Check if jq is available for merging
    if ! command -v jq &> /dev/null; then
        log_with_level "WARN" "jq not available, overwriting $name (local plugins may be lost)"
        echo "$repo_content" > "$dest"
        log_with_level "SUCCESS" "Restored $name"
        return
    fi

    # Extract local plugins from preserved marketplaces (from .plugins object)
    local local_content=$(cat "$dest")
    local preserved_plugins="{}"

    for marketplace in "${PRESERVE_MARKETPLACES[@]}"; do
        # Extract plugins ending with @marketplace from the .plugins object
        local marketplace_plugins=$(echo "$local_content" | jq ".plugins | to_entries | map(select(.key | endswith(\"@$marketplace\"))) | from_entries")
        preserved_plugins=$(echo "$preserved_plugins" | jq ". + $marketplace_plugins")
    done

    # Get repo plugins and merge with preserved local plugins
    local repo_plugins=$(echo "$repo_content" | jq '.plugins')
    local merged_plugins=$(echo "$repo_plugins" | jq ". + $preserved_plugins")

    # Get version from repo (or local if repo doesn't have it)
    local version=$(echo "$repo_content" | jq '.version // 2')

    # Build final merged object
    local merged=$(jq -n --argjson version "$version" --argjson plugins "$merged_plugins" '{version: $version, plugins: $plugins}')
    echo "$merged" > "$dest"

    local preserved_count=$(echo "$preserved_plugins" | jq 'keys | length')
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
    local repo_content=$(sed "s|\\\$HOME|$HOME|g" "$src")

    # If destination doesn't exist, just copy
    if [ ! -f "$dest" ]; then
        echo "$repo_content" > "$dest"
        log_with_level "SUCCESS" "Restored $name"
        return
    fi

    # Check if jq is available for merging
    if ! command -v jq &> /dev/null; then
        log_with_level "WARN" "jq not available, overwriting $name (local marketplaces may be lost)"
        echo "$repo_content" > "$dest"
        log_with_level "SUCCESS" "Restored $name"
        return
    fi

    # Extract preserved marketplaces from local config
    local local_content=$(cat "$dest")
    local preserved_marketplaces="{}"

    for marketplace in "${PRESERVE_MARKETPLACES[@]}"; do
        local marketplace_entry=$(echo "$local_content" | jq "if has(\"$marketplace\") then {\"$marketplace\": .[\"$marketplace\"]} else {} end")
        preserved_marketplaces=$(echo "$preserved_marketplaces" | jq ". + $marketplace_entry")
    done

    # Merge: repo content + preserved local marketplaces (local takes precedence)
    local merged=$(echo "$repo_content" | jq ". + $preserved_marketplaces")
    echo "$merged" > "$dest"

    local preserved_count=$(echo "$preserved_marketplaces" | jq 'keys | length')
    if [ "$preserved_count" -gt 0 ]; then
        log_with_level "SUCCESS" "Restored $name (preserved $preserved_count local marketplace(s))"
    else
        log_with_level "SUCCESS" "Restored $name"
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

log_with_level "SUCCESS" "Claude Code configuration restored!"
echo ""
echo "📥 Restored files to ~/.claude:"
echo "   - settings.json"
echo "   - plugins/installed_plugins.json"
echo "   - plugins/known_marketplaces.json"
echo ""
echo "💡 Restart Claude Code for changes to take effect"
