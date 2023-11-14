#!/bin/bash

echo 'UPDATING BREW PACKAGES'
brew update && brew upgrade `brew outdated`

echo 'UPDATING BREW CASKS'
brew upgrade --cask
brew cleanup

echo 'UPDATING GCLOUD COMPONENTS'
gcloud components update
