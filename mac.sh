#!/bin/sh

cp . ~/.gitconfig 2>/dev/null
cp . ~/.gitignore_global 2>/dev/null
cp . ~/.bash_profile 2>/dev/null

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
  fancy_echo "Installing Homebrew ..."
    curl -fsS \
      'https://raw.githubusercontent.com/Homebrew/install/master/install' | ruby

    export PATH="/usr/local/bin:$PATH"
fi

if brew list | grep -Fq brew-cask; then
  fancy_echo "Uninstalling old Homebrew-Cask ..."
  brew uninstall --force brew-cask
fi

fancy_echo "Updating Homebrew formulae ..."
brew update --force # https://github.com/Homebrew/brew/issues/1151
brew bundle --file=- <<EOF
tap "thoughtbot/formulae"
tap "homebrew/services"
tap "homebrew/cask"

brew "git"
brew "openssl"
brew "libyaml"
brew "coreutils"
brew "keychain"
brew "htop"
brew "nmap"
brew "bash-completion"
brew "bash-git-prompt"
brew "rbenv"
brew "pyenv"
brew "nodenv"
brew "watchman"
brew "awscli"

cask "google-cloud-sdk"
cask "docker"
cask "tidal"
cask "fork"
cask "visual-studio-code"
cask "slack"
EOF

fancy_echo "Installing python@2 from github"
brew install https://raw.githubusercontent.com/Homebrew/homebrew-core/86a44a0a552c673a05f11018459c9f5faae3becc/Formula/python@2.rb
