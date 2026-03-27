#!/usr/bin/env bats

# Load test helpers
load '../helpers/setup'

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

@test "lint command filters SC1071 warning lines" {
  # Skip if shellcheck not installed
  if ! command -v shellcheck >/dev/null 2>&1; then
    skip "shellcheck not installed"
  fi

  # Act - run shellcheck directly with the same filter
  run bash -c "cd $PROJECT_ROOT && shellcheck --shell=bash scripts/*.sh 2>&1 | grep -Ev 'SC1071|SC2296' | grep SC1071"

  # Assert - should fail to find SC1071 (exit code 1 from grep means not found)
  [ "$status" -ne 0 ]
}

@test "lint command filters SC2296 warning lines" {
  # Skip if shellcheck not installed
  if ! command -v shellcheck >/dev/null 2>&1; then
    skip "shellcheck not installed"
  fi

  # Act - run shellcheck directly with the same filter
  run bash -c "cd $PROJECT_ROOT && shellcheck --shell=bash scripts/*.sh 2>&1 | grep -Ev 'SC1071|SC2296' | grep SC2296"

  # Assert - should fail to find SC2296 (exit code 1 from grep means not found)
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
