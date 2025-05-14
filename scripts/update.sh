#!/bin/zsh

source "$(dirname "$0")/utils.sh"

setup_logging() {
    local log_file="$HOME/.supercharged_install.log"
    exec 1> >(tee -a "$log_file")
    exec 2> >(tee -a "$log_file" >&2)
    echo "Installation started at $(date)"
}

echo 'UPDATING BREW PACKAGES'
brew update && brew upgrade `brew outdated` &
wait $!

echo 'UPDATING BREW CASKS'
brew upgrade --cask && brew cleanup &
wait $!

echo 'UPDATING ASDF PLUGINS'
asdf plugin update --all & # This command will fail for the `nodejs` plugin => https://github.com/asdf-vm/asdf/issues/1896
wait $!

echo 'RUNNING ASDF RESHIM WITH SUDO PRIVILEGES'
sudo asdf reshim &
wait $! # Wait for the asdf reshim to finish
