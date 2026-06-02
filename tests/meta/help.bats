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
  [[ "$output" == *"npm run restore:dotfiles"* ]]
}

@test "help.sh displays backup and restore commands" {
  # Act
  run "$PROJECT_ROOT/scripts/help.sh"

  # Assert
  [ "$status" -eq 0 ]
  [[ "$output" == *"Backup & Restore Commands:"* ]]
  [[ "$output" == *"npm run backup:all"* ]]
  [[ "$output" == *"npm run backup:claude"* ]]
  [[ "$output" == *"npm run backup:codex"* ]]
  [[ "$output" == *"npm run restore:claude"* ]]
  [[ "$output" == *"npm run restore:codex"* ]]
  [[ "$output" == *"-- --force"* ]]
}

@test "backup:all includes Claude and Codex backups" {
  command -v jq >/dev/null || skip "jq not installed"

  run jq -r '.scripts["backup:all"]' "$PROJECT_ROOT/package.json"

  [ "$status" -eq 0 ]
  [[ "$output" == *"backup:claude"* ]]
  [[ "$output" == *"backup:codex"* ]]
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

# Hidden internal scripts (pretest is an npm lifecycle hook, not user-facing)
HELP_IGNORED_SCRIPTS=("pretest")

@test "help.sh stays in sync with package.json scripts" {
  # Skip if jq isn't available (only available in CI / dev machines)
  command -v jq >/dev/null || skip "jq not installed"

  # Act
  run "$PROJECT_ROOT/scripts/help.sh"
  [ "$status" -eq 0 ]
  help_output="$output"

  # Build list of every script from package.json
  scripts=$(jq -r '.scripts | keys[]' "$PROJECT_ROOT/package.json")

  missing=()
  while IFS= read -r script; do
    # Skip ignored scripts (pretest, help itself is the script)
    [ "$script" = "help" ] && continue
    case " ${HELP_IGNORED_SCRIPTS[*]} " in
      *" $script "*) continue ;;
    esac

    if [[ "$help_output" != *"npm run $script"* ]] && [[ "$help_output" != *"npm $script"* ]]; then
      missing+=("$script")
    fi
  done <<< "$scripts"

  # Assert: every package.json script appears in help output
  if [ ${#missing[@]} -gt 0 ]; then
    printf 'Scripts missing from help.sh: %s\n' "${missing[*]}"
    return 1
  fi
}
