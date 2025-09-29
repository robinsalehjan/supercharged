#!/bin/zsh

source "$(dirname "$0")/utils.sh"

# System requirements validation
validate_system() {
    log_with_level "INFO" "Validating system requirements..."

    # Check macOS version
    local macos_version=$(sw_vers -productVersion | cut -d. -f1-2)
    local required_version="12.0"

    if [ "$(printf '%s\n' "$required_version" "$macos_version" | sort -V | head -n1)" != "$required_version" ]; then
        log_with_level "ERROR" "macOS $required_version or later required (found: $macos_version)"
        exit 1
    fi

    # Check available disk space (in GB)
    local available_space_raw=$(df -h / | awk 'NR==2 {print $4}')
    local available_space=$(echo "$available_space_raw" | sed 's/[^0-9.]//g')

    # Convert to integer for comparison (remove decimal part if present)
    local available_space_int=${available_space%.*}

    if [ -z "$available_space_int" ] || [ "$available_space_int" -lt 10 ]; then
        log_with_level "ERROR" "At least 10GB free space required (found: ${available_space_raw})"
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
    if ! ping -c 1 -W 5000 google.com >/dev/null 2>&1; then
        log_with_level "ERROR" "Internet connectivity required for installation"
        exit 1
    fi

    log_with_level "SUCCESS" "System validation passed"
}

# Setup error handling and cleanup
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_with_level "ERROR" "Installation failed with exit code $exit_code"
        if [ -f "$HOME/.supercharged_last_backup" ]; then
            local backup_dir=$(cat "$HOME/.supercharged_last_backup")
            echo ""
            echo "💡 You can restore your previous configuration with:"
            echo "   source $(dirname "$0")/utils.sh && restore_from_backup '$backup_dir'"
        fi
        brew cleanup 2>/dev/null || true
    fi
    exit $exit_code
}

trap cleanup EXIT
trap 'ret=$?; test $ret -ne 0 && printf "failed\n\n" >&2; exit $ret' EXIT

# Initialize logging
setup_logging

# Validate system before starting
validate_system

# Create restoration point
create_restoration_point

# Setup user preferences and git config
setup_user_preferences
setup_git_config

# Parse versions from .tool-versions
SCRIPT_DIR="$(dirname "$0")"
TOOL_VERSIONS_FILE="$SCRIPT_DIR/../dot_files/.tool-versions"

python_version=$(awk '/python/{print $2}' "$TOOL_VERSIONS_FILE")
ruby_version=$(awk '/ruby/{print $2}' "$TOOL_VERSIONS_FILE")
node_version=$(awk '/nodejs/{print $2}' "$TOOL_VERSIONS_FILE")
gcloud_version=$(awk '/gcloud/{print $2}' "$TOOL_VERSIONS_FILE")
firebase_version=$(awk '/firebase/{print $2}' "$TOOL_VERSIONS_FILE")

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
        fancy_echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$($HOMEBREW_PREFIX/bin/brew shellenv)"
    else
        fancy_echo "Homebrew already installed"
    fi
}

install_homebrew

fancy_echo 'Updating Homebrew formulae ...'
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
brew "htop"
brew "nmap"
brew "asdf"
brew "aria2"
brew "tree"
brew "ripgrep"
brew "tmux"'

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
cask \"docker-desktop\""
fi

# Add standard applications
BREWFILE_CONTENT="$BREWFILE_CONTENT
cask \"spotify\"
cask \"wireshark\"
cask \"visual-studio-code\"
cask \"slack\"
cask \"postman\"
cask \"raycast\""

echo "$BREWFILE_CONTENT" | brew bundle --file=-

fancy_echo 'Installing zsh themes and plugins'
install_zsh_plugin \
    "https://github.com/zsh-users/zsh-autosuggestions" \
    "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"

install_zsh_plugin \
    "https://github.com/zsh-users/zsh-syntax-highlighting" \
    "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"

install_zsh_plugin \
    "https://github.com/romkatv/powerlevel10k" \
    "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"


log_with_level "INFO" "Installing asdf plugins and versions..."

# Install plugins
install_asdf_plugin python
install_asdf_plugin ruby
install_asdf_plugin nodejs
install_asdf_plugin gcloud
install_asdf_plugin firebase

# Install versions
install_asdf_version python "$python_version"
install_asdf_version ruby "$ruby_version"
install_asdf_version nodejs "$node_version"
install_asdf_version gcloud "$gcloud_version"
install_asdf_version firebase "$firebase_version"

# Reshim to ensure all binaries are available
asdf reshim

# Install additional tools based on preferences
if [[ "${INSTALL_DATA_SCIENCE:-N}" =~ ^[Yy] ]]; then
    log_with_level "INFO" "Installing data science tools..."
    # Future: Install jupyter, pandas, numpy, etc.
    pip3 install jupyter pandas numpy matplotlib scikit-learn
fi

# Install Github Copilot CLI
log_with_level "INFO" "Installing GitHub Copilot CLI..."
npm install -g @github/copilot

log_with_level "SUCCESS" "Installation completed successfully!"
