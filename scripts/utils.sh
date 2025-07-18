#!/bin/zsh

# Colored output for better user experience
fancy_echo() {
    local fmt="$1"; shift
    printf "\n\033[1;32m==> $fmt\033[0m\n" "$@"
}

# Logging setup
setup_logging() {
    local log_file="$HOME/.supercharged_install.log"
    exec 1> >(tee -a "$log_file")
    exec 2> >(tee -a "$log_file" >&2)
    echo "Installation started at $(date)"
}

# Version checking
check_version() {
    local cmd=$1
    local min_version=$2
    local version
    version=$($cmd --version | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0")
    if [ "$(printf '%s\n' "$min_version" "$version" | sort -V | head -n1)" != "$min_version" ]; then
        echo "Error: $cmd version $min_version or higher is required"
        exit 1
    fi
}

# Backup functionality
backup_dotfiles() {
    local backup_dir="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    for file in .zshrc .gitconfig .p10k.zsh .tool-versions; do
        if [ -f "$HOME/$file" ]; then
            cp "$HOME/$file" "$backup_dir/"
        fi
    done
    echo "Backed up existing configurations to $backup_dir"
}

# ZSH plugin installation
install_zsh_plugin() {
    local repo=$1
    local dest=$2
    if [ -d "$dest" ]; then
        echo "Plugin already installed at $dest"
    else
        git clone "$repo" "$dest" || {
            echo "Failed to clone $repo"
            return 1
        }
    fi
}

# Enhanced error handling
set -euo pipefail

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to safely install asdf plugins
install_asdf_plugin() {
    local plugin=$1
    if ! asdf plugin list | grep -q "^${plugin}$"; then
        fancy_echo "asdf: adding $plugin plugin"
        asdf plugin add "$plugin" || {
            echo "Warning: Failed to add $plugin plugin"
            return 1
        }
    else
        fancy_echo "asdf: $plugin plugin already installed"
    fi
}

# Function to safely install asdf versions
install_asdf_version() {
    local plugin=$1
    local version=$2

    if ! asdf list "$plugin" | grep -q "$version"; then
        fancy_echo "asdf: installing $plugin version $version"
        asdf install "$plugin" "$version" || {
            echo "Warning: Failed to install $plugin $version"
            return 1
        }
    else
        fancy_echo "asdf: $plugin $version already installed"
    fi

    asdf set --home "$plugin" "$version"
}

# Validation functions
validate_tool() {
    local tool=$1
    local expected_version=$2

    if command_exists "$tool"; then
        local version
        case "$tool" in
            "python"|"python3")
                version=$(python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
                ;;
            "node"|"nodejs")
                version=$(node --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
                ;;
            "ruby")
                version=$(ruby --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
                ;;
            *)
                version=$($tool --version 2>&1 | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
                ;;
        esac

        if [ "$version" = "$expected_version" ] || [ "$expected_version" = "" ]; then
            echo "✅ $tool: $version"
            return 0
        else
            echo "⚠️  $tool: expected $expected_version, found $version"
            return 1
        fi
    else
        echo "❌ $tool: not found"
        return 1
    fi
}

validate_installation() {
    echo "🔍 Validating installation..."
    local failed=0

    # Read versions from .tool-versions if available
    local python_version ruby_version node_version
    local tool_versions_file="$(dirname "$0")/../dot_files/.tool-versions"
    if [ -f "$tool_versions_file" ]; then
        python_version=$(awk '/python/{print $2}' "$tool_versions_file")
        ruby_version=$(awk '/ruby/{print $2}' "$tool_versions_file")
        node_version=$(awk '/nodejs/{print $2}' "$tool_versions_file")
    fi

    # Validate core tools
    validate_tool "brew" "" || ((failed++))
    validate_tool "git" "" || ((failed++))
    validate_tool "asdf" "" || ((failed++))
    validate_tool "python3" "$python_version" || ((failed++))
    validate_tool "node" "$node_version" || ((failed++))
    validate_tool "ruby" "$ruby_version" || ((failed++))

    # Validate optional tools
    validate_tool "tmux" "" || echo "ℹ️  tmux not found (optional)"
    validate_tool "htop" "" || echo "ℹ️  htop not found (optional)"

    if [ $failed -eq 0 ]; then
        echo "🎉 All validations passed!"
        return 0
    else
        echo "💥 $failed validation(s) failed"
        return 1
    fi
}

# Run validation if script is called directly or with validation argument
if [[ "${1:-}" == "validate" ]] || [[ "$(basename "$0")" == "utils.sh" ]]; then
    # Enable strict error handling for validation
    set -euo pipefail
    validate_installation
fi
