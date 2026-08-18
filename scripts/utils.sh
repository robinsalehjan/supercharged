#!/bin/zsh

# Defensive: clear interactive-safety aliases (cp -iv, mv -iv, mkdir -pv from
# dot_files/.zshrc) that would prompt on overwrite when this file is sourced
# from a user's interactive shell. Scripts executed via shebang start a fresh
# non-interactive zsh and never see these aliases, but sourcing into a live
# session (e.g. `source scripts/utils.sh && setup_obscura`) would otherwise
# inherit them and break unattended cp/mv calls inside setup_* helpers.
# `|| true` keeps `set -e` callers happy when the aliases don't exist.
unalias cp mv mkdir 2>/dev/null || true

# Compute paths once at script load time.
# When sourced, use bash's BASH_SOURCE or zsh's special handling. Guard the
# array access with :- so callers running under `set -u` (which leaves
# BASH_SOURCE unset under zsh) don't trip on the parameter check itself.
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    # bash: use BASH_SOURCE
    UTILS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
elif [[ -n "${ZSH_VERSION:-}" ]]; then
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
_source_submodule "$UTILS_SCRIPT_DIR/utils/codex.sh" || return 1
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

    if [ "${DRY_RUN:-false}" != true ]; then
        command -v brew >/dev/null 2>&1 && brew cleanup 2>/dev/null || true
    fi
    exit $exit_code
}

migrate_git_identity() {
    local git_config="${1:-$HOME/.gitconfig}"
    local local_config="${2:-$HOME/.gitconfig.local}"
    local entries_file key value

    [ -f "$git_config" ] || return 0
    [ ! -e "$local_config" ] || return 0
    command -v git >/dev/null 2>&1 || return 0

    entries_file=$(mktemp)
    if ! git config --file "$git_config" --get-regexp '^user\.' > "$entries_file" 2>/dev/null; then
        rm -f "$entries_file"
        return 0
    fi

    : > "$local_config"
    while IFS=' ' read -r key value || [ -n "$key" ]; do
        [ -n "$key" ] || continue
        git config --file "$local_config" --add "$key" "$value"
    done < "$entries_file"
    rm -f "$entries_file"
    chmod 600 "$local_config"
    log_with_level "SUCCESS" "Migrated Git user.* identity to ~/.gitconfig.local"
}

git_local_identity_complete() {
    local local_config="${1:-$HOME/.gitconfig.local}"
    local name email

    [ -f "$local_config" ] || return 1
    name=$(git config --file "$local_config" --get user.name 2>/dev/null || true)
    email=$(git config --file "$local_config" --get user.email 2>/dev/null || true)
    [ -n "$name" ] && [ -n "$email" ]
}

warn_missing_git_identity() {
    if ! git_local_identity_complete; then
        log_with_level "WARN" "Git identity is unset; add user.name and user.email to ~/.gitconfig.local"
        log_with_level "WARN" "Run: git config --file ~/.gitconfig.local user.name 'Your Name'"
        log_with_level "WARN" "Run: git config --file ~/.gitconfig.local user.email 'you@example.com'"
    fi
}

install_managed_git_config() {
    local git_source="$UTILS_PROJECT_ROOT/dot_files/.gitconfig"
    local git_config="$HOME/.gitconfig"

    if [ ! -f "$git_source" ]; then
        log_with_level "ERROR" "Git config not found at $git_source"
        return 1
    fi

    migrate_git_identity "$git_config" "$HOME/.gitconfig.local"
    cp "$git_source" "$git_config"
    log_with_level "SUCCESS" "Git configuration copied successfully"
    warn_missing_git_identity
}

# Interactive setup completes the machine-local identity after the managed
# config has been installed. Restore-only commands deliberately never prompt.
setup_git_config() {
    local git_name git_email

    if [ ! -f "$HOME/.gitconfig" ]; then
        install_managed_git_config
    fi

    if git_local_identity_complete; then
        log_with_level "INFO" "Machine-local Git identity already configured"
        return 0
    fi

    echo ""
    echo "🔧 Configure your machine-local Git identity:"
    while [ -z "${git_name:-}" ]; do
        printf "Git user name: "
        read -r git_name
    done
    while [ -z "${git_email:-}" ]; do
        printf "Git user email: "
        read -r git_email
    done

    : > "$HOME/.gitconfig.local"
    git config --file "$HOME/.gitconfig.local" user.name "$git_name"
    git config --file "$HOME/.gitconfig.local" user.email "$git_email"
    chmod 600 "$HOME/.gitconfig.local"
    log_with_level "SUCCESS" "Saved Git identity to ~/.gitconfig.local"
}

