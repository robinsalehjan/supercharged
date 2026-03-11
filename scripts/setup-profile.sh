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

# Source utilities for backup functionality (provides MANAGED_DOTFILES)
source "$SCRIPT_DIR/utils.sh"

# Create backup before making changes
echo "💾 Creating backup of existing configuration..."
create_restoration_point

echo ""
echo "📁 Copying dotfiles to $HOME..."

# Copy each dotfile (uses shared MANAGED_DOTFILES from utils.sh, excluding non-dotfiles)
for file in "${MANAGED_DOTFILES[@]}"; do
    if [ -f "$DOT_FILES_DIR/$file" ]; then
        cp "$DOT_FILES_DIR/$file" "$HOME/" || {
            log_with_level "ERROR" "Failed to copy $file to $HOME"
            continue
        }
        echo "  ✓ Copied $file"
    elif [ "$file" = ".supercharged_preferences" ]; then
        # Preferences file is generated at runtime, not part of dot_files
        continue
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
