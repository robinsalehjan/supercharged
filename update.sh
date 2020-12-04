cp ~/.gitconfig .
cp ~/.gitignore_global .
cp ~/.bash_profile .
echo "[brew]: UPDATING OUTDATED PACKAGES"
brew update && brew upgrade `brew outdated`
echo "[brew cask]: UPDATING OUTDATED CASKS"
brew upgrade --cask
if ! [[ $(ps aux | grep gcloud | grep -vc gcloud) > 0 ]]; then exit 0; else $("gcloud components update"); fi
brew cleanup
brew bundle --force cleanup
gcloud components update
