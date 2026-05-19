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

@test "install-plugins.sh fails when claude CLI is missing" {
  # Ensure no claude in PATH; mock jq so we get past the jq check
  _ensure_mock_bin_dir
  rm -f "$MOCK_BIN_DIR/claude"

  # Strip system claude from PATH for this test
  run env PATH="$MOCK_BIN_DIR:/usr/bin:/bin" "$SCRIPT" --dry-run

  [ "$status" -ne 0 ]
  [[ "$output" == *"claude CLI not found"* ]]
}

@test "install-plugins.sh --dry-run completes successfully" {
  mock_claude

  run "$SCRIPT" --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run]"* ]]
  [[ "$output" == *"Plugin installation complete"* ]]
}

@test "install-plugins.sh --dry-run does not call claude" {
  mock_claude

  run "$SCRIPT" --dry-run
  [ "$status" -eq 0 ]

  # claude.calls should be empty — dry-run must not invoke the CLI
  if [ -f "$MOCK_BIN_DIR/claude.calls" ]; then
    [ ! -s "$MOCK_BIN_DIR/claude.calls" ]
  fi
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

@test "install-plugins.sh warns on unknown flag but does not exit" {
  mock_claude

  run "$SCRIPT" --bogus-flag --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Unknown option"* ]]
  [[ "$output" == *"--bogus-flag"* ]]
}
