#!/bin/zsh
set -e

source "$(dirname "$0")/utils.sh"

# System requirements validation
validate_system() {
    log_with_level "INFO" "Validating system requirements..."

    # Check macOS version
    local macos_version=$(sw_vers -productVersion | cut -d. -f1-2)

    if ! version_gte "$macos_version" "$REQUIRED_MACOS_VERSION"; then
        log_with_level "ERROR" "macOS $REQUIRED_MACOS_VERSION or later required (found: $macos_version)"
        exit 1
    fi

    # Check available disk space (in GB)
    local available_space_raw=$(df -h / | awk 'NR==2 {print $4}')
    local available_space=$(echo "$available_space_raw" | sed 's/[^0-9.]//g')

    # Convert to integer for comparison (remove decimal part if present)
    local available_space_int=${available_space%.*}

    if [ -z "$available_space_int" ] || [ "$available_space_int" -lt "$REQUIRED_DISK_SPACE_GB" ]; then
        log_with_level "ERROR" "At least ${REQUIRED_DISK_SPACE_GB}GB free space required (found: ${available_space_raw})"
        exit 1
    fi

    # Check for Xcode Command Line Tools
    if ! xcode-select -p >/dev/null 2>&1; then
        log_with_level "INFO" "Installing Xcode Command Line Tools..."
        xcode-select --install
        log_with_level "INFO" "Please complete Xcode Command Line Tools installation and run this script again"
        exit 0
    fi

    # Check internet connectivity
    require_internet || exit 1

    # Check for Oh My Zsh
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        log_with_level "ERROR" "Oh My Zsh is required but not installed."
        log_with_level "INFO" "Install it with: sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
        exit 1
    fi

    log_with_level "SUCCESS" "System validation passed"
}

# Setup error handling and cleanup
cleanup() {
    standard_cleanup "Installation"
}

trap cleanup EXIT

# Initialize logging
setup_logging

# Validate system before starting
validate_system

# Create restoration point
create_restoration_point

# Setup user preferences and git config
setup_user_preferences
setup_git_config

# Parse versions from .tool-versions using utility function
parse_tool_versions
python_version="${TOOL_VERSIONS[python]}"
ruby_version="${TOOL_VERSIONS[ruby]}"
node_version="${TOOL_VERSIONS[nodejs]}"
gcloud_version="${TOOL_VERSIONS[gcloud]}"
firebase_version="${TOOL_VERSIONS[firebase]}"
java_version="${TOOL_VERSIONS[java]}"
kotlin_version="${TOOL_VERSIONS[kotlin]}"

# Version checks
check_version "git" "2.49.0"
check_version "python" "$python_version"

# Homebrew installation with architecture detection
install_homebrew() {
    if [[ $(uname -m) == "arm64" ]]; then
        HOMEBREW_PREFIX="/opt/homebrew"
    else
        HOMEBREW_PREFIX="/usr/local"
    fi

    if ! command -v brew >/dev/null; then
        log_with_level "INFO" "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
            log_with_level "ERROR" "Failed to install Homebrew"
            exit 1
        }
        eval "$($HOMEBREW_PREFIX/bin/brew shellenv)"
    else
        log_with_level "INFO" "Homebrew already installed"
    fi
}

install_homebrew

log_with_level "INFO" "Updating Homebrew formulae..."
brew update --force # https://github.com/Homebrew/brew/issues/1151

# Build brewfile based on user preferences
BREWFILE_CONTENT='tap "thoughtbot/formulae"
tap "homebrew/services"

brew "coreutils"
brew "git"
brew "curl"
brew "openssl@3"
brew "readline"
brew "libyaml"
brew "gmp"
brew "keychain"
brew "nmap"
brew "asdf"
brew "aria2"
brew "tree"
brew "ripgrep"
brew "tmux"
brew "gh"
brew "shellcheck"
brew "jq"
brew "bats-core"
brew "duckdb"
brew "sqlite"
brew "beads"
brew "btop"'

# Add iOS development tools if requested
if [[ "${INSTALL_IOS_TOOLS:-Y}" =~ ^[Yy] ]]; then
    log_with_level "INFO" "Including iOS development tools"
    BREWFILE_CONTENT="$BREWFILE_CONTENT
