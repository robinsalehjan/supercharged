#!/bin/zsh

source "$(dirname "$0")/utils.sh"

# Initialize logging
setup_logging

fancy_echo 'UPDATING BREW PACKAGES'
brew update && brew upgrade

fancy_echo 'UPDATING BREW CASKS'
brew upgrade --cask && brew cleanup

fancy_echo 'UPDATING ASDF PLUGINS'
asdf plugin update --all

fancy_echo 'UPDATING ASDF TOOL VERSIONS'
# Parse and update versions from .tool-versions if they exist
SCRIPT_DIR="$(dirname "$0")"
TOOL_VERSIONS_FILE="$SCRIPT_DIR/../dot_files/.tool-versions"

if [ -f "$TOOL_VERSIONS_FILE" ]; then
    while read -r line; do
        if [[ ! "$line" =~ ^# ]] && [[ -n "$line" ]]; then
            plugin=$(echo "$line" | awk '{print $1}')
            version=$(echo "$line" | awk '{print $2}')
            if asdf plugin list | grep -q "^${plugin}$"; then
                fancy_echo "Updating $plugin to version $version"
                asdf install "$plugin" "$version"
                asdf global "$plugin" "$version"
            fi
        fi
    done < "$TOOL_VERSIONS_FILE"
fi

fancy_echo 'RUNNING ASDF RESHIM'
asdf reshim
