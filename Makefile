# Set shell to bash
SHELL := /bin/bash

help:
	@echo "setup - install dependencies and configure bash profile"
	@echo "update - update existing dependencies and bash profile"

setup:
	@echo "Moving .bash_profile to home directory"
	@mv .bash_profile ~/
	
	@echo "Moving .gitconfig to home directory"
	@mv .gitconfig ~/
	
	@echo "Moving .gitignore_global to home directory"
	@mv .gitignore_global ~/
	
	@echo "Installing developer tools via 'xcode-select --install'"
	@xcode-select --install

	@echo "Running mac.sh script to install dependencies and setup bash profile"
	./mac.sh

update:
	@echo "Copying ~/.bash_profile to current directory"
	@cp ~/.gitconfig .
	
	@echo "Copying ~/.gitignore_global to current directory"
	@cp ~/.gitignore_global .
	
	@echo "Copying ~/.bash_profile to current directory"
	@cp ~/.bash_profile .

	@echo "Running update.sh script to update dependencies and bash profile"
	./update.sh
