#!/usr/bin/env bats

load '../helpers/setup'
load '../helpers/mocks'

setup() {
  setup_test_env

  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

teardown() {
  unmock_all
  teardown_test_env
}

# =============================================================================
# show_help tests
# =============================================================================

@test "update.sh --help shows usage information" {
  run zsh -c "
    source '$PROJECT_ROOT/scripts/utils.sh'
    source '$PROJECT_ROOT/scripts/update.sh'
    show_help
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--only COMPONENT"* ]]
  [[ "$output" == *"--dry-run"* ]]
  [[ "$output" == *"--skip-brew"* ]]
  [[ "$output" == *"--skip-asdf"* ]]
}

# =============================================================================
# Flag defaults tests
# =============================================================================

@test "update.sh default flags are all false" {
  run zsh -c "
    source '$PROJECT_ROOT/scripts/utils.sh'
    source '$PROJECT_ROOT/scripts/update.sh'
    echo \"DRY_RUN=\$DRY_RUN\"
    echo \"SKIP_BREW=\$SKIP_BREW\"
    echo \"SKIP_CASK=\$SKIP_CASK\"
    echo \"SKIP_ASDF=\$SKIP_ASDF\"
    echo \"SKIP_ZSH=\$SKIP_ZSH\"
    echo \"SKIP_NPM=\$SKIP_NPM\"
    echo \"SKIP_PIP=\$SKIP_PIP\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY_RUN=false"* ]]
  [[ "$output" == *"SKIP_BREW=false"* ]]
  [[ "$output" == *"SKIP_CASK=false"* ]]
  [[ "$output" == *"SKIP_ASDF=false"* ]]
  [[ "$output" == *"SKIP_ZSH=false"* ]]
  [[ "$output" == *"SKIP_NPM=false"* ]]
  [[ "$output" == *"SKIP_PIP=false"* ]]
}

# =============================================================================
# Dry-run tests (full script execution)
# =============================================================================

@test "update.sh --dry-run exits cleanly" {
  mock_brew
  mock_ping_success

  run zsh "$PROJECT_ROOT/scripts/update.sh" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY RUN"* ]]
  [[ "$output" == *"No changes were made"* ]]
}

# =============================================================================
# Unknown flag tests
# =============================================================================

@test "update.sh rejects unknown flags" {
  run zsh "$PROJECT_ROOT/scripts/update.sh" --unknown-flag
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown option"* ]]
}

# =============================================================================
# --only flag tests
# =============================================================================

@test "update.sh --only brew includes brew section in dry-run" {
  mock_brew
  mock_ping_success

  run zsh "$PROJECT_ROOT/scripts/update.sh" --only brew --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Outdated Homebrew formulae"* ]]
  [[ "$output" == *"Outdated Homebrew casks"* ]]
  [[ "$output" != *"Outdated npm"* ]]
}

@test "update.sh --only asdf skips brew section in dry-run" {
  mock_ping_success

  run zsh "$PROJECT_ROOT/scripts/update.sh" --only asdf --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" != *"Outdated Homebrew formulae"* ]]
  [[ "$output" != *"Outdated Homebrew casks"* ]]
  [[ "$output" != *"Outdated npm"* ]]
}

@test "update.sh --only rejects unknown component" {
  run zsh "$PROJECT_ROOT/scripts/update.sh" --only invalid
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown component"* ]]
}

@test "update.sh --only without component shows error" {
  run zsh "$PROJECT_ROOT/scripts/update.sh" --only
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown component"* ]]
}