tap \"xcodesorg/made\"
brew \"xcodesorg/made/xcodes\"
brew \"xcode-build-server\"
brew \"xcbeautify\"
brew \"swiftlint\"
brew \"swift-format\"
brew \"ios-deploy\""
fi

# Add development tools if requested
if [[ "${INSTALL_DEV_TOOLS:-Y}" =~ ^[Yy] ]]; then
    log_with_level "INFO" "Including additional development tools"
    BREWFILE_CONTENT="$BREWFILE_CONTENT
brew \"k9s\"
brew \"docker\"
brew \"docker-compose\"
brew \"colima\""
fi

# Add standard applications
BREWFILE_CONTENT="$BREWFILE_CONTENT
brew \"wireshark\"
cask \"spotify\"
cask \"visual-studio-code\"
cask \"slack\"
cask \"postman\"
cask \"raycast\"
cask \"google-chrome\"
cask \"font-jetbrains-mono-nerd-font\""

# Fix wireshark symlinks and remove deprecated cask
fix_wireshark_symlinks

echo "$BREWFILE_CONTENT" | brew bundle --file=-

log_with_level "INFO" "Installing zsh themes and plugins..."
install_zsh_plugin \
    "https://github.com/zsh-users/zsh-autosuggestions" \
    "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"

install_zsh_plugin \
    "https://github.com/zsh-users/zsh-syntax-highlighting" \
    "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"

install_zsh_plugin \
    "https://github.com/romkatv/powerlevel10k" \
    "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"

# Setup tmux: TPM, configuration, and plugins
log_with_level "INFO" "Setting up tmux with TPM and plugins..."

TMUX_SOURCE="$UTILS_PROJECT_ROOT/dot_files/.tmux.conf"
if [ -f "$TMUX_SOURCE" ]; then
    cp "$TMUX_SOURCE" "$HOME/.tmux.conf"
    log_with_level "SUCCESS" "Tmux configuration copied"
fi

if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    log_with_level "SUCCESS" "TPM installed"
else
    log_with_level "INFO" "TPM already installed"
fi

if [ -f "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]; then
    "$HOME/.tmux/plugins/tpm/bin/install_plugins"
    log_with_level "SUCCESS" "Tmux plugins installed"
else
    log_with_level "WARN" "TPM install script not found, plugins will install on first tmux launch (prefix + I)"
fi

log_with_level "INFO" "Installing asdf plugins and versions..."

# Install plugins
install_asdf_plugin python
install_asdf_plugin ruby
install_asdf_plugin nodejs
install_asdf_plugin gcloud
install_asdf_plugin firebase
install_asdf_plugin java
install_asdf_plugin kotlin

# Install versions
install_asdf_version python "$python_version"
install_asdf_version ruby "$ruby_version"
install_asdf_version nodejs "$node_version"
install_asdf_version gcloud "$gcloud_version"
install_asdf_version firebase "$firebase_version"
install_asdf_version java "$java_version"
install_asdf_version kotlin "$kotlin_version"

# Reshim to ensure all binaries are available
asdf reshim

# Install Claude Code if requested
if [[ "${INSTALL_CLAUDE_CODE:-Y}" =~ ^[Yy] ]]; then
    log_with_level "INFO" "Installing Claude Code..."
    install_script=$(curl -fsSL https://claude.ai/install.sh) || {
        log_with_level "ERROR" "Failed to download Claude Code installer"
        exit 1
    }
    echo "$install_script" | bash

    # Restore Claude configuration from repository if available
    if [ -x "$SCRIPT_DIR/restore-claude.sh" ]; then
        log_with_level "INFO" "Restoring Claude configuration from repository..."
        "$SCRIPT_DIR/restore-claude.sh" --force || log_with_level "WARN" "Claude config restore skipped or failed"
    fi
fi
# Install additional tools based on preferences
if [[ "${INSTALL_DATA_SCIENCE:-N}" =~ ^[Yy] ]]; then
    log_with_level "INFO" "Installing data science tools..."
    # Future: Install jupyter, pandas, numpy, etc.
    pip3 install --quiet jupyter pandas numpy matplotlib scikit-learn
fi

log_with_level "SUCCESS" "Installation completed successfully!"
