#!/usr/bin/env bats

load '../helpers/setup'
load '../helpers/mocks'

setup() {
  setup_test_env

  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  DOT_FILES_DIR="$PROJECT_ROOT/dot_files"

  # Source utils.sh for MANAGED_DOTFILES and helper functions
  source "$PROJECT_ROOT/scripts/utils.sh"

  # Mock commands used by create_restoration_point
  mock_brew
  mock_asdf
}

teardown() {
  unmock_all
  teardown_test_env
}

# =============================================================================
# Dotfile copying tests (mirrors setup-profile.sh logic)
# =============================================================================

@test "copies managed dotfiles to HOME" {
  for file in "${MANAGED_DOTFILES[@]}"; do
    if [ -f "$DOT_FILES_DIR/$file" ]; then
      cp "$DOT_FILES_DIR/$file" "$HOME/"
    fi
  done

  [ -f "$HOME/.zshrc" ]
  [ -f "$HOME/.gitconfig" ]
  [ -f "$HOME/.tool-versions" ]
  [ -f "$HOME/.tmux.conf" ]
}

@test "dotfiles in repo are not empty" {
  for file in "${MANAGED_DOTFILES[@]}"; do
    if [ -f "$DOT_FILES_DIR/$file" ]; then
      [ -s "$DOT_FILES_DIR/$file" ] || {
        echo "$file is empty"
        return 1
      }
    fi
  done
}

@test "MANAGED_DOTFILES list is populated" {
  [ "${#MANAGED_DOTFILES[@]}" -gt 0 ]
}

# =============================================================================
# Dotfile portability tests
# =============================================================================

@test ".zshrc uses env vars not hardcoded paths" {
  if grep -q "/Users/[a-zA-Z]" "$DOT_FILES_DIR/.zshrc"; then
    echo ".zshrc contains hardcoded /Users/ paths"
    grep "/Users/[a-zA-Z]" "$DOT_FILES_DIR/.zshrc"
    return 1
  fi
}

@test ".gitconfig uses env vars not hardcoded home paths" {
  if grep -qE "^\s*(path|helper)\s*=.*\/Users\/[a-zA-Z]" "$DOT_FILES_DIR/.gitconfig"; then
    echo ".gitconfig contains hardcoded home directory paths"
    return 1
  fi
}

# =============================================================================
# Restoration point tests
# =============================================================================

@test "create_restoration_point creates backup directory" {
  run create_restoration_point
  [ "$status" -eq 0 ]

  [ -d "$HOME/.supercharged_backups" ]
  [ -f "$HOME/.supercharged_last_backup" ]

  local backup_dir
  backup_dir=$(cat "$HOME/.supercharged_last_backup")
  [ -d "$backup_dir" ]
}

@test "create_restoration_point backs up existing dotfiles" {
  echo "test-zshrc" > "$HOME/.zshrc"
  echo "test-gitconfig" > "$HOME/.gitconfig"

  run create_restoration_point
  [ "$status" -eq 0 ]

  local backup_dir
  backup_dir=$(cat "$HOME/.supercharged_last_backup")
  [ -f "$backup_dir/.zshrc" ]
  [ -f "$backup_dir/.gitconfig" ]
}

# =============================================================================
# version_gte tests (POSIX-compatible, sourced directly)
# =============================================================================

@test "version_gte returns true for equal versions" {
  version_gte "14.0" "14.0"
}

@test "version_gte returns true for greater version" {
  version_gte "15.1" "14.0"
}

@test "version_gte returns false for lesser version" {
  ! version_gte "11.0" "14.0"
}
