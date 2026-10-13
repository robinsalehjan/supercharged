#!/bin/zsh

set -euo pipefail

source "$(dirname "$0")/utils.sh"

apply=false
only=all
while [ "$#" -gt 0 ]; do
    case "$1" in
        --apply) apply=true ;;
        --only)
            shift
            case "${1:-}" in asdf|agents) only="$1" ;; *) echo "Usage: $0 [--apply] [--only asdf|agents]" >&2; exit 2 ;; esac
            ;;
        *) echo "Usage: $0 [--apply] [--only asdf|agents]" >&2; exit 2 ;;
    esac
    shift
done

work_dir=$(mktemp -d)
cleanup() { rm -rf "$work_dir"; }
trap cleanup EXIT

tool_versions="${ASDF_TOOL_VERSIONS:-$UTILS_PROJECT_ROOT/dot_files/.tool-versions}"
manifest="${MANAGED_TOOLS_MANIFEST:-$UTILS_PROJECT_ROOT/agent_config/managed_tools.json}"
plugin_registry="${CODEX_PLUGIN_REGISTRY:-$UTILS_PROJECT_ROOT/codex_config/plugins.json}"
asdf_policy="${ASDF_POLICY_MANIFEST:-$UTILS_PROJECT_ROOT/agent_config/asdf_policy.json}"
cp "$tool_versions" "$work_dir/tool-versions"
cp "$manifest" "$work_dir/managed-tools.json"
cp "$plugin_registry" "$work_dir/plugins.json"

