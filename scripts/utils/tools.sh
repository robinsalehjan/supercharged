#!/bin/zsh

# ZSH plugin installation
install_zsh_plugin() {
    local repo=$1
    local dest=$2
    if [ -d "$dest" ]; then
        echo "Plugin already installed at $dest"
    else
        git clone "$repo" "$dest" || {
            log_with_level "ERROR" "Failed to clone $repo"
            return 1
        }
    fi
}

# Function to safely install asdf plugins
install_asdf_plugin() {
    local plugin=$1
    if ! asdf plugin list | grep -q "^${plugin}$"; then
        fancy_echo "asdf: adding $plugin plugin"
        asdf plugin add "$plugin" || {
            log_with_level "WARN" "Failed to add $plugin plugin"
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

    if ! asdf set --home "$plugin" "$version"; then
        log_with_level "ERROR" "Failed to set $plugin $version as global default"
        return 1
    fi
    log_with_level "SUCCESS" "asdf: $plugin set to version $version"
}

# Setup RTK (Rust Token Killer) for Claude Code
setup_rtk() {
    if ! command_exists rtk; then
        log_with_level "WARN" "RTK not installed, skipping configuration"
        return 0
    fi

    # Skip if already configured (hook file exists)
    if [ -f "$HOME/.claude/hooks/rtk-rewrite.sh" ]; then
        log_with_level "INFO" "RTK already configured, skipping"
        return 0
    fi

    log_with_level "INFO" "Configuring RTK (Rust Token Killer) for Claude Code..."

    # Run rtk init with auto-patch to configure hooks
    local rtk_output
    if rtk_output=$(rtk init -g --auto-patch 2>&1); then
        log_with_level "SUCCESS" "RTK configured successfully"
        log_with_level "INFO" "RTK will automatically optimize git commands to save 60-90% tokens"
    else
        log_with_level "WARN" "RTK configuration failed: $rtk_output"
    fi
}

# Setup Dippy (Permission automation for Claude Code)
setup_dippy() {
    if command_exists dippy; then
        log_with_level "INFO" "Dippy already installed"
        return 0
    fi

    log_with_level "INFO" "Installing Dippy (permission automation)..."

    # Check if Homebrew is available
    if ! command_exists brew; then
        log_with_level "ERROR" "Homebrew not found, cannot install Dippy"
        return 1
    fi

    # Add Dippy tap and install
    local tap_output
    if tap_output=$(brew tap ldayton/dippy 2>&1); then
        log_with_level "INFO" "Added ldayton/dippy tap"
    elif echo "$tap_output" | grep -qi "already tapped"; then
        log_with_level "INFO" "Dippy tap already added"
    else
        log_with_level "ERROR" "Failed to add Dippy tap: $tap_output"
        return 1
    fi

    if brew install dippy >/dev/null 2>&1; then
        log_with_level "SUCCESS" "Dippy installed successfully via Homebrew"
    else
        log_with_level "ERROR" "Failed to install Dippy via Homebrew"
        return 1
    fi

    log_with_level "INFO" "Dippy will auto-approve safe commands (ls, git status, cat) while blocking destructive operations"
    log_with_level "INFO" "Configure Dippy hook in ~/.claude/settings.json to enable it"
}

# Setup code-review-graph (AI-optimized code context via knowledge graph)
setup_code_review_graph() {
    if ! command_exists pipx; then
        log_with_level "WARN" "pipx not installed, skipping code-review-graph"
        return 0
    fi

    if command_exists code-review-graph; then
        log_with_level "INFO" "code-review-graph already installed, ensuring Claude Code integration..."
    else
        log_with_level "INFO" "Installing code-review-graph (AI-optimized code context)..."
        if pipx install code-review-graph >/dev/null 2>&1; then
            log_with_level "SUCCESS" "code-review-graph installed successfully"
        else
            log_with_level "ERROR" "Failed to install code-review-graph via pipx"
            return 1
        fi
    fi

    # Skip Claude Code integration if already configured
    if [ -f "$HOME/.claude/.mcp.json" ] && grep -q "code-review-graph" "$HOME/.claude/.mcp.json" 2>/dev/null; then
        log_with_level "INFO" "code-review-graph already configured for Claude Code"
        return 0
    fi

    # Configure for Claude Code (idempotency already handled above, so failure here is real)
    local crg_output
    if crg_output=$(code-review-graph install --platform claude-code 2>&1); then
        log_with_level "SUCCESS" "code-review-graph configured for Claude Code"
    else
        log_with_level "WARN" "code-review-graph Claude Code configuration failed: $crg_output"
    fi

    log_with_level "INFO" "code-review-graph builds a knowledge graph of your codebase to reduce AI token usage by ~8x"
    log_with_level "INFO" "Run 'code-review-graph build' in a repo to index it"
}

# Setup Plannotator (Visual annotation tool for AI coding agents)
setup_plannotator() {
    if command_exists plannotator; then
        log_with_level "INFO" "Plannotator already installed"
        return 0
    fi

    log_with_level "INFO" "Installing Plannotator..."

    # Detect architecture
    local arch
    arch=$(uname -m)
    if [[ "$arch" == "arm64" ]] || [[ "$arch" == "aarch64" ]]; then
        arch="arm64"
    elif [[ "$arch" == "x86_64" ]]; then
        arch="x64"
    else
        log_with_level "ERROR" "Unsupported architecture: $arch"
        return 1
    fi

    # Fetch latest version via GitHub API
    local version
    if command_exists gh; then
        version=$(gh api repos/backnotprop/plannotator/releases/latest --jq '.tag_name' 2>/dev/null)
    fi

    if [ -z "$version" ]; then
        log_with_level "WARN" "Could not fetch latest version via gh CLI, trying curl..."
        version=$(curl -fsSL https://api.github.com/repos/backnotprop/plannotator/releases/latest | grep -o '"tag_name": *"[^"]*"' | sed 's/"tag_name": *"\(.*\)"/\1/' 2>/dev/null)
    fi

    if [ -z "$version" ]; then
        log_with_level "ERROR" "Failed to determine latest plannotator version"
        return 1
    fi

    log_with_level "INFO" "Latest plannotator version: $version"

    # Download binary and checksum
    local binary_name="plannotator-darwin-${arch}"
    local binary_url="https://github.com/backnotprop/plannotator/releases/download/${version}/${binary_name}"
    local checksum_url="${binary_url}.sha256"
    local tmp_dir
    tmp_dir=$(mktemp -d)

    if ! curl -fsSL -o "$tmp_dir/${binary_name}" "$binary_url"; then
        log_with_level "ERROR" "Failed to download plannotator binary"
        rm -rf "$tmp_dir"
        return 1
    fi

    if ! curl -fsSL -o "$tmp_dir/${binary_name}.sha256" "$checksum_url"; then
        log_with_level "ERROR" "Failed to download plannotator checksum"
        rm -rf "$tmp_dir"
        return 1
    fi

    # Verify checksum (checksum file references the original binary filename)
    if ! (cd "$tmp_dir" && shasum -a 256 -c "${binary_name}.sha256" >/dev/null 2>&1); then
        log_with_level "ERROR" "Plannotator checksum verification failed"
        rm -rf "$tmp_dir"
        return 1
    fi

    # Install to ~/.local/bin
    mkdir -p "$HOME/.local/bin"
    mv "$tmp_dir/${binary_name}" "$HOME/.local/bin/plannotator"
    chmod +x "$HOME/.local/bin/plannotator"
    rm -rf "$tmp_dir"

    log_with_level "SUCCESS" "Plannotator installed successfully"
    log_with_level "INFO" "Install the Claude Code plugin: /plugin marketplace add backnotprop/plannotator"
}

# Setup Claude Code Statusline (Enhanced terminal statusline)
setup_statusline() {
    # Check if statusline is already installed
    if [ -f "$HOME/.claude/statusline/statusline.sh" ] && [ -d "$HOME/.claude/statusline/lib" ]; then
        log_with_level "INFO" "Claude Code statusline already installed"
        return 0
    fi

    log_with_level "INFO" "Installing Claude Code enhanced statusline..."

    # Backup existing Config.toml if present (preserve user customizations)
    local config_backup=""
    if [ -f "$HOME/.claude/statusline/Config.toml" ]; then
        config_backup=$(mktemp)
        cp "$HOME/.claude/statusline/Config.toml" "$config_backup"
        log_with_level "INFO" "Preserved existing Config.toml"
    fi

    # Download and run the installer
    local installer_url="https://raw.githubusercontent.com/rz1989s/claude-code-statusline/main/install.sh"
    local tmp_installer
    tmp_installer=$(mktemp)

    if ! curl -fsSL "$installer_url" -o "$tmp_installer"; then
        log_with_level "ERROR" "Failed to download statusline installer"
        rm -f "$tmp_installer"
        [ -n "$config_backup" ] && rm -f "$config_backup"
        return 1
    fi

    # Run the installer
    if bash "$tmp_installer" >/dev/null 2>&1; then
        # Restore backed up config if it existed
        if [ -n "$config_backup" ] && [ -f "$config_backup" ]; then
            cp "$config_backup" "$HOME/.claude/statusline/Config.toml"
            log_with_level "INFO" "Restored preserved Config.toml"
            rm -f "$config_backup"
        fi

        log_with_level "SUCCESS" "Claude Code statusline installed successfully"
        log_with_level "INFO" "Statusline provides real-time metrics, cost tracking, and MCP monitoring"
        log_with_level "INFO" "Customize: ~/.claude/statusline/Config.toml"
    else
        log_with_level "ERROR" "Statusline installation failed"
        rm -f "$tmp_installer"
        [ -n "$config_backup" ] && rm -f "$config_backup"
        return 1
    fi

    rm -f "$tmp_installer"
}
