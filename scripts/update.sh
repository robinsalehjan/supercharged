#!/bin/zsh
set -e

source "$(dirname "$0")/utils.sh"

# Default flags
DRY_RUN=false
SKIP_BREW=false
SKIP_CASK=false
SKIP_ASDF=false
SKIP_ZSH=false
SKIP_NPM=false
SKIP_PIP=false
ONLY_MODE=false

# Usage information
show_help() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Update all dependencies and tools installed by mac.sh"
    echo ""
    echo "Options:"
    echo "  --only COMPONENT  Update only the specified component (brew, asdf, zsh, npm, pip)"
    echo "                    Can be repeated: --only brew --only npm"
    echo "  --dry-run         Preview what would be updated without making changes"
    echo "  --skip-brew       Skip Homebrew formula updates"
    echo "  --skip-cask       Skip Homebrew cask updates"
    echo "  --skip-asdf       Skip asdf plugin and version updates"
    echo "  --skip-zsh        Skip zsh plugin updates"
    echo "  --skip-npm        Skip npm global package updates"
    echo "  --skip-pip        Skip pip package updates"
    echo "  -h, --help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0")                    # Update everything"
    echo "  $(basename "$0") --only brew        # Update only Homebrew (formulae + casks)"
    echo "  $(basename "$0") --only brew --only npm  # Update Homebrew and npm only"
    echo "  $(basename "$0") --dry-run          # Preview all updates"
    echo "  $(basename "$0") --skip-npm --skip-pip  # Skip npm and pip updates"
}

# Setup error handling and cleanup
cleanup() {
    standard_cleanup "Update"
}

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --only)
                if [[ "$ONLY_MODE" != true ]]; then
                    ONLY_MODE=true
                    SKIP_BREW=true
                    SKIP_CASK=true
                    SKIP_ASDF=true
                    SKIP_ZSH=true
                    SKIP_NPM=true
                    SKIP_PIP=true
                fi
                shift
                case "${1:-}" in
                    brew) SKIP_BREW=false; SKIP_CASK=false ;;
                    asdf) SKIP_ASDF=false ;;
                    zsh)  SKIP_ZSH=false ;;
                    npm)  SKIP_NPM=false ;;
                    pip)  SKIP_PIP=false ;;
                    *)
                        echo "Unknown component: ${1:-<missing>}"
                        echo "Valid components: brew, asdf, zsh, npm, pip"
                        exit 1
                        ;;
                esac
                shift
                ;;
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

    trap cleanup EXIT

    # Initialize logging
    setup_logging

    if $DRY_RUN; then
        log_with_level "INFO" "=== DRY RUN MODE - No changes will be made ==="
    fi

    log_with_level "INFO" "Starting update process..."

    # Check internet connectivity before attempting updates
    require_internet || exit 1

    # Show outdated packages report
    log_with_level "INFO" "Checking for outdated packages..."
    echo ""

    if ! $SKIP_BREW; then
        log_with_level "INFO" "📦 Outdated Homebrew formulae:"
        brew update --quiet
        outdated_brew=$(brew outdated --formula)
        if [ -n "$outdated_brew" ]; then
            # shellcheck disable=SC2001
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
            # shellcheck disable=SC2001
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
            # shellcheck disable=SC2001
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

        # Fix wireshark symlinks and remove deprecated cask
        fix_wireshark_symlinks

        brew upgrade
    fi

    if ! $SKIP_CASK; then
        log_with_level "INFO" "Updating brew casks..."
        # Update casks; some may fail due to upstream cask definition issues
        if brew upgrade --cask 2>&1; then
            log_with_level "SUCCESS" "Casks updated successfully"
        else
            log_with_level "WARN" "Some casks may have failed to update (this can happen with upstream cask definition issues)"
        fi
        brew cleanup
    fi

    if ! $SKIP_ASDF; then
        log_with_level "INFO" "Updating asdf plugins..."
        asdf plugin update --all

        log_with_level "INFO" "Updating asdf tool versions..."
        # Parse versions from .tool-versions using shared utility
        TOOL_VERSIONS_FILE="$UTILS_PROJECT_ROOT/dot_files/.tool-versions"

        if [ -f "$TOOL_VERSIONS_FILE" ]; then
            parse_tool_versions "$TOOL_VERSIONS_FILE"
            installed_plugins=$(asdf plugin list 2>/dev/null)
            # shellcheck disable=SC2066  # zsh ${(@k)…} array-key expansion (script is zsh-only)
            for plugin in "${(@k)TOOL_VERSIONS}"; do
                version="${TOOL_VERSIONS[$plugin]}"
                if echo "$installed_plugins" | grep -q "^${plugin}$"; then
                    log_with_level "INFO" "Updating $plugin to version $version"
                    asdf install "$plugin" "$version"
                    asdf set --home "$plugin" "$version"
                fi
            done
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
            pip3 install --quiet --upgrade jupyter pandas numpy matplotlib scikit-learn 2>/dev/null || log_with_level "WARN" "Failed to update pip packages"
        fi
    fi

    # Ensure RTK is configured for Claude Code (if both are installed)
    if command -v rtk >/dev/null 2>&1 && [ -d "$HOME/.claude" ]; then
        setup_rtk
    fi

    # Ensure Dippy is installed for permission automation (if Claude Code is installed)
    if [ -d "$HOME/.claude" ] && ! command -v dippy >/dev/null 2>&1; then
        setup_dippy
    fi

    # Ensure Worktrunk shell integration is configured (if installed)
    if command -v wt >/dev/null 2>&1; then
        setup_worktrunk
    fi

    # Ensure code-review-graph is configured for Claude Code (if both are installed)
    if command -v code-review-graph >/dev/null 2>&1 && [ -d "$HOME/.claude" ]; then
        setup_code_review_graph
    fi

    log_with_level "SUCCESS" "Update completed successfully!"
}

# Source guard: skip main() when sourced, run when executed directly
if [[ -n "${ZSH_EVAL_CONTEXT:-}" ]]; then
    if [[ "${ZSH_EVAL_CONTEXT}" != *file* ]]; then
        main "$@"
    fi
else
    if [[ "${BASH_SOURCE[0]:-$0}" == "${0}" ]]; then
        main "$@"
    fi
fi
