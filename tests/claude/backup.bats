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

# Helper function to simulate backup sanitization
# This mimics the logic from backup-claude.sh
sanitize_plugins() {
  local input_file="$1"
  local output_file="$2"

  # Build jq filter to remove vend-plugins entries
  # Use ORIGINAL_HOME for path replacement since HOME is overridden in tests
  jq '{version: .version, plugins: (.plugins | to_entries | map(select(.key | endswith("@vend-plugins") | not)) | from_entries)}' \
    "$input_file" | sed "s|$ORIGINAL_HOME|\$HOME|g" > "$output_file"
}

sanitize_marketplaces() {
  local input_file="$1"
  local output_file="$2"

  # Remove vend-plugins marketplace
  jq 'del(.["vend-plugins"])' "$input_file" | sed "s|$ORIGINAL_HOME|\$HOME|g" > "$output_file"
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

  # Act: Sanitize settings (remove vend-plugins from enabledPlugins)
  jq '{enabledPlugins: (.enabledPlugins | to_entries | map(select(.key | endswith("@vend-plugins") | not)) | from_entries)} + (. | del(.enabledPlugins))' \
    "$TEMP_CLAUDE/settings.json" | sed "s|$ORIGINAL_HOME|\$HOME|g" > "$TEMP_REPO_CONFIG/settings.json"

  # Assert: Vend plugins removed from enabledPlugins
  local vend_in_enabled
  vend_in_enabled=$(jq '.enabledPlugins | to_entries | map(select(.key | endswith("@vend-plugins"))) | length' "$TEMP_REPO_CONFIG/settings.json")
  [ "$vend_in_enabled" -eq 0 ] || {
    echo "Expected no vend-plugins in enabledPlugins, found $vend_in_enabled"
    return 1
  }

  # Assert: Personal plugins preserved
  local personal_count
  personal_count=$(jq '.enabledPlugins | to_entries | map(select(.key | endswith("@claude-plugins-official"))) | length' "$TEMP_REPO_CONFIG/settings.json")
  [ "$personal_count" -eq 2 ] || {
    echo "Expected 2 personal plugins in enabledPlugins, found $personal_count"
    return 1
  }

  # Assert: Other settings fields preserved
  assert_json_field "$TEMP_REPO_CONFIG/settings.json" '.theme' "dark"
  assert_json_field "$TEMP_REPO_CONFIG/settings.json" '.model' "claude-sonnet-4-5"
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