# Interactive user preferences setup
normalize_yes_no_preference() {
    local response="${1:-}"
    local default="${2:-N}"

    response="${response:-$default}"
    if [[ "$response" =~ ^[Yy] ]]; then
        printf 'Y'
    else
        printf 'N'
    fi
}

setup_user_preferences() {
    echo ""
    echo "🎯 Configure your development environment preferences:"
    echo ""

    # Temporarily disable strict mode for interactive input
    set +u

    # Ask about iOS development
    printf "Install iOS development tools (xcodes, ios-deploy, swift tools)? [Y/n]: "
    read -r install_ios
    install_ios=$(normalize_yes_no_preference "$install_ios" "Y")

    # Ask about data science tools
    printf "Install data science tools (jupyter, pandas, numpy)? [y/N]: "
    read -r install_datascience
    install_datascience=$(normalize_yes_no_preference "$install_datascience" "N")

    # Ask about additional development tools
    printf "Install additional development tools (docker, kubernetes tools)? [Y/n]: "
    read -r install_devtools
    install_devtools=$(normalize_yes_no_preference "$install_devtools" "Y")

    # Ask about Claude Code
    printf "Install Claude Code (AI coding assistant)? [Y/n]: "
    read -r install_claude
    install_claude=$(normalize_yes_no_preference "$install_claude" "Y")

    # Ask about the ChatGPT desktop surface used for Codex access. Keep the
    # preference name for compatibility with existing preference files.
    printf "Install ChatGPT desktop app for Codex access? [Y/n]: "
    read -r install_codex_app
    install_codex_app=$(normalize_yes_no_preference "$install_codex_app" "Y")

    # Ask about JVM tooling (Java + Kotlin via asdf)
    printf "Install JVM tooling (java, kotlin)? [y/N]: "
    read -r install_jvm
    install_jvm=$(normalize_yes_no_preference "$install_jvm" "N")

    # Ask about extra GUI apps (Postman + Google Chrome)
    printf "Install extra GUI apps (postman, google-chrome)? [y/N]: "
    read -r install_extras
    install_extras=$(normalize_yes_no_preference "$install_extras" "N")

    # Ask about cloud SDKs (gcloud + firebase via asdf)
    printf "Install cloud SDKs (gcloud, firebase)? [Y/n]: "
    read -r install_cloud
    install_cloud=$(normalize_yes_no_preference "$install_cloud" "Y")

    # Ask about network/HTTP debugging tools (Wireshark, mitmproxy, Proxyman)
    printf "Install network tools (wireshark, mitmproxy, proxyman)? [Y/n]: "
    read -r install_network
    install_network=$(normalize_yes_no_preference "$install_network" "Y")

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
INSTALL_CODEX_APP=${install_codex_app}
INSTALL_JVM_TOOLS=${install_jvm}
INSTALL_EXTRA_APPS=${install_extras}
INSTALL_CLOUD_TOOLS=${install_cloud}
INSTALL_NETWORK_TOOLS=${install_network}
SETUP_DATE=$(date)
EOF

    log_with_level "SUCCESS" "User preferences saved to $prefs_file"

    # Export variables for current session
    export INSTALL_IOS_TOOLS="$install_ios"
    export INSTALL_DATA_SCIENCE="$install_datascience"
    export INSTALL_DEV_TOOLS="$install_devtools"
    export INSTALL_CLAUDE_CODE="$install_claude"
    export INSTALL_CODEX_APP="$install_codex_app"
    export INSTALL_JVM_TOOLS="$install_jvm"
    export INSTALL_EXTRA_APPS="$install_extras"
    export INSTALL_CLOUD_TOOLS="$install_cloud"
    export INSTALL_NETWORK_TOOLS="$install_network"
}

# Run validation only when utils.sh itself is executed. Positional arguments
# from a script that sources this file must never trigger validation.
_utils_main() {
    if [[ "${1:-}" == "validate" ]]; then
        # Enable strict undefined variable checking but not -e since we handle
        # errors explicitly with counters in validate_installation.
        set -uo pipefail
        validate_installation
    fi
}

if [[ -n "${ZSH_EVAL_CONTEXT:-}" ]]; then
    if [[ "${ZSH_EVAL_CONTEXT}" != *file* ]]; then
        _utils_main "$@"
    fi
else
    if [[ "${BASH_SOURCE[0]:-$0}" == "${0}" ]]; then
        _utils_main "$@"
    fi
fi
