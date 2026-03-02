#!/bin/zsh

# Compute paths once at script load time
UTILS_SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)" || UTILS_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]:-$0}")"
# Handle the case where utils.sh is sourced
if [[ "$UTILS_SCRIPT_DIR" == "." ]] || [[ -z "$UTILS_SCRIPT_DIR" ]]; then
    UTILS_SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")" 2>/dev/null && pwd)" || UTILS_SCRIPT_DIR="$PWD"
fi
UTILS_PROJECT_ROOT="$(cd "$UTILS_SCRIPT_DIR/.." 2>/dev/null && pwd)" || UTILS_PROJECT_ROOT="$UTILS_SCRIPT_DIR"
UTILS_LOG_FILE="$UTILS_PROJECT_ROOT/.supercharged_install.log"

# Colored output for better user experience
fancy_echo() {
    local fmt="$1"; shift
    printf "\n\033[1;32m==> $fmt\033[0m\n" "$@"
}

# Enhanced logging with levels
log_with_level() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case $level in
        "ERROR")
            echo "[$timestamp] [❌ ERROR] $message" | tee -a "$UTILS_LOG_FILE" >&2
            ;;
        "WARN")
            echo "[$timestamp] [⚠️  WARN] $message" | tee -a "$UTILS_LOG_FILE"
            ;;
        "INFO")
            echo "[$timestamp] [ℹ️  INFO] $message" | tee -a "$UTILS_LOG_FILE"
            ;;
        "SUCCESS")
            echo "[$timestamp] [✅ SUCCESS] $message" | tee -a "$UTILS_LOG_FILE"
            ;;
        *)
            echo "[$timestamp] [DEBUG] $message" | tee -a "$UTILS_LOG_FILE"
            ;;
    esac
}

# Logging setup
setup_logging() {
    exec 1> >(tee -a "$UTILS_LOG_FILE")
    exec 2> >(tee -a "$UTILS_LOG_FILE" >&2)
    log_with_level "INFO" "Installation started"
}

# Create restoration point
create_restoration_point() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_base="$HOME/.supercharged_backups"
    local backup_dir="$backup_base/$timestamp"

    log_with_level "INFO" "Creating restoration point at $backup_dir"
    mkdir -p "$backup_dir"

    # Backup existing configurations
    for file in .zshrc .zprofile .gitconfig .p10k.zsh .tool-versions .tmux.conf .supercharged_preferences; do
        if [ -f "$HOME/$file" ]; then
            cp "$HOME/$file" "$backup_dir/"
            log_with_level "INFO" "Backed up $file"
        fi
    done

    # Backup Claude Code configuration if available (strip home directory for portability)
    if [ -d "$HOME/.claude" ]; then
        mkdir -p "$backup_dir/claude_config"
        if [ -f "$HOME/.claude/settings.json" ]; then
            cp "$HOME/.claude/settings.json" "$backup_dir/claude_config/"
            log_with_level "INFO" "Backed up Claude Code settings.json"
        fi
        if [ -f "$HOME/.claude/plugins/installed_plugins.json" ]; then
            make_path_portable < "$HOME/.claude/plugins/installed_plugins.json" > "$backup_dir/claude_config/installed_plugins.json"
            log_with_level "INFO" "Backed up Claude Code installed_plugins.json (paths made portable)"
        fi
        if [ -f "$HOME/.claude/plugins/known_marketplaces.json" ]; then
            make_path_portable < "$HOME/.claude/plugins/known_marketplaces.json" > "$backup_dir/claude_config/known_marketplaces.json"
            log_with_level "INFO" "Backed up Claude Code known_marketplaces.json (paths made portable)"
        fi
    fi

    # Store brew list if available
    if command -v brew >/dev/null 2>&1; then
        brew list > "$backup_dir/brew_packages.txt" 2>/dev/null || true
        brew list --cask > "$backup_dir/brew_casks.txt" 2>/dev/null || true
    fi

    # Store asdf plugins if available
    if command -v asdf >/dev/null 2>&1; then
        asdf plugin list > "$backup_dir/asdf_plugins.txt" 2>/dev/null || true
        asdf list > "$backup_dir/asdf_versions.txt" 2>/dev/null || true
    fi

    echo "$backup_dir" > "$HOME/.supercharged_last_backup"

    # Clean up old backups, keeping only the last 5
    local backup_count=$(ls -1d "$backup_base"/*/ 2>/dev/null | wc -l | tr -d ' ')
    if [ "$backup_count" -gt 5 ]; then
        log_with_level "INFO" "Cleaning up old backups (keeping last 5)..."
        ls -1dt "$backup_base"/*/ | tail -n +6 | xargs rm -rf
    fi

    log_with_level "SUCCESS" "Restoration point created successfully"
    return 0
}

