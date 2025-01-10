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

echo 'UPDATING BREW CASKS'
brew upgrade --cask && brew cleanup &

echo 'UPDATING ASDF PLUGINS'
asdf plugin update --all &
wait $! # Wait for the asdf plugin update (last launched process)to finish

echo 'RUNNING ASDF RESHIM WITH SUDO PRIVILEGES'
sudo asdf reshim
wait $! # Wait for the asdf reshim to finish

echo 'UPDATING GCLOUD COMPONENTS'
gcloud components update &
