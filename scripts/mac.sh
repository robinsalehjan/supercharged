#!/bin/bash

fancy_echo() {
  local fmt="$1"; shift

  printf "\n$fmt\n" "$@"
}

fancy_echo 'Setting up bash script'
trap 'ret=$?; test $ret -ne 0 && printf "failed\n\n" >&2; exit $ret' EXIT
set -e

HOMEBREW_PREFIX="/usr/local"

if [ ! -d "$HOME/.bin/" ]; then
  mkdir "$HOME/.bin"
fi

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
brew "buildpacks/tap/pack"
brew "tmux"
brew "spotify"

cask "copilot-for-xcode"
cask "wireshark"
cask "google-cloud-sdk"
cask "docker"
cask "fork"
cask "visual-studio-code"
cask "slack"
cask "postman"
EOF

fancy_echo 'asdf: adding ruby plugin'
asdf plugin add ruby

fancy_echo 'asdf: adding nodejs plugin'
asdf plugin add nodejs

fancy_echo 'asdf: adding python plugin'
asdf plugin add python

fancy_echo 'asdf: adding java plugin'
asdf plugin add java

fancy_echo 'asdf: add direnv plugin'
asdf plugin add direnv

fancy_echo 'asdf: install all asdf tools specified in .tool-versions'
asdf install

fancy_echo 'asdf: setup direnv for bash'
asdf direnv setup --shell bash --version latest

fancy_echo 'asdf: allow direnv'
asdf exec direnv allow
