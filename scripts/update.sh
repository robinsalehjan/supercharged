#!/bin/zsh

source "$(dirname "$0")/utils.sh"

# Initialize logging
setup_logging

log_with_level "INFO" "Starting update process..."

log_with_level "INFO" "Updating brew packages..."
brew update && brew upgrade

log_with_level "INFO" "Updating brew casks..."
brew upgrade --cask && brew cleanup

log_with_level "INFO" "Updating asdf plugins..."
asdf plugin update --all

log_with_level "INFO" "Updating asdf tool versions..."
# Parse and update versions from .tool-versions if they exist
SCRIPT_DIR="$(dirname "$0")"
TOOL_VERSIONS_FILE="$SCRIPT_DIR/../dot_files/.tool-versions"

if [ -f "$TOOL_VERSIONS_FILE" ]; then
    while read -r line; do
        if [[ ! "$line" =~ ^# ]] && [[ -n "$line" ]]; then
            plugin=$(echo "$line" | awk '{print $1}')
            version=$(echo "$line" | awk '{print $2}')
            if asdf plugin list | grep -q "^${plugin}$"; then
                log_with_level "INFO" "Updating $plugin to version $version"
                asdf install "$plugin" "$version"
                asdf set --home "$plugin" "$version"
            fi
        fi
    done < "$TOOL_VERSIONS_FILE"
fi

log_with_level "INFO" "Running asdf reshim..."
asdf reshim

log_with_level "SUCCESS" "Update completed successfully!"
