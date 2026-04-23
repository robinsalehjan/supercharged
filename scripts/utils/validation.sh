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

    if [ $failed -eq 0 ]; then
        echo "🎉 All validations passed!"
        return 0
    else
        echo "💥 $failed validation(s) failed"
        return 1
    fi
}
