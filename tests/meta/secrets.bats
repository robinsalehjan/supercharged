#!/usr/bin/env bats

load '../helpers/setup'

setup() {
  setup_test_env
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCAN_SCRIPT="$PROJECT_ROOT/scripts/scan-secrets.sh"
}

teardown() {
  teardown_test_env
}

@test "scan-secrets.sh script is executable" {
  [ -x "$SCAN_SCRIPT" ]
}

@test "scan-secrets.sh passes clean files" {
  mkdir -p "$TEST_TEMP_DIR/clean"
  printf '%s\n' 'TOKEN_PLACEHOLDER="YOUR_TOKEN_HERE"' > "$TEST_TEMP_DIR/clean/example.env"

  run "$SCAN_SCRIPT" "$TEST_TEMP_DIR/clean"

  [ "$status" -eq 0 ]
  [[ "$output" == *"No likely secrets found"* ]]
}

@test "scan-secrets.sh flags likely secrets" {
  mkdir -p "$TEST_TEMP_DIR/leaky"
  printf 'api_key="%s%s"\n' "1234567890abcdef" "1234567890abcdef" > "$TEST_TEMP_DIR/leaky/config.txt"

  run "$SCAN_SCRIPT" "$TEST_TEMP_DIR/leaky"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Potential secrets found"* ]]
  [[ "$output" == *"config.txt"* ]]
}
