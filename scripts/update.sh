#!/bin/zsh

source "$(dirname "$0")/utils.sh"

# Default flags
DRY_RUN=false
SKIP_BREW=false
SKIP_CASK=false
SKIP_ASDF=false
SKIP_ZSH=false
SKIP_NPM=false
SKIP_PIP=false

# Usage information
show_help() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Update all dependencies and tools installed by mac.sh"
    echo ""
    echo "Options:"
    echo "  --dry-run      Preview what would be updated without making changes"
    echo "  --skip-brew    Skip Homebrew formula updates"
    echo "  --skip-cask    Skip Homebrew cask updates"
    echo "  --skip-asdf    Skip asdf plugin and version updates"
    echo "  --skip-zsh     Skip zsh plugin updates"
    echo "  --skip-npm     Skip npm global package updates"
    echo "  --skip-pip     Skip pip package updates"
    echo "  -h, --help     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0")                    # Update everything"
    echo "  $(basename "$0") --dry-run          # Preview all updates"
    echo "  $(basename "$0") --skip-npm --skip-pip  # Skip npm and pip updates"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-brew)
            SKIP_BREW=true
            shift
            ;;
        --skip-cask)
            SKIP_CASK=true
            shift
            ;;
        --skip-asdf)
            SKIP_ASDF=true
            shift
            ;;
        --skip-zsh)
            SKIP_ZSH=true
            shift
            ;;
        --skip-npm)
            SKIP_NPM=true
            shift
            ;;
        --skip-pip)
            SKIP_PIP=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Setup error handling and cleanup
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_with_level "ERROR" "Update failed with exit code $exit_code"
        brew cleanup 2>/dev/null || true
    fi
    exit $exit_code
}

trap cleanup EXIT

# Initialize logging
setup_logging

if $DRY_RUN; then
    log_with_level "INFO" "=== DRY RUN MODE - No changes will be made ==="
fi

log_with_level "INFO" "Starting update process..."

# Check internet connectivity before attempting updates
if ! ping -c 1 -W 5000 google.com >/dev/null 2>&1; then
    log_with_level "ERROR" "Internet connectivity required for updates"
    exit 1
fi

# Show outdated packages report
log_with_level "INFO" "Checking for outdated packages..."
echo ""

if ! $SKIP_BREW; then
    log_with_level "INFO" "📦 Outdated Homebrew formulae:"
    brew update --quiet
    outdated_brew=$(brew outdated --formula)
    if [ -n "$outdated_brew" ]; then
        echo "$outdated_brew" | sed 's/^/   /'
    else
        echo "   All formulae are up to date"
    fi
    echo ""
fi

if ! $SKIP_CASK; then
    log_with_level "INFO" "🖥️  Outdated Homebrew casks:"
    outdated_casks=$(brew outdated --cask)
    if [ -n "$outdated_casks" ]; then
        echo "$outdated_casks" | sed 's/^/   /'
    else
        echo "   All casks are up to date"
    fi
    echo ""
fi

if ! $SKIP_NPM && command -v npm >/dev/null 2>&1; then
    log_with_level "INFO" "📦 Outdated npm global packages:"
    outdated_npm=$(npm outdated -g --depth=0 2>/dev/null || true)
    if [ -n "$outdated_npm" ]; then
        echo "$outdated_npm" | sed 's/^/   /'
    else
        echo "   All npm packages are up to date"
    fi
    echo ""
fi

# In dry-run mode, exit after showing report
if $DRY_RUN; then
    log_with_level "INFO" "=== DRY RUN COMPLETE - No changes were made ==="
    exit 0
fi

# Perform updates
if ! $SKIP_BREW; then
    log_with_level "INFO" "Updating brew packages..."
    brew upgrade
fi

if ! $SKIP_CASK; then
    log_with_level "INFO" "Updating brew casks..."
    brew upgrade --cask && brew cleanup
fi

if ! $SKIP_ASDF; then
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
fi

# Update zsh plugins if they exist
if ! $SKIP_ZSH; then
    log_with_level "INFO" "Updating zsh plugins..."
    ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    for plugin_dir in "$ZSH_CUSTOM/plugins/"* "$ZSH_CUSTOM/themes/"*; do
        if [ -d "$plugin_dir/.git" ]; then
            plugin_name=$(basename "$plugin_dir")
            log_with_level "INFO" "Updating zsh plugin: $plugin_name"
            git -C "$plugin_dir" pull --quiet 2>/dev/null || log_with_level "WARN" "Failed to update $plugin_name"
        fi
    done
fi

# Update npm global packages if npm is available
if ! $SKIP_NPM && command -v npm >/dev/null 2>&1; then
    log_with_level "INFO" "Updating npm global packages..."
    npm update -g 2>/dev/null || log_with_level "WARN" "Failed to update npm packages"
fi

# Update pip packages if pip is available and data science tools are installed
if ! $SKIP_PIP && command -v pip3 >/dev/null 2>&1; then
    if pip3 show jupyter >/dev/null 2>&1; then
        log_with_level "INFO" "Updating pip data science packages..."
        pip3 install --upgrade jupyter pandas numpy matplotlib scikit-learn 2>/dev/null || log_with_level "WARN" "Failed to update pip packages"
    fi
fi

log_with_level "SUCCESS" "Update completed successfully!"
