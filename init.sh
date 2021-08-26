#!/bin/sh

mv .bash_profile ~/
mv .gitconfig ~/
mv .gitignore_global ~/
xcode-select --install
source $PWD/mac.sh
