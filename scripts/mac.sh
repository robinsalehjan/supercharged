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

# Version checks
check_version "git" "2.0.0"
check_version "python3" "3.7.0"

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
tap "homebrew/cask"

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
brew "tmux"
brew "spotify"
brew "aria2"
brew "k9s"
brew "xcode-build-server"
brew "xcbeautify"
brew "swiftlint"
brew "swiftformat"
brew "tree"
brew "firebase-cli"
brew "firebase-admin"
brew "ripgrep"

cask "wireshark"
cask "google-cloud-sdk"
cask "docker"
cask "visual-studio-code"
cask "slack"
cask "postman"
cask "cursor"
cask "raycast"
cask "notion"
cask "obsidian"

EOF

fancy_echo 'Installing zsh themes and plugins'
install_zsh_plugin \
    "https://github.com/zsh-users/zsh-autosuggestions" \
    "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"

install_zsh_plugin \
    "https://github.com/zsh-users/zsh-syntax-highlighting" \
    "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"

install_zsh_plugin \
    "https://github.com/romkatv/powerlevel10k" \
    "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"

fancy_echo 'asdf: adding ruby plugin'
asdf plugin add ruby

fancy_echo 'asdf: adding nodejs plugin'
asdf plugin add nodejs
