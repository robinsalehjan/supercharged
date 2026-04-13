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

@test "preserves ANSI escape sequences in JSON strings" {
  # Arrange: Create JSON with ANSI color codes (like statusLine command)
  cat > "$TEST_TEMP_DIR/input.json" <<'EOF'
{
  "statusLine": {
    "type": "command",
    "command": "printf \"\\033[36m%s\\033[0m:\\033[34m%s\\033[0m\" \"user\" \"dir\""
  }
}
EOF

  # Act: Round-trip through portable and back
  make_path_portable < "$TEST_TEMP_DIR/input.json" > "$TEST_TEMP_DIR/portable.json"
  expand_portable_path < "$TEST_TEMP_DIR/portable.json" > "$TEST_TEMP_DIR/restored.json"

  # Assert: JSON files are identical (structure and escape sequences preserved)
  diff <(jq -S . "$TEST_TEMP_DIR/input.json") <(jq -S . "$TEST_TEMP_DIR/restored.json") || {
    echo "Round-trip did not preserve JSON structure and escape sequences"
    return 1
  }

  # Assert: Escape sequences are present in JSON representation (not interpreted)
  grep '\\033' "$TEST_TEMP_DIR/restored.json" || {
    echo "Expected \\\\033 in restored JSON file"
    cat "$TEST_TEMP_DIR/restored.json"
    return 1
  }
}

@test "preserves unicode escape sequences in JSON strings" {
  # Arrange: Create JSON with unicode escapes
  cat > "$TEST_TEMP_DIR/input.json" <<'EOF'
{
  "text": "Hello \\u0041\\u0042\\u0043",
  "emoji": "Test \\uD83D\\uDE00 emoji"
}
EOF

  # Act: Round-trip
  make_path_portable < "$TEST_TEMP_DIR/input.json" > "$TEST_TEMP_DIR/portable.json"
  expand_portable_path < "$TEST_TEMP_DIR/portable.json" > "$TEST_TEMP_DIR/restored.json"

  # Assert: Unicode escapes preserved
  diff <(jq -S . "$TEST_TEMP_DIR/input.json") <(jq -S . "$TEST_TEMP_DIR/restored.json") || {
    echo "Unicode escape sequences not preserved"
    return 1
  }
}

@test "preserves JSON escape sequences with $HOME placeholders" {
  # Arrange: Create JSON with both escape sequences AND $HOME paths
  # Use jq to build the JSON to ensure proper escaping
  jq -n --arg home "$HOME" '{
    hooks: {
      command: ($home + "/.claude/hooks/test.sh")
    },
    statusLine: {
      command: "printf \"\\u001b[36m%s\\u001b[0m\" \"test\""
    }
  }' > "$TEST_TEMP_DIR/input.json"

  # Act: Make portable then expand
  make_path_portable < "$TEST_TEMP_DIR/input.json" > "$TEST_TEMP_DIR/portable.json"
  expand_portable_path < "$TEST_TEMP_DIR/portable.json" > "$TEST_TEMP_DIR/restored.json"

  # Assert: Valid JSON after round-trip
  jq empty "$TEST_TEMP_DIR/restored.json" || {
    echo "Restored JSON is invalid"
    cat "$TEST_TEMP_DIR/restored.json"
    return 1
  }

  # Assert: Paths expanded correctly
  local hooks_cmd
  hooks_cmd=$(jq -r '.hooks.command' "$TEST_TEMP_DIR/restored.json")
  [[ "$hooks_cmd" == "$HOME/.claude/hooks/test.sh" ]] || {
    echo "Expected $HOME/.claude/hooks/test.sh, got: $hooks_cmd"
    return 1
  }

  # Assert: Escape sequences preserved (check JSON contains \u001b, not interpreted ESC)
  grep -q '\\u001b' "$TEST_TEMP_DIR/restored.json" || {
    echo "Expected \\u001b in restored JSON file"
    cat "$TEST_TEMP_DIR/restored.json"
    return 1
  }
}

@test "preserves complex escape sequences in real settings.json" {
  # Arrange: Create JSON matching actual Claude Code settings.json structure
  # Use jq to build it with proper escaping (jq uses \u001b for ESC)
  jq -n --arg home "$HOME" '{
    hooks: {
      PreToolUse: [
        {
          matcher: "Bash",
          hooks: [
            {
              type: "command",
              command: ($home + "/.claude/hooks/rtk-rewrite.sh")
            }
          ]
        }
      ]
    },
    statusLine: {
      type: "command",
      command: "input=$(cat); printf \"\\u001b[36m%s\\u001b[0m:\\u001b[34m%s\\u001b[0m\" \"user\" \"dir\""
    }
  }' > "$TEST_TEMP_DIR/settings.json"

  # Act: Backup (make portable) then restore (expand)
  make_path_portable < "$TEST_TEMP_DIR/settings.json" > "$TEST_TEMP_DIR/backup.json"
  expand_portable_path < "$TEST_TEMP_DIR/backup.json" > "$TEST_TEMP_DIR/restored.json"

  # Assert: Valid JSON after round-trip
  jq empty "$TEST_TEMP_DIR/restored.json" || {
    echo "Restored JSON is invalid"
    cat "$TEST_TEMP_DIR/restored.json"
    return 1
  }

  # Assert: Hook command expanded
  local hook_cmd
  hook_cmd=$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$TEST_TEMP_DIR/restored.json")
  [[ "$hook_cmd" == "$HOME/.claude/hooks/rtk-rewrite.sh" ]] || {
    echo "Hook command not expanded correctly: $hook_cmd"
    return 1
  }

  # Assert: StatusLine escape sequences preserved in JSON (as \u001b)
  grep -q '\\u001b\[36m' "$TEST_TEMP_DIR/restored.json" || {
    echo "StatusLine ANSI cyan code not preserved in JSON"
    cat "$TEST_TEMP_DIR/restored.json"
    return 1
  }

  grep -q '\\u001b\[0m' "$TEST_TEMP_DIR/restored.json" || {
    echo "StatusLine ANSI reset not preserved in JSON"
    cat "$TEST_TEMP_DIR/restored.json"
    return 1
  }

  grep -q '\\u001b\[34m' "$TEST_TEMP_DIR/restored.json" || {
    echo "StatusLine ANSI blue code not preserved in JSON"
    cat "$TEST_TEMP_DIR/restored.json"
    return 1
  }
}

@test "handles non-JSON files gracefully" {
  # Arrange: Create a plain text file with $HOME
  cat > "$TEST_TEMP_DIR/plain.txt" <<EOF
This is a plain text file
HOME=$HOME
PATH=$HOME/bin
EOF

  # Act: Run through portability functions
  make_path_portable < "$TEST_TEMP_DIR/plain.txt" > "$TEST_TEMP_DIR/portable.txt"
  expand_portable_path < "$TEST_TEMP_DIR/portable.txt" > "$TEST_TEMP_DIR/restored.txt"

  # Assert: Plain text processing works (via sed fallback)
  grep "HOME=\$HOME" "$TEST_TEMP_DIR/portable.txt" || {
    echo "Plain text make_path_portable failed"
    cat "$TEST_TEMP_DIR/portable.txt"
    return 1
  }

  grep "HOME=$HOME" "$TEST_TEMP_DIR/restored.txt" || {
    echo "Plain text expand_portable_path failed"
    cat "$TEST_TEMP_DIR/restored.txt"
    return 1
  }
}
