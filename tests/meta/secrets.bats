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

@test "CI installs ripgrep for secret scan" {
  workflow_file="$PROJECT_ROOT/.github/workflows/test.yml"

  [ -f "$workflow_file" ]
  grep -Eq 'for pkg in .*ripgrep' "$workflow_file"
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

@test "scan-secrets.sh ignores code identifiers assigned to token-related options" {
  mkdir -p "$TEST_TEMP_DIR/clean-code"
  printf '%s\n' 'max_output_tokens_per_file=args.max_output_tokens_per_file,' > "$TEST_TEMP_DIR/clean-code/example.py"

  run "$SCAN_SCRIPT" "$TEST_TEMP_DIR/clean-code"

  [ "$status" -eq 0 ]
  [[ "$output" == *"No likely secrets found"* ]]
}

@test "scan-secrets.sh flags a literal secret beside an ignored code reference" {
  mkdir -p "$TEST_TEMP_DIR/mixed"
  printf 'token=args.token; password="%s%s"\n' \
    "1234567890abcdef" "1234567890abcdef" > "$TEST_TEMP_DIR/mixed/example.py"

  run "$SCAN_SCRIPT" "$TEST_TEMP_DIR/mixed"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Potential secrets found"* ]]
  [[ "$output" == *"password="* ]]
}
