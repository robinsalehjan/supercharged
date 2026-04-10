#!/usr/bin/env bats

# Load test helpers
load '../helpers/setup'
load '../helpers/assertions'
load '../helpers/mocks'

# Setup runs before each test
setup() {
  setup_test_env

  # Get project root (two levels up from tests/claude/)
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

  # Source utils.sh for make_path_portable function
  source "$PROJECT_ROOT/scripts/utils.sh"
}

# Teardown runs after each test
teardown() {
  teardown_test_env
}

# Helper: Run a jq filter + path portability replacement
# Usage: _sanitize_json ".jq_filter" "input.json" "output.json"
_sanitize_json() {
  local jq_filter="$1"
  local input_file="$2"
  local output_file="$3"

  # Use ORIGINAL_HOME for path replacement since HOME is overridden in tests
  # pipefail ensures jq failures propagate through the pipe
  set -o pipefail
  jq "$jq_filter" "$input_file" | sed "s|$ORIGINAL_HOME|\$HOME|g" > "$output_file"
  local result=$?
  set +o pipefail
  return $result
}

# Helper: Sanitize plugins for backup testing
# Note: Production (backup-claude.sh) uses dynamic jq filters built from the
# SANITIZE_MARKETPLACES array. This test uses hardcoded 'vend-plugins' filters
# for clarity. If new marketplaces are added to SANITIZE_MARKETPLACES,
# corresponding test cases should be added here.
sanitize_plugins() {
  _sanitize_json \
    '{version: .version, plugins: (.plugins | to_entries | map(select(.key | endswith("@vend-plugins") | not)) | from_entries)}' \
    "$1" "$2"
}

sanitize_marketplaces() {
  _sanitize_json 'del(.["vend-plugins"])' "$1" "$2"
}

# Note: mirrors the production jq filter in backup-claude.sh which strips
# vend-plugins from enabledPlugins and removes sensitive env vars.
# If SANITIZE_ENV_VARS grows, add corresponding del() clauses here.
sanitize_settings() {
  _sanitize_json \
    '(. + {enabledPlugins: (.enabledPlugins | to_entries | map(select(.key | endswith("@vend-plugins") | not)) | from_entries)}) | del(.env["GITHUB_PERSONAL_ACCESS_TOKEN"]) | del(.mcpServers[]?.env["GITHUB_PERSONAL_ACCESS_TOKEN"])' \
    "$1" "$2"
}

@test "removes vend-plugins entries from installed_plugins.json" {
  # Arrange: Load fixture
  load_fixture "claude-backup/plugins-mixed.json" "$TEMP_CLAUDE_PLUGINS/installed_plugins.json"

  # Act: Run sanitization
  sanitize_plugins "$TEMP_CLAUDE_PLUGINS/installed_plugins.json" "$TEMP_REPO_CONFIG/installed_plugins.json"

  # Assert: Vend plugins removed
  assert_plugin_not_exists "$TEMP_REPO_CONFIG/installed_plugins.json" "vend-internal@vend-plugins"
  assert_plugin_not_exists "$TEMP_REPO_CONFIG/installed_plugins.json" "vend-api@vend-plugins"

  # Assert: Personal plugins preserved
  assert_plugin_exists "$TEMP_REPO_CONFIG/installed_plugins.json" "superpowers@claude-plugins-official"
  assert_plugin_exists "$TEMP_REPO_CONFIG/installed_plugins.json" "hookify@claude-plugins-official"
}

@test "removes vend-plugins marketplace from known_marketplaces.json" {
  # Arrange: Load fixture
  load_fixture "claude-backup/marketplaces-full.json" "$TEMP_CLAUDE_PLUGINS/known_marketplaces.json"

  # Act: Run sanitization
  sanitize_marketplaces "$TEMP_CLAUDE_PLUGINS/known_marketplaces.json" "$TEMP_REPO_CONFIG/known_marketplaces.json"

  # Assert: Vend marketplace removed
  assert_marketplace_not_exists "$TEMP_REPO_CONFIG/known_marketplaces.json" "vend-plugins"

  # Assert: Personal marketplace preserved
  assert_marketplace_exists "$TEMP_REPO_CONFIG/known_marketplaces.json" "claude-plugins-official"
}

@test "makes paths portable by replacing HOME directory" {
  # Arrange: Load fixture with absolute paths
  load_fixture "claude-backup/plugins-mixed.json" "$TEMP_CLAUDE_PLUGINS/installed_plugins.json"

  # Act: Run sanitization (includes make_path_portable)
  sanitize_plugins "$TEMP_CLAUDE_PLUGINS/installed_plugins.json" "$TEMP_REPO_CONFIG/installed_plugins.json"

  # Assert: Paths contain $HOME placeholder
  local path
  path=$(jq -r '.plugins["superpowers@claude-plugins-official"].installPath' "$TEMP_REPO_CONFIG/installed_plugins.json")

  [[ "$path" == "\$HOME"* ]] || {
    echo "Expected path to start with \$HOME, got: $path"
    return 1
  }
}

@test "removes vend-plugins from settings.json enabledPlugins" {
  # Arrange: Load settings fixture
  load_fixture "claude-backup/settings-full.json" "$TEMP_CLAUDE/settings.json"

  # Act: Sanitize settings
  sanitize_settings "$TEMP_CLAUDE/settings.json" "$TEMP_REPO_CONFIG/settings.json"

  # Assert: Vend plugins removed from enabledPlugins
  assert_json_field "$TEMP_REPO_CONFIG/settings.json" \
    '.enabledPlugins | to_entries | map(select(.key | endswith("@vend-plugins"))) | length' "0"

  # Assert: Personal plugins preserved
  assert_json_field "$TEMP_REPO_CONFIG/settings.json" \
    '.enabledPlugins | to_entries | map(select(.key | endswith("@claude-plugins-official"))) | length' "2"

  # Assert: Other settings fields preserved
  assert_json_field "$TEMP_REPO_CONFIG/settings.json" '.theme' "dark"
  assert_json_field "$TEMP_REPO_CONFIG/settings.json" '.model' "claude-sonnet-4-5"
}

