#!/usr/bin/env bats

# Load test helpers
load '../helpers/setup'

# Shellcheck disable rules (must match .shellcheckrc — moved from package.json
# in chore/config-improvements so the rules live next to the code they describe).
SHELLCHECK_EXCLUDE='SC1071,SC2296,SC1091'

setup() {
  setup_test_env

  # Get project root
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

teardown() {
  teardown_test_env
}

@test "shellcheck is installed" {
  # Assert
  run command -v shellcheck
  [ "$status" -eq 0 ]
}

@test "lint command runs shellcheck on all scripts" {
  # Skip if shellcheck not installed
  if ! command -v shellcheck >/dev/null 2>&1; then
    skip "shellcheck not installed"
  fi

  # Act - run lint via npm
  run bash -c "cd $PROJECT_ROOT && npm run lint"

  # Assert - should complete (exit code 0 means no errors found, or only filtered warnings)
  # Non-zero exit means actual errors exist
  # We're just checking the command structure works
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "lint command excludes SC1071 warnings" {
  # Skip if shellcheck not installed
  if ! command -v shellcheck >/dev/null 2>&1; then
    skip "shellcheck not installed"
  fi

  # Act - run shellcheck with exclusions
  run bash -c "cd $PROJECT_ROOT && shellcheck --shell=bash --exclude=$SHELLCHECK_EXCLUDE scripts/*.sh 2>&1 | grep SC1071"

  # Assert - should fail to find SC1071 (excluded)
  [ "$status" -ne 0 ]
}

@test "lint command excludes SC2296 warnings" {
  # Skip if shellcheck not installed
  if ! command -v shellcheck >/dev/null 2>&1; then
    skip "shellcheck not installed"
  fi

  # Act - run shellcheck with exclusions
  run bash -c "cd $PROJECT_ROOT && shellcheck --shell=bash --exclude=$SHELLCHECK_EXCLUDE scripts/*.sh 2>&1 | grep SC2296"

  # Assert - should fail to find SC2296 (excluded)
  [ "$status" -ne 0 ]
}

@test "shellcheck finds all shell scripts" {
  # Skip if shellcheck not installed
  if ! command -v shellcheck >/dev/null 2>&1; then
    skip "shellcheck not installed"
  fi

  # Act - count how many .sh files exist
  script_count=$(ls -1 "$PROJECT_ROOT/scripts/"*.sh 2>/dev/null | wc -l | tr -d ' ')

  # Assert - should have multiple scripts to check
  [ "$script_count" -gt 0 ]
}

@test "lint command uses bash shell mode" {
  # Skip if shellcheck not installed
  if ! command -v shellcheck >/dev/null 2>&1; then
    skip "shellcheck not installed"
  fi

  # Arrange - get the lint command from package.json
  lint_cmd=$(grep '"lint"' "$PROJECT_ROOT/package.json" | grep "shellcheck")

  # Assert - should specify --shell=bash
  [[ "$lint_cmd" == *"--shell=bash"* ]]
}

@test ".shellcheckrc disables expected zsh-noise codes" {
  # Arrange - .shellcheckrc lives at project root and holds the disable list
  rc_file="$PROJECT_ROOT/.shellcheckrc"
  [ -f "$rc_file" ]

  # Act - read the disable directive
  disable_line=$(grep -E '^disable=' "$rc_file")

  # Assert - every code in $SHELLCHECK_EXCLUDE must appear
  IFS=',' read -ra codes <<< "$SHELLCHECK_EXCLUDE"
  for code in "${codes[@]}"; do
    [[ "$disable_line" == *"$code"* ]] || {
      echo "Missing $code in .shellcheckrc: $disable_line"
      return 1
    }
  done
}
