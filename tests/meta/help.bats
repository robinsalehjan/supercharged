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
  [[ "$output" == *"npm run restore:claude:force"* ]]
}

@test "help.sh displays update commands" {
  # Act
  run "$PROJECT_ROOT/scripts/help.sh"

  # Assert
  [ "$status" -eq 0 ]
  [[ "$output" == *"Update Commands:"* ]]
  [[ "$output" == *"npm run update"* ]]
  [[ "$output" == *"npm run update:dry-run"* ]]
  [[ "$output" == *"npm run update:brew"* ]]
  [[ "$output" == *"npm run update:asdf"* ]]
  [[ "$output" == *"npm run update:zsh"* ]]
  [[ "$output" == *"npm run update:npm"* ]]
  [[ "$output" == *"npm run update:pip"* ]]
}

@test "help.sh displays development commands" {
  # Act
  run "$PROJECT_ROOT/scripts/help.sh"

  # Assert
  [ "$status" -eq 0 ]
  [[ "$output" == *"Development Commands:"* ]]
  [[ "$output" == *"npm run lint"* ]]
  [[ "$output" == *"npm test"* ]]
  [[ "$output" == *"npm run test:claude"* ]]
  [[ "$output" == *"npm run test:utils"* ]]
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
