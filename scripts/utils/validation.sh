#!/bin/zsh

# Compare versions: returns 0 (true) if $1 >= $2
version_gte() {
    local version="$1"
    local min_version="$2"
    [ "$(printf '%s\n' "$min_version" "$version" | sort -V | head -n1)" = "$min_version" ]
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

    local version
    version=$(extract_tool_version "$cmd")

    if ! version_gte "$version" "$min_version"; then
        log_with_level "WARN" "$cmd version $min_version or higher recommended (found: $version)"
        return 1
    fi

    log_with_level "INFO" "$cmd version $version meets minimum requirement $min_version"
    return 0
}

# Extract version from a tool command
extract_tool_version() {
    local cmd=$1
    local version_output

    case "$cmd" in
        "kotlin")
            # Special case: strip "(JRE ...)" to avoid matching JRE version
            version_output=$(kotlin -version 2>&1 | head -1 || true)
            version_output="${version_output%%\(*}"
            echo "$version_output" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0"
            ;;
        "shellcheck")
            # Special case: version is in "version: X.Y.Z" format
            version_output=$(shellcheck --version 2>&1 || true)
            echo "$version_output" | grep -m1 'version:' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0"
            ;;
        "python"|"python3")
            # Use python3 explicitly for consistency
            python3 --version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0"
            ;;
        "rg")
            # ripgrep: version is on the first line as "ripgrep X.Y.Z"
            version_output=$(rg --version 2>&1 | head -1 || true)
            echo "$version_output" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0"
            ;;
        "tmux")
            # tmux uses -V and may have letter suffix (e.g., "tmux 3.6a")
            version_output=$(tmux -V 2>&1 || true)
            # Keep letter suffix as it's part of the version identifier
            echo "$version_output" | grep -oE '[0-9]+\.[0-9]+[a-z]?' || echo "0.0.0"
            ;;
        "nmap")
            # nmap: "Nmap version X.Y"
            version_output=$(nmap --version 2>&1 | head -1 || true)
            echo "$version_output" | grep -oE '[0-9]+\.[0-9]+' || echo "0.0.0"
            ;;
        "plannotator")
            # plannotator has no version flag - just check if executable
            echo "installed"
            ;;
        "xcodes")
            # xcodes uses `xcodes version` subcommand (rejects --version)
            xcodes version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "0.0.0"
            ;;
        "xcode-build-server")
            # No version flag at all - both --version and version print usage
            echo "installed"
            ;;
        "kubectl")
            # kubectl rejects --version; `version --client` avoids server ping
            kubectl version --client 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "0.0.0"
            ;;
        "obscura")
            # No version flag (clap rejects --version/-V/version subcommand)
            echo "installed"
            ;;
        "periphery")
            # Binary needs DEVELOPER_DIR to resolve its hardcoded
            # `/Applications/Xcode.app` rpath when Xcode is installed under
            # a versioned name (e.g. Xcode-26.4.1.app via `xcodes`). Setting
            # it from `xcode-select -p` lets `periphery version` run cleanly.
            DEVELOPER_DIR="$(xcode-select -p 2>/dev/null)" periphery version 2>&1 \
                | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "0.0.0"
            ;;
        *)
            # Default: try standard --version flag
            version_output=$($cmd --version 2>&1 | head -1 || true)
            echo "$version_output" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "0.0.0"
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
        { [[ "$tool" =~ ^# ]] || [[ -z "$tool" ]]; } && continue
        TOOL_VERSIONS[$tool]="$version"
    done < "$tool_versions_file"
}

# Check internet connectivity
require_internet() {
    if ! ping -c 1 -W 5 google.com >/dev/null 2>&1; then
        log_with_level "ERROR" "Internet connectivity required"
        return 1
    fi
    return 0
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Validation functions
validate_tool() {
    local tool=$1
    local expected_version=$2

    if command_exists "$tool"; then
        local version
        version=$(extract_tool_version "$tool")

        if [ "$version" = "installed" ]; then
            # Special case for tools without version flags
            echo "✅ $tool: installed"
            return 0
        elif [ -z "$version" ] || [ "$version" = "0.0.0" ]; then
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

# Return 0 if any file matching the given glob pattern exists in either the
# user or system font directory. `find` is used (instead of bash-only
# `compgen -G` or shell globbing) because this file is sourced from both
# bash and zsh, and the two shells handle non-matching globs differently.
_font_pattern_matches() {
    local pattern="$1"
    local hit
    hit="$(find "$HOME/Library/Fonts" "/Library/Fonts" -maxdepth 1 -name "$pattern" -print -quit 2>/dev/null)"
    [[ -n "$hit" ]]
}

# Check whether a font family is registered with macOS.
# Looks for .ttf/.otf files matching the given filename pattern in the standard
# user/system font directories. Faster and more deterministic than parsing
# `system_profiler SPFontsDataType` (which can take seconds).
validate_font() {
    local label="$1"          # human label, e.g. "JetBrainsMono Nerd Font"
    local pattern="$2"        # filename glob, e.g. "JetBrainsMono*Nerd*.ttf"

    if _font_pattern_matches "$pattern"; then
        echo "✅ font: $label"
        return 0
    else
        echo "❌ font: $label not registered (run 'npm run setup' or see README)"
        return 1
    fi
}

# Ensure a Homebrew font cask is actually registered with macOS.
# Some environments end up with the cask "installed" per `brew list --cask`
# but the .ttf files only staged in the Caskroom — never copied into
# ~/Library/Fonts. This function detects that mismatch and copies the staged
# fonts into the user font directory, where macOS auto-discovers them.
ensure_font_registered() {
    local cask="$1"           # e.g. "font-jetbrains-mono-nerd-font"
    local pattern="$2"        # e.g. "JetBrainsMono*Nerd*.ttf"

    # Skip silently if the cask isn't installed — `brew bundle` will handle it.
    if ! brew list --cask "$cask" >/dev/null 2>&1; then
        return 0
    fi

    # Already registered — nothing to do.
    if _font_pattern_matches "$pattern"; then
        return 0
    fi

    local caskroom
    caskroom="$(brew --prefix 2>/dev/null)/Caskroom/$cask"
    if [[ ! -d "$caskroom" ]]; then
        log_with_level "WARN" "Cask '$cask' marked installed but Caskroom missing; reinstall recommended"
        return 1
    fi

    # Pick the highest version directory present (sorts version-aware).
    local version_dir
    version_dir="$(find "$caskroom" -mindepth 1 -maxdepth 1 -type d ! -name '.metadata' \
        | sort -V | tail -n1)"
    if [[ -z "$version_dir" ]]; then
        log_with_level "WARN" "No staged fonts found in $caskroom"
        return 1
    fi

    mkdir -p "$HOME/Library/Fonts"
    # Use find to avoid glob expansion issues with shopt/extglob differences.
    # -L follows symlinks; -type f then matches both real files and symlinks
    # whose target exists. Dangling symlinks (a real-world failure mode where
    # the cask was installed once but ~/Library/Fonts was wiped) are skipped.
    local copied=0
    while IFS= read -r -d '' ttf; do
        cp -fL "$ttf" "$HOME/Library/Fonts/" && copied=$((copied + 1))
    done < <(find -L "$version_dir" -maxdepth 1 -type f \( -iname '*.ttf' -o -iname '*.otf' \) -print0 2>/dev/null)

    if [[ $copied -gt 0 ]]; then
        log_with_level "SUCCESS" "Registered $copied font file(s) from $cask into ~/Library/Fonts"
        return 0
    fi

    # Caskroom has nothing usable (e.g. only dangling symlinks pointing back at
    # ~/Library/Fonts that were since deleted). Re-run the cask install to
    # re-download and re-register the fonts.
    log_with_level "WARN" "Cask '$cask' has no usable font files; reinstalling..."
    if brew reinstall --cask "$cask" >/dev/null 2>&1; then
        copied=0
        while IFS= read -r -d '' ttf; do
            cp -fL "$ttf" "$HOME/Library/Fonts/" 2>/dev/null && copied=$((copied + 1))
        done < <(find -L "$version_dir" -maxdepth 1 -type f \( -iname '*.ttf' -o -iname '*.otf' \) -print0 2>/dev/null)

        # After a reinstall the fonts may already be in ~/Library/Fonts (cask
        # does that itself). Treat either success path as a win.
        if [[ $copied -gt 0 ]] || _font_pattern_matches "$pattern"; then
            log_with_level "SUCCESS" "Reinstalled and registered $cask"
            return 0
        fi
    fi

    log_with_level "WARN" "Could not register $cask; run 'brew reinstall --cask $cask' manually"
    return 1
}

validate_zsh_plugin() {
    local plugin_name=$1
    local plugin_path=$2

    if [ -d "$plugin_path" ]; then
        echo "✅ zsh plugin: $plugin_name"
        return 0
    else
        echo "❌ zsh plugin: $plugin_name not found at $plugin_path"
        return 1
    fi
}

validate_tmux_setup() {
    local label=$1

    if [ ! -f "$HOME/.tmux.conf" ]; then
        echo "❌ tmux: .tmux.conf not found"
        return 1
    fi

    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
        echo "❌ tmux: TPM (Tmux Plugin Manager) not installed"
        return 1
    fi

    echo "✅ tmux: configuration and TPM installed"
    return 0
}

validate_claude_component() {
    local component=$1
    local check_path=$2

    if [ -f "$check_path" ] || [ -d "$check_path" ]; then
        echo "✅ Claude Code: $component"
        return 0
    else
        echo "⚠️  Claude Code: $component not configured"
        return 1
    fi
}

validate_installation() {
    echo "🔍 Validating installation..."
    local failed=0
    local warned=0

    # Read versions from .tool-versions using helper function
    parse_tool_versions
    local python_version="${TOOL_VERSIONS[python]}"
    local ruby_version="${TOOL_VERSIONS[ruby]}"
    local node_version="${TOOL_VERSIONS[nodejs]}"
    local bundler_version="${TOOL_VERSIONS[bundler]}"
    local gcloud_version="${TOOL_VERSIONS[gcloud]}"
    local firebase_version="${TOOL_VERSIONS[firebase]}"
    # JVM toolchain — only used when INSTALL_JVM_TOOLS=Y.
    # When pinned in .tool-versions, validate against that; otherwise just check presence
    # (the install path resolves `asdf latest` so we don't know the target version up-front).
    # Strip "openjdk-" prefix from java pin → semver for `java --version` comparison.
    local java_pin="${TOOL_VERSIONS[java]:-}"
    local java_version="${java_pin#*-}"
    local kotlin_version="${TOOL_VERSIONS[kotlin]:-}"

    echo ""
    echo "Core Tools:"
    validate_tool "brew" "" || ((failed++))
    validate_tool "git" "" || ((failed++))
    validate_tool "asdf" "" || ((failed++))
    validate_tool "shellcheck" "" || ((failed++))
    validate_tool "gh" "" || ((warned++))  # GitHub CLI (optional but useful)

    echo ""
    echo "Development Tools:"
    validate_tool "jq" "" || ((warned++))
    validate_tool "tree" "" || ((warned++))
    validate_tool "rg" "" || ((warned++))  # ripgrep command is 'rg'
    validate_tool "tmux" "" || ((warned++))
    validate_tool "htop" "" || true  # Optional, don't count if missing
    validate_tool "btop" "" || true  # Optional, don't count if missing
    validate_tool "nmap" "" || ((warned++))
    validate_tool "aria2c" "" || ((warned++))
    validate_tool "duckdb" "" || ((warned++))
    validate_tool "sqlite3" "" || ((warned++))

    echo ""
    echo "AI & Optimization Tools:"
    validate_tool "rtk" "" || ((warned++))
    validate_tool "wt" "" || ((warned++))
    validate_tool "code-review-graph" "" || ((warned++))
    validate_tool "ollama" "" || true  # Optional local AI runtime
    validate_tool "pipx" "" || ((warned++))
    validate_tool "uv" "" || ((warned++))

    echo ""
    echo "Language Runtimes:"
    validate_tool "python3" "$python_version" || ((failed++))
    validate_tool "node" "$node_version" || ((failed++))
    validate_tool "ruby" "$ruby_version" || ((failed++))
    validate_tool "bundler" "$bundler_version" || ((failed++))

    # Check for optional categories if preference file indicates they should be installed
    if [ -f "$HOME/.supercharged_preferences" ]; then
        # shellcheck disable=SC1091
        source "$HOME/.supercharged_preferences"

        if [[ "${INSTALL_CLOUD_TOOLS:-Y}" =~ ^[Yy] ]]; then
            echo ""
            echo "Cloud & DevOps:"
            validate_tool "gcloud" "$gcloud_version" || ((failed++))
            validate_tool "firebase" "$firebase_version" || ((failed++))
        fi

        if [[ "${INSTALL_NETWORK_TOOLS:-Y}" =~ ^[Yy] ]]; then
            echo ""
            echo "Network Tools:"
            # The `wireshark` brew formula ships CLI tools (tshark, dumpcap)
            # but no `wireshark` binary on macOS — that's the separate cask.
            # Check tshark, which is the formula's primary entry point.
            validate_tool "tshark" "" || ((warned++))
            validate_tool "mitmproxy" "" || ((warned++))
            # Proxyman is a cask without a top-level CLI shim, so just check the .app exists
            if [ -d "/Applications/Proxyman.app" ]; then
                echo "✅ Proxyman installed"
            else
                echo "⚠️  Proxyman not installed"
                ((warned++))
            fi
        fi

        if [[ "${INSTALL_JVM_TOOLS:-N}" =~ ^[Yy] ]]; then
            echo ""
            echo "JVM Toolchain:"
            validate_tool "java" "$java_version" || ((failed++))
            validate_tool "kotlin" "$kotlin_version" || ((failed++))
        fi

        if [[ "${INSTALL_IOS_TOOLS:-Y}" =~ ^[Yy] ]]; then
            echo ""
            echo "iOS Development Tools:"
            validate_tool "xcodes" "" || ((warned++))
            validate_tool "xcode-build-server" "" || ((warned++))
            validate_tool "xcbeautify" "" || ((warned++))
            validate_tool "swiftlint" "" || ((warned++))
            validate_tool "swift-format" "" || ((warned++))
            validate_tool "swiftformat" "" || ((warned++))
            validate_tool "ios-deploy" "" || ((warned++))
            validate_tool "periphery" "" || ((warned++))
        fi

        if [[ "${INSTALL_DEV_TOOLS:-Y}" =~ ^[Yy] ]]; then
            echo ""
            echo "Container & Orchestration Tools:"
            validate_tool "docker" "" || ((warned++))
            validate_tool "docker-compose" "" || ((warned++))
            validate_tool "colima" "" || ((warned++))
            validate_tool "kubectl" "" || ((warned++))
        fi
    fi

    echo ""
    echo "Shell Configuration:"
    # Check for Oh My Zsh
    if [ -d "$HOME/.oh-my-zsh" ]; then
        echo "✅ Oh My Zsh installed"
    else
        echo "❌ Oh My Zsh not installed"
        ((failed++))
    fi

    # Check zsh plugins
    local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    validate_zsh_plugin "zsh-autosuggestions" "$zsh_custom/plugins/zsh-autosuggestions" || ((warned++))
    validate_zsh_plugin "zsh-syntax-highlighting" "$zsh_custom/plugins/zsh-syntax-highlighting" || ((warned++))
    validate_zsh_plugin "powerlevel10k" "$zsh_custom/themes/powerlevel10k" || ((warned++))

    # Check for Worktrunk shell integration
    if grep -q "wt config shell init" "$HOME/.zshrc" 2>/dev/null; then
        echo "✅ Worktrunk shell integration configured"
    else
        echo "⚠️  Worktrunk shell integration not configured"
        ((warned++))
    fi

    echo ""
    echo "Tmux Setup:"
    validate_tmux_setup "tmux" || ((warned++))

    echo ""
    echo "Fonts:"
    validate_font "JetBrainsMono Nerd Font" "JetBrainsMono*Nerd*.ttf" || ((failed++))

    # Check Claude Code components (all optional)
    if command_exists claude; then
        echo ""
        echo "Claude Code Components:"
        validate_claude_component "RTK hooks" "$HOME/.claude/hooks/rtk-rewrite.sh" || ((warned++))
        validate_claude_component "Statusline" "$HOME/.claude/statusline/statusline.sh" || ((warned++))
        validate_tool "plannotator" "" || ((warned++))
        validate_tool "obscura" "" || ((warned++))
        validate_tool "zeroshot" "" || true  # Optional AI workflow tool

        # Check for code-review-graph watcher
        # Note: grep -q can cause SIGPIPE with pipefail, so use redirect instead
        if [ -f "$HOME/Library/LaunchAgents/com.code-review-graph.watcher.plist" ]; then
            if launchctl list | grep "com.code-review-graph.watcher" >/dev/null 2>&1; then
                echo "✅ Claude Code: code-review-graph watcher running"
            else
                echo "⚠️  Claude Code: code-review-graph watcher not running"
                ((warned++))
            fi
        else
            echo "⚠️  Claude Code: code-review-graph watcher not configured"
            ((warned++))
        fi
    fi

    echo ""
    echo "Configuration Files:"
    if [ -f "$HOME/.gitconfig" ]; then
        echo "✅ Git configuration (.gitconfig)"
    else
        echo "❌ Git configuration (.gitconfig) not found"
        ((failed++))
    fi

    if [ -f "$HOME/.zshrc" ]; then
        echo "✅ Zsh configuration (.zshrc)"
    else
        echo "❌ Zsh configuration (.zshrc) not found"
        ((failed++))
    fi

    echo ""

    # Collect actionable recommendations
    local actions=()

    # Check bundler version (use local var from top of function)
    if command_exists bundler; then
        local bundler_current
        bundler_current=$(extract_tool_version "bundler")
        if [ "$bundler_current" != "$bundler_version" ] && [ -n "$bundler_version" ]; then
            actions+=("Update bundler: asdf install bundler $bundler_version && asdf global bundler $bundler_version")
        fi
    fi

    # Check gcloud version (use local var from top of function)
    if command_exists gcloud; then
        local gcloud_current
        gcloud_current=$(extract_tool_version "gcloud")
        if [ "$gcloud_current" != "$gcloud_version" ] && [ -n "$gcloud_version" ]; then
            actions+=("Update gcloud: asdf install gcloud $gcloud_version && asdf global gcloud $gcloud_version")
        fi
    fi

    # Check for code-review-graph watcher (only if it's installed but not running)
    # Note: grep -q can cause SIGPIPE with pipefail, so use redirect instead
    if command_exists code-review-graph; then
        if [ -f "$HOME/Library/LaunchAgents/com.code-review-graph.watcher.plist" ]; then
            if ! launchctl list | grep "com.code-review-graph.watcher" >/dev/null 2>&1; then
                actions+=("Start code-review-graph watcher: launchctl load ~/Library/LaunchAgents/com.code-review-graph.watcher.plist")
            fi
        fi
    fi

    # Check for missing Oh My Zsh
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        actions+=("Install Oh My Zsh: sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\"")
    fi

    # Suggest optional tools if user might want them
    local optional_missing=()
    command_exists htop || optional_missing+=("htop")
    command_exists btop || optional_missing+=("btop")
    command_exists ollama || optional_missing+=("ollama")

    if [ $failed -eq 0 ] && [ $warned -eq 0 ]; then
        echo "🎉 All validations passed!"

        if [ ${#optional_missing[@]} -gt 0 ]; then
            echo ""
            echo "💡 Optional tools you might want to install:"
            for tool in "${optional_missing[@]}"; do
                echo "   - $tool: brew install $tool"
            done
        fi
        return 0
    elif [ $failed -eq 0 ]; then
        echo "✅ Core validations passed ($warned optional component(s) missing)"

        if [ ${#actions[@]} -gt 0 ]; then
            echo ""
            echo "💡 Recommended actions:"
            for action in "${actions[@]}"; do
                echo "   $action"
            done
        fi
        return 0
    else
        echo "💥 $failed critical validation(s) failed, $warned warning(s)"

        if [ ${#actions[@]} -gt 0 ]; then
            echo ""
            echo "🔧 Required actions to fix failures:"
            for action in "${actions[@]}"; do
                echo "   $action"
            done
        fi

        echo ""
        echo "💡 Run 'npm run setup' to install missing components"
        return 1
    fi
}
