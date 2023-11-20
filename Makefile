# Set shell to bash
SHELL := /bin/bash

help:
	@echo "setup - install dependencies and configure bash profile"
	@echo "setup_profile - copy .gitconfig, .gitignore_global, .tool.versions, .bashrc and .bash_profile to $(HOME)"
	@echo "update - update existing dependencies"

setup: setup_profile
	@echo "Running mac.sh script to install dependencies"
	./mac.sh

setup_profile:
	@echo "Copying contents of .gitconfig to $(HOME)"
	@cp .gitconfig $(HOME)
	
	@echo "Copying contents of .gitignore_global to $(HOME)"
	@cp .gitignore_global $(HOME)

	@echo "Copying contents of .tool-versions to $(HOME)"
	@cp .tool-versions $(HOME)

	@echo "Copying contents of .envrc to $(HOME)"
	@cp .envrc $(HOME)

	@echo "Copying contents of .bashrc to $(HOME)"
	@cp .bashrc $(HOME)
	
	@echo "Copying contents of .bash_profile to $(HOME)"
	@cp .bash_profile $(HOME)

update:
	@echo "Running update.sh script to update dependencies and bash profile"
	./update.sh