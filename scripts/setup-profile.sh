#!/bin/bash

# ============================================================================
# Profile Setup Script
# ============================================================================
# This script copies dotfiles from the dot_files directory to the user's home directory
# It creates a backup before making any changes to preserve existing configurations

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DOT_FILES_DIR="$PROJECT_ROOT/dot_files"

# Source utilities for backup functionality
source "$SCRIPT_DIR/utils.sh"

# Array of dotfiles to copy
DOTFILES=(
    ".gitconfig"
    ".gitignore_global"
    ".tool-versions"
    ".zshrc"
    ".zprofile"
    ".tmux.conf"
    ".p10k.zsh"
)

# Create backup before making changes
echo "💾 Creating backup of existing configuration..."
create_restoration_point

echo ""
echo "📁 Copying dotfiles to $HOME..."

# Copy each dotfile
for file in "${DOTFILES[@]}"; do
    if [ -f "$DOT_FILES_DIR/$file" ]; then
        cp "$DOT_FILES_DIR/$file" "$HOME/"
        echo "  ✓ Copied $file"
    else
        echo "  ⚠️  Warning: $file not found in $DOT_FILES_DIR"
    fi
done

echo "✅ Dotfiles copied to \$HOME"

# Restore Claude Code configuration if available
CLAUDE_CONFIG_DIR="$PROJECT_ROOT/claude_config"
CLAUDE_HOME="$HOME/.claude"

if [ -d "$CLAUDE_CONFIG_DIR" ]; then
    echo ""
    echo "🤖 Restoring Claude Code configuration..."

    mkdir -p "$CLAUDE_HOME/plugins"

    if [ -f "$CLAUDE_CONFIG_DIR/settings.json" ]; then
        cp "$CLAUDE_CONFIG_DIR/settings.json" "$CLAUDE_HOME/settings.json"
        echo "  ✓ Restored settings.json"
    fi

    # Restore plugin config files (expand $HOME placeholder to actual home directory)
    if [ -f "$CLAUDE_CONFIG_DIR/installed_plugins.json" ]; then
        sed "s|\\\$HOME|$HOME|g" "$CLAUDE_CONFIG_DIR/installed_plugins.json" > "$CLAUDE_HOME/plugins/installed_plugins.json"
        echo "  ✓ Restored installed_plugins.json"
    fi

    if [ -f "$CLAUDE_CONFIG_DIR/known_marketplaces.json" ]; then
        sed "s|\\\$HOME|$HOME|g" "$CLAUDE_CONFIG_DIR/known_marketplaces.json" > "$CLAUDE_HOME/plugins/known_marketplaces.json"
        echo "  ✓ Restored known_marketplaces.json"
    fi

    echo "✅ Claude Code configuration restored"
fi

# Display backup location for user reference
echo ""
if [ -f "$HOME/.supercharged_last_backup" ]; then
    echo "💡 Tip: Your previous configuration was backed up to:"
    echo "   $(cat "$HOME/.supercharged_last_backup")"
    echo "   Run 'npm run restore' to restore if needed."
fi
