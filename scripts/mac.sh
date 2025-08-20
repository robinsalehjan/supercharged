#!/bin/zsh

source "$(dirname "$0")/utils.sh"

# Setup error handling and cleanup
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "Installation failed. Cleaning up..."
        brew cleanup
        rm -rf "$HOME/.bin"
    fi
    exit $exit_code
}

trap cleanup EXIT
trap 'ret=$?; test $ret -ne 0 && printf "failed\n\n" >&2; exit $ret' EXIT

# Initialize logging
setup_logging

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

# Backup existing configurations
backup_dotfiles

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
brew bundle --file=- <<EOF
tap "thoughtbot/formulae"
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
brew "xcodesorg/made/xcodes"
brew "aria2"
brew "k9s"
brew "xcode-build-server"
brew "xcbeautify"
brew "swiftlint"
brew "tree"
brew "ripgrep"
brew "ios-deploy"

cask "spotify"
cask "wireshark-app"
cask "docker-desktop"
cask "visual-studio-code"
cask "slack"
cask "postman"
cask "raycast"
EOF

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


fancy_echo 'Installing asdf plugins and versions...'

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
