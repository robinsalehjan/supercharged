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

@test "restore:dotfiles does not restore agent config or initialize code-review-graph" {
  script="$PROJECT_ROOT/scripts/setup-profile.sh"

  run grep -E 'restore-(claude|codex)\.sh|setup_code_review_graph|setup_crg_watcher' "$script"
  [ "$status" -eq 1 ]
}

@test "setup orchestrator creates one snapshot and skips nested backups" {
  setup_script="$PROJECT_ROOT/scripts/setup.sh"

  [ "$(grep -c '^create_restoration_point$' "$setup_script")" -eq 1 ]
  grep -F 'setup-profile.sh" --skip-backup' "$setup_script"
  grep -F 'mac.sh" --skip-backup' "$setup_script"
}

@test "normalize_yes_no_preference constrains shell-like input" {
  run normalize_yes_no_preference '$(touch "$HOME/pwned")' "Y"

  [ "$status" -eq 0 ]
  [ "$output" = "N" ]
  [ ! -e "$HOME/pwned" ]
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
  [ -f "$backup_dir/files/.zshrc" ]
  [ -f "$backup_dir/files/.gitconfig" ]
}

@test "managed git config keeps identity in a local include" {
  grep -F '[include]' "$DOT_FILES_DIR/.gitconfig"
  grep -F 'path = ~/.gitconfig.local' "$DOT_FILES_DIR/.gitconfig"
  ! grep -F '[user]' "$DOT_FILES_DIR/.gitconfig"
}

@test "install_managed_git_config migrates existing user values once" {
  cat > "$HOME/.gitconfig" <<'EOF'
[user]
  name = Existing User
  email = existing@example.com
  signingkey = ABC123
EOF

  run install_managed_git_config

  [ "$status" -eq 0 ]
  [ "$(git config --file "$HOME/.gitconfig.local" user.name)" = "Existing User" ]
  [ "$(git config --file "$HOME/.gitconfig.local" user.email)" = "existing@example.com" ]
  [ "$(git config --file "$HOME/.gitconfig.local" user.signingkey)" = "ABC123" ]
  grep -F 'path = ~/.gitconfig.local' "$HOME/.gitconfig"
}

@test "install_managed_git_config preserves an existing local identity" {
  printf '%s\n' '[user]' '  name = Local User' '  email = local@example.com' > "$HOME/.gitconfig.local"
  printf '%s\n' '[user]' '  name = Old User' '  email = old@example.com' > "$HOME/.gitconfig"

  install_managed_git_config

  [ "$(git config --file "$HOME/.gitconfig.local" user.name)" = "Local User" ]
  [ "$(git config --file "$HOME/.gitconfig.local" user.email)" = "local@example.com" ]
}

@test "interactive setup prompts until Git name and email are non-empty" {
  install_managed_git_config >/dev/null
  rm -f "$HOME/.gitconfig.local"

  run bash -c "printf '\nPrompted User\n\nprompted@example.com\n' | zsh -c 'export HOME=\"$HOME\"; source \"$PROJECT_ROOT/scripts/utils.sh\"; setup_git_config'"

  [ "$status" -eq 0 ]
  [ "$(git config --file "$HOME/.gitconfig.local" user.name)" = "Prompted User" ]
  [ "$(git config --file "$HOME/.gitconfig.local" user.email)" = "prompted@example.com" ]
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
