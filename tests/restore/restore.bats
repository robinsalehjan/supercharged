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

@test "restore.sh script exists and is executable" {
  # Assert
  [ -f "$PROJECT_ROOT/scripts/restore.sh" ]
  [ -x "$PROJECT_ROOT/scripts/restore.sh" ]
}

@test "restore.sh sources utils.sh" {
  # Act
  run grep "source.*utils.sh" "$PROJECT_ROOT/scripts/restore.sh"

  # Assert
  [ "$status" -eq 0 ]
  [[ "$output" == *"utils.sh"* ]]
}

@test "restore.sh calls restore_from_backup function" {
  # Act
  run grep "restore_from_backup" "$PROJECT_ROOT/scripts/restore.sh"

  # Assert
  [ "$status" -eq 0 ]
}

@test "restore.sh has trap for cleanup" {
  # Assert: trap is registered AND a cleanup wrapper invokes standard_cleanup
  run grep "trap.*cleanup" "$PROJECT_ROOT/scripts/restore.sh"
  [ "$status" -eq 0 ]

  run grep "standard_cleanup" "$PROJECT_ROOT/scripts/restore.sh"
  [ "$status" -eq 0 ]
}

@test "restore.sh accepts backup directory argument" {
  # Arrange - check script comments/usage
  run grep -A 3 "Usage:" "$PROJECT_ROOT/scripts/restore.sh"

  # Assert - should mention backup_dir argument
  [ "$status" -eq 0 ]
  [[ "$output" == *"backup_dir"* ]]
}

@test "restore_from_backup function exists in utils.sh" {
  # Arrange
  source "$PROJECT_ROOT/scripts/utils.sh"

  # Assert - function should be defined
  run type restore_from_backup
  [ "$status" -eq 0 ]
}

@test "restore.sh uses set -euo pipefail for error handling" {
  # Act
  run head -10 "$PROJECT_ROOT/scripts/restore.sh"

  # Assert
  [ "$status" -eq 0 ]
  [[ "$output" == *"set -euo pipefail"* ]]
}

@test "restore command in package.json points to restore.sh" {
  # Act
  run grep '"restore"' "$PROJECT_ROOT/package.json"

  # Assert
  [ "$status" -eq 0 ]
  [[ "$output" == *"./scripts/restore.sh"* ]]
}

@test "restore.sh script has shebang for zsh" {
  # Act
  run head -1 "$PROJECT_ROOT/scripts/restore.sh"

  # Assert
  [ "$status" -eq 0 ]
  [[ "$output" == "#!/bin/zsh" ]]
}
