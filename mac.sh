#!/bin/bash

fancy_echo() {
  local fmt="$1"; shift

  printf "\n$fmt\n" "$@"
}

trap 'ret=$?; test $ret -ne 0 && printf "failed\n\n" >&2; exit $ret' EXIT

set -e

if [ ! -d "$HOME/.bin/" ]; then
  mkdir "$HOME/.bin"
fi

HOMEBREW_PREFIX="/usr/local"

if [ -d "$HOMEBREW_PREFIX" ]; then
  if ! [ -r "$HOMEBREW_PREFIX" ]; then
    sudo chown -R "$LOGNAME:admin" /usr/local
  fi
else
  sudo mkdir "$HOMEBREW_PREFIX"
  sudo chflags norestricted "$HOMEBREW_PREFIX"
  sudo chown -R "$LOGNAME:admin" "$HOMEBREW_PREFIX"
fi

gem_install_or_update() {
  if gem list "$1" --installed > /dev/null; then
    gem update "$@"
  else
    gem install "$@"
  fi
}

if ! command -v brew >/dev/null; then
  fancy_echo 'Installing Homebrew ...'
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if brew list | grep -Fq brew-cask; then
  fancy_echo 'Uninstalling old Homebrew-Cask ...'
  brew uninstall --force brew-cask
fi

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
brew "bash-completion"
brew "bash-git-prompt"
brew "asdf"
brew "xcodesorg/made/xcodes"
brew "kubectl"
brew "kubectx"

cask "wireshark"
cask "google-cloud-sdk"
cask "docker"
cask "tidal"
cask "fork"
cask "visual-studio-code"
cask "slack"
cask "postman"
EOF

fancy_echo 'Add ruby plugin to asdf'
asdf plugin add ruby

fancy_echo 'Add nodejs plugin to asdf'
asdf plugin add nodejs

fancy_echo 'Add python plugin to asdf'
asdf plugin add python

fancy_echo 'Installing python, ruby and nodejs versions specified in .tool-versions'
asdf install

fancy_echo 'Installing sdkman'
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
