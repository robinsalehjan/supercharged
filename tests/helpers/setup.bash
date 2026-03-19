#!/usr/bin/env bash
# Test environment setup and teardown utilities

# Create isolated temp directory for each test
setup_test_env() {
  # Save original HOME first, before anything that could fail
  export ORIGINAL_HOME="$HOME"

  TEST_TEMP_DIR="$(mktemp -d)" || {
    echo "Failed to create temp directory" >&2
    export HOME="$ORIGINAL_HOME"
    return 1
  }

  TEMP_CLAUDE="$TEST_TEMP_DIR/.claude"
  TEMP_CLAUDE_PLUGINS="$TEMP_CLAUDE/plugins"
  TEMP_REPO_CONFIG="$TEST_TEMP_DIR/claude_config"

  mkdir -p "$TEMP_CLAUDE_PLUGINS" "$TEMP_REPO_CONFIG"

  export HOME="$TEST_TEMP_DIR"

  # Fixture directory path (resolved to absolute from tests/fixtures/)
  FIXTURE_DIR="$(cd "$BATS_TEST_DIRNAME/../fixtures" && pwd)"

  export TEST_TEMP_DIR TEMP_CLAUDE TEMP_CLAUDE_PLUGINS TEMP_REPO_CONFIG FIXTURE_DIR
}

# Cleanup after each test
teardown_test_env() {
  if [ -n "$TEST_TEMP_DIR" ] && [ -d "$TEST_TEMP_DIR" ]; then
    rm -rf "$TEST_TEMP_DIR"
  fi

  # Restore original HOME if we backed it up
  if [ -n "$ORIGINAL_HOME" ]; then
    export HOME="$ORIGINAL_HOME"
  fi
}

# Load fixture file to destination
# Usage: load_fixture "claude-backup/plugins-mixed.json" "$TEMP_CLAUDE_PLUGINS/installed_plugins.json"
load_fixture() {
  local fixture_name="$1"
  local destination="$2"

  if [ ! -f "$FIXTURE_DIR/$fixture_name" ]; then
    echo "Fixture not found: $FIXTURE_DIR/$fixture_name" >&2
    return 1
  fi

  mkdir -p "$(dirname "$destination")"
  cp "$FIXTURE_DIR/$fixture_name" "$destination"
}
