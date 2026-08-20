#!/bin/zsh

# Codex-first health audit. `--repo-only` is deterministic and safe for CI: it
# validates only tracked configuration, manifests, hook behavior, and mirrors.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CODEX_CONFIG_DIR="$PROJECT_ROOT/codex_config"
AGENT_CONFIG_DIR="$PROJECT_ROOT/agent_config"
JSON_OUTPUT=false
REPO_ONLY=false
PROFILE="base"
AUDIT_TMP_DIR="$(mktemp -d)"
typeset -a PASSES WARNINGS FAILURES

cleanup() {
    rm -rf "$AUDIT_TMP_DIR"
}
trap cleanup EXIT

show_help() {
    echo "Usage: $(basename "$0") [--json] [--repo-only] [--profile apple|apple-headless|review]"
    echo ""
    echo "Audit managed Codex configuration, plugins, MCP intent, skills, RTK, and CRG."
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --repo-only)
            REPO_ONLY=true
            shift
            ;;
        --profile)
            PROFILE="${2:-}"
            if [[ "$PROFILE" != "apple" && "$PROFILE" != "apple-headless" && "$PROFILE" != "review" ]]; then
                echo "--profile must be apple, apple-headless, or review" >&2
                exit 2
            fi
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            show_help
            exit 2
            ;;
    esac
done

pass() {
    PASSES+=("$1")
}

warn() {
    WARNINGS+=("$1")
}

fail() {
    FAILURES+=("$1")
}

require_command() {
    local command_name="$1"
    local description="$2"

    if command -v "$command_name" >/dev/null 2>&1; then
        pass "$description"
    else
        fail "$description (missing executable: $command_name)"
    fi
}

version_gte() {
    local installed="$1" required="$2"
    local installed_major installed_minor installed_patch
    local required_major required_minor required_patch
    IFS=. read -r installed_major installed_minor installed_patch <<<"$installed"
    IFS=. read -r required_major required_minor required_patch <<<"$required"
    (( installed_major > required_major )) && return 0
    (( installed_major < required_major )) && return 1
    (( installed_minor > required_minor )) && return 0
    (( installed_minor < required_minor )) && return 1
    (( installed_patch > required_patch )) && return 0
    (( installed_patch < required_patch )) && return 1
    return 0
}

audit_compatibility_tool() {
    local key="$1" default_command="$2"
    local command_name minimum tested output installed
    command_name=$(jq -r --arg key "$key" '.compatibility[$key].command // empty' "$MANAGED_TOOLS_MANIFEST")
    command_name="${command_name:-$default_command}"
    minimum=$(jq -r --arg key "$key" '.compatibility[$key].minimum_version' "$MANAGED_TOOLS_MANIFEST")
    tested=$(jq -r --arg key "$key" '.compatibility[$key].tested_version' "$MANAGED_TOOLS_MANIFEST")
    if ! command -v "$command_name" >/dev/null 2>&1; then
        fail "$key compatibility floor cannot be checked (missing $command_name)"
        return
    fi
    output=$("$command_name" --version 2>&1 || true)
    installed=$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+' <<<"$output" | head -1)
    if [ -z "$installed" ] || ! version_gte "$installed" "$minimum"; then
        fail "$key $installed is below the supported minimum $minimum"
    elif [ "$installed" = "$tested" ]; then
        pass "$key $installed matches the tested version"
    else
        warn "$key $installed meets the $minimum minimum but differs from tested $tested"
    fi
}

if ! command -v jq >/dev/null 2>&1; then
    echo "audit:agents requires jq" >&2
    exit 2
fi

