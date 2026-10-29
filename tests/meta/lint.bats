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

  [ "$status" -eq 0 ]
}

@test "lint command excludes SC1071 warnings" {
  # Skip if shellcheck not installed
  if ! command -v shellcheck >/dev/null 2>&1; then
    skip "shellcheck not installed"
  fi

  run bash -c "cd $PROJECT_ROOT && shellcheck --shell=bash scripts/*.sh 2>&1 | grep SC1071"

  # Assert - should fail to find SC1071 (excluded)
  [ "$status" -ne 0 ]
}

@test "lint command excludes SC2296 warnings" {
  # Skip if shellcheck not installed
  if ! command -v shellcheck >/dev/null 2>&1; then
    skip "shellcheck not installed"
  fi

  run bash -c "cd $PROJECT_ROOT && shellcheck --shell=bash scripts/*.sh 2>&1 | grep SC2296"

  # Assert - should fail to find SC2296 (excluded)
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
  lint_cmd=$(jq -r '.scripts.lint' "$PROJECT_ROOT/package.json")
  lint_source=$(<"$PROJECT_ROOT/scripts/lint.sh")

  # Assert - should specify --shell=bash
  [[ "$lint_cmd" == "./scripts/lint.sh" ]]
  [[ "$lint_source" == *"--shell=bash"* ]]
}

@test "lint covers Codex hooks, zsh syntax, and GitHub Actions" {
  lint_cmd=$(<"$PROJECT_ROOT/scripts/lint.sh")

  [[ "$lint_cmd" == *"codex_config/hooks/*.sh"* ]]
  [[ "$lint_cmd" == *"zsh -n"* ]]
  [[ "$lint_cmd" == *"dot_files/.zshrc"* ]]
  [[ "$lint_cmd" == *"actionlint"* ]]
  grep -F 'actionlint bats-core' "$PROJECT_ROOT/.github/workflows/test.yml"
}

@test ".shellcheckrc is the only ShellCheck suppression source" {
  # Arrange - .shellcheckrc lives at project root and holds the disable list
  rc_file="$PROJECT_ROOT/.shellcheckrc"
  [ -f "$rc_file" ]

  disable_line=$(grep -E '^disable=' "$rc_file")
  [[ "$disable_line" == *"SC1071"* ]]
  [[ "$disable_line" == *"SC2296"* ]]
  ! grep -F -- '--exclude=' "$PROJECT_ROOT/scripts/lint.sh"
}

@test "lint reports a syntax error in a later filename" {
  lint_root="$TEST_TEMP_DIR/lint-root"
  mkdir -p "$lint_root/scripts/utils" "$lint_root/codex_config/hooks" "$lint_root/tests/helpers" "$lint_root/dot_files" "$lint_root/bin"
  printf '#!/bin/zsh\ntrue\n' > "$lint_root/scripts/a-first.sh"
  printf '#!/bin/zsh\nif then\n' > "$lint_root/scripts/z-last.sh"
  printf '#!/bin/zsh\ntrue\n' > "$lint_root/scripts/utils/helper.sh"
  printf '#!/bin/zsh\ntrue\n' > "$lint_root/codex_config/hooks/hook.sh"
  printf '#!/bin/bash\ntrue\n' > "$lint_root/tests/helpers/helper.bash"
  for file in .zshrc .zprofile .p10k.zsh; do printf 'true\n' > "$lint_root/dot_files/$file"; done
  printf '#!/bin/sh\nexit 0\n' > "$lint_root/bin/shellcheck"
  printf '#!/bin/sh\nexit 0\n' > "$lint_root/bin/actionlint"
  chmod +x "$lint_root/bin/shellcheck" "$lint_root/bin/actionlint"

  run env PATH="$lint_root/bin:$PATH" LINT_PROJECT_ROOT="$lint_root" zsh "$PROJECT_ROOT/scripts/lint.sh"

  [ "$status" -ne 0 ]
  [[ "$output" == *"z-last.sh"* ]]
}
