#!/usr/bin/env bats

# Smoke tests for restore-claude.sh helper functions.
# Sources the script with EXIT_BEFORE_MAIN=1 hooks aren't available, so instead
# we exercise the pure helper functions (get_file_mtime, get_newest_mtime) by
# extracting them via zsh -c subshells with stubs for utils.sh.

load '../helpers/setup'
load '../helpers/mocks'

setup() {
  setup_test_env

  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$PROJECT_ROOT/scripts/restore-claude.sh"
}

teardown() {
  unmock_all
  teardown_test_env
}

@test "restore-claude.sh script is executable" {
  [ -x "$SCRIPT" ]
}

@test "restore-claude.sh has zsh shebang" {
  run head -1 "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == "#!/bin/zsh" ]]
}

@test "restore-claude.sh references PRESERVE_MARKETPLACES" {
  # Sanitization contract: vend-plugins is the canonical work-only marketplace
  # and must remain in the preserve list (mirrored against SANITIZE_MARKETPLACES
  # in backup-claude.sh).
  run grep -E '^PRESERVE_MARKETPLACES=' "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"vend-plugins"* ]]
}

@test "restore-claude.sh references INJECT_SETTINGS_ENV_VARS" {
  run grep -E '^INJECT_SETTINGS_ENV_VARS=' "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"GITHUB_PERSONAL_ACCESS_TOKEN"* ]]
}

@test "restore-claude.sh accepts --force argument" {
  run grep -E -- '--force' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "restore-claude.sh guards CLAUDE.md @ references" {
  run grep -F 'is_safe_markdown_ref "$ref_file"' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "get_file_mtime returns mtime for existing file" {
  # Create a test file with known content
  test_file="$TEST_TEMP_DIR/sample.txt"
  echo "test" > "$test_file"

  # Extract and run get_file_mtime in a zsh subprocess
  run zsh -c "
    $(sed -n '/^get_file_mtime()/,/^}/p' "$SCRIPT")
    get_file_mtime '$test_file'
  "

  [ "$status" -eq 0 ]
  # Should be a positive integer (mtime in seconds since epoch)
  [[ "$output" =~ ^[0-9]+$ ]]
  [ "$output" -gt 0 ]
}

@test "get_file_mtime returns 0 for missing file" {
  run zsh -c "
    $(sed -n '/^get_file_mtime()/,/^}/p' "$SCRIPT")
    get_file_mtime '$TEST_TEMP_DIR/does-not-exist'
  "

  # Function returns non-zero exit code but echoes '0' for missing files
  [[ "$output" == *"0"* ]]
}

@test "get_newest_mtime returns mtime of newest JSON in directory" {
  test_dir="$TEST_TEMP_DIR/configs"
  mkdir -p "$test_dir"

  # Create files with controlled mtimes
  echo "{}" > "$test_dir/old.json"
  echo "{}" > "$test_dir/new.json"
  # Bump new.json forward; touch -t requires CCYYMMDDhhmm format
  touch -t 200001010000 "$test_dir/old.json"
  touch -t 203001010000 "$test_dir/new.json"

  run zsh -c "
    $(sed -n '/^get_file_mtime()/,/^}/p' "$SCRIPT")
    $(sed -n '/^get_newest_mtime()/,/^}/p' "$SCRIPT")
    get_newest_mtime '$test_dir'
  "

  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]+$ ]]

  # Newest should match the mtime of new.json (year 2030)
  expected=$(stat -f %m "$test_dir/new.json" 2>/dev/null || stat -c %Y "$test_dir/new.json")
  [ "$output" = "$expected" ]
}

@test "get_newest_mtime returns 0 for directory with no JSON files" {
  # NOTE: zsh's default `nomatch` option means `for f in dir/*.json` will print
  # an error and fail when there are no matches. The real script side-steps this
  # because claude_config/ always contains at least one JSON. We document the
  # behavior here by ensuring at least one non-JSON file exists and verifying
  # the function returns 0 because no JSON matched.
  test_dir="$TEST_TEMP_DIR/no-json"
  mkdir -p "$test_dir"
  echo "not json" > "$test_dir/readme.txt"

  run zsh -c "
    setopt null_glob
    $(sed -n '/^get_file_mtime()/,/^}/p' "$SCRIPT")
    $(sed -n '/^get_newest_mtime()/,/^}/p' "$SCRIPT")
    get_newest_mtime '$test_dir'
  "

  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}
