#!/bin/zsh

# ============================================================================
# Profile Setup Script
# ============================================================================
# This script copies dotfiles from the dot_files directory to the user's home directory
# It creates a backup before making any changes to preserve existing configurations

set -e

# Get the directory where this script is located (zsh syntax)
SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
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

# Restore Claude Code configuration using dedicated script
if [ -x "$SCRIPT_DIR/restore-claude.sh" ]; then
    echo ""
    "$SCRIPT_DIR/restore-claude.sh" --force
fi

# Display backup location for user reference
echo ""
if [ -f "$HOME/.supercharged_last_backup" ]; then
    echo "💡 Tip: Your previous configuration was backed up to:"
    echo "   $(cat "$HOME/.supercharged_last_backup")"
    echo "   Run 'npm run restore' to restore if needed."
fi
