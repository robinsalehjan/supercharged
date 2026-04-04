#!/bin/zsh

# ============================================================================
# Profile Setup Script
# ============================================================================
# Creates a backup before making changes to preserve existing configurations
#
# Usage:
#   ./setup-profile.sh           # Normal mode - copy files
#   ./setup-profile.sh --dry-run # Preview mode - show what would be copied

set -e

# Get the directory where this script is located (zsh syntax)
# These MUST stay outside main() — they use zsh-only ${(%):-%x} syntax
SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DOT_FILES_DIR="$PROJECT_ROOT/dot_files"

# Source utilities for backup functionality (provides MANAGED_DOTFILES)
source "$SCRIPT_DIR/utils.sh"

DRY_RUN=false

show_help() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Copy dotfiles and Claude Code configuration to \$HOME"
    echo ""
    echo "Options:"
    echo "  --dry-run      Preview what would be copied without making changes"
    echo "  -h, --help     Show this help message"
}

main() {
    # Parse command line arguments
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
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    if $DRY_RUN; then
        echo "=== DRY RUN MODE - No changes will be made ==="
        echo ""
    fi

    # Create backup before making changes (skip in dry-run)
    if ! $DRY_RUN; then
        echo "💾 Creating backup of existing configuration..."
        create_restoration_point
        echo ""
    fi

    echo "📁 Dotfiles that would be copied to $HOME:"
    echo ""

    # Copy each dotfile (uses shared MANAGED_DOTFILES from utils.sh, excluding non-dotfiles)
    for file in "${MANAGED_DOTFILES[@]}"; do
        if [ -f "$DOT_FILES_DIR/$file" ]; then
            if $DRY_RUN; then
                echo "  → Would copy: $file"
            else
                cp "$DOT_FILES_DIR/$file" "$HOME/" || {
                    log_with_level "ERROR" "Failed to copy $file to $HOME"
                    continue
                }
                echo "  ✓ Copied $file"
            fi
        elif [ "$file" = ".supercharged_preferences" ]; then
            # Preferences file is generated at runtime, not part of dot_files
            continue
        else
            echo "  ⚠️  Warning: $file not found in $DOT_FILES_DIR"
        fi
    done

    if $DRY_RUN; then
        echo ""
        echo "=== DRY RUN COMPLETE - No changes were made ==="
        exit 0
    fi

    echo "✅ Dotfiles copied to \$HOME"

    # Configure git hooks for security enforcement
    echo ""
    echo "🔧 Configuring git hooks..."
    cd "$PROJECT_ROOT"

    # Set git hooks path if not already set
    CURRENT_HOOKS_PATH=$(git config core.hooksPath 2>/dev/null || echo "")
    if [ "$CURRENT_HOOKS_PATH" != ".husky" ]; then
        git config core.hooksPath .husky
        echo "  ✓ Set git hooks path to .husky"
    else
        echo "  ✓ Git hooks path already configured"
    fi

    # Ensure hooks are executable
    chmod +x .husky/pre-commit 2>/dev/null || true
    echo "  ✓ Made hooks executable"

    echo "✅ Git hooks configured"

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
}

# Source guard: skip main() when sourced, run when executed directly
if [[ -n "${ZSH_EVAL_CONTEXT:-}" ]]; then
    if [[ "${ZSH_EVAL_CONTEXT}" != *file* ]]; then
        main "$@"
    fi
else
    if [[ "${BASH_SOURCE[0]:-$0}" == "${0}" ]]; then
        main "$@"
    fi
fi
