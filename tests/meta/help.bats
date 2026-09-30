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

@test "help.sh displays consolidated setup and configuration commands" {
  # Act
  run "$PROJECT_ROOT/scripts/help.sh"

  # Assert
  [ "$status" -eq 0 ]
  [[ "$output" == *"Setup & Configuration Commands:"* ]]
  [[ "$output" == *"npm run setup"* ]]
  [[ "$output" == *"npm run sync"* ]]
  [[ "$output" == *"npm run sync -- --only agents"* ]]
  [[ "$output" == *"npm run sync -- --only dotfiles"* ]]
  [[ "$output" == *"npm run backup"* ]]
  [[ "$output" == *"npm run backup -- --only claude"* ]]
  [[ "$output" == *"npm run rollback"* ]]
}

@test "package.json exposes only the consolidated configuration commands" {
  command -v jq >/dev/null || skip "jq not installed"

  run jq -r '[.scripts.sync, .scripts.backup, .scripts.rollback] | join(" ")' "$PROJECT_ROOT/package.json"

  [ "$status" -eq 0 ]
  [ "$output" = "./scripts/sync.sh ./scripts/backup-all.sh ./scripts/rollback.sh" ]

  run jq -e '.scripts | has("restore") or has("restore:all") or has("restore:agents") or has("restore:claude") or has("restore:codex") or has("restore:dotfiles") or has("backup:all") or has("backup:claude") or has("backup:codex") or has("update:with-backup") or has("update:dry-run") or has("update:only")' "$PROJECT_ROOT/package.json"
  [ "$status" -ne 0 ]
}

@test "help.sh displays update commands" {
  # Act
  run "$PROJECT_ROOT/scripts/help.sh"

  # Assert
  [ "$status" -eq 0 ]
  [[ "$output" == *"Update Commands:"* ]]
  [[ "$output" == *"npm run update"* ]]
  [[ "$output" == *"npm run update -- --backup"* ]]
  [[ "$output" == *"npm run update -- --dry-run"* ]]
  [[ "$output" == *"npm run update -- --only"* ]]
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
