cp ~/.gitconfig .
cp ~/.gitignore_global .
cp ~/.bash_profile .

echo "[brew]: UPDATING OUTDATED PACKAGES"
brew update && brew upgrade `brew outdated`

echo "[brew cask]: UPDATING OUTDATED CASKS"
brew upgrade --cask
brew cleanup
brew bundle --force cleanup

gcloud components update
