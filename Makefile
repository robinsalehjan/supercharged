# Set shell to zsh
SHELL := /bin/zsh

SCRIPTS_FOLDER_PATH := $(PWD)/scripts
DOT_FILES_FOLDER_PATH := $(PWD)/dot_files

help:
	@echo "setup - install dependencies and configure environment profiles"
	@echo "setup_profile - copy .gitconfig, .gitignore_global, .tool.versions, .zshrc and .zprofile to $(HOME)"
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

	@echo "Copying contents of .zshrc to $(HOME)"
	@cp $(DOT_FILES_FOLDER_PATH)/.zshrc $(HOME)

	@echo "Copying contents of .zprofile to $(HOME)"
	@cp $(DOT_FILES_FOLDER_PATH)/.zprofile $(HOME)

	@echo "Copying contents of .tmux.conf to $(HOME)"
	@cp $(DOT_FILES_FOLDER_PATH)/.tmux.conf $(HOME)

update: setup_profile
	@echo "Running update.sh script to update dependencies and environment profiles"
	$(SCRIPTS_FOLDER_PATH)/update.sh