validate_toml_shape() {
    local file="$1"
    local line trimmed value

    while IFS= read -r line || [ -n "$line" ]; do
        trimmed="${line#"${line%%[![:space:]]*}"}"
        [ -z "$trimmed" ] && continue
        [[ "$trimmed" == \#* ]] && continue
        if [[ "$trimmed" == \[*\] ]]; then
            continue
        fi
        if [[ "$trimmed" != *=* ]]; then
            return 1
        fi
        value="${trimmed#*=}"
        value="${value#"${value%%[![:space:]]*}"}"
        case "$value" in
            true|false|\"*\"|\[*\]|[0-9]*|-[0-9]*) ;;
            *) return 1 ;;
        esac
    done < "$file"
}

# A fixed collation keeps the inventory assertion deterministic on developer
# machines and macOS CI runners with different locale defaults.
base_mcp_names=$(sed -n 's/^\[mcp_servers\.\([^].]*\)\]$/\1/p' "$CODEX_CONFIG_DIR/config.toml" | LC_ALL=C sort | tr '\n' ' ')
apple_mcp_names=$(sed -n 's/^\[mcp_servers\.\([^].]*\)\]$/\1/p' "$CODEX_CONFIG_DIR/apple.config.toml" | LC_ALL=C sort | tr '\n' ' ')
apple_headless_mcp_names=$(sed -n 's/^\[mcp_servers\.\([^].]*\)\]$/\1/p' "$CODEX_CONFIG_DIR/apple-headless.config.toml" | LC_ALL=C sort | tr '\n' ' ')
if validate_toml_shape "$CODEX_CONFIG_DIR/config.toml" && \
   validate_toml_shape "$CODEX_CONFIG_DIR/apple.config.toml" && \
   validate_toml_shape "$CODEX_CONFIG_DIR/apple-headless.config.toml" && \
   validate_toml_shape "$CODEX_CONFIG_DIR/review.config.toml" && \
   rg -q '^web_search = "live"$' "$CODEX_CONFIG_DIR/config.toml" && \
   rg -q '^model_reasoning_effort = "high"$' "$CODEX_CONFIG_DIR/config.toml" && \
   rg -q '^hooks = true$' "$CODEX_CONFIG_DIR/config.toml" && \
   rg -q '^memories = false$' "$CODEX_CONFIG_DIR/config.toml" && \
   [ "$base_mcp_names" = "code-review-graph computer-use openaiDeveloperDocs " ] && \
   [ "$apple_mcp_names" = "xcode " ] && \
   [ "$apple_headless_mcp_names" = "XcodeBuildMCP " ] && \
   rg -q '^model_reasoning_effort = "xhigh"$' "$CODEX_CONFIG_DIR/review.config.toml"; then
    pass "Tracked Codex base, Apple, headless Apple, and review TOML profiles parse with the intended scoped inventory"
else
    fail "Tracked Codex TOML is malformed, deprecated, or has an invalid profile inventory"
fi

if ! rg -q 'web_search = "cached"|js_repl|node_repl|NODE_REPL_TRUSTED' "$CODEX_CONFIG_DIR"; then
    pass "Removed Codex legacy web-search, JS REPL, and Node REPL configuration is absent"
else
    fail "Removed Codex legacy configuration is still tracked"
fi

if jq -e '
    (.mcpServers | keys | sort) == ["code-review-graph", "openaiDeveloperDocs"] and
    .mcpServers["code-review-graph"] == {command: "code-review-graph", args: ["serve"], type: "stdio"} and
    .mcpServers.openaiDeveloperDocs == {type: "http", url: "https://developers.openai.com/mcp"}
' "$PROJECT_ROOT/.mcp.json" >/dev/null 2>&1 && \
   jq -e 'type == "object" and length == 0' "$PROJECT_ROOT/claude_config/mcp_servers.json" >/dev/null 2>&1; then
    pass "Shared MCP inventory is canonical and Apple servers are Codex-profile-only"
else
    fail "Shared MCP inventory has duplicate, misplaced, or malformed servers"
fi

if jq -e '
    (.hooks.PreToolUse | length == 1) and
    (.hooks.Stop | length == 1) and
    (has("PostToolUse") | not) and
    (has("SessionStart") | not)
' "$CODEX_CONFIG_DIR/hooks.json" >/dev/null 2>&1; then
    pass "Hook JSON retains RTK PreToolUse and Plannotator Stop without synchronous CRG hooks"
else
    fail "Hook JSON is malformed or still contains synchronous code-review-graph hooks"
fi

if [[ -f "$CODEX_CONFIG_DIR/hooks/rtk-enforce.sh" ]] && \
   rg -q 'permissionDecision:"allow"' "$CODEX_CONFIG_DIR/hooks/rtk-enforce.sh" && \
   rg -q 'updatedInput:\{command:\$command\}' "$CODEX_CONFIG_DIR/hooks/rtk-enforce.sh"; then
    pass "RTK hook declares the supported non-blocking rewrite contract"
else
    fail "RTK hook does not declare a supported allow-and-rewrite contract"
fi

printf '%s\n' '#!/usr/bin/env bash' \
    'if [ "$1" = "rewrite" ]; then printf "%s\\n" "rtk git status"; exit 0; fi' \
    'exit 1' > "$AUDIT_TMP_DIR/rtk"
chmod +x "$AUDIT_TMP_DIR/rtk"
if hook_result=$(printf '%s\n' '{"tool_input":{"command":"git status"}}' | \
    PATH="$AUDIT_TMP_DIR:$PATH" bash "$CODEX_CONFIG_DIR/hooks/rtk-enforce.sh") && \
    jq -e '.hookSpecificOutput.permissionDecision == "allow" and .hookSpecificOutput.updatedInput.command == "rtk git status"' \
        <<<"$hook_result" >/dev/null; then
    pass "RTK hook rewrites a command without blocking it"
else
    fail "RTK hook rewrite behavior is invalid"
fi

if jq -e '
    .version == 1 and
    (.marketplaces | length == 1) and
    .marketplaces[0].name == "axiom-marketplace" and
    .marketplaces[0].source == "CharlesWiltgen/Axiom" and
    (.marketplaces[0].ref | test("^[0-9a-f]{40}$")) and
    (.plugins | length == 1) and
    .plugins[0].id == "axiom@axiom-marketplace" and
    (.plugins[0].version | test("^[0-9]+\\.[0-9]+\\.[0-9]+([.-][0-9A-Za-z.-]+)?$")) and
    .plugins[0].required == true and .plugins[0].enabled == true
' "$CODEX_CONFIG_DIR/plugins.json" >/dev/null 2>&1; then
    pass "Managed plugin registry contains only required enabled Axiom"
else
    fail "Managed Codex plugin registry is malformed or does not match Axiom policy"
fi

MANAGED_TOOLS_MANIFEST="${MANAGED_TOOLS_MANIFEST:-$AGENT_CONFIG_DIR/managed_tools.json}"
if jq -e '
    .version == 2 and
    (.tools | keys | sort) == ["code-review-graph", "obscura", "plannotator", "xcodebuildmcp"] and
    (.tools.plannotator.version | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")) and
    .tools.plannotator.repository == "backnotprop/plannotator" and
    ([.tools.plannotator.assets["darwin-arm64"], .tools.plannotator.assets["darwin-x64"]] | all(
        (.name | test("^plannotator-darwin-(arm64|x64)$")) and
        (.sha256 | test("^[0-9a-f]{64}$"))
    )) and
    (.tools["code-review-graph"].version | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")) and
    .tools["code-review-graph"].policy == "exact-pypi" and
    .tools["code-review-graph"].package == "code-review-graph" and
    .tools["code-review-graph"].extras == ["embeddings", "communities"] and
    ([.tools.xcodebuildmcp, .tools.obscura] | all(
        .policy == "exact-release" and
        (.version | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")) and
        ([.assets["darwin-arm64"], .assets["darwin-x64"]] | all(.sha256 | test("^[0-9a-f]{64}$")))
    )) and
    (.tools.obscura.assets | [."darwin-arm64", ."darwin-x64"] | all(
        (.binaries.obscura | test("^[0-9a-f]{64}$")) and
        (.binaries["obscura-worker"] | test("^[0-9a-f]{64}$"))
    )) and
    (.compatibility | to_entries | all(
        (.value.minimum_version | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")) and
        (.value.tested_version | test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))
    ))
' "$MANAGED_TOOLS_MANIFEST" >/dev/null 2>&1; then
    pass "Managed tool manifest pins exact tools and compatibility floors"
else
    fail "Managed tool manifest is missing or has invalid pin policy"
fi

if jq -e '.skills // {} | to_entries | all(.value.ref | test("^[0-9a-f]{40}$"))' \
    "$AGENT_CONFIG_DIR/installed_skills.json" >/dev/null 2>&1; then
    pass "Tracked git skills use immutable commit refs"
else
    fail "Tracked git skills must use immutable 40-character commit refs"
fi

if "$SCRIPT_DIR/generate-claude-skill-mirrors.sh" --check >/dev/null 2>&1; then
    pass "Canonical shared skills and Claude compatibility mirrors are in sync"
else
    fail "Canonical shared skills and Claude compatibility mirrors have drifted"
fi

if [ -d "$AGENT_CONFIG_DIR/skills" ] && [ "$(find "$AGENT_CONFIG_DIR/skills" -mindepth 2 -maxdepth 2 -type f -name 'SKILL.md' | wc -l | tr -d ' ')" -eq 4 ]; then
    pass "Canonical shared skill inventory contains the four graph skills"
else
    fail "Canonical shared skill inventory is incomplete"
fi

if [ "$REPO_ONLY" = false ]; then
    require_command codex "Codex CLI is installed"
    require_command rtk "RTK is installed"
    require_command code-review-graph "code-review-graph is installed"

    audit_compatibility_tool codex codex
    audit_compatibility_tool claude claude
    audit_compatibility_tool rtk rtk
    audit_compatibility_tool worktrunk wt

    plannotator_arch=$(uname -m)
    case "$plannotator_arch" in
        arm64|aarch64) plannotator_asset="darwin-arm64" ;;
        x86_64) plannotator_asset="darwin-x64" ;;
        *) plannotator_asset="" ;;
    esac
    plannotator_path="$HOME/.local/bin/plannotator"
    plannotator_version=$(jq -r '.tools.plannotator.version' "$MANAGED_TOOLS_MANIFEST")
    plannotator_expected_sha=$(jq -r --arg asset "$plannotator_asset" '.tools.plannotator.assets[$asset].sha256 // ""' "$MANAGED_TOOLS_MANIFEST")
    plannotator_installed_sha=""
    if [ -f "$plannotator_path" ]; then
        plannotator_installed_sha=$(shasum -a 256 "$plannotator_path" 2>/dev/null | awk '{print $1}') || plannotator_installed_sha=""
    fi
    if [ -n "$plannotator_expected_sha" ] && \
       [ "$plannotator_installed_sha" = "$plannotator_expected_sha" ] && \
       [ -x "$plannotator_path" ]; then
        pass "Plannotator $plannotator_version matches the managed checksum"
    else
        fail "Plannotator does not match managed version $plannotator_version; run npm run install:plannotator"
    fi

    obscura_arch=$(uname -m)
    case "$obscura_arch" in
        arm64|aarch64) obscura_asset="darwin-arm64" ;;
        x86_64) obscura_asset="darwin-x64" ;;
        *) obscura_asset="" ;;
    esac
    obscura_version=$(jq -r '.tools.obscura.version' "$MANAGED_TOOLS_MANIFEST")
    obscura_expected_sha=$(jq -r --arg asset "$obscura_asset" '.tools.obscura.assets[$asset].binaries.obscura // ""' "$MANAGED_TOOLS_MANIFEST")
    worker_expected_sha=$(jq -r --arg asset "$obscura_asset" '.tools.obscura.assets[$asset].binaries["obscura-worker"] // ""' "$MANAGED_TOOLS_MANIFEST")
    obscura_installed_sha=$(shasum -a 256 "$HOME/.local/bin/obscura" 2>/dev/null | awk '{print $1}') || obscura_installed_sha=""
    worker_installed_sha=$(shasum -a 256 "$HOME/.local/bin/obscura-worker" 2>/dev/null | awk '{print $1}') || worker_installed_sha=""
    if [ "$obscura_installed_sha" = "$obscura_expected_sha" ] && \
       [ "$worker_installed_sha" = "$worker_expected_sha" ]; then
        pass "Obscura $obscura_version binaries match the managed checksums"
    else
        fail "Obscura differs from managed version $obscura_version; run npm run install:managed-tools"
    fi

    claude_plugins_live="$HOME/.claude/plugins/installed_plugins.json"
    if [ -f "$claude_plugins_live" ] && jq -e --slurpfile desired "$PROJECT_ROOT/claude_config/installed_plugins.json" '
        . as $live |
        ($desired[0].plugins | to_entries) as $expected |
        all($expected[]; .key as $plugin | .value[0].version as $version |
            ($live.plugins[$plugin][0].version // "") == $version)
    ' "$claude_plugins_live" >/dev/null 2>&1; then
        pass "Claude plugins match their tracked marketplace versions"
    else
        fail "Claude plugins differ from tracked versions; run npm run install:plugins"
    fi

    if command -v codex >/dev/null 2>&1; then
        audit_codex_home="$AUDIT_TMP_DIR/codex-home"
        mkdir -p "$audit_codex_home"
        cp "$CODEX_CONFIG_DIR/config.toml" "$CODEX_CONFIG_DIR/apple.config.toml" "$CODEX_CONFIG_DIR/apple-headless.config.toml" "$CODEX_CONFIG_DIR/review.config.toml" "$audit_codex_home/"
        if CODEX_HOME="$audit_codex_home" codex --strict-config --help >/dev/null 2>&1 && \
           CODEX_HOME="$audit_codex_home" codex --strict-config --profile apple --help >/dev/null 2>&1 && \
           CODEX_HOME="$audit_codex_home" codex --strict-config --profile apple-headless --help >/dev/null 2>&1 && \
           CODEX_HOME="$audit_codex_home" codex --strict-config --profile review --help >/dev/null 2>&1; then
            pass "Codex CLI strictly parses the tracked base and profile configuration"
        else
            fail "Codex CLI rejects tracked base or profile configuration"
        fi

        if marketplace_state=$(codex plugin marketplace list --json 2>&1) && \
           jq -e '.marketplaces[]? | select(.name == "axiom-marketplace")' <<<"$marketplace_state" >/dev/null; then
            pass "Axiom marketplace is configured locally"
        else
            fail "Axiom marketplace is not configured locally"
        fi

        axiom_version=$(jq -r '.plugins[] | select(.id == "axiom@axiom-marketplace") | .version' "$CODEX_CONFIG_DIR/plugins.json")
        if plugin_state=$(codex plugin list --json 2>&1) && \
           jq -e --arg version "$axiom_version" '.installed[]? | select(
               (.pluginId // .id // .name // "") == "axiom@axiom-marketplace" and .version == $version
           )' <<<"$plugin_state" >/dev/null; then
            pass "Required Axiom plugin matches pinned version $axiom_version"
        else
            fail "Required Axiom plugin is missing or differs from pinned version $axiom_version"
        fi
    fi

    if command -v code-review-graph >/dev/null 2>&1; then
        crg_expected=$(jq -r '.tools["code-review-graph"].version' "$MANAGED_TOOLS_MANIFEST")
        crg_installed=$(code-review-graph --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        if [ "$crg_installed" = "$crg_expected" ]; then
            pass "code-review-graph $crg_installed matches the exact pin"
        else
            fail "code-review-graph ${crg_installed:-unknown} differs from exact pin $crg_expected"
        fi

        if code-review-graph status >/dev/null 2>&1; then
            pass "code-review-graph reports a registered, current graph"
        else
            fail "code-review-graph is not registered or its graph is stale; run crg-here or code-review-graph update"
        fi

        if [ -f "$HOME/Library/LaunchAgents/com.code-review-graph.watcher.plist" ]; then
            pass "code-review-graph launchd watcher is configured"
        else
            fail "code-review-graph launchd watcher is not configured"
        fi
    fi

    case "$PROFILE" in
        apple)
            require_command xcrun "Apple profile: xcrun MCP bridge is available"
            ;;
        apple-headless)
            require_command xcodebuildmcp "Headless Apple profile: XcodeBuildMCP is installed"
            xcodebuildmcp_expected=$(jq -r '.tools.xcodebuildmcp.version | sub("^v"; "")' "$MANAGED_TOOLS_MANIFEST")
            case "$(uname -m)" in
                arm64|aarch64) xcodebuildmcp_asset="darwin-arm64" ;;
                x86_64) xcodebuildmcp_asset="darwin-x64" ;;
                *) xcodebuildmcp_asset="" ;;
            esac
            xcodebuildmcp_expected_sha=$(jq -r --arg asset "$xcodebuildmcp_asset" '.tools.xcodebuildmcp.assets[$asset].sha256 // ""' "$MANAGED_TOOLS_MANIFEST")
            xcodebuildmcp_installed_sha=$(cat "$HOME/.local/share/supercharged/xcodebuildmcp/.active-archive-sha256" 2>/dev/null || true)
            xcodebuildmcp_installed=$(xcodebuildmcp --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            if [ "$xcodebuildmcp_installed" = "$xcodebuildmcp_expected" ] && \
               [ "$xcodebuildmcp_installed_sha" = "$xcodebuildmcp_expected_sha" ]; then
                pass "XcodeBuildMCP $xcodebuildmcp_installed matches the exact release checksum"
            else
                fail "XcodeBuildMCP differs from exact pin $xcodebuildmcp_expected; run npm run install:managed-tools"
            fi
            ;;
        *)
            pass "Apple-profile executables are not required without an Apple profile"
            ;;
    esac

    if command -v rtk >/dev/null 2>&1; then
        if rtk gain --history >/dev/null 2>&1; then
            pass "RTK savings summary is available"
        else
            warn "RTK is installed but has no savings history yet"
        fi
    fi

    if command -v claude >/dev/null 2>&1; then
        pass "Claude compatibility CLI is installed"
    else
        warn "Claude compatibility CLI is not installed"
    fi
