#!/usr/bin/env bats

load '../helpers/setup'

setup() {
  setup_test_env
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  INSTALLER="$PROJECT_ROOT/scripts/install-agent-tooling.sh"
  CHECKER="$PROJECT_ROOT/scripts/check-agent-tooling.py"
  CALLS="$TEST_TEMP_DIR/installers.calls"
  STUB_DIR="$TEST_TEMP_DIR/stubs"
  mkdir -p "$STUB_DIR"

  for name in managed skills claude-plugins codex-plugins; do
    stub="$STUB_DIR/$name"
    printf '%s\n' '#!/bin/sh' 'printf "%s %s\\n" "$(basename "$0")" "$*" >> "$INSTALLER_CALLS"' > "$stub"
    chmod +x "$stub"
  done
}

teardown() {
  teardown_test_env
}

run_installer() {
  run env \
    INSTALLER_CALLS="$CALLS" \
    MANAGED_TOOLS_INSTALLER="$STUB_DIR/managed" \
    SKILLS_INSTALLER="$STUB_DIR/skills" \
    CLAUDE_PLUGINS_INSTALLER="$STUB_DIR/claude-plugins" \
    CODEX_PLUGINS_INSTALLER="$STUB_DIR/codex-plugins" \
    "$INSTALLER" "$@"
}

@test "agent tooling reconciler previews shared tooling and both harnesses" {
  run_installer --dry-run

  [ "$status" -eq 0 ]
  [ "$(wc -l < "$CALLS" | tr -d ' ')" -eq 4 ]
  grep -Fx 'managed --dry-run' "$CALLS"
  grep -Fx 'skills --dry-run' "$CALLS"
  grep -Fx 'claude-plugins --dry-run' "$CALLS"
  grep -Fx 'codex-plugins --dry-run' "$CALLS"
}

@test "agent tooling reconciler can target one harness adapter" {
  run_installer --dry-run --harness claude

  [ "$status" -eq 0 ]
  grep -Fx 'claude-plugins --dry-run' "$CALLS"
  ! grep -q 'codex-plugins' "$CALLS"
}

@test "agent tooling reconciler rejects a missing harness value" {
  run_installer --harness

  [ "$status" -eq 2 ]
  [[ "$output" == *"--harness requires"* ]]
}

@test "agent tooling reconciler documents harness targeting" {
  run "$INSTALLER" --help

  [ "$status" -eq 0 ]
  [[ "$output" == *"--harness both|claude|codex"* ]]
}

@test "agent tooling parity report describes intentional native differences" {
  run "$CHECKER" --json

  [ "$status" -eq 0 ]
  run jq -e '
    .ok == true and
    (.shared.mcp_servers == ["code-review-graph", "openaiDeveloperDocs"]) and
    (.native_adapters.claude_plugins | index("swift-lsp@claude-plugins-official")) and
    (.native_adapters.codex_mcp_servers == ["XcodeBuildMCP", "computer-use", "xcode"]) and
    (.native_adapters.codex_plugins == ["axiom@axiom-marketplace"])
  ' <<<"$output"
  [ "$status" -eq 0 ]
}

@test "agent tooling parity report rejects shared MCP drift" {
  fixture="$TEST_TEMP_DIR/repo"
  mkdir -p "$fixture"
  cp -R "$PROJECT_ROOT/agent_config" "$PROJECT_ROOT/claude_config" \
    "$PROJECT_ROOT/codex_config" "$PROJECT_ROOT/.claude" "$fixture/"
  cp "$PROJECT_ROOT/.mcp.json" "$fixture/.mcp.json"
  jq '.mcpServers["code-review-graph"].args = ["different"]' \
    "$fixture/.mcp.json" > "$fixture/.mcp.json.tmp"
  mv "$fixture/.mcp.json.tmp" "$fixture/.mcp.json"

  run env SUPERCHARGED_PROJECT_ROOT="$fixture" "$CHECKER" --json

  [ "$status" -ne 0 ]
  run jq -e '.errors | index("Shared MCP configuration differs for: code-review-graph")' <<<"$output"
  [ "$status" -eq 0 ]
}
