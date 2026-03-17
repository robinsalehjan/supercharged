#!/usr/bin/env bats

# Load test helpers
load '../helpers/setup'
load '../helpers/assertions'
load '../helpers/mocks'

setup() {
  setup_test_env

  # Get project root
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

  # Source utils.sh for expand_portable_path function
  source "$PROJECT_ROOT/scripts/utils.sh"
}

teardown() {
  teardown_test_env
}

# Helper function to simulate restore merge
# This mimics the logic from restore-claude.sh
merge_plugin_configs() {
  local repo_file="$1"
  local local_file="$2"
  local output_file="$3"

  # If no local file, just expand repo config
  if [ ! -f "$local_file" ]; then
    expand_portable_path < "$repo_file" > "$output_file"
    return 0
  fi

  # Extract vend-plugins from local config
  local local_vend
  local_vend=$(jq '.plugins // {} | to_entries | map(select(.key | endswith("@vend-plugins"))) | from_entries' "$local_file")

  # Get repo plugins and expand paths
  local repo_plugins
  repo_plugins=$(expand_portable_path < "$repo_file" | jq '.plugins // {}')

  # Merge: repo + local vend plugins (local takes precedence)
  local merged_plugins
  merged_plugins=$(echo "$repo_plugins" | jq --argjson vend "$local_vend" '. + $vend')

  # Get version from repo
  local version
  version=$(jq '.version // 2' "$repo_file")

  # Build final merged object
  jq -n --argjson version "$version" --argjson plugins "$merged_plugins" '{version: $version, plugins: $plugins}' > "$output_file"
}

@test "merges repo config with preserved local vend-plugins" {
  # Arrange: Load fixtures
  load_fixture "claude-restore/repo-sanitized.json" "$TEMP_REPO_CONFIG/installed_plugins.json"
  load_fixture "claude-restore/local-with-vend.json" "$TEMP_CLAUDE_PLUGINS/installed_plugins.json"

  # Act: Run merge
  merge_plugin_configs \
    "$TEMP_REPO_CONFIG/installed_plugins.json" \
    "$TEMP_CLAUDE_PLUGINS/installed_plugins.json" \
    "$TEMP_CLAUDE_PLUGINS/merged.json"

  # Assert: Repo plugins present
  assert_plugin_exists "$TEMP_CLAUDE_PLUGINS/merged.json" "superpowers@claude-plugins-official"
  assert_plugin_exists "$TEMP_CLAUDE_PLUGINS/merged.json" "hookify@claude-plugins-official"

  # Assert: Local vend plugin preserved
  assert_plugin_exists "$TEMP_CLAUDE_PLUGINS/merged.json" "vend-internal@vend-plugins"

  # Assert: Old plugin not present (repo takes precedence for non-vend)
  assert_plugin_not_exists "$TEMP_CLAUDE_PLUGINS/merged.json" "old-plugin@claude-plugins-official"
}

@test "creates new config when no local config exists" {
  # Arrange: Load repo fixture only (no local)
  load_fixture "claude-restore/repo-sanitized.json" "$TEMP_REPO_CONFIG/installed_plugins.json"

  # Act: Run merge with no local file
  merge_plugin_configs \
    "$TEMP_REPO_CONFIG/installed_plugins.json" \
    "$TEMP_CLAUDE_PLUGINS/nonexistent.json" \
    "$TEMP_CLAUDE_PLUGINS/merged.json"

  # Assert: Repo plugins present
  assert_plugin_exists "$TEMP_CLAUDE_PLUGINS/merged.json" "superpowers@claude-plugins-official"
  assert_plugin_exists "$TEMP_CLAUDE_PLUGINS/merged.json" "hookify@claude-plugins-official"

  # Assert: No vend plugins
  local vend_count
  vend_count=$(jq '.plugins | to_entries | map(select(.key | endswith("@vend-plugins"))) | length' "$TEMP_CLAUDE_PLUGINS/merged.json")
  [ "$vend_count" -eq 0 ]
}

@test "expands \$HOME placeholder to actual home directory" {
  # Arrange: Load repo fixture with $HOME placeholder
  load_fixture "claude-restore/repo-sanitized.json" "$TEMP_REPO_CONFIG/installed_plugins.json"

  # Act: Run merge (which calls expand_portable_path)
  merge_plugin_configs \
    "$TEMP_REPO_CONFIG/installed_plugins.json" \
    "$TEMP_CLAUDE_PLUGINS/nonexistent.json" \
    "$TEMP_CLAUDE_PLUGINS/merged.json"

  # Assert: Paths expanded to actual HOME value
  local path
  path=$(jq -r '.plugins["superpowers@claude-plugins-official"].installPath' "$TEMP_CLAUDE_PLUGINS/merged.json")

  # Path should start with the actual HOME directory (our temp dir in tests)
  [[ "$path" == "$HOME"* ]] || {
    echo "Expected path to start with $HOME, got: $path"
    return 1
  }

  # Path should NOT contain the literal string "\$HOME"
  [[ "$path" != *"\$HOME"* ]] || {
    echo "Path should not contain literal \$HOME, got: $path"
    return 1
  }
}

@test "preserves multiple vend-plugins during merge" {
  # Arrange: Create local config with multiple vend plugins
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
    },
    "vend-tools@vend-plugins": {
      "version": "3.0.0",
      "installPath": "/Users/test/.claude/plugins/cache/vend-plugins/vend-tools/3.0.0"
    }
  }
}
EOF

  load_fixture "claude-restore/repo-sanitized.json" "$TEMP_REPO_CONFIG/installed_plugins.json"

  # Act: Run merge
  merge_plugin_configs \
    "$TEMP_REPO_CONFIG/installed_plugins.json" \
    "$TEMP_CLAUDE_PLUGINS/installed_plugins.json" \
    "$TEMP_CLAUDE_PLUGINS/merged.json"

  # Assert: All three vend plugins preserved
  assert_plugin_exists "$TEMP_CLAUDE_PLUGINS/merged.json" "vend-internal@vend-plugins"
  assert_plugin_exists "$TEMP_CLAUDE_PLUGINS/merged.json" "vend-api@vend-plugins"
  assert_plugin_exists "$TEMP_CLAUDE_PLUGINS/merged.json" "vend-tools@vend-plugins"

  # Assert: Repo plugins also present
  assert_plugin_exists "$TEMP_CLAUDE_PLUGINS/merged.json" "superpowers@claude-plugins-official"
}

@test "handles empty local plugins during merge" {
  # Arrange: Create empty local config
  echo '{"version": 2, "plugins": {}}' > "$TEMP_CLAUDE_PLUGINS/installed_plugins.json"
  load_fixture "claude-restore/repo-sanitized.json" "$TEMP_REPO_CONFIG/installed_plugins.json"

  # Act: Run merge
  merge_plugin_configs \
    "$TEMP_REPO_CONFIG/installed_plugins.json" \
    "$TEMP_CLAUDE_PLUGINS/installed_plugins.json" \
    "$TEMP_CLAUDE_PLUGINS/merged.json"

  # Assert: Repo plugins present
  assert_plugin_exists "$TEMP_CLAUDE_PLUGINS/merged.json" "superpowers@claude-plugins-official"
  assert_plugin_exists "$TEMP_CLAUDE_PLUGINS/merged.json" "hookify@claude-plugins-official"

  # Assert: No vend plugins added
  local vend_count
  vend_count=$(jq '.plugins | to_entries | map(select(.key | endswith("@vend-plugins"))) | length' "$TEMP_CLAUDE_PLUGINS/merged.json")
  [ "$vend_count" -eq 0 ]
}
