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

@test "restoration point captures complete managed configuration privately" {
  source "$PROJECT_ROOT/scripts/utils.sh"
  mkdir -p "$HOME/.codex/hooks" "$HOME/.codex/rules" "$HOME/.codex/skills/example" "$HOME/.claude/statusline" "$HOME/.claude/skills/example"
  printf '%s\n' 'git identity' > "$HOME/.gitconfig.local"
  printf '%s\n' '{}' > "$HOME/.claude/settings.json"
  printf '%s\n' '{}' > "$HOME/.claude.json"
  printf '%s\n' 'model = "local"' > "$HOME/.codex/config.toml"
  printf '%s\n' 'command = "xcrun"' > "$HOME/.codex/apple.config.toml"
  printf '%s\n' 'command = "xcodebuildmcp"' > "$HOME/.codex/apple-headless.config.toml"
  printf '%s\n' 'model_reasoning_effort = "xhigh"' > "$HOME/.codex/review.config.toml"
  printf '%s\n' '#!/bin/sh' > "$HOME/.codex/hooks/example.sh"
  chmod 755 "$HOME/.codex/hooks/example.sh"

  create_restoration_point
  backup_dir=$(<"$HOME/.supercharged_last_backup")

  [ "$(stat -f %Lp "$backup_dir" 2>/dev/null || stat -c %a "$backup_dir")" = "700" ]
  [ "$(stat -f %Lp "$backup_dir/files/.claude/settings.json" 2>/dev/null || stat -c %a "$backup_dir/files/.claude/settings.json")" = "600" ]
  grep -F $'file\t.gitconfig.local' "$backup_dir/presence.tsv"
  grep -F $'file\t.claude.json' "$backup_dir/presence.tsv"
  grep -F $'dir\t.claude/skills' "$backup_dir/presence.tsv"
  grep -F $'dir\t.codex/hooks' "$backup_dir/presence.tsv"
  grep -F $'file\t.codex/apple.config.toml' "$backup_dir/presence.tsv"
  grep -F $'file\t.codex/apple-headless.config.toml' "$backup_dir/presence.tsv"
  grep -F $'file\t.codex/review.config.toml' "$backup_dir/presence.tsv"
  [ ! -e "$backup_dir/files/.claude/plugins/cache" ]
}

@test "manifest rollback removes files that were absent before restore" {
  source "$PROJECT_ROOT/scripts/utils.sh"
  rm -f "$HOME/.claude/settings.json"
  create_restoration_point
  backup_dir=$(<"$HOME/.supercharged_last_backup")
  printf '%s\n' '{"created":true}' > "$HOME/.claude/settings.json"

  restore_from_backup "$backup_dir"

  [ ! -e "$HOME/.claude/settings.json" ]
}

@test "manifest rollback removes Codex profiles that were absent before restore" {
  source "$PROJECT_ROOT/scripts/utils.sh"
  rm -f "$HOME/.codex/apple.config.toml" "$HOME/.codex/apple-headless.config.toml" "$HOME/.codex/review.config.toml"
  create_restoration_point
  backup_dir=$(<"$HOME/.supercharged_last_backup")
  mkdir -p "$HOME/.codex"
  printf '%s\n' 'model_reasoning_effort = "xhigh"' > "$HOME/.codex/apple.config.toml"
  printf '%s\n' 'model_reasoning_effort = "xhigh"' > "$HOME/.codex/apple-headless.config.toml"
  printf '%s\n' 'model_reasoning_effort = "xhigh"' > "$HOME/.codex/review.config.toml"

  restore_from_backup "$backup_dir"

  [ ! -e "$HOME/.codex/apple.config.toml" ]
  [ ! -e "$HOME/.codex/apple-headless.config.toml" ]
  [ ! -e "$HOME/.codex/review.config.toml" ]
}

@test "manifest rollback restores directory contents and executable modes" {
  source "$PROJECT_ROOT/scripts/utils.sh"
  mkdir -p "$HOME/.codex/hooks"
  printf '%s\n' '#!/bin/sh' > "$HOME/.codex/hooks/original.sh"
  chmod 755 "$HOME/.codex/hooks/original.sh"
  create_restoration_point
  backup_dir=$(<"$HOME/.supercharged_last_backup")
  rm -f "$HOME/.codex/hooks/original.sh"
  printf '%s\n' '#!/bin/sh' > "$HOME/.codex/hooks/created.sh"

  restore_from_backup "$backup_dir"

  [ -x "$HOME/.codex/hooks/original.sh" ]
  [ ! -e "$HOME/.codex/hooks/created.sh" ]
}

@test "legacy manifest-less backups remain copy-only restorable" {
  source "$PROJECT_ROOT/scripts/utils.sh"
  legacy="$TEST_TEMP_DIR/legacy"
  mkdir -p "$legacy"
  printf '%s\n' 'legacy zsh' > "$legacy/.zshrc"
  printf '%s\n' 'keep me' > "$HOME/.gitconfig.local"

  restore_from_backup "$legacy"

  grep -F 'legacy zsh' "$HOME/.zshrc"
  grep -F 'keep me' "$HOME/.gitconfig.local"
}
