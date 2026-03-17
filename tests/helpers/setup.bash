#!/usr/bin/env bash
# Test environment setup and teardown utilities

# Create isolated temp directory for each test
setup_test_env() {
  TEST_TEMP_DIR="$(mktemp -d)"
  TEMP_CLAUDE="$TEST_TEMP_DIR/.claude"
  TEMP_CLAUDE_PLUGINS="$TEMP_CLAUDE/plugins"
  TEMP_REPO_CONFIG="$TEST_TEMP_DIR/claude_config"

  mkdir -p "$TEMP_CLAUDE_PLUGINS"
  mkdir -p "$TEMP_REPO_CONFIG"

  # Backup original HOME before override
  export ORIGINAL_HOME="$HOME"

  # Override HOME for path portability tests
  export HOME="$TEST_TEMP_DIR"

  # Set fixture directory path (relative to tests/)
  FIXTURE_DIR="$(cd "$(dirname "${BATS_TEST_DIRNAME}")/../fixtures" && pwd)"

  # Export for use in tests
  export TEST_TEMP_DIR
  export TEMP_CLAUDE
  export TEMP_CLAUDE_PLUGINS
  export TEMP_REPO_CONFIG
  export FIXTURE_DIR
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
