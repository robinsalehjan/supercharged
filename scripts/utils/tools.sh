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

# Resolve `latest` for an asdf plugin and install it (optionally filtered).
# Usage: install_asdf_latest <plugin> [filter]
#   filter is passed through to `asdf latest` (e.g. "openjdk" for the java plugin).
install_asdf_latest() {
    local plugin=$1
    local filter="${2:-}"
    local resolved
    if [ -n "$filter" ]; then
        resolved=$(asdf latest "$plugin" "$filter" 2>/dev/null || true)
    else
        resolved=$(asdf latest "$plugin" 2>/dev/null || true)
    fi
    if [ -z "$resolved" ]; then
        log_with_level "ERROR" "Failed to resolve latest version for $plugin${filter:+ (filter: $filter)}"
        return 1
    fi
    log_with_level "INFO" "asdf: latest $plugin${filter:+ ($filter)} → $resolved"
    install_asdf_version "$plugin" "$resolved"
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

# Setup Worktrunk (Git worktree manager for parallel AI agents)
setup_worktrunk() {
    if ! command_exists wt; then
        log_with_level "WARN" "Worktrunk not installed (wt command not found), skipping configuration"
        return 0
    fi

    # Skip if shell integration already configured
    if grep -q "wt config shell init" "$HOME/.zshrc" 2>/dev/null; then
        log_with_level "INFO" "Worktrunk shell integration already configured, skipping"
        return 0
    fi

    log_with_level "INFO" "Configuring Worktrunk shell integration..."

    local wt_output
    if wt_output=$(wt config shell install -y 2>&1); then
        log_with_level "SUCCESS" "Worktrunk shell integration installed (restart shell or run 'source ~/.zshrc')"
        log_with_level "INFO" "Use 'wt switch -c <branch>' to create worktrees, 'wt remove' or 'wt merge main' to clean up"
    else
        log_with_level "WARN" "Worktrunk shell configuration failed: $wt_output"
    fi
}

# Setup code-review-graph (AI-optimized code context via knowledge graph)
setup_code_review_graph() {
    if ! command_exists pipx; then
        log_with_level "WARN" "pipx not installed, skipping code-review-graph"
        return 0
    fi

    if command_exists code-review-graph; then
        log_with_level "INFO" "code-review-graph already installed, checking for extras..."

        # Check if extras are installed in the pipx venv (not system Python)
        local missing_extras=false
        if ! pipx runpip code-review-graph list 2>/dev/null | grep -q "sentence-transformers"; then
            log_with_level "INFO" "embeddings extra not found, will inject"
            missing_extras=true
        fi
        if ! pipx runpip code-review-graph list 2>/dev/null | grep -q "igraph"; then
            log_with_level "INFO" "communities extra not found, will inject"
            missing_extras=true
        fi

        if $missing_extras; then
            log_with_level "INFO" "Adding embeddings + communities extras to existing installation..."
            if pipx inject code-review-graph sentence-transformers igraph >/dev/null 2>&1; then
                log_with_level "SUCCESS" "code-review-graph extras added successfully"
            else
                log_with_level "WARN" "Failed to inject extras, continuing with base installation"
            fi
        else
            log_with_level "INFO" "code-review-graph extras already installed"
        fi
    else
        log_with_level "INFO" "Installing code-review-graph with embeddings + community detection..."
        if pipx install 'code-review-graph[embeddings,communities]' >/dev/null 2>&1; then
            log_with_level "SUCCESS" "code-review-graph installed successfully"
        else
            log_with_level "ERROR" "Failed to install code-review-graph via pipx"
            return 1
        fi
    fi

    # Per-repo MCP config (.mcp.json), hooks, skills, and .gitignore entries
    # are committed in this repo. Other repos use `crg-here` (register + build).
    # No `code-review-graph install` step is needed here — running it would
    # re-inject boilerplate into CLAUDE.md on every restore.
    log_with_level "INFO" "code-review-graph builds a knowledge graph of your codebase to reduce AI token usage by ~8x"
    log_with_level "INFO" "Run 'code-review-graph build' in a repo to index it (or 'crg-here' for register+build)"
}

# Setup the code-review-graph multi-repo watcher (launchd-managed).
# Orchestrates library primitives: reads ~/.code-review-graph/registry.json
# and runs `code-review-graph watch --repo <path>` for each registered repo.
# Reloads automatically when the registry changes.
setup_crg_watcher() {
    if ! command_exists code-review-graph; then
        log_with_level "INFO" "code-review-graph not installed, skipping watcher setup"
        return 0
    fi

    local script_path="$HOME/.local/bin/crg-watch-all.sh"
    local plist_path="$HOME/Library/LaunchAgents/com.code-review-graph.watcher.plist"
    local script_tmp plist_tmp
    script_tmp=$(mktemp)
    plist_tmp=$(mktemp)

    mkdir -p "$HOME/.local/bin" "$HOME/Library/LaunchAgents" "$HOME/.code-review-graph"

    cat > "$script_tmp" <<'WATCHER_EOF'
#!/usr/bin/env zsh
# crg-watch-all.sh — Run `code-review-graph watch` for every registered repo.
# Managed by launchd (com.code-review-graph.watcher). Exits on registry change
# so launchd restarts us with fresh state.

set -u
emulate -L zsh

REGISTRY="${HOME}/.code-review-graph/registry.json"
CRG="${CRG_BIN:-$(command -v code-review-graph)}"
INTERVAL="${CRG_WATCH_INTERVAL:-30}"

if [[ -z "$CRG" || ! -x "$CRG" ]]; then
    print -u2 "code-review-graph not on PATH"
    sleep 60
    exit 1
fi

if [[ ! -f "$REGISTRY" ]]; then
    print -u2 "No registry at $REGISTRY"
    sleep 60
    exit 0
fi

paths=( "${(@f)$(jq -r '.repos[].path' "$REGISTRY" 2>/dev/null)}" )
if (( ${#paths} == 0 )) || [[ -z "${paths[1]:-}" ]]; then
    print -u2 "No registered repos"
    sleep 60
    exit 0
fi

typeset -a pids
for p in "${paths[@]}"; do
    [[ -d "$p" ]] || { print -u2 "skip missing: $p"; continue; }
    "$CRG" watch --repo "$p" &
    pids+=($!)
    print -u2 "watching: $p (pid $!)"
done

if (( ${#pids} == 0 )); then
    sleep 60
    exit 0
fi

cleanup() {
    for pid in $pids; do kill "$pid" 2>/dev/null; done
    wait 2>/dev/null
}
trap cleanup EXIT INT TERM

mtime=$(stat -f %m "$REGISTRY")
while sleep "$INTERVAL"; do
    new=$(stat -f %m "$REGISTRY" 2>/dev/null)
    if [[ "$new" != "$mtime" ]]; then
        print -u2 "registry changed — exiting for reload"
        exit 0
    fi
done
WATCHER_EOF

    cat > "$plist_tmp" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.code-review-graph.watcher</string>
    <key>ProgramArguments</key>
    <array>
        <string>${script_path}</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:${HOME}/.local/bin:/usr/bin:/bin</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ThrottleInterval</key>
    <integer>30</integer>
    <key>StandardOutPath</key>
    <string>${HOME}/.code-review-graph/watcher.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/.code-review-graph/watcher.err</string>
</dict>
</plist>
PLIST_EOF

    if ! plutil -lint "$plist_tmp" >/dev/null 2>&1; then
        log_with_level "ERROR" "Generated launchd plist failed validation"
        rm -f "$script_tmp" "$plist_tmp"
        return 1
    fi

    # Only rewrite + reload if content actually changed, to avoid disrupting an
    # already-running watcher on every `npm run update` invocation.
    local changed=false
    if [ ! -f "$script_path" ] || ! cmp -s "$script_tmp" "$script_path"; then
        mv "$script_tmp" "$script_path"
        chmod +x "$script_path"
        changed=true
    else
        rm -f "$script_tmp"
    fi
    if [ ! -f "$plist_path" ] || ! cmp -s "$plist_tmp" "$plist_path"; then
        mv "$plist_tmp" "$plist_path"
        changed=true
    else
        rm -f "$plist_tmp"
    fi

    if ! $changed; then
        log_with_level "INFO" "code-review-graph watcher already up to date"
        return 0
    fi

    if [ "${SUPERCHARGED_SKIP_LAUNCHCTL:-0}" = "1" ]; then
        log_with_level "INFO" "SUPERCHARGED_SKIP_LAUNCHCTL=1 — skipping launchctl reload"
        return 0
    fi

    launchctl unload "$plist_path" 2>/dev/null || true
    if launchctl load "$plist_path" 2>/dev/null; then
        log_with_level "SUCCESS" "code-review-graph watcher loaded (com.code-review-graph.watcher)"
        log_with_level "INFO" "Use 'crg-here' inside a git repo to register + build"
    else
        log_with_level "WARN" "launchctl load failed for code-review-graph watcher"
    fi
}

# Setup Plannotator (Visual annotation tool for AI coding agents)
setup_plannotator() {
    # Path-based idempotency check — `command_exists` would miss a prior
    # install when ~/.local/bin isn't on PATH in the current shell (e.g.
    # non-interactive runs before .zshrc is sourced).
    if [ -x "$HOME/.local/bin/plannotator" ]; then
        log_with_level "INFO" "Plannotator already installed"
        return 0
    fi

    log_with_level "INFO" "Installing Plannotator..."

    local arch
    arch=$(uname -m)
    if [[ "$arch" == "arm64" ]] || [[ "$arch" == "aarch64" ]]; then
        arch="arm64"
    elif [[ "$arch" == "x86_64" ]]; then
        arch="x64"
    else
        # Plannotator is optional tooling; don't abort the larger setup pipeline
        # over an unsupported arch (matches setup_obscura's policy).
        log_with_level "WARN" "Unsupported architecture for Plannotator: $arch — skipping"
        return 0
    fi

    # Fetch latest version via GitHub API. gh failures are handled by the
    # curl fallback below (and stderr would just be noise here); if both
    # fail, the final "Failed to determine latest plannotator version"
    # error is the actionable line.
    local version=""
    if command_exists gh; then
        version=$(gh api repos/backnotprop/plannotator/releases/latest --jq '.tag_name' 2>/dev/null) || version=""
    fi

    if [ -z "$version" ]; then
        log_with_level "WARN" "Could not fetch latest version via gh CLI, trying curl..."
        version=$(curl -fsSL https://api.github.com/repos/backnotprop/plannotator/releases/latest 2>/dev/null \
            | grep -o '"tag_name": *"[^"]*"' \
            | sed 's/"tag_name": *"\(.*\)"/\1/')
    fi

    if [ -z "$version" ]; then
        log_with_level "ERROR" "Failed to determine latest plannotator version"
        return 1
    fi

    log_with_level "INFO" "Latest plannotator version: $version"

    local binary_name="plannotator-darwin-${arch}"
    local binary_url="https://github.com/backnotprop/plannotator/releases/download/${version}/${binary_name}"
    local checksum_url="${binary_url}.sha256"
    local tmp_dir
    tmp_dir=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -rf '$tmp_dir'" RETURN

    # Capture stderr to surface the actual failure reason (HTTP 404, DNS, etc.)
    local curl_err
    if ! curl_err=$(curl -fsSL -o "$tmp_dir/${binary_name}" "$binary_url" 2>&1); then
        log_with_level "ERROR" "Failed to download plannotator binary ($binary_url): $curl_err"
        return 1
    fi

    if ! curl_err=$(curl -fsSL -o "$tmp_dir/${binary_name}.sha256" "$checksum_url" 2>&1); then
        log_with_level "ERROR" "Failed to download plannotator checksum ($checksum_url): $curl_err"
        return 1
    fi

    # Verify checksum (checksum file references the original binary filename)
    local shasum_err
    if ! shasum_err=$(cd "$tmp_dir" && shasum -a 256 -c "${binary_name}.sha256" 2>&1); then
        log_with_level "ERROR" "Plannotator checksum verification failed: $shasum_err"
        return 1
    fi

    # Single guarded block — without this, a failed mv (cross-device, disk
    # full, permission denied) would silently log SUCCESS with no binary on
    # disk.
    if ! mkdir -p "$HOME/.local/bin" \
        || ! mv "$tmp_dir/${binary_name}" "$HOME/.local/bin/plannotator" \
        || ! chmod +x "$HOME/.local/bin/plannotator"; then
        log_with_level "ERROR" "Failed to install plannotator binary to ~/.local/bin"
        rm -f "$HOME/.local/bin/plannotator"
        return 1
    fi

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
