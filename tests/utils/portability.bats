#!/usr/bin/env bats

# Load test helpers
load '../helpers/setup'
load '../helpers/assertions'

setup() {
  setup_test_env

  # Get project root
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

  # Source utils.sh for path functions
  source "$PROJECT_ROOT/scripts/utils.sh"
}

teardown() {
  teardown_test_env
}

@test "make_path_portable replaces home directory with \$HOME" {
  # Arrange: Create JSON with absolute home paths
  cat > "$TEST_TEMP_DIR/input.json" <<EOF
{
  "path": "$HOME/.claude/plugins/test",
  "nested": {
    "path": "$HOME/Documents/test"
  }
}
EOF

  # Act: Run make_path_portable
  make_path_portable < "$TEST_TEMP_DIR/input.json" > "$TEST_TEMP_DIR/output.json"

  # Assert: Paths replaced with $HOME
  local path1
  path1=$(jq -r '.path' "$TEST_TEMP_DIR/output.json")
  [[ "$path1" == "\$HOME/.claude/plugins/test" ]] || {
    echo "Expected path to be \$HOME/.claude/plugins/test, got: $path1"
    return 1
  }

  local path2
  path2=$(jq -r '.nested.path' "$TEST_TEMP_DIR/output.json")
  [[ "$path2" == "\$HOME/Documents/test" ]] || {
    echo "Expected nested path to be \$HOME/Documents/test, got: $path2"
    return 1
  }
}

@test "expand_portable_path replaces \$HOME with actual directory" {
  # Arrange: Create JSON with $HOME placeholders
  cat > "$TEST_TEMP_DIR/input.json" <<'EOF'
{
  "path": "$HOME/.claude/plugins/test",
  "nested": {
    "path": "$HOME/Documents/test"
  }
}
EOF

  # Act: Run expand_portable_path
  expand_portable_path < "$TEST_TEMP_DIR/input.json" > "$TEST_TEMP_DIR/output.json"

  # Assert: Paths expanded to actual HOME
  local path1
  path1=$(jq -r '.path' "$TEST_TEMP_DIR/output.json")
  [[ "$path1" == "$HOME/.claude/plugins/test" ]] || {
    echo "Expected path to be $HOME/.claude/plugins/test, got: $path1"
    return 1
  }

  # Should NOT contain literal $HOME
  [[ "$path1" != *"\$HOME"* ]] || {
    echo "Path should not contain literal \$HOME, got: $path1"
    return 1
  }
}

@test "round-trip preserves JSON structure and data" {
  # Arrange: Create complex JSON
  cat > "$TEST_TEMP_DIR/original.json" <<EOF
{
  "version": 2,
  "plugins": {
    "test@marketplace": {
      "version": "1.0.0",
      "installPath": "$HOME/.claude/plugins/cache/test/1.0.0",
      "metadata": {
        "enabled": true,
        "priority": 10
      }
    }
  }
}
EOF

  # Act: Round-trip through portable and back
  make_path_portable < "$TEST_TEMP_DIR/original.json" > "$TEST_TEMP_DIR/portable.json"
  expand_portable_path < "$TEST_TEMP_DIR/portable.json" > "$TEST_TEMP_DIR/restored.json"

  # Assert: Structure preserved (compare normalized JSON)
  diff <(jq -S . "$TEST_TEMP_DIR/original.json") <(jq -S . "$TEST_TEMP_DIR/restored.json") || {
    echo "Round-trip did not preserve JSON structure"
    return 1
  }
}

@test "handles multiple paths in same JSON file" {
  # Arrange: Create JSON with multiple paths
  cat > "$TEST_TEMP_DIR/input.json" <<EOF
{
  "paths": [
    "$HOME/.claude/config",
    "$HOME/.ssh/keys",
    "$HOME/Downloads"
  ]
}
EOF

  # Act: Make portable
  make_path_portable < "$TEST_TEMP_DIR/input.json" > "$TEST_TEMP_DIR/output.json"

  # Assert: All paths converted
  local converted_paths
  converted_paths=$(jq -r '.paths[]' "$TEST_TEMP_DIR/output.json")

  while IFS= read -r path; do
    [[ "$path" == "\$HOME"* ]] || {
      echo "Expected all paths to start with \$HOME, got: $path"
      return 1
    }
  done < <(echo "$converted_paths")
}

@test "preserves paths that don't contain HOME" {
  # Arrange: Create JSON with mixed paths
  cat > "$TEST_TEMP_DIR/input.json" <<EOF
{
  "home_path": "$HOME/.claude",
  "system_path": "/usr/local/bin",
  "relative_path": "./local/path"
}
EOF

  # Act: Make portable
  make_path_portable < "$TEST_TEMP_DIR/input.json" > "$TEST_TEMP_DIR/output.json"

  # Assert: Only home_path changed
  assert_json_field "$TEST_TEMP_DIR/output.json" '.home_path' "\$HOME/.claude"
  assert_json_field "$TEST_TEMP_DIR/output.json" '.system_path' "/usr/local/bin"
  assert_json_field "$TEST_TEMP_DIR/output.json" '.relative_path' "./local/path"
}

@test "handles empty JSON objects" {
  # Arrange: Create empty JSON
  echo '{}' > "$TEST_TEMP_DIR/input.json"

  # Act: Make portable
  make_path_portable < "$TEST_TEMP_DIR/input.json" > "$TEST_TEMP_DIR/output.json"

  # Assert: Still valid empty JSON
  assert_json_field "$TEST_TEMP_DIR/output.json" '. | type' "object"
  assert_json_field "$TEST_TEMP_DIR/output.json" '. | length' "0"
}

@test "handles nested paths in JSON objects" {
  # Arrange: Create deeply nested JSON
  cat > "$TEST_TEMP_DIR/input.json" <<EOF
{
  "level1": {
    "level2": {
      "level3": {
        "path": "$HOME/.claude/deep/path"
      }
    }
  }
}
EOF

  # Act: Make portable
  make_path_portable < "$TEST_TEMP_DIR/input.json" > "$TEST_TEMP_DIR/output.json"

  # Assert: Deep path converted
  assert_json_field "$TEST_TEMP_DIR/output.json" '.level1.level2.level3.path' "\$HOME/.claude/deep/path"
}