@test "strips GITHUB_PERSONAL_ACCESS_TOKEN from settings.json env" {
  # Arrange: Load settings fixture (contains token in env)
  load_fixture "claude-backup/settings-full.json" "$TEMP_CLAUDE/settings.json"

  # Act: Sanitize settings
  sanitize_settings "$TEMP_CLAUDE/settings.json" "$TEMP_REPO_CONFIG/settings.json"

  # Assert: Token removed
  assert_json_field "$TEMP_REPO_CONFIG/settings.json" \
    '.env | has("GITHUB_PERSONAL_ACCESS_TOKEN")' "false"
}

@test "preserves non-sensitive env vars in settings.json" {
  # Arrange: Load settings fixture
  load_fixture "claude-backup/settings-full.json" "$TEMP_CLAUDE/settings.json"

  # Act: Sanitize settings
  sanitize_settings "$TEMP_CLAUDE/settings.json" "$TEMP_REPO_CONFIG/settings.json"

  # Assert: Non-sensitive env var preserved
  assert_json_field "$TEMP_REPO_CONFIG/settings.json" \
    '.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS' "1"
}

@test "handles settings.json with no env section" {
  # Arrange: Settings without env block
  echo '{"enabledPlugins": {"superpowers@claude-plugins-official": true}, "theme": "dark"}' \
    > "$TEMP_CLAUDE/settings.json"

  # Act: Sanitize settings
  sanitize_settings "$TEMP_CLAUDE/settings.json" "$TEMP_REPO_CONFIG/settings.json"

  # Assert: Output is valid JSON with other fields intact
  assert_json_field "$TEMP_REPO_CONFIG/settings.json" '.theme' "dark"
  assert_json_field "$TEMP_REPO_CONFIG/settings.json" '.env' "null"
}

@test "preserves JSON structure during sanitization" {
  # Arrange: Load fixture
  load_fixture "claude-backup/plugins-mixed.json" "$TEMP_CLAUDE_PLUGINS/installed_plugins.json"

  # Act: Run sanitization
  sanitize_plugins "$TEMP_CLAUDE_PLUGINS/installed_plugins.json" "$TEMP_REPO_CONFIG/installed_plugins.json"

  # Assert: Version field preserved
  assert_json_field "$TEMP_REPO_CONFIG/installed_plugins.json" ".version" "2"

  # Assert: Plugins is an object
  assert_json_field "$TEMP_REPO_CONFIG/installed_plugins.json" ".plugins | type" "object"
}

@test "handles malformed JSON gracefully" {
  # Arrange: Load malformed fixture
  load_fixture "claude-backup/plugins-malformed.json" "$TEMP_CLAUDE_PLUGINS/installed_plugins.json"

  # Act & Assert: Sanitization should fail with malformed input
  run sanitize_plugins "$TEMP_CLAUDE_PLUGINS/installed_plugins.json" "$TEMP_REPO_CONFIG/installed_plugins.json"

  # Should fail (non-zero exit code)
  [ "$status" -ne 0 ]
}

@test "handles missing source file gracefully" {
  # Arrange: No fixture loaded (file doesn't exist)

  # Act: Attempt sanitization with missing file
  run sanitize_plugins "$TEMP_CLAUDE_PLUGINS/nonexistent.json" "$TEMP_REPO_CONFIG/installed_plugins.json"

  # Assert: Should fail
  [ "$status" -ne 0 ]
}

@test "handles empty plugins object" {
  # Arrange: Create empty plugins file
  echo '{"version": 2, "plugins": {}}' > "$TEMP_CLAUDE_PLUGINS/installed_plugins.json"

  # Act: Run sanitization
  sanitize_plugins "$TEMP_CLAUDE_PLUGINS/installed_plugins.json" "$TEMP_REPO_CONFIG/installed_plugins.json"

  # Assert: Output is valid JSON with empty plugins
  assert_json_field "$TEMP_REPO_CONFIG/installed_plugins.json" ".plugins | length" "0"
  assert_json_field "$TEMP_REPO_CONFIG/installed_plugins.json" ".version" "2"
}

@test "handles all vend-plugins removed scenario" {
  # Arrange: Create file with only vend plugins
  cat > "$TEMP_CLAUDE_PLUGINS/installed_plugins.json" <<'EOF'
{
  "version": 2,
  "plugins": {
    "vend-internal@vend-plugins": {
      "version": "1.0.0",
      "installPath": "/Users/test/.claude/plugins/cache/vend-plugins/vend-internal/1.0.0"
    },
    "vend-api@vend-plugins": {
      "version": "2.0.0",
      "installPath": "/Users/test/.claude/plugins/cache/vend-plugins/vend-api/2.0.0"
    }
  }
}
EOF

  # Act: Run sanitization
  sanitize_plugins "$TEMP_CLAUDE_PLUGINS/installed_plugins.json" "$TEMP_REPO_CONFIG/installed_plugins.json"

  # Assert: Result should have empty plugins object
  assert_json_field "$TEMP_REPO_CONFIG/installed_plugins.json" ".plugins | length" "0"
}
