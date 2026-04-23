#!/bin/zsh

# Compute paths once at script load time
# When sourced, use bash's BASH_SOURCE or zsh's special handling
if [[ -n "${BASH_SOURCE[0]}" ]]; then
    # bash: use BASH_SOURCE
    UTILS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
elif [[ -n "${ZSH_VERSION}" ]]; then
    # zsh: use %x parameter expansion
    UTILS_SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")" 2>/dev/null && pwd)"
else
    # Fallback: use $0
    UTILS_SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)" || UTILS_SCRIPT_DIR="$PWD"
fi
export UTILS_PROJECT_ROOT
UTILS_PROJECT_ROOT="$(cd "$UTILS_SCRIPT_DIR/.." 2>/dev/null && pwd)" || UTILS_PROJECT_ROOT="$UTILS_SCRIPT_DIR"
export UTILS_LOG_FILE
UTILS_LOG_FILE="$UTILS_PROJECT_ROOT/.supercharged_install.log"

# Constants (exported for submodules)
export BACKUP_RETENTION_COUNT=5

# Shared list of dotfiles for backup/restore/copy operations
# Note: array export only works in zsh; all consumers source utils.sh in-process so this is fine
# shellcheck disable=SC2034  # Used by submodules (backup.sh, restore.sh) via source
MANAGED_DOTFILES=(.zshrc .zprofile .gitconfig .gitignore_global .p10k.zsh .tool-versions .tmux.conf .supercharged_preferences)

# Source submodules (logging must load first — all others call log_with_level)
_source_submodule() {
    local module_path="$1"
    if [[ ! -f "$module_path" ]]; then
        echo "[ERROR] utils.sh: Required submodule not found: $module_path" >&2
        return 1
    fi
    # shellcheck disable=SC1090  # Dynamic path resolved at runtime
    source "$module_path"
}

_source_submodule "$UTILS_SCRIPT_DIR/utils/logging.sh" || return 1
_source_submodule "$UTILS_SCRIPT_DIR/utils/json.sh" || return 1
_source_submodule "$UTILS_SCRIPT_DIR/utils/validation.sh" || return 1
_source_submodule "$UTILS_SCRIPT_DIR/utils/backup.sh" || return 1
_source_submodule "$UTILS_SCRIPT_DIR/utils/tools.sh" || return 1

# Fix wireshark symlinks and remove deprecated cask
fix_wireshark_symlinks() {
    # Remove deprecated wireshark-app cask if present (has broken definition)
    if brew list --cask wireshark-app &>/dev/null 2>&1; then
        log_with_level "INFO" "Removing deprecated wireshark-app cask..."
        brew uninstall --cask wireshark-app 2>/dev/null || true
    fi

    # Fix wireshark linking issues if it's installed
    if brew list wireshark &>/dev/null; then
        log_with_level "INFO" "Fixing wireshark symlinks..."
        brew unlink wireshark 2>/dev/null || true
        brew link --overwrite wireshark 2>/dev/null || true
    fi
}

# Standard cleanup function with brew cleanup and optional backup restoration message
standard_cleanup() {
    local script_name="${1:-Script}"
    local exit_code=$?

    if [ $exit_code -ne 0 ] && [ $exit_code -ne 1 ]; then
        log_with_level "ERROR" "$script_name failed with exit code $exit_code"

        if [ -f "$HOME/.supercharged_last_backup" ]; then
            echo ""
            echo "💡 You can restore your previous configuration with:"
            echo "   npm run restore"
        fi
    fi

    command -v brew >/dev/null 2>&1 && brew cleanup 2>/dev/null || true
    exit $exit_code
}

# Interactive git configuration setup
setup_git_config() {
    # Use pre-computed paths from top of file
    local git_source="$UTILS_PROJECT_ROOT/dot_files/.gitconfig"
    local git_config="$HOME/.gitconfig"

    # Check if git config already exists and is identical to source first
    if [ -f "$git_config" ] && [ -f "$git_source" ] && cmp -s "$git_source" "$git_config"; then
        log_with_level "INFO" "Git configuration already exists and is up to date"
        return 0
    fi

    log_with_level "INFO" "Looking for git config at: $git_source"

    if [ ! -f "$git_source" ]; then
        log_with_level "ERROR" "Git config not found at $git_source"
        log_with_level "INFO" "Current working directory: $(pwd)"
        log_with_level "INFO" "Project root: $UTILS_PROJECT_ROOT"
        return 1
    fi

    echo ""
    echo "🔧 Setting up Git configuration..."
    echo ""

    # Copy the git config file
    cp "$git_source" "$git_config"

    log_with_level "SUCCESS" "Git configuration copied successfully"
    return 0
}

# Interactive user preferences setup
setup_user_preferences() {
    echo ""
    echo "🎯 Configure your development environment preferences:"
    echo ""

    # Temporarily disable strict mode for interactive input
    set +u

    # Ask about iOS development
    printf "Install iOS development tools (xcodes, ios-deploy, swift tools)? [Y/n]: "
    read -r install_ios
    install_ios=${install_ios:-Y}

    # Ask about data science tools
    printf "Install data science tools (jupyter, pandas, numpy)? [y/N]: "
    read -r install_datascience
    install_datascience=${install_datascience:-N}

    # Ask about additional development tools
    printf "Install additional development tools (docker, kubernetes tools)? [Y/n]: "
    read -r install_devtools
    install_devtools=${install_devtools:-Y}

    # Ask about Claude Code
    printf "Install Claude Code (AI coding assistant)? [Y/n]: "
    read -r install_claude
    install_claude=${install_claude:-Y}

    # Re-enable strict mode
    set -u

    # Store preferences
    local prefs_file="$HOME/.supercharged_preferences"
    cat > "$prefs_file" << EOF
# Supercharged Setup Preferences
INSTALL_IOS_TOOLS=${install_ios}
INSTALL_DATA_SCIENCE=${install_datascience}
INSTALL_DEV_TOOLS=${install_devtools}
INSTALL_CLAUDE_CODE=${install_claude}
SETUP_DATE=$(date)
EOF

    log_with_level "SUCCESS" "User preferences saved to $prefs_file"

    # Export variables for current session
    export INSTALL_IOS_TOOLS="$install_ios"
    export INSTALL_DATA_SCIENCE="$install_datascience"
    export INSTALL_DEV_TOOLS="$install_devtools"
    export INSTALL_CLAUDE_CODE="$install_claude"
}

# Run validation if script is called directly with validation argument
# Note: In zsh, $0 changes to the sourced file name, so we also check
# that no other script has sourced us by looking for the validate argument
if [[ "${1:-}" == "validate" ]]; then
    # Enable strict error handling for validation
    set -euo pipefail
    validate_installation
fi
