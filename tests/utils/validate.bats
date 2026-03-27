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

@test "validate command checks for brew" {
  # Act
  run bash -c "cd $PROJECT_ROOT/scripts && ./utils.sh validate"

  # Assert - should pass if brew is installed
  if command -v brew >/dev/null 2>&1; then
    [ "$status" -eq 0 ]
    [[ "$output" == *"brew:"* ]]
  else
    # If brew not installed, expect validation to fail
    [ "$status" -ne 0 ]
  fi
}

@test "validate command checks for git" {
  # Act
  run bash -c "cd $PROJECT_ROOT/scripts && ./utils.sh validate"

  # Assert - git should always be available on macOS
  [ "$status" -eq 0 ]
  [[ "$output" == *"git:"* ]]
}

@test "validate command checks for asdf" {
  # Act
  run bash -c "cd $PROJECT_ROOT/scripts && ./utils.sh validate"

  # Assert
  if command -v asdf >/dev/null 2>&1; then
    [ "$status" -eq 0 ]
    [[ "$output" == *"asdf:"* ]]
  else
    # If asdf not installed, expect validation to fail
    [ "$status" -ne 0 ]
  fi
}

@test "validate command shows success message when all tools present" {
  # Act
  run bash -c "cd $PROJECT_ROOT/scripts && ./utils.sh validate"

  # Assert - if all validations pass, should show success
  if [ "$status" -eq 0 ]; then
    [[ "$output" == *"All validations passed!"* ]]
  fi
}

@test "validate_tool function exists in utils.sh" {
  # Arrange
  source "$PROJECT_ROOT/scripts/utils.sh"

  # Assert - function should be defined
  run type validate_tool
  [ "$status" -eq 0 ]
}

@test "validate_installation function exists in utils.sh" {
  # Arrange
  source "$PROJECT_ROOT/scripts/utils.sh"

  # Assert - function should be defined
  run type validate_installation
  [ "$status" -eq 0 ]
}
