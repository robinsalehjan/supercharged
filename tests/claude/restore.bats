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

# Helper: Merge plugin configs for restore testing
# Note: Production (restore-claude.sh) uses dynamic jq filters built from the
# PRESERVE_MARKETPLACES array and iterates over each marketplace with per-marketplace
# error handling. This test hardcodes 'vend-plugins' for clarity. If new marketplaces
# are added to PRESERVE_MARKETPLACES, corresponding test cases should be added here.
merge_plugin_configs() {
  local repo_file="$1"
  local local_file="$2"
  local output_file="$3"

  set -o pipefail

  # If no local file, just expand repo config
  if [ ! -f "$local_file" ]; then
    expand_portable_path < "$repo_file" > "$output_file"
    set +o pipefail
    return 0
  fi

  # Extract vend-plugins from local config
  local local_vend
  if ! local_vend=$(jq '.plugins // {} | to_entries | map(select(.key | endswith("@vend-plugins"))) | from_entries' "$local_file" 2>&1); then
    echo "Failed to extract vend-plugins from local config: $local_vend" >&2
    set +o pipefail
    return 1
  fi

  # Get repo plugins and expand paths
  local repo_plugins
  if ! repo_plugins=$(expand_portable_path < "$repo_file" | jq '.plugins // {}' 2>&1); then
    echo "Failed to extract repo plugins: $repo_plugins" >&2
    set +o pipefail
    return 1
  fi

  # Merge: repo + local vend plugins (local takes precedence)
  local merged_plugins
  if ! merged_plugins=$(echo "$repo_plugins" | jq --argjson vend "$local_vend" '. + $vend' 2>&1); then
    echo "Failed to merge plugins: $merged_plugins" >&2
    set +o pipefail
    return 1
  fi

  # Get version from repo
  local version
  if ! version=$(jq '.version // 2' "$repo_file" 2>&1); then
    echo "Failed to extract version: $version" >&2
    set +o pipefail
    return 1
  fi

  # Build final merged object
  jq -n --argjson version "$version" --argjson plugins "$merged_plugins" '{version: $version, plugins: $plugins}' > "$output_file"
  local result=$?
  set +o pipefail
  return $result
}

# Helper: Merge marketplace configs for restore testing
# Mirrors merge_marketplace_config() from restore-claude.sh with hardcoded 'vend-plugins'
merge_marketplace_configs() {
  local repo_file="$1"
  local local_file="$2"
  local output_file="$3"

  set -o pipefail

  # If no local file, just expand repo config
  if [ ! -f "$local_file" ]; then
    expand_portable_path < "$repo_file" > "$output_file"
    set +o pipefail
    return 0
  fi

  local repo_content
  if ! repo_content=$(expand_portable_path < "$repo_file" 2>&1); then
    echo "Failed to expand repo file: $repo_content" >&2
    set +o pipefail
    return 1
  fi

  local local_content
  local_content=$(cat "$local_file")

  # Extract vend-plugins marketplace from local config
  local preserved
  if ! preserved=$(echo "$local_content" | jq 'if has("vend-plugins") then {"vend-plugins": .["vend-plugins"]} else {} end' 2>&1); then
    echo "Failed to extract marketplace: $preserved" >&2
    set +o pipefail
    return 1
  fi

  # Merge: repo + preserved local (local takes precedence)
  local merged
  if ! merged=$(echo "$repo_content" | jq --argjson preserved "$preserved" '. + $preserved' 2>&1); then
    echo "Failed to merge marketplaces: $merged" >&2
    set +o pipefail
    return 1
  fi

  echo "$merged" > "$output_file"
  set +o pipefail
}

# =============================================================================
# Plugin merge tests
# =============================================================================

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
  assert_json_field "$TEMP_CLAUDE_PLUGINS/merged.json" \
    '.plugins | to_entries | map(select(.key | endswith("@vend-plugins"))) | length' "0"
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
  assert_json_field "$TEMP_CLAUDE_PLUGINS/merged.json" \
    '.plugins | to_entries | map(select(.key | endswith("@vend-plugins"))) | length' "0"
}

# =============================================================================
# Marketplace merge tests
# =============================================================================

