#!/bin/zsh

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
    local log_file="$HOME/.supercharged_install.log"

    case $level in
        "ERROR")
            echo "[$timestamp] [❌ ERROR] $message" | tee -a "$log_file" >&2
            ;;
        "WARN")
            echo "[$timestamp] [⚠️  WARN] $message" | tee -a "$log_file"
            ;;
        "INFO")
            echo "[$timestamp] [ℹ️  INFO] $message" | tee -a "$log_file"
            ;;
        "SUCCESS")
            echo "[$timestamp] [✅ SUCCESS] $message" | tee -a "$log_file"
            ;;
        *)
            echo "[$timestamp] [DEBUG] $message" | tee -a "$log_file"
            ;;
    esac
}

# Logging setup
setup_logging() {
    local log_file="$HOME/.supercharged_install.log"
    exec 1> >(tee -a "$log_file")
    exec 2> >(tee -a "$log_file" >&2)
    log_with_level "INFO" "Installation started"
}

# Create restoration point
create_restoration_point() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="$HOME/.supercharged_backup_$timestamp"

    log_with_level "INFO" "Creating restoration point at $backup_dir"
    mkdir -p "$backup_dir"

    # Backup existing configurations
    for file in .zshrc .zprofile .gitconfig .p10k.zsh .tool-versions .tmux.conf; do
        if [ -f "$HOME/$file" ]; then
            cp "$HOME/$file" "$backup_dir/"
            log_with_level "INFO" "Backed up $file"
        fi
    done

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

    for file in .zshrc .zprofile .gitconfig .p10k.zsh .tool-versions .tmux.conf; do
        if [ -f "$backup_dir/$file" ]; then
            cp "$backup_dir/$file" "$HOME/"
            log_with_level "INFO" "Restored $file"
        fi
    done

    log_with_level "SUCCESS" "Restoration completed"
    return 0
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

# Backup functionality (legacy - use create_restoration_point for enhanced features)
backup_dotfiles() {
    log_with_level "WARN" "backup_dotfiles is deprecated, using create_restoration_point instead"
    create_restoration_point
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

# Interactive git configuration setup
setup_git_config() {
    local git_template="$(dirname "$0")/../dot_files/.gitconfig.template"
    local git_config="$HOME/.gitconfig"

    if [ ! -f "$git_template" ]; then
        log_with_level "ERROR" "Git config template not found at $git_template"
        return 1
    fi

    # Check if git config already exists and has real values
    if [ -f "$git_config" ] && ! grep -q "YOUR_NAME_HERE\|YOUR_EMAIL_HERE" "$git_config"; then
        log_with_level "INFO" "Git configuration already exists with valid values"
        return 0
    fi

    echo ""
    echo "🔧 Setting up Git configuration..."
    echo ""

    # Get user input
    read -p "Enter your full name for Git commits: " git_name
    read -p "Enter your email for Git commits: " git_email

    # Validate inputs
    if [ -z "$git_name" ] || [ -z "$git_email" ]; then
        log_with_level "ERROR" "Name and email are required for Git configuration"
        return 1
    fi

    # Create personalized git config
    sed -e "s/YOUR_NAME_HERE/$git_name/g" \
        -e "s/YOUR_EMAIL_HERE/$git_email/g" \
        "$git_template" > "$git_config"

    log_with_level "SUCCESS" "Git configuration created successfully"
    return 0
}

# Interactive user preferences setup
setup_user_preferences() {
    echo ""
    echo "🎯 Configure your development environment preferences:"
    echo ""

    # Ask about iOS development
    read -p "Install iOS development tools (xcodes, ios-deploy, swift tools)? [Y/n]: " install_ios
    install_ios=${install_ios:-Y}

    # Ask about data science tools
    read -p "Install data science tools (jupyter, pandas, numpy)? [y/N]: " install_datascience
    install_datascience=${install_datascience:-N}

    # Ask about additional development tools
    read -p "Install additional development tools (docker, kubernetes tools)? [Y/n]: " install_devtools
    install_devtools=${install_devtools:-Y}

    # Store preferences
    local prefs_file="$HOME/.supercharged_preferences"
    cat > "$prefs_file" << EOF
# Supercharged Setup Preferences
INSTALL_IOS_TOOLS=${install_ios}
INSTALL_DATA_SCIENCE=${install_datascience}
INSTALL_DEV_TOOLS=${install_devtools}
SETUP_DATE=$(date)
EOF

    log_with_level "SUCCESS" "User preferences saved to $prefs_file"

    # Export variables for current session
    export INSTALL_IOS_TOOLS="$install_ios"
    export INSTALL_DATA_SCIENCE="$install_datascience"
    export INSTALL_DEV_TOOLS="$install_devtools"
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
                version=$($tool --version 2>&1 | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "not installed")
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
    validate_tool "htop" "" || echo "" > /dev/null

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
