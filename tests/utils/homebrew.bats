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
        printf "%s\n" danger/tap finn/brew getsentry/xcodebuildmcp mobai-app/tap thoughtbot/formulae xcodesorg/made
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
  ! grep -Fq 'trust --formula getsentry/xcodebuildmcp/xcodebuildmcp' "$BREW_CALLS_FILE"
  grep -Fxq 'trust --formula mobai-app/tap/simslim' "$BREW_CALLS_FILE"
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
        printf "%s\n" danger/tap finn/brew mobai-app/tap
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
  [[ "$output" == *'Would trust managed Homebrew formula: mobai-app/tap/simslim'* ]]
  [[ "$output" == *'Would remove unused Homebrew tap: finn/brew'* ]]
}

@test "upgrade_homebrew_formulae uses the xcodes bottle and upgrades other formulae normally" {
  run zsh -c '
    export BREW_CALLS_FILE="'"$BREW_CALLS_FILE"'"
    brew() {
      printf "%s\n" "$*" >> "$BREW_CALLS_FILE"
      if [ "$1 $2 $3" = "outdated --formula --quiet" ]; then
        printf "%s\n" readline xcodes jq
      fi
    }
    source "'"$PROJECT_ROOT"'/scripts/utils.sh"
    upgrade_homebrew_formulae
  '

  [ "$status" -eq 0 ]
  grep -Fxq 'upgrade --formula --force-bottle --dry-run xcodesorg/made/xcodes' "$BREW_CALLS_FILE"
  grep -Fxq 'upgrade --formula --force-bottle xcodesorg/made/xcodes' "$BREW_CALLS_FILE"
  grep -Fxq 'upgrade --formula readline jq' "$BREW_CALLS_FILE"
  ! grep -Fxq 'upgrade' "$BREW_CALLS_FILE"
}

@test "upgrade_homebrew_formulae skips xcodes when its tap has no usable bottle" {
  run zsh -c '
    export BREW_CALLS_FILE="'"$BREW_CALLS_FILE"'"
    brew() {
      printf "%s\n" "$*" >> "$BREW_CALLS_FILE"
      if [ "$1 $2 $3" = "outdated --formula --quiet" ]; then
        printf "%s\n" xcodes
      elif [ "$1 $2 $3 $4" = "upgrade --formula --force-bottle --dry-run" ]; then
        return 1
      fi
    }
    source "'"$PROJECT_ROOT"'/scripts/utils.sh"
    upgrade_homebrew_formulae
  '

  [ "$status" -eq 0 ]
  [ "$(grep -c '^upgrade ' "$BREW_CALLS_FILE")" -eq 1 ]
  [[ "$output" == *'tap has no usable bottle'* ]]
}
