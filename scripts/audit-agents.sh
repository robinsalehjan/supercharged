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
    .marketplaces[0] == {name: "axiom-marketplace", source: "CharlesWiltgen/Axiom"} and
    (.plugins | length == 1) and
    .plugins[0] == {id: "axiom@axiom-marketplace", required: true, enabled: true}
' "$CODEX_CONFIG_DIR/plugins.json" >/dev/null 2>&1; then
    pass "Managed plugin registry contains only required enabled Axiom"
else
    fail "Managed Codex plugin registry is malformed or does not match Axiom policy"
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

        if plugin_state=$(codex plugin list --json 2>&1) && \
           jq -e '[.installed[]? | if type == "string" then . else (.pluginId // .id // .name // "") end] | index("axiom@axiom-marketplace") != null' \
               <<<"$plugin_state" >/dev/null; then
            pass "Required Axiom plugin is installed locally"
        else
            fail "Required Axiom plugin is not installed locally"
        fi
    fi

    if command -v code-review-graph >/dev/null 2>&1; then
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