else
    pass "Runtime executables, local plugins, and graph state skipped in deterministic --repo-only mode"
fi

if [ "$JSON_OUTPUT" = true ]; then
    pass_json=$(printf '%s\n' "${PASSES[@]}" | jq -Rsc 'split("\n") | map(select(length > 0))')
    warn_json=$(printf '%s\n' "${WARNINGS[@]}" | jq -Rsc 'split("\n") | map(select(length > 0))')
    fail_json=$(printf '%s\n' "${FAILURES[@]}" | jq -Rsc 'split("\n") | map(select(length > 0))')
    jq -n \
        --argjson passed "$pass_json" \
        --argjson warnings "$warn_json" \
        --argjson failures "$fail_json" \
        --arg profile "$PROFILE" \
        --argjson repo_only "$REPO_ONLY" \
        '{ok: ($failures | length == 0), profile: $profile, repo_only: $repo_only, passed: $passed, warnings: $warnings, failures: $failures}'
else
    echo "Agent health audit ($([ "$REPO_ONLY" = true ] && echo repo-only || echo local), profile: $PROFILE)"
    for message in "${PASSES[@]}"; do
        echo "PASS  $message"
    done
    for message in "${WARNINGS[@]}"; do
        echo "WARN  $message"
    done
    for message in "${FAILURES[@]}"; do
        echo "FAIL  $message"
    done
fi

[ "${#FAILURES[@]}" -eq 0 ]
