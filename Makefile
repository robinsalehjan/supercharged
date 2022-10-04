# Set shell to bash
SHELL := /bin/bash

help:
	@echo "setup - install dependencies and configure bash profile"
	@echo "setup_profile - copy .gitconfig, .gitignore_global and .bash_profile to home directory"
	@echo "update - update existing dependencies"

setup: setup_profile
	@echo "Running mac.sh script to install dependencies and setup bash profile"
	./mac.sh

setup_profile:
	@echo "Copying contents of .gitconfig to home directory"
	@cp .gitconfig ~/
	
	@echo "Copying contents of .gitignore_global to home directory"
	@cp .gitignore_global ~/
	
	@echo "Copying contents of .bash_profile to home directory"
	@cp .bash_profile ~/

update:
	@echo "Running update.sh script to update dependencies and bash profile"
	./update.sh