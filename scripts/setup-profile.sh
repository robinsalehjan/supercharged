#!/bin/bash

# ============================================================================
# Profile Setup Script
# ============================================================================
# This script copies dotfiles from the dot_files directory to the user's home directory

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DOT_FILES_DIR="$PROJECT_ROOT/dot_files"

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
