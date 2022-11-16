#!/bin/sh

echo '[brew]: UPDATING OUTDATED PACKAGES'
brew update && brew upgrade `brew outdated`

echo '[brew cask]: UPDATING OUTDATED CASKS'
brew upgrade --cask
brew cleanup

softwareupdate --all --install

gcloud components update
