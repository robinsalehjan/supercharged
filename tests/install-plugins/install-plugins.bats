#!/usr/bin/env bats

# Smoke tests for install-plugins.sh — exercises argument parsing,
# prerequisite handling, and dry-run output against the real repo configs.

load '../helpers/setup'
load '../helpers/mocks'

setup() {
  setup_test_env

  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$PROJECT_ROOT/scripts/install-plugins.sh"
}

teardown() {
  unmock_all
  teardown_test_env
}

@test "install-plugins.sh script is executable" {
  [ -x "$SCRIPT" ]
}

@test "install-plugins.sh previews without requiring the Claude CLI" {
  # Ensure no claude in PATH; mock jq so we get past the jq check
  _ensure_mock_bin_dir
  rm -f "$MOCK_BIN_DIR/claude"

  # Strip system claude from PATH for this test
  run env PATH="$MOCK_BIN_DIR:/usr/bin:/bin" "$SCRIPT" --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *"Would install plugin"* ]]
}

@test "install-plugins.sh --dry-run completes successfully" {
  mock_claude

  run "$SCRIPT" --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run]"* ]]
  [[ "$output" == *"Plugin installation complete"* ]]
}

@test "install-plugins.sh documents its dry-run contract" {
  run "$SCRIPT" --help

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--dry-run"* ]]
}

@test "install-plugins.sh --dry-run does not call claude" {
  mock_claude

  run "$SCRIPT" --dry-run
  [ "$status" -eq 0 ]

  # claude.calls is created empty by mock_claude — dry-run must not append.
  # Use -s directly: returns false for both missing files AND empty files.
  [ ! -s "$MOCK_BIN_DIR/claude.calls" ]
}

@test "install-plugins.sh --dry-run lists known marketplaces" {
  mock_claude

  run "$SCRIPT" --dry-run
  [ "$status" -eq 0 ]

  # Should reference at least one marketplace from known_marketplaces.json
  [[ "$output" == *"Would add marketplace"* ]]
}

@test "install-plugins.sh --dry-run lists installed plugins" {
  mock_claude

  run "$SCRIPT" --dry-run
  [ "$status" -eq 0 ]

  # Should reference at least one plugin from installed_plugins.json
  [[ "$output" == *"Would install plugin"* ]]
}

@test "install-plugins.sh rejects an unknown flag" {
  mock_claude

  run "$SCRIPT" --bogus-flag --dry-run
  [ "$status" -eq 2 ]
  [[ "$output" == *"Unknown option"* ]]
  [[ "$output" == *"--bogus-flag"* ]]
}

@test "install-plugins.sh rejects a live Claude plugin version mismatch" {
  mock_claude
  local expected_version
  local drifted_version="0.0.0-test-drift"
  expected_version=$(jq -r '.plugins["swift-lsp@claude-plugins-official"][0].version' \
    "$PROJECT_ROOT/claude_config/installed_plugins.json")
  cp "$PROJECT_ROOT/claude_config/installed_plugins.json" \
    "$TEMP_CLAUDE_PLUGINS/installed_plugins.json"
  jq --arg version "$drifted_version" \
    '.plugins["swift-lsp@claude-plugins-official"][0].version = $version' \
    "$TEMP_CLAUDE_PLUGINS/installed_plugins.json" \
    > "$TEMP_CLAUDE_PLUGINS/installed_plugins.json.tmp"
  mv "$TEMP_CLAUDE_PLUGINS/installed_plugins.json.tmp" \
    "$TEMP_CLAUDE_PLUGINS/installed_plugins.json"

  run env CLAUDE_HOME="$TEMP_CLAUDE" "$SCRIPT"

  [ "$status" -ne 0 ]
  [[ "$output" == *"Claude plugin version mismatch for swift-lsp@claude-plugins-official"* ]]
  [[ "$output" == *"expected $expected_version, found $drifted_version"* ]]
}
