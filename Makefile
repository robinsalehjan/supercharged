# Set shell to bash
SHELL := /bin/bash

help:
	@echo "setup - install dependencies and configure bash profile"
	@echo "update - update existing dependencies and bash profile"

setup:
	@echo "Copying contents of .bash_profile to home directory"
	@cp .bash_profile ~/
	
	@echo "Copying contents of .gitconfig to home directory"
	@cp .gitconfig ~/
	
	@echo "Copying contents of .gitignore_global to home directory"
	@cp .gitignore_global ~/
	
	@echo "Installing developer tools via 'xcode-select --install'"
	@xcode-select --install

	@echo "Running mac.sh script to install dependencies and setup bash profile"
	./mac.sh

update:
	@echo "Copying contents of .gitconfig from home directory"
	@cp ~/.gitconfig .
	
	@echo "Copying contents of .gitignore_global from home directory
	@cp ~/.gitignore_global .
	
	@echo "Copying contents of .bash_profile from home directory
	@cp ~/.bash_profile .

	@echo "Running update.sh script to update dependencies and bash profile"
	./update.sh
