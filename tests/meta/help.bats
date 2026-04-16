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

@test "help.sh displays setup commands section" {
  # Act
  run "$PROJECT_ROOT/scripts/help.sh"

  # Assert
  [ "$status" -eq 0 ]
  [[ "$output" == *"Setup Commands:"* ]]
  [[ "$output" == *"npm run setup"* ]]
  [[ "$output" == *"npm run setup:profile"* ]]
}

@test "help.sh displays backup and restore commands" {
  # Act
  run "$PROJECT_ROOT/scripts/help.sh"

  # Assert
  [ "$status" -eq 0 ]
  [[ "$output" == *"Backup & Restore Commands:"* ]]
  [[ "$output" == *"npm run backup:claude"* ]]
  [[ "$output" == *"npm run restore:claude"* ]]
  [[ "$output" == *"-- --force"* ]]
}

@test "help.sh displays update commands" {
  # Act
  run "$PROJECT_ROOT/scripts/help.sh"

  # Assert
  [ "$status" -eq 0 ]
  [[ "$output" == *"Update Commands:"* ]]
  [[ "$output" == *"npm run update"* ]]
  [[ "$output" == *"npm run update:dry-run"* ]]
  [[ "$output" == *"npm run update:only"* ]]
}

@test "help.sh displays development commands" {
  # Act
  run "$PROJECT_ROOT/scripts/help.sh"

  # Assert
  [ "$status" -eq 0 ]
  [[ "$output" == *"Development Commands:"* ]]
  [[ "$output" == *"npm run lint"* ]]
  [[ "$output" == *"npm test"* ]]
  [[ "$output" == *"bats tests/"* ]]
  [[ "$output" == *"npm run test:watch"* ]]
}

@test "help.sh displays other commands" {
  # Act
  run "$PROJECT_ROOT/scripts/help.sh"

  # Assert
  [ "$status" -eq 0 ]
  [[ "$output" == *"Other Commands:"* ]]
  [[ "$output" == *"npm run validate"* ]]
  [[ "$output" == *"npm run restore"* ]]
}

@test "help.sh script is executable" {
  # Assert
  [ -x "$PROJECT_ROOT/scripts/help.sh" ]
}

@test "help.sh displays decorative separators" {
  # Act
  run "$PROJECT_ROOT/scripts/help.sh"

  # Assert - should have visual separators
  [ "$status" -eq 0 ]
  [[ "$output" == *"━━━"* ]]
}
