#!/usr/bin/env bats

# Load test helpers
load '../helpers/setup'
load '../helpers/assertions'
load '../helpers/mocks'

# Override TEST_SANITIZE_MARKETPLACES in setup() to test non-default marketplaces

# Setup runs before each test
setup() {
  setup_test_env

  # Get project root (two levels up from tests/claude/)
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

  # Source utils.sh for make_path_portable function
  source "$PROJECT_ROOT/scripts/utils.sh"

  # Test configuration: define which marketplaces to sanitize
  TEST_SANITIZE_MARKETPLACES=("vend-plugins")
}

# Teardown runs after each test
teardown() {
  teardown_test_env
}

# Exercise the production transformations in their native shell.
sanitize_plugins() {
  local input_file="$1" output_file="$2"
  HOME="$HOME" zsh -c 'source "$1"; sanitize_claude_plugins "$2" "$3"' \
    _ "$PROJECT_ROOT/scripts/backup-claude.sh" "$input_file" "$output_file"
}

sanitize_marketplaces() {
  local input_file="$1" output_file="$2"
  HOME="$HOME" zsh -c 'source "$1"; sanitize_claude_marketplaces "$2" "$3"' \
    _ "$PROJECT_ROOT/scripts/backup-claude.sh" "$input_file" "$output_file"
}

sanitize_settings() {
  local input_file="$1" output_file="$2"
  HOME="$HOME" zsh -c 'source "$1"; sanitize_claude_settings "$2" "$3"' \
    _ "$PROJECT_ROOT/scripts/backup-claude.sh" "$input_file" "$output_file"
}

@test "removes vend-plugins entries from installed_plugins.json" {
  # Arrange: Load fixture
  load_fixture "claude-backup/plugins-mixed.json" "$TEMP_CLAUDE_PLUGINS/installed_plugins.json"

  # Act: Run sanitization
  sanitize_plugins "$TEMP_CLAUDE_PLUGINS/installed_plugins.json" "$TEMP_REPO_CONFIG/installed_plugins.json" "${TEST_SANITIZE_MARKETPLACES[@]}"

  # Assert: Vend plugins removed
  assert_plugin_not_exists "$TEMP_REPO_CONFIG/installed_plugins.json" "vend-internal@vend-plugins"
  assert_plugin_not_exists "$TEMP_REPO_CONFIG/installed_plugins.json" "vend-api@vend-plugins"

  # Assert: Personal plugins preserved
  assert_plugin_exists "$TEMP_REPO_CONFIG/installed_plugins.json" "superpowers@claude-plugins-official"
  assert_plugin_exists "$TEMP_REPO_CONFIG/installed_plugins.json" "hookify@claude-plugins-official"
}

@test "complete backup command sanitizes an isolated repository copy" {
  repo_copy="$TEST_TEMP_DIR/repository"
  mkdir -p "$repo_copy"
  cp -R "$PROJECT_ROOT/scripts" "$PROJECT_ROOT/agent_config" "$PROJECT_ROOT/claude_config" "$repo_copy/"
  load_fixture "claude-backup/settings-full.json" "$HOME/.claude/settings.json"
  load_fixture "claude-backup/plugins-mixed.json" "$HOME/.claude/plugins/installed_plugins.json"
  load_fixture "shared/marketplaces-with-vend.json" "$HOME/.claude/plugins/known_marketplaces.json"

  run env HOME="$HOME" zsh "$repo_copy/scripts/backup-claude.sh"

  [ "$status" -eq 0 ]
  [ "$(jq '[.plugins | keys[] | select(endswith("@vend-plugins"))] | length' "$repo_copy/claude_config/installed_plugins.json")" -eq 0 ]
  [ "$(jq 'has("vend-plugins")' "$repo_copy/claude_config/known_marketplaces.json")" = false ]
  [ "$(jq '.env | has("GITHUB_PERSONAL_ACCESS_TOKEN")' "$repo_copy/claude_config/settings.json")" = false ]
}

@test "backup-claude.sh guards CLAUDE.md @ references" {
  run grep -F 'is_safe_markdown_ref "$ref_file"' "$PROJECT_ROOT/scripts/backup-claude.sh"
  [ "$status" -eq 0 ]
}

@test "removes vend-plugins marketplace from known_marketplaces.json" {
  # Arrange: Load fixture
  load_fixture "shared/marketplaces-with-vend.json" "$TEMP_CLAUDE_PLUGINS/known_marketplaces.json"

  # Act: Run sanitization
  sanitize_marketplaces "$TEMP_CLAUDE_PLUGINS/known_marketplaces.json" "$TEMP_REPO_CONFIG/known_marketplaces.json" "${TEST_SANITIZE_MARKETPLACES[@]}"

  # Assert: Vend marketplace removed
  assert_marketplace_not_exists "$TEMP_REPO_CONFIG/known_marketplaces.json" "vend-plugins"

  # Assert: Personal marketplace preserved
  assert_marketplace_exists "$TEMP_REPO_CONFIG/known_marketplaces.json" "claude-plugins-official"
}