if [ "$only" != agents ]; then
    if ! command -v asdf >/dev/null 2>&1; then
        echo "asdf is required to capture installed runtime versions" >&2
        exit 1
    fi
    while IFS= read -r plugin; do
        [ -n "$plugin" ] || continue
        policy=$(jq -r --arg plugin "$plugin" '.plugins[$plugin].policy' "$asdf_policy")
        [ "$policy" = hold ] && continue
        installed=$(asdf current "$plugin" 2>/dev/null | awk 'NR == 2 && $4 == "true" { print $2 }' || true)
        if [ -z "$installed" ]; then
            echo "Skipping $plugin: active version is not installed"
            continue
        fi
        if ! asdf where "$plugin" "$installed" >/dev/null 2>&1; then
            echo "Skipping $plugin $installed: selected but not installed"
            continue
        fi
        if ! jq -e --arg plugin "$plugin" --arg version "$installed" '
            .plugins[$plugin] as $policy |
            ($version | test($policy.match)) and
            (($policy.line // "") as $line | $line == "" or ($version | startswith($line + ".")))
        ' "$asdf_policy" >/dev/null; then
            echo "Skipping $plugin $installed: outside the tracked version policy"
            continue
        fi
        current=$(awk -v plugin="$plugin" '$1 == plugin { print $2; exit }' "$work_dir/tool-versions")
        [ "$installed" = "$current" ] && continue
        awk -v plugin="$plugin" -v version="$installed" \
            '$1 == plugin && NF == 2 { print plugin, version; next } { print }' \
            "$work_dir/tool-versions" > "$work_dir/tool-versions.next"
        mv "$work_dir/tool-versions.next" "$work_dir/tool-versions"
        echo "asdf $plugin: $current -> $installed"
    done < <(jq -r '.plugins | keys[]' "$asdf_policy")
fi

release_json() {
    local repository="$1" tag="$2" destination="$3"
    if command -v gh >/dev/null 2>&1; then
        gh api "repos/$repository/releases/tags/$tag" > "$destination"
    else
        curl -fsSL "${CURL_METADATA_OPTS[@]}" "https://api.github.com/repos/$repository/releases/tags/$tag" > "$destination"
    fi
}

installed_npm_version() {
    local package="$1"
    command -v npm >/dev/null 2>&1 || return 0
    npm list --global --depth=0 --json "$package" 2>/dev/null |
        jq -r --arg package "$package" '.dependencies[$package].version // empty' 2>/dev/null || true
}

installed_cli_version() {
    local command_name="$1"
    command -v "$command_name" >/dev/null 2>&1 || return 0
    "$command_name" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true
}

if [ "$only" != asdf ]; then
    case "$(uname -m)" in
        arm64|aarch64) arch=darwin-arm64 ;;
        x86_64) arch=darwin-x64 ;;
        *) echo "Unsupported architecture for local agent pin promotion" >&2; exit 1 ;;
    esac

    plannotator_version=$(installed_cli_version "$HOME/.local/bin/plannotator")
    obscura_version=$(installed_cli_version "$HOME/.local/bin/obscura")
    [ -x "$HOME/.local/bin/obscura-worker" ] || obscura_version=""
    crg_version=$(installed_cli_version code-review-graph)
    openwiki_version=$(installed_npm_version openwiki)
    firebase_version=$(installed_npm_version firebase-tools)
    [ -n "$firebase_version" ] && [ "$(installed_cli_version firebase)" = "$firebase_version" ] || firebase_version=""
    playwright_cli_version=$(installed_npm_version @playwright/cli)
    playwright_mcp_version=$(installed_npm_version @playwright/mcp)

    for entry in \
        "plannotator:$plannotator_version" "obscura:$obscura_version" \
        "code-review-graph:$crg_version" "openwiki:$openwiki_version" \
        "firebase:$firebase_version" \
        "playwright-cli:$playwright_cli_version" "playwright-mcp:$playwright_mcp_version"; do
        key="${entry%%:*}"
        version="${entry#*:}"
        if [ -z "$version" ]; then
            version=$(jq -r --arg key "$key" '.tools[$key].version' "$manifest")
            echo "Skipping $key: no local installation detected"
        fi
        case "$key" in
            plannotator|obscura) version="${version#v}"; version="v$version" ;;
        esac
        case "$key" in
            plannotator) plannotator_version="$version" ;;
            obscura) obscura_version="$version" ;;
            code-review-graph) crg_version="$version" ;;
            openwiki) openwiki_version="$version" ;;
            firebase) firebase_version="$version" ;;
            playwright-cli) playwright_cli_version="$version" ;;
            playwright-mcp) playwright_mcp_version="$version" ;;
        esac
    done

    if [ "$plannotator_version" = "$(jq -r '.tools.plannotator.version' "$manifest")" ]; then
        jq '{tag_name: .tools.plannotator.version, assets: [.tools.plannotator.assets | to_entries[] | {name: .value.name, digest: ("sha256:" + .value.sha256)}]}' "$manifest" > "$work_dir/plannotator.json"
    else
        release_json "$(jq -r '.tools.plannotator.repository' "$manifest")" "$plannotator_version" "$work_dir/plannotator.json"
    fi
    if [ "$obscura_version" = "$(jq -r '.tools.obscura.version' "$manifest")" ]; then
        jq '{tag_name: .tools.obscura.version, assets: [.tools.obscura.assets | to_entries[] | {name: .value.name, digest: ("sha256:" + .value.sha256)}]}' "$manifest" > "$work_dir/obscura.json"
    else
        release_json "$(jq -r '.tools.obscura.repository' "$manifest")" "$obscura_version" "$work_dir/obscura.json"
    fi
    jq -n --arg version "$crg_version" '{info: {version: $version}}' > "$work_dir/crg.json"

    MANAGED_TOOLS_MANIFEST="$work_dir/managed-tools.json" \
    CODEX_PLUGIN_REGISTRY="$work_dir/plugins.json" \
    PLANNOTATOR_RELEASE_JSON="$work_dir/plannotator.json" \
    OBSCURA_RELEASE_JSON="$work_dir/obscura.json" \
    CRG_PYPI_JSON="$work_dir/crg.json" \
    OPENWIKI_NPM_VERSION="$openwiki_version" \
    FIREBASE_NPM_VERSION="$firebase_version" \
    PLAYWRIGHT_CLI_NPM_VERSION="$playwright_cli_version" \
    PLAYWRIGHT_MCP_NPM_VERSION="$playwright_mcp_version" \
    SKIP_AXIOM_UPDATE=true \
    SUPERCHARGED_LOCAL_PROMOTION=1 \
        "$UTILS_PROJECT_ROOT/scripts/update-agent-tool-pins.sh" --apply

    for tool in plannotator obscura obscura-worker; do
        case "$tool" in
            plannotator)
                [ "$plannotator_version" = "$(jq -r '.tools.plannotator.version' "$manifest")" ] && continue
                expected=$(jq -r --arg arch "$arch" '.tools.plannotator.assets[$arch].sha256' "$work_dir/managed-tools.json")
                ;;
            *)
                [ "$obscura_version" = "$(jq -r '.tools.obscura.version' "$manifest")" ] && continue
                expected=$(jq -r --arg arch "$arch" --arg tool "$tool" '.tools.obscura.assets[$arch].binaries[$tool]' "$work_dir/managed-tools.json")
                ;;
        esac
        actual=$(shasum -a 256 "$HOME/.local/bin/$tool" | awk '{print $1}')
        if [ "$actual" != "$expected" ]; then
            echo "$tool does not match the release checksum; no pins were changed" >&2
            exit 1
        fi
    done
fi

if cmp -s "$tool_versions" "$work_dir/tool-versions" && cmp -s "$manifest" "$work_dir/managed-tools.json"; then
    echo "No eligible installed versions differ from tracked pins"
    exit 0
fi

if ! $apply; then
    echo "Preview only. Re-run with --apply after validating the installed tools."
    exit 0
fi

[ "$only" = agents ] || cp "$work_dir/tool-versions" "$tool_versions"
[ "$only" = asdf ] || cp "$work_dir/managed-tools.json" "$manifest"
echo "Promoted installed versions to tracked pins"
