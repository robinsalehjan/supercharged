# Set shell to zsh
SHELL := /bin/zsh

SCRIPTS_FOLDER_PATH := $(PWD)/scripts
DOT_FILES_FOLDER_PATH := $(PWD)/dot_files

help:
	@echo "setup - install dependencies, configure environment profiles, and validate"
	@echo "setup_profile - copy .gitconfig, .gitignore_global, .tool-versions, .zshrc and .zprofile to $(HOME)"
	@echo "update - update existing dependencies"
	@echo "validate - check if all tools are properly installed"
	@echo "clean_xcode - clean Xcode caches and derived data"

setup: setup_profile
	@echo "Running mac.sh script to install dependencies"
	$(SCRIPTS_FOLDER_PATH)/mac.sh
	@echo "Running validation to ensure everything is installed correctly..."
	@$(MAKE) validate

setup_profile:
	@echo "Copying .gitconfig to $(HOME)"
	@cp $(DOT_FILES_FOLDER_PATH)/.gitconfig $(HOME)

	@echo "Copying .gitignore_global to $(HOME)"
	@cp $(DOT_FILES_FOLDER_PATH)/.gitignore_global $(HOME)

	@echo "Copying .tool-versions to $(HOME)"
	@cp $(DOT_FILES_FOLDER_PATH)/.tool-versions $(HOME)

	@echo "Copying .zshrc to $(HOME)"
	@cp $(DOT_FILES_FOLDER_PATH)/.zshrc $(HOME)

	@echo "Copying .zprofile to $(HOME)"
	@cp $(DOT_FILES_FOLDER_PATH)/.zprofile $(HOME)

	@echo "Copying .tmux.conf to $(HOME)"
	@cp $(DOT_FILES_FOLDER_PATH)/.tmux.conf $(HOME)

	@echo "Copying .p10k.zsh to $(HOME)"
	@cp $(DOT_FILES_FOLDER_PATH)/.p10k.zsh $(HOME)

update: setup_profile
	@echo "Running update.sh script to update dependencies and environment profiles"
	$(SCRIPTS_FOLDER_PATH)/update.sh

validate:
	@echo "Validating installation..."
	@cd $(SCRIPTS_FOLDER_PATH) && ./utils.sh validate && echo "✅ All tools validated successfully" || echo "❌ Validation failed"

clean_xcode:
	@echo "Cleaning Xcode caches and derived data..."
	$(SCRIPTS_FOLDER_PATH)/nuke_xcode.sh

.PHONY: help setup setup_profile update validate clean_xcode
