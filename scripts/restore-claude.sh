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

# Restore settings.json
restore_config_file \
    "$CLAUDE_CONFIG_DIR/settings.json" \
    "$CLAUDE_HOME/settings.json" \
    "settings.json"

# Restore installed_plugins.json
restore_config_file \
    "$CLAUDE_CONFIG_DIR/installed_plugins.json" \
    "$CLAUDE_HOME/plugins/installed_plugins.json" \
    "installed_plugins.json"

# Restore known_marketplaces.json
restore_config_file \
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