# Restore from backup
restore_from_backup() {
    local backup_dir="$1"

    if [ -z "$backup_dir" ] && [ -f "$HOME/.supercharged_last_backup" ]; then
        backup_dir=$(cat "$HOME/.supercharged_last_backup")
    fi

    if [ ! -d "$backup_dir" ]; then
        log_with_level "ERROR" "Backup directory not found: $backup_dir"
        return 1
    fi

    log_with_level "INFO" "Restoring from backup: $backup_dir"

    for file in .zshrc .zprofile .gitconfig .p10k.zsh .tool-versions .tmux.conf .supercharged_preferences; do
        if [ -f "$backup_dir/$file" ]; then
            cp "$backup_dir/$file" "$HOME/"
            log_with_level "INFO" "Restored $file"
        fi
    done

    # Restore Claude Code configuration if available in backup (expand $HOME placeholder)
    if [ -d "$backup_dir/claude_config" ]; then
        mkdir -p "$HOME/.claude/plugins"
        if [ -f "$backup_dir/claude_config/settings.json" ]; then
            cp "$backup_dir/claude_config/settings.json" "$HOME/.claude/"
            log_with_level "INFO" "Restored Claude Code settings.json"
        fi
        if [ -f "$backup_dir/claude_config/installed_plugins.json" ]; then
            expand_portable_path < "$backup_dir/claude_config/installed_plugins.json" > "$HOME/.claude/plugins/installed_plugins.json"
            log_with_level "INFO" "Restored Claude Code installed_plugins.json"
        fi
        if [ -f "$backup_dir/claude_config/known_marketplaces.json" ]; then
            expand_portable_path < "$backup_dir/claude_config/known_marketplaces.json" > "$HOME/.claude/plugins/known_marketplaces.json"
            log_with_level "INFO" "Restored Claude Code known_marketplaces.json"
        fi
    fi

    log_with_level "SUCCESS" "Restoration completed"
    return 0
}

# Version checking with safety improvements
check_version() {
    local cmd=$1
    local min_version=$2

    # Check if command exists first
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_with_level "WARN" "$cmd not found, skipping version check"
        return 1
    fi

    local version=$(extract_tool_version "$cmd")

    if [ "$(printf '%s\n' "$min_version" "$version" | sort -V | head -n1)" != "$min_version" ]; then
        log_with_level "WARN" "$cmd version $min_version or higher recommended (found: $version)"
        return 1
    fi

    log_with_level "INFO" "$cmd version $version meets minimum requirement $min_version"
    return 0
}

# Path portability helpers - make paths portable across machines
make_path_portable() {
    sed "s|$HOME|\$HOME|g"
}

expand_portable_path() {
    sed "s|\\\$HOME|$HOME|g"
}

# Extract version from a tool command
extract_tool_version() {
    local cmd=$1
    case "$cmd" in
        "python"|"python3")
            python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0"
            ;;
        "node"|"nodejs")
            node --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0"
            ;;
        "ruby")
            ruby --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0"
            ;;
        "java")
            java -version 2>&1 | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0"
            ;;
        *)
            $cmd --version 2>&1 | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0"
            ;;
    esac
}

