#!/bin/sh

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
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fancy_echo '# Set PATH, MANPATH, etc., for Homebrew.' >> /Users/robinsalehjan/.zprofile
  fancy_echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> /Users/robinsalehjan/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
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
EOF

fancy_echo "Agree to xcodebuild license"
sudo xcodebuild -license

fancy_echo "Installing python 2.7.18 through pyenv"
pyenv install 2.7.18

fancy_echo "Installing python 3.10.6 through pyenv"
pyenv install 3.10.6