@test "marketplace merge preserves local vend-plugins marketplace" {
  # Arrange: repo has only official, local has both
  load_fixture "claude-restore/marketplaces-repo.json" "$TEMP_REPO_CONFIG/known_marketplaces.json"
  load_fixture "claude-restore/marketplaces-local.json" "$TEMP_CLAUDE_PLUGINS/known_marketplaces.json"

  # Act: Run marketplace merge
  merge_marketplace_configs \
    "$TEMP_REPO_CONFIG/known_marketplaces.json" \
    "$TEMP_CLAUDE_PLUGINS/known_marketplaces.json" \
    "$TEMP_CLAUDE_PLUGINS/merged_marketplaces.json"

  # Assert: Both marketplaces present
  assert_marketplace_exists "$TEMP_CLAUDE_PLUGINS/merged_marketplaces.json" "claude-plugins-official"
  assert_marketplace_exists "$TEMP_CLAUDE_PLUGINS/merged_marketplaces.json" "vend-plugins"
}

@test "marketplace merge creates new config when no local exists" {
  # Arrange: only repo config
  load_fixture "claude-restore/marketplaces-repo.json" "$TEMP_REPO_CONFIG/known_marketplaces.json"

  # Act: Run marketplace merge with no local file
  merge_marketplace_configs \
    "$TEMP_REPO_CONFIG/known_marketplaces.json" \
    "$TEMP_CLAUDE_PLUGINS/nonexistent.json" \
    "$TEMP_CLAUDE_PLUGINS/merged_marketplaces.json"

  # Assert: Only repo marketplace present, no vend-plugins
  assert_marketplace_exists "$TEMP_CLAUDE_PLUGINS/merged_marketplaces.json" "claude-plugins-official"
  assert_marketplace_not_exists "$TEMP_CLAUDE_PLUGINS/merged_marketplaces.json" "vend-plugins"
}

@test "marketplace merge handles empty local config" {
  # Arrange: repo has official, local is empty object
  load_fixture "claude-restore/marketplaces-repo.json" "$TEMP_REPO_CONFIG/known_marketplaces.json"
  echo '{}' > "$TEMP_CLAUDE_PLUGINS/known_marketplaces.json"

  # Act: Run marketplace merge
  merge_marketplace_configs \
    "$TEMP_REPO_CONFIG/known_marketplaces.json" \
    "$TEMP_CLAUDE_PLUGINS/known_marketplaces.json" \
    "$TEMP_CLAUDE_PLUGINS/merged_marketplaces.json"

  # Assert: Only repo marketplace present
  assert_marketplace_exists "$TEMP_CLAUDE_PLUGINS/merged_marketplaces.json" "claude-plugins-official"
  assert_marketplace_not_exists "$TEMP_CLAUDE_PLUGINS/merged_marketplaces.json" "vend-plugins"
}

# =============================================================================
# Error scenario tests
# =============================================================================

@test "plugin merge fails with malformed local JSON" {
  # Arrange: repo is valid, local is malformed
  load_fixture "claude-restore/repo-sanitized.json" "$TEMP_REPO_CONFIG/installed_plugins.json"
  echo '{"version": 2, "plugins": {bad json' > "$TEMP_CLAUDE_PLUGINS/installed_plugins.json"

  # Act & Assert: merge should fail
  run merge_plugin_configs \
    "$TEMP_REPO_CONFIG/installed_plugins.json" \
    "$TEMP_CLAUDE_PLUGINS/installed_plugins.json" \
    "$TEMP_CLAUDE_PLUGINS/merged.json"

  [ "$status" -ne 0 ]
}

@test "marketplace merge fails with malformed local JSON" {
  # Arrange: repo is valid, local is malformed
  load_fixture "claude-restore/marketplaces-repo.json" "$TEMP_REPO_CONFIG/known_marketplaces.json"
  echo '{bad json' > "$TEMP_CLAUDE_PLUGINS/known_marketplaces.json"

  # Act & Assert: merge should fail
  run merge_marketplace_configs \
    "$TEMP_REPO_CONFIG/known_marketplaces.json" \
    "$TEMP_CLAUDE_PLUGINS/known_marketplaces.json" \
    "$TEMP_CLAUDE_PLUGINS/merged_marketplaces.json"

  [ "$status" -ne 0 ]
}