# Parse .tool-versions file into an associative array
# Usage: parse_tool_versions; echo "${TOOL_VERSIONS[python]}"
parse_tool_versions() {
    local tool_versions_file="${1:-$UTILS_PROJECT_ROOT/dot_files/.tool-versions}"
    typeset -gA TOOL_VERSIONS

    while IFS=' ' read -r tool version || [[ -n "$tool" ]]; do
        # Skip comments and empty lines
        [[ "$tool" =~ ^# ]] || [[ -z "$tool" ]] && continue
        TOOL_VERSIONS[$tool]="$version"
    done < "$tool_versions_file"
}

# Get specific tool version from .tool-versions file
get_tool_version_from_file() {
    local tool=$1
    local versions_file="${2:-$UTILS_PROJECT_ROOT/dot_files/.tool-versions}"
    awk -v tool="$tool" '$1 == tool {print $2; exit}' "$versions_file"
}

# Check internet connectivity
require_internet() {
    if ! ping -c 1 -W 5 google.com >/dev/null 2>&1; then
        log_with_level "ERROR" "Internet connectivity required"
        return 1
    fi
    return 0
}

# Fix wireshark symlinks and remove deprecated cask
fix_wireshark_symlinks() {
    # Remove deprecated wireshark-app cask if present (has broken definition)
    if brew list --cask wireshark-app &>/dev/null 2>&1; then
        log_with_level "INFO" "Removing deprecated wireshark-app cask..."
        brew uninstall --cask wireshark-app 2>/dev/null || true
    fi

    # Fix wireshark linking issues if it's installed
    if brew list wireshark &>/dev/null; then
        log_with_level "INFO" "Fixing wireshark symlinks..."
        brew unlink wireshark 2>/dev/null || true
        brew link --overwrite wireshark 2>/dev/null || true
    fi
}

# Standard cleanup function with brew cleanup and optional backup restoration message
standard_cleanup() {
    local script_name="${1:-Script}"
    local exit_code=$?

    if [ $exit_code -ne 0 ] && [ $exit_code -ne 1 ]; then
        log_with_level "ERROR" "$script_name failed with exit code $exit_code"

        if [ -f "$HOME/.supercharged_last_backup" ]; then
            local backup_dir=$(cat "$HOME/.supercharged_last_backup")
            echo ""
            echo "💡 You can restore your previous configuration with:"
            echo "   npm run restore"
        fi
    fi

    command -v brew >/dev/null 2>&1 && brew cleanup 2>/dev/null || true
    exit $exit_code
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

# Interactive git configuration setup
setup_git_config() {
    # Use pre-computed paths from top of file
    local git_source="$UTILS_PROJECT_ROOT/dot_files/.gitconfig"
    local git_config="$HOME/.gitconfig"

    # Check if git config already exists and is identical to source first
    if [ -f "$git_config" ] && [ -f "$git_source" ] && cmp -s "$git_source" "$git_config"; then
        log_with_level "INFO" "Git configuration already exists and is up to date"
        return 0
    fi

    log_with_level "INFO" "Looking for git config at: $git_source"

    if [ ! -f "$git_source" ]; then
        log_with_level "ERROR" "Git config not found at $git_source"
        log_with_level "INFO" "Current working directory: $(pwd)"
        log_with_level "INFO" "Project root: $UTILS_PROJECT_ROOT"
        return 1
    fi

    echo ""
    echo "🔧 Setting up Git configuration..."
    echo ""

    # Copy the git config file
    cp "$git_source" "$git_config"

    log_with_level "SUCCESS" "Git configuration copied successfully"
    return 0
}

# Interactive user preferences setup
setup_user_preferences() {
    echo ""
    echo "🎯 Configure your development environment preferences:"
    echo ""

    # Temporarily disable strict mode for interactive input
    set +u

    # Ask about iOS development
    printf "Install iOS development tools (xcodes, ios-deploy, swift tools)? [Y/n]: "
    read -r install_ios
    install_ios=${install_ios:-Y}

    # Ask about data science tools
    printf "Install data science tools (jupyter, pandas, numpy)? [y/N]: "
    read -r install_datascience
    install_datascience=${install_datascience:-N}

    # Ask about additional development tools
    printf "Install additional development tools (docker, kubernetes tools)? [Y/n]: "
    read -r install_devtools
    install_devtools=${install_devtools:-Y}

    # Ask about Claude Code
    printf "Install Claude Code (AI coding assistant)? [Y/n]: "
    read -r install_claude
    install_claude=${install_claude:-Y}

    # Re-enable strict mode
    set -u

    # Store preferences
    local prefs_file="$HOME/.supercharged_preferences"
    cat > "$prefs_file" << EOF
# Supercharged Setup Preferences
INSTALL_IOS_TOOLS=${install_ios}
INSTALL_DATA_SCIENCE=${install_datascience}
INSTALL_DEV_TOOLS=${install_devtools}
INSTALL_CLAUDE_CODE=${install_claude}
SETUP_DATE=$(date)
EOF

    log_with_level "SUCCESS" "User preferences saved to $prefs_file"

    # Export variables for current session
    export INSTALL_IOS_TOOLS="$install_ios"
    export INSTALL_DATA_SCIENCE="$install_datascience"
    export INSTALL_DEV_TOOLS="$install_devtools"
    export INSTALL_CLAUDE_CODE="$install_claude"
}

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

# Function to safely install asdf versions (idempotent)
install_asdf_version() {
    local plugin=$1
    local version=$2

    # Check if already at the correct version (global setting)
    local current_version
    current_version=$(asdf current "$plugin" 2>/dev/null | awk '{print $2}' || echo "")

    if [ "$current_version" = "$version" ]; then
        log_with_level "INFO" "asdf: $plugin already at version $version, skipping"
        return 0
    fi

    if ! asdf list "$plugin" 2>/dev/null | grep -q "$version"; then
        fancy_echo "asdf: installing $plugin version $version"
        asdf install "$plugin" "$version" || {
            log_with_level "ERROR" "Failed to install $plugin $version"
            return 1
        }
    else
        fancy_echo "asdf: $plugin $version already installed"
    fi

    asdf set --home "$plugin" "$version"
    log_with_level "SUCCESS" "asdf: $plugin set to version $version"
}

# Validation functions
validate_tool() {
    local tool=$1
    local expected_version=$2

    if command_exists "$tool"; then
        local version=$(extract_tool_version "$tool")

        if [ -z "$version" ] || [ "$version" = "0.0.0" ]; then
            echo "⚠️  $tool: version not detected"
            return 1
        elif [ "$version" = "$expected_version" ] || [ "$expected_version" = "" ]; then
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

    # Read versions from .tool-versions using helper function
    parse_tool_versions
    local python_version="${TOOL_VERSIONS[python]}"
    local ruby_version="${TOOL_VERSIONS[ruby]}"
    local node_version="${TOOL_VERSIONS[nodejs]}"

    # Validate core tools
    validate_tool "brew" "" || ((failed++))
    validate_tool "git" "" || ((failed++))
    validate_tool "asdf" "" || ((failed++))
    validate_tool "python3" "$python_version" || ((failed++))
    validate_tool "node" "$node_version" || ((failed++))
    validate_tool "ruby" "$ruby_version" || ((failed++))

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
