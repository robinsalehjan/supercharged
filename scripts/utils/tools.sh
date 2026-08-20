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
    local dry_run=false
    [ "${1:-}" = "--dry-run" ] && dry_run=true
    if ! command_exists pipx; then
        log_with_level "WARN" "pipx not installed, skipping code-review-graph"
        return 0
    fi

    local manifest="${MANAGED_TOOLS_MANIFEST:-$UTILS_PROJECT_ROOT/agent_config/managed_tools.json}"
    local managed_version package extras managed_spec installed_version=""
    managed_version=$(jq -er '.tools["code-review-graph"].version' "$manifest" 2>/dev/null) || managed_version=""
    package=$(jq -er '.tools["code-review-graph"].package' "$manifest" 2>/dev/null) || package=""
    extras=$(jq -er '.tools["code-review-graph"].extras | join(",")' "$manifest" 2>/dev/null) || extras=""
    if [[ ! "$managed_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || \
       [ "$package" != "code-review-graph" ] || [ -z "$extras" ]; then
        log_with_level "ERROR" "Invalid code-review-graph pin in $manifest"
        return 1
    fi
    managed_spec="${package}[${extras}]==${managed_version}"

    if command_exists code-review-graph; then
        installed_version=$(code-review-graph --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1) || installed_version=""
    fi

    if [ "$installed_version" != "$managed_version" ]; then
        if $dry_run; then
            log_with_level "INFO" "Would install managed code-review-graph $managed_version"
            return 0
        fi
        log_with_level "INFO" "Installing managed code-review-graph $managed_version..."
        if pipx install --force "$managed_spec" >/dev/null 2>&1; then
            log_with_level "SUCCESS" "code-review-graph $managed_version installed"
        else
            log_with_level "ERROR" "Failed to install managed code-review-graph $managed_version via pipx"
            return 1
        fi
    fi

    if $dry_run; then
        log_with_level "INFO" "code-review-graph $managed_version matches the managed pin"
        return 0
    fi

    if command_exists code-review-graph; then
        log_with_level "INFO" "Checking code-review-graph extras..."

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
# An opt-in local watcher config can discover nested Git repositories, register
# and build them, then add an independent watcher for each one.
# Reloads automatically when the registry or watcher config changes.
setup_crg_watcher() {
    if ! command_exists code-review-graph; then
        log_with_level "INFO" "code-review-graph not installed, skipping watcher setup"
        return 0
    fi

    local script_path="$HOME/.local/bin/crg-watch-all.sh"
    local plist_path="$HOME/Library/LaunchAgents/com.code-review-graph.watcher.plist"
    local discovery_config_path="$HOME/.code-review-graph/watcher-config.json"
    local script_tmp plist_tmp discovery_config_tmp
    script_tmp=$(mktemp)
    plist_tmp=$(mktemp)
    discovery_config_tmp=$(mktemp)

    mkdir -p "$HOME/.local/bin" "$HOME/Library/LaunchAgents" "$HOME/.code-review-graph"

    if [ ! -f "$discovery_config_path" ]; then
        cat > "$discovery_config_tmp" <<'DISCOVERY_CONFIG_EOF'
{
  "discovery_roots": []
}
DISCOVERY_CONFIG_EOF
        mv "$discovery_config_tmp" "$discovery_config_path"
        log_with_level "INFO" "Created code-review-graph watcher config at $discovery_config_path"
    else
        rm -f "$discovery_config_tmp"
    fi

    cat > "$script_tmp" <<'WATCHER_EOF'
#!/usr/bin/env zsh
# crg-watch-all.sh — Run `code-review-graph watch` for registered repositories.
# Optional discovery roots automatically register, build, and watch nested Git
# repositories with .git directories. Linked worktrees use .git files and are
# intentionally excluded to avoid duplicate graphs.

set -u
emulate -L zsh

REGISTRY="${HOME}/.code-review-graph/registry.json"
DISCOVERY_CONFIG="${CRG_WATCHER_CONFIG:-${HOME}/.code-review-graph/watcher-config.json}"
CRG="${CRG_BIN:-$(command -v code-review-graph)}"
INTERVAL="${CRG_WATCH_INTERVAL:-30}"
DISCOVERY_INTERVAL="${CRG_DISCOVERY_INTERVAL:-300}"

[[ "$INTERVAL" == <-> ]] && (( INTERVAL > 0 )) || INTERVAL=30
[[ "$DISCOVERY_INTERVAL" == <-> ]] && (( DISCOVERY_INTERVAL > 0 )) || DISCOVERY_INTERVAL=300

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

canonical_path() {
    local candidate="$1"
    (cd "$candidate" 2>/dev/null && pwd -P)
}

file_mtime() {
    [[ -e "$1" ]] && stat -f %m "$1" || print 0
}

typeset -a paths pids
typeset -A registered_paths watched_paths
new_discoveries=false

add_watch_path() {
    local candidate="$1" canonical
    [[ -d "$candidate" ]] || { print -u2 "skip missing: $candidate"; return; }
    canonical=$(canonical_path "$candidate") || { print -u2 "skip unreadable: $candidate"; return; }
    [[ -n "${watched_paths[$canonical]:-}" ]] && return
    paths+=("$canonical")
    watched_paths[$canonical]=1
}

while IFS= read -r repo_path; do
    [[ -n "$repo_path" ]] || continue
    canonical=$(canonical_path "$repo_path") || continue
    registered_paths[$canonical]=1
    add_watch_path "$canonical"
done < <(jq -r '.repos[]?.path // empty' "$REGISTRY" 2>/dev/null)

if (( ${#paths} == 0 )); then
    print -u2 "No registered repos"
    sleep 60
    exit 0
fi

discover_nested_repositories() {
    [[ -f "$DISCOVERY_CONFIG" ]] || return 0

    local discovery_root max_depth git_dir candidate canonical
    while IFS=$'\t' read -r discovery_root max_depth; do
        [[ -d "$discovery_root" ]] || {
            print -u2 "skip missing discovery root: $discovery_root"
            continue
        }

        discovery_root=$(canonical_path "$discovery_root") || continue
        if [[ -z "${registered_paths[$discovery_root]:-}" ]]; then
            print -u2 "skip unregistered discovery root: $discovery_root"
            continue
        fi

        while IFS= read -r git_dir; do
            candidate="${git_dir:h}"
            canonical=$(canonical_path "$candidate") || continue
            [[ "$canonical" == "$discovery_root" ]] && continue

            if [[ -z "${registered_paths[$canonical]:-}" ]]; then
                print -u2 "registering nested repo: $canonical"
                if ! "$CRG" register "$canonical"; then
                    print -u2 "failed to register nested repo: $canonical"
                    continue
                fi
                if ! "$CRG" build --repo "$canonical"; then
                    print -u2 "failed to build nested repo: $canonical"
                    continue
                fi
                registered_paths[$canonical]=1
                new_discoveries=true
            fi

            add_watch_path "$canonical"
        done < <(find "$discovery_root" -mindepth 2 -maxdepth "$((max_depth + 1))" \
            -type d -name .git -prune -print 2>/dev/null)
    done < <(jq -r '
        (.discovery_roots // [])[]?
        | select(type == "object")
        | .path as $path
        | (.max_depth // 4) as $depth
        | select(($path | type) == "string")
        | select(($depth | type) == "number")
        | select($depth >= 1 and $depth <= 10 and ($depth | floor) == $depth)
        | [$path, $depth] | @tsv
    ' "$DISCOVERY_CONFIG" 2>/dev/null)
}

discover_nested_repositories

for p in "${paths[@]}"; do
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

registry_mtime=$(file_mtime "$REGISTRY")
config_mtime=$(file_mtime "$DISCOVERY_CONFIG")
discovery_elapsed=0
while sleep "$INTERVAL"; do
    new_registry_mtime=$(file_mtime "$REGISTRY")
    new_config_mtime=$(file_mtime "$DISCOVERY_CONFIG")
    if [[ "$new_registry_mtime" != "$registry_mtime" || "$new_config_mtime" != "$config_mtime" ]]; then
        print -u2 "registry or watcher config changed — exiting for reload"
        exit 0
    fi

    discovery_elapsed=$((discovery_elapsed + INTERVAL))
    if (( discovery_elapsed >= DISCOVERY_INTERVAL )); then
        new_discoveries=false
        discover_nested_repositories
        if $new_discoveries; then
            print -u2 "nested repositories discovered — exiting for reload"
            exit 0
        fi
        discovery_elapsed=0
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
        <string>/opt/homebrew/bin:/usr/local/bin:${HOME}/.local/bin:/usr/bin:/bin</string>
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
        log_with_level "INFO" "Add registered parent roots to $discovery_config_path to auto-index nested repos"
    else
        log_with_level "WARN" "launchctl load failed for code-review-graph watcher"
    fi
}

# Setup Plannotator (Visual annotation tool for AI coding agents)
setup_plannotator() {
    local dry_run=false
    if [ "${1:-}" = "--dry-run" ]; then
        dry_run=true
    fi

    local manifest="${PLANNOTATOR_MANIFEST:-$UTILS_PROJECT_ROOT/agent_config/managed_tools.json}"
    local install_dir="${PLANNOTATOR_INSTALL_DIR:-$HOME/.local/bin}"
    local install_path="$install_dir/plannotator"
    local arch_uname="${PLANNOTATOR_ARCH:-$(uname -m)}"
    local asset_key

    if ! command_exists jq; then
        log_with_level "ERROR" "jq is required to read the managed Plannotator version"
        return 1
    fi

    if [ ! -f "$manifest" ]; then
        log_with_level "ERROR" "Managed tool manifest not found: $manifest"
        return 1
    fi

    if [[ "$arch_uname" == "arm64" ]] || [[ "$arch_uname" == "aarch64" ]]; then
        asset_key="darwin-arm64"
    elif [[ "$arch_uname" == "x86_64" ]]; then
        asset_key="darwin-x64"
    else
        log_with_level "WARN" "Unsupported architecture for Plannotator: $arch_uname — skipping"
        return 0
    fi

    local version repository binary_name expected_sha
    version=$(jq -er '.tools.plannotator.version' "$manifest" 2>/dev/null) || version=""
    repository=$(jq -er '.tools.plannotator.repository' "$manifest" 2>/dev/null) || repository=""
    binary_name=$(jq -er --arg asset "$asset_key" '.tools.plannotator.assets[$asset].name' "$manifest" 2>/dev/null) || binary_name=""
    expected_sha=$(jq -er --arg asset "$asset_key" '.tools.plannotator.assets[$asset].sha256' "$manifest" 2>/dev/null) || expected_sha=""

    if [ -z "$version" ] || [ -z "$repository" ] || [ -z "$binary_name" ] || \
       [[ ! "$expected_sha" =~ ^[0-9a-f]{64}$ ]]; then
        log_with_level "ERROR" "Invalid Plannotator entry in $manifest"
        return 1
    fi

    local installed_sha=""
    if [ -f "$install_path" ]; then
        installed_sha=$(shasum -a 256 "$install_path" 2>/dev/null | awk '{print $1}') || installed_sha=""
    fi

    if [ "$installed_sha" = "$expected_sha" ] && [ -x "$install_path" ]; then
        log_with_level "INFO" "Plannotator $version already installed"
        return 0
    fi

    if $dry_run; then
        if [ -e "$install_path" ]; then
            log_with_level "INFO" "Would update Plannotator to $version"
        else
            log_with_level "INFO" "Would install Plannotator $version"
        fi
        return 0
    fi

    local action="Installing"
    [ -e "$install_path" ] && action="Updating"
    log_with_level "INFO" "$action Plannotator to managed version $version..."

    if ! mkdir -p "$install_dir"; then
        log_with_level "ERROR" "Failed to create Plannotator install directory: $install_dir"
        return 1
    fi

    local binary_url="https://github.com/${repository}/releases/download/${version}/${binary_name}"
    local tmp_dir
    if ! tmp_dir=$(mktemp -d "$install_dir/.plannotator.XXXXXX"); then
        log_with_level "ERROR" "Failed to create a temporary Plannotator install directory"
        return 1
    fi
    _plannotator_cleanup() { rm -rf "$tmp_dir"; }

    local curl_err
    if ! curl_err=$(curl -fsSL -o "$tmp_dir/${binary_name}" "$binary_url" 2>&1); then
        log_with_level "ERROR" "Failed to download plannotator binary ($binary_url): $curl_err"
        _plannotator_cleanup
        return 1
    fi

    local downloaded_sha
    downloaded_sha=$(shasum -a 256 "$tmp_dir/${binary_name}" 2>/dev/null | awk '{print $1}') || downloaded_sha=""
    if [ "$downloaded_sha" != "$expected_sha" ]; then
        log_with_level "ERROR" "Plannotator checksum verification failed (expected $expected_sha, found ${downloaded_sha:-unavailable})"
        _plannotator_cleanup
        return 1
    fi

    # The temporary file lives beside the destination, so the final rename is
    # atomic and a download/verification failure leaves the old binary intact.
    if ! chmod +x "$tmp_dir/${binary_name}" || \
       ! mv "$tmp_dir/${binary_name}" "$install_path"; then
        log_with_level "ERROR" "Failed to install plannotator binary to $install_path"
        _plannotator_cleanup
        return 1
    fi

    _plannotator_cleanup
    log_with_level "SUCCESS" "Plannotator $version installed successfully"
}

# Setup XcodeBuildMCP from an exact, checksummed upstream release archive.
setup_xcodebuildmcp() {
    local dry_run=false
    [ "${1:-}" = "--dry-run" ] && dry_run=true

    local manifest="${MANAGED_TOOLS_MANIFEST:-$UTILS_PROJECT_ROOT/agent_config/managed_tools.json}"
    local install_root="${XCODEBUILDMCP_INSTALL_ROOT:-$HOME/.local/share/supercharged/xcodebuildmcp}"
    local bin_dir="${XCODEBUILDMCP_BIN_DIR:-$HOME/.local/bin}"
    local arch_uname="${XCODEBUILDMCP_ARCH:-$(uname -m)}" asset_key
    case "$arch_uname" in
        arm64|aarch64) asset_key="darwin-arm64" ;;
        x86_64) asset_key="darwin-x64" ;;
        *)
            log_with_level "WARN" "Unsupported architecture for XcodeBuildMCP: $arch_uname — skipping"
            return 0
            ;;
    esac

    local version repository asset_name expected_sha installed_version="" installed_sha=""
    version=$(jq -er '.tools.xcodebuildmcp.version' "$manifest" 2>/dev/null) || version=""
    repository=$(jq -er '.tools.xcodebuildmcp.repository' "$manifest" 2>/dev/null) || repository=""
    asset_name=$(jq -er --arg asset "$asset_key" '.tools.xcodebuildmcp.assets[$asset].name' "$manifest" 2>/dev/null) || asset_name=""
    expected_sha=$(jq -er --arg asset "$asset_key" '.tools.xcodebuildmcp.assets[$asset].sha256' "$manifest" 2>/dev/null) || expected_sha=""
    if [[ ! "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || [ -z "$repository" ] || \
       [ -z "$asset_name" ] || [[ ! "$expected_sha" =~ ^[0-9a-f]{64}$ ]]; then
        log_with_level "ERROR" "Invalid XcodeBuildMCP pin in $manifest"
        return 1
    fi

    if [ -x "$bin_dir/xcodebuildmcp" ]; then
        installed_version=$("$bin_dir/xcodebuildmcp" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1) || installed_version=""
    fi
    installed_sha=$(cat "$install_root/.active-archive-sha256" 2>/dev/null || true)
    if [ "$installed_version" = "${version#v}" ] && [ "$installed_sha" = "$expected_sha" ]; then
        if ! $dry_run && [ "${XCODEBUILDMCP_SKIP_BREW_CLEANUP:-0}" != "1" ] && \
           command_exists brew && brew list --formula xcodebuildmcp >/dev/null 2>&1; then
            log_with_level "INFO" "Removing the superseded Homebrew XcodeBuildMCP installation"
            brew uninstall xcodebuildmcp >/dev/null 2>&1 || brew unlink xcodebuildmcp >/dev/null 2>&1 || true
        fi
        log_with_level "INFO" "XcodeBuildMCP $version already installed"
        return 0
    fi
    if $dry_run; then
        log_with_level "INFO" "Would install XcodeBuildMCP $version"
        return 0
    fi

    local target_dir="$install_root/${version}-${expected_sha[1,12]}" tmp_dir archive downloaded_sha
    mkdir -p "$install_root" "$bin_dir" || return 1
    tmp_dir=$(mktemp -d "$install_root/.xcodebuildmcp.XXXXXX") || return 1
    archive="$tmp_dir/$asset_name"
    _xcodebuildmcp_cleanup() { rm -rf "$tmp_dir"; }

    if ! curl -fsSL "https://github.com/$repository/releases/download/$version/$asset_name" -o "$archive"; then
        log_with_level "ERROR" "Failed to download XcodeBuildMCP $version"
        _xcodebuildmcp_cleanup
        return 1
    fi
    downloaded_sha=$(shasum -a 256 "$archive" 2>/dev/null | awk '{print $1}') || downloaded_sha=""
    if [ "$downloaded_sha" != "$expected_sha" ]; then
        log_with_level "ERROR" "XcodeBuildMCP checksum verification failed"
        _xcodebuildmcp_cleanup
        return 1
    fi
    mkdir -p "$tmp_dir/extracted"
    if ! tar -xzf "$archive" -C "$tmp_dir/extracted" --strip-components=1 || \
       [ ! -x "$tmp_dir/extracted/bin/xcodebuildmcp" ]; then
        log_with_level "ERROR" "XcodeBuildMCP archive is malformed"
        _xcodebuildmcp_cleanup
        return 1
    fi

    if [ -d "$target_dir" ] && \
       [ "$("$target_dir/bin/xcodebuildmcp" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)" != "${version#v}" ]; then
        target_dir="${target_dir}-${EPOCHSECONDS}"
    fi
    if [ ! -d "$target_dir" ]; then
        mv "$tmp_dir/extracted" "$target_dir" || {
            _xcodebuildmcp_cleanup
            return 1
        }
    fi
    ln -sfn "$target_dir/bin/xcodebuildmcp" "$bin_dir/xcodebuildmcp"
    ln -sfn "$target_dir/bin/xcodebuildmcp-doctor" "$bin_dir/xcodebuildmcp-doctor"
    printf '%s\n' "$expected_sha" > "$install_root/.active-archive-sha256"
    if [ "${XCODEBUILDMCP_SKIP_BREW_CLEANUP:-0}" != "1" ] && \
       command_exists brew && brew list --formula xcodebuildmcp >/dev/null 2>&1; then
        log_with_level "INFO" "Removing the superseded Homebrew XcodeBuildMCP installation"
        brew uninstall xcodebuildmcp >/dev/null 2>&1 || brew unlink xcodebuildmcp >/dev/null 2>&1 || true
    fi
    _xcodebuildmcp_cleanup
    log_with_level "SUCCESS" "XcodeBuildMCP $version installed"
}

# Setup Obscura (Rust-based headless browser for AI agents and web scraping)
setup_obscura() {
    local dry_run=false
    [ "${1:-}" = "--dry-run" ] && dry_run=true
    local manifest="${MANAGED_TOOLS_MANIFEST:-$UTILS_PROJECT_ROOT/agent_config/managed_tools.json}"
    local install_dir="${OBSCURA_INSTALL_DIR:-$HOME/.local/bin}"
    local arch_uname="${OBSCURA_ARCH:-$(uname -m)}" asset_key
    case "$arch_uname" in
        arm64|aarch64) asset_key="darwin-arm64" ;;
        x86_64) asset_key="darwin-x64" ;;
        *)
            log_with_level "WARN" "Unsupported architecture for Obscura: $arch_uname — skipping"
            return 0
            ;;
    esac

    local version repository asset_name expected_archive_sha expected_obscura_sha expected_worker_sha
    version=$(jq -er '.tools.obscura.version' "$manifest" 2>/dev/null) || version=""
    repository=$(jq -er '.tools.obscura.repository' "$manifest" 2>/dev/null) || repository=""
    asset_name=$(jq -er --arg asset "$asset_key" '.tools.obscura.assets[$asset].name' "$manifest" 2>/dev/null) || asset_name=""
    expected_archive_sha=$(jq -er --arg asset "$asset_key" '.tools.obscura.assets[$asset].sha256' "$manifest" 2>/dev/null) || expected_archive_sha=""
    expected_obscura_sha=$(jq -er --arg asset "$asset_key" '.tools.obscura.assets[$asset].binaries.obscura' "$manifest" 2>/dev/null) || expected_obscura_sha=""
    expected_worker_sha=$(jq -er --arg asset "$asset_key" '.tools.obscura.assets[$asset].binaries["obscura-worker"]' "$manifest" 2>/dev/null) || expected_worker_sha=""
    if [[ ! "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || [ -z "$repository" ] || \
       [ -z "$asset_name" ] || [[ ! "$expected_archive_sha" =~ ^[0-9a-f]{64}$ ]] || \
       [[ ! "$expected_obscura_sha" =~ ^[0-9a-f]{64}$ ]] || [[ ! "$expected_worker_sha" =~ ^[0-9a-f]{64}$ ]]; then
        log_with_level "ERROR" "Invalid Obscura pin in $manifest"
        return 1
    fi

    local installed_obscura_sha="" installed_worker_sha=""
    [ -f "$install_dir/obscura" ] && installed_obscura_sha=$(shasum -a 256 "$install_dir/obscura" | awk '{print $1}')
    [ -f "$install_dir/obscura-worker" ] && installed_worker_sha=$(shasum -a 256 "$install_dir/obscura-worker" | awk '{print $1}')
    if [ "$installed_obscura_sha" = "$expected_obscura_sha" ] && \
       [ "$installed_worker_sha" = "$expected_worker_sha" ] && \
       [ -x "$install_dir/obscura" ] && [ -x "$install_dir/obscura-worker" ]; then
        log_with_level "INFO" "Obscura $version already installed"
        return 0
    fi
    if $dry_run; then
        log_with_level "INFO" "Would install Obscura $version"
        return 0
    fi

    log_with_level "INFO" "Installing managed Obscura $version..."
    local tmp_dir
    mkdir -p "$install_dir" || return 1
    tmp_dir=$(mktemp -d "$install_dir/.obscura.XXXXXX") || return 1
    _obscura_cleanup() { rm -rf "$tmp_dir"; }

    local download_err
    if ! download_err=$(curl -fsSL \
            "https://github.com/$repository/releases/download/$version/$asset_name" \
            -o "$tmp_dir/$asset_name" 2>&1); then
        log_with_level "ERROR" "Failed to download $asset_name from $repository: $download_err"
        _obscura_cleanup
        return 1
    fi

    local downloaded_archive_sha
    downloaded_archive_sha=$(shasum -a 256 "$tmp_dir/$asset_name" | awk '{print $1}') || downloaded_archive_sha=""
    if [ "$downloaded_archive_sha" != "$expected_archive_sha" ]; then
        log_with_level "ERROR" "Obscura archive checksum verification failed"
        _obscura_cleanup
        return 1
    fi

    local tar_err
    if ! tar_err=$(tar -xzf "$tmp_dir/$asset_name" -C "$tmp_dir" 2>&1); then
        log_with_level "ERROR" "Failed to extract Obscura archive: $tar_err"
        _obscura_cleanup
        return 1
    fi

    local obscura_bin worker_bin
    obscura_bin=$(find "$tmp_dir" -type f -name obscura -perm -u+x 2>/dev/null | head -1)
    worker_bin=$(find "$tmp_dir" -type f -name obscura-worker -perm -u+x 2>/dev/null | head -1)
    if [ -z "$obscura_bin" ] || [ -z "$worker_bin" ]; then
        log_with_level "ERROR" "Obscura archive missing expected binaries (obscura, obscura-worker)"
        _obscura_cleanup
        return 1
    fi

    local obscura_sha worker_sha
    obscura_sha=$(shasum -a 256 "$obscura_bin" | awk '{print $1}')
    worker_sha=$(shasum -a 256 "$worker_bin" | awk '{print $1}')
    if [ "$obscura_sha" != "$expected_obscura_sha" ] || [ "$worker_sha" != "$expected_worker_sha" ]; then
        log_with_level "ERROR" "Obscura binary checksum verification failed"
        _obscura_cleanup
        return 1
    fi

    if ! chmod +x "$obscura_bin" "$worker_bin" || \
       ! mv "$obscura_bin" "$install_dir/obscura" || \
       ! mv "$worker_bin" "$install_dir/obscura-worker"; then
        log_with_level "ERROR" "Failed to install Obscura binaries to $install_dir"
        _obscura_cleanup
        return 1
    fi

    _obscura_cleanup
    log_with_level "SUCCESS" "Obscura $version installed to $install_dir"
    log_with_level "INFO" "Test with: obscura fetch https://example.com --eval 'document.title'"
}

# Setup Claude Code Statusline (Enhanced terminal statusline)
setup_statusline() {
    local dry_run=false
    [ "${1:-}" = "--dry-run" ] && dry_run=true
    local manifest="${MANAGED_TOOLS_MANIFEST:-$UTILS_PROJECT_ROOT/agent_config/managed_tools.json}"
    local install_dir="$HOME/.claude/statusline"
    local marker="$install_dir/.supercharged-source-ref"
    local repository commit installer
    repository=$(jq -er '.tools["claude-statusline"].repository' "$manifest" 2>/dev/null) || repository=""
    commit=$(jq -er '.tools["claude-statusline"].commit' "$manifest" 2>/dev/null) || commit=""
    installer=$(jq -er '.tools["claude-statusline"].installer' "$manifest" 2>/dev/null) || installer=""
    if [ -z "$repository" ] || [[ ! "$commit" =~ ^[0-9a-f]{40}$ ]] || [ -z "$installer" ]; then
        log_with_level "ERROR" "Invalid Claude statusline pin in $manifest"
        return 1
    fi

    if [ -f "$install_dir/statusline.sh" ] && [ -d "$install_dir/lib" ] && \
       [ "$(cat "$marker" 2>/dev/null)" = "$commit" ]; then
        log_with_level "INFO" "Claude Code statusline already at managed commit ${commit[1,12]}"
        return 0
    fi

    if $dry_run; then
        log_with_level "INFO" "Would install Claude Code statusline commit ${commit[1,12]}"
        return 0
    fi

    log_with_level "INFO" "Installing Claude Code enhanced statusline..."

    # Backup existing Config.toml if present (preserve user customizations)
    local config_backup=""
    if [ -f "$install_dir/Config.toml" ]; then
        config_backup=$(mktemp)
        cp "$install_dir/Config.toml" "$config_backup"
        log_with_level "INFO" "Preserved existing Config.toml"
    fi

    # Download and run the installer
    local installer_url="https://raw.githubusercontent.com/${repository}/${commit}/${installer}"
    local tmp_installer
    tmp_installer=$(mktemp)

    if ! curl -fsSL "$installer_url" -o "$tmp_installer"; then
        log_with_level "ERROR" "Failed to download statusline installer"
        rm -f "$tmp_installer"
        [ -n "$config_backup" ] && rm -f "$config_backup"
        return 1
    fi

    # Run the installer
    if CLAUDE_INSTALL_BRANCH="$commit" bash "$tmp_installer" >/dev/null 2>&1; then
        # Restore backed up config if it existed
        if [ -n "$config_backup" ] && [ -f "$config_backup" ]; then
            cp "$config_backup" "$install_dir/Config.toml"
            log_with_level "INFO" "Restored preserved Config.toml"
            rm -f "$config_backup"
        fi

        printf '%s\n' "$commit" > "$marker"
        log_with_level "SUCCESS" "Claude Code statusline installed at commit ${commit[1,12]}"
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
