# Set shell to bash
SHELL := /bin/bash

SCRIPTS_FOLDER_PATH := $(PWD)/scripts
DOT_FILES_FOLDER_PATH := $(PWD)/dot_files

help:
	@echo "setup - install dependencies and configure bash profile"
	@echo "setup_profile - copy .gitconfig, .gitignore_global, .tool.versions, .bashrc and .bash_profile to $(HOME)"
	@echo "update - update existing dependencies"

setup: setup_profile
	@echo "Running mac.sh script to install dependencies"
	$(SCRIPTS_FOLDER_PATH)/mac.sh

setup_profile:
	@echo "Copying contents of .gitconfig to $(HOME)"
	@cp $(DOT_FILES_FOLDER_PATH)/.gitconfig $(HOME)

	@echo "Copying contents of .gitignore_global to $(HOME)"
	@cp $(DOT_FILES_FOLDER_PATH)/.gitignore_global $(HOME)

	@echo "Copying contents of .tool-versions to $(HOME)"
	@cp $(DOT_FILES_FOLDER_PATH)/.tool-versions $(HOME)

	@echo "Copying contents of .envrc to $(HOME)"
	@cp $(DOT_FILES_FOLDER_PATH)/.envrc $(HOME)

	@echo "Copying contents of .bashrc to $(HOME)"
	@cp $(DOT_FILES_FOLDER_PATH)/.bashrc $(HOME)

	@echo "Copying contents of .bash_profile to $(HOME)"
	@cp $(DOT_FILES_FOLDER_PATH)/.bash_profile $(HOME)

	@echo "Copying contents of .bash_profile to $(HOME)"
	@cp $(DOT_FILES_FOLDER_PATH)/.tmux.conf $(HOME)

update: setup_profile
	@echo "Running update.sh script to update dependencies and bash profile"
	$(SCRIPTS_FOLDER_PATH)/update.sh
