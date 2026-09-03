#!/usr/bin/env bats

load '../helpers/setup'

setup() {
  setup_test_env
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export BREW_CALLS_FILE="$TEST_TEMP_DIR/brew-calls"
}

teardown() {
  teardown_test_env
}

@test "reconcile_homebrew_taps trusts managed formulae and safely retires old taps" {
  run zsh -c '
    export BREW_CALLS_FILE="'"$BREW_CALLS_FILE"'"
    brew() {
      if [ "$1" = tap ] && [ "$#" -eq 1 ]; then
        printf "%s\n" danger/tap finn/brew getsentry/xcodebuildmcp thoughtbot/formulae xcodesorg/made
        return 0
      fi
      printf "%s\n" "$*" >> "$BREW_CALLS_FILE"
      [ "$1 $2" != "untap getsentry/xcodebuildmcp" ]
    }
    source "'"$PROJECT_ROOT"'/scripts/utils.sh"
    reconcile_homebrew_taps
  '

  [ "$status" -eq 0 ]
  grep -Fxq 'trust --formula danger/tap/danger-js' "$BREW_CALLS_FILE"
  grep -Fxq 'trust --formula danger/tap/danger-swift' "$BREW_CALLS_FILE"
  grep -Fxq 'trust --formula getsentry/xcodebuildmcp/xcodebuildmcp' "$BREW_CALLS_FILE"
  grep -Fxq 'trust --formula xcodesorg/made/xcodes' "$BREW_CALLS_FILE"
  grep -Fxq 'untap finn/brew' "$BREW_CALLS_FILE"
  grep -Fxq 'untap thoughtbot/formulae' "$BREW_CALLS_FILE"
  [[ "$output" == *'Kept Homebrew tap getsentry/xcodebuildmcp because it still provides an installed item'* ]]
  ! grep -Fq -- '--force' "$BREW_CALLS_FILE"
}

@test "reconcile_homebrew_taps dry-run reports changes without mutating Homebrew" {
  run zsh -c '
    export BREW_CALLS_FILE="'"$BREW_CALLS_FILE"'"
    brew() {
      if [ "$1" = tap ] && [ "$#" -eq 1 ]; then
        printf "%s\n" danger/tap finn/brew
        return 0
      fi
      printf "%s\n" "$*" >> "$BREW_CALLS_FILE"
    }
    source "'"$PROJECT_ROOT"'/scripts/utils.sh"
    reconcile_homebrew_taps true
  '

  [ "$status" -eq 0 ]
  [ ! -e "$BREW_CALLS_FILE" ]
  [[ "$output" == *'Would trust managed Homebrew formula: danger/tap/danger-js'* ]]
  [[ "$output" == *'Would remove unused Homebrew tap: finn/brew'* ]]
}