@test "makes paths portable by replacing HOME directory" {
  # Arrange: Load fixture with absolute paths
  load_fixture "claude-backup/plugins-mixed.json" "$TEMP_CLAUDE_PLUGINS/installed_plugins.json"

  # Act: Run sanitization (includes make_path_portable)
  sanitize_plugins "$TEMP_CLAUDE_PLUGINS/installed_plugins.json" "$TEMP_REPO_CONFIG/installed_plugins.json" "${TEST_SANITIZE_MARKETPLACES[@]}"

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
  sanitize_settings "$TEMP_CLAUDE/settings.json" "$TEMP_REPO_CONFIG/settings.json" "${TEST_SANITIZE_MARKETPLACES[@]}"

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
  sanitize_settings "$TEMP_CLAUDE/settings.json" "$TEMP_REPO_CONFIG/settings.json" "${TEST_SANITIZE_MARKETPLACES[@]}"

  # Assert: Token removed
  assert_json_field "$TEMP_REPO_CONFIG/settings.json" \
    '.env | has("GITHUB_PERSONAL_ACCESS_TOKEN")' "false"
}

@test "removes legacy MCP servers from settings.json" {
  load_fixture "claude-backup/settings-full.json" "$TEMP_CLAUDE/settings.json"

  sanitize_settings "$TEMP_CLAUDE/settings.json" "$TEMP_REPO_CONFIG/settings.json" "${TEST_SANITIZE_MARKETPLACES[@]}"

  assert_json_field "$TEMP_REPO_CONFIG/settings.json" 'has("mcpServers")' "false"
}

@test "backup does not import live user-scoped MCP definitions" {
  run grep -E 'CLAUDE_USER_CONFIG|HOME/\.claude\.json|HOME/.claude.json' "$PROJECT_ROOT/scripts/backup-claude.sh"
  [ "$status" -eq 1 ]
}

@test "preserves non-sensitive env vars in settings.json" {
  # Arrange: Load settings fixture
  load_fixture "claude-backup/settings-full.json" "$TEMP_CLAUDE/settings.json"

  # Act: Sanitize settings
  sanitize_settings "$TEMP_CLAUDE/settings.json" "$TEMP_REPO_CONFIG/settings.json" "${TEST_SANITIZE_MARKETPLACES[@]}"

  # Assert: Non-sensitive env var preserved
  assert_json_field "$TEMP_REPO_CONFIG/settings.json" \
    '.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS' "1"
}

@test "handles settings.json with no env section" {
  # Arrange: Settings without env block
  echo '{"enabledPlugins": {"superpowers@claude-plugins-official": true}, "theme": "dark"}' \
    > "$TEMP_CLAUDE/settings.json"

  # Act: Sanitize settings
  sanitize_settings "$TEMP_CLAUDE/settings.json" "$TEMP_REPO_CONFIG/settings.json" "${TEST_SANITIZE_MARKETPLACES[@]}"

  # Assert: Output is valid JSON with other fields intact
  assert_json_field "$TEMP_REPO_CONFIG/settings.json" '.theme' "dark"
  assert_json_field "$TEMP_REPO_CONFIG/settings.json" '.env' "null"
}

@test "preserves JSON structure during sanitization" {
  # Arrange: Load fixture
  load_fixture "claude-backup/plugins-mixed.json" "$TEMP_CLAUDE_PLUGINS/installed_plugins.json"

  # Act: Run sanitization
  sanitize_plugins "$TEMP_CLAUDE_PLUGINS/installed_plugins.json" "$TEMP_REPO_CONFIG/installed_plugins.json" "${TEST_SANITIZE_MARKETPLACES[@]}"

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

@test "removes unmanaged statusLine configuration during backup" {
  load_fixture "claude-backup/settings-with-ansi.json" "$TEMP_CLAUDE/settings.json"
  jq '.statusLine = {type: "command", command: "legacy-statusline"}' \
    "$TEMP_CLAUDE/settings.json" > "$TEMP_CLAUDE/settings.json.tmp"
  mv "$TEMP_CLAUDE/settings.json.tmp" "$TEMP_CLAUDE/settings.json"

  sanitize_settings "$TEMP_CLAUDE/settings.json" "$TEMP_REPO_CONFIG/settings.json" "${TEST_SANITIZE_MARKETPLACES[@]}"

  assert_json_field "$TEMP_REPO_CONFIG/settings.json" 'has("statusLine")' "false"
}

@test "normalizes durable Claude settings and removes transient state" {
  load_fixture "claude-backup/settings-full.json" "$TEMP_CLAUDE/settings.json"
  jq '
    .additionalDirectories = ["~/Repositories"] |
    .skipDangerousModePermissionPrompt = true |
    .skipAutoPermissionPrompt = true |
    .env.MAX_THINKING_TOKENS = "64000"
  ' "$TEMP_CLAUDE/settings.json" > "$TEMP_CLAUDE/settings.json.tmp"
  mv "$TEMP_CLAUDE/settings.json.tmp" "$TEMP_CLAUDE/settings.json"

  sanitize_settings "$TEMP_CLAUDE/settings.json" "$TEMP_REPO_CONFIG/settings.json" "${TEST_SANITIZE_MARKETPLACES[@]}"

  run jq -e '
    .["$schema"] == "https://json.schemastore.org/claude-code-settings.json" and
    .permissions.additionalDirectories == ["~/Repositories"] and
    (has("additionalDirectories") | not) and
    (has("skipDangerousModePermissionPrompt") | not) and
    (has("skipAutoPermissionPrompt") | not) and
    ((.env // {}) | has("MAX_THINKING_TOKENS") | not)
  ' "$TEMP_REPO_CONFIG/settings.json"
  [ "$status" -eq 0 ]
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
  sanitize_plugins "$TEMP_CLAUDE_PLUGINS/installed_plugins.json" "$TEMP_REPO_CONFIG/installed_plugins.json" "${TEST_SANITIZE_MARKETPLACES[@]}"

  # Assert: Result should have empty plugins object
  assert_json_field "$TEMP_REPO_CONFIG/installed_plugins.json" ".plugins | length" "0"
}
