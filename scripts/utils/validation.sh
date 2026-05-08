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

validate_installation() {
    echo "🔍 Validating installation..."
    local failed=0

    # Read versions from .tool-versions using helper function
    parse_tool_versions
    local python_version="${TOOL_VERSIONS[python]}"
    local ruby_version="${TOOL_VERSIONS[ruby]}"
    local node_version="${TOOL_VERSIONS[nodejs]}"
    local bundler_version="${TOOL_VERSIONS[bundler]}"
    local gcloud_version="${TOOL_VERSIONS[gcloud]}"
    local firebase_version="${TOOL_VERSIONS[firebase]}"
    local java_version="${TOOL_VERSIONS[java]#*-}"  # Strip "openjdk-" prefix → semver
    local kotlin_version="${TOOL_VERSIONS[kotlin]}"

    # Validate core tools
    validate_tool "brew" "" || ((failed++))
    validate_tool "git" "" || ((failed++))
    validate_tool "asdf" "" || ((failed++))
    validate_tool "shellcheck" "" || ((failed++))
    validate_tool "rtk" "" || ((failed++))
    validate_tool "wt" "" || ((failed++))
    validate_tool "code-review-graph" "" || ((failed++))

    # Validate ASDF-managed languages and runtimes
    validate_tool "python3" "$python_version" || ((failed++))
    validate_tool "node" "$node_version" || ((failed++))
    validate_tool "ruby" "$ruby_version" || ((failed++))
    validate_tool "bundler" "$bundler_version" || ((failed++))
    validate_tool "java" "$java_version" || ((failed++))
    validate_tool "kotlin" "$kotlin_version" || ((failed++))

    # Validate cloud and DevOps tools
    validate_tool "gcloud" "$gcloud_version" || ((failed++))
    validate_tool "firebase" "$firebase_version" || ((failed++))

    # Validate Nerd Font (required for tmux/Catppuccin glyphs)
    validate_font "JetBrainsMono Nerd Font" "JetBrainsMono*Nerd*.ttf" || ((failed++))

    if [ $failed -eq 0 ]; then
        echo "🎉 All validations passed!"
        return 0
    else
        echo "💥 $failed validation(s) failed"
        return 1
    fi
}
