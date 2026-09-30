#!/usr/bin/env bats

load '../helpers/setup'
load '../helpers/mocks'

setup() {
  setup_test_env

  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  UPDATE_ORCHESTRATOR_DIR="$TEST_TEMP_DIR/update-orchestrator"
  mkdir -p "$UPDATE_ORCHESTRATOR_DIR"
  cp "$PROJECT_ROOT/scripts/update-all.sh" "$UPDATE_ORCHESTRATOR_DIR/update-all.sh"
  chmod +x "$UPDATE_ORCHESTRATOR_DIR/update-all.sh"

  cat > "$UPDATE_ORCHESTRATOR_DIR/utils.sh" <<'EOF'
log_with_level() { :; }
EOF
  for script in backup-all.sh sync.sh install-agent-tooling.sh update.sh; do
    cat > "$UPDATE_ORCHESTRATOR_DIR/$script" <<EOF
#!/bin/zsh
printf '%s %s\n' '$script' "\$*" >> "\$HOME/update-calls"
EOF
    chmod +x "$UPDATE_ORCHESTRATOR_DIR/$script"
  done
}

teardown() {
  unmock_all
  teardown_test_env
}

@test "update command uses the consolidated orchestrator" {
  update_script=$(jq -r '.scripts.update' "$PROJECT_ROOT/package.json")

  [ "$update_script" = "./scripts/update-all.sh" ]
}

@test "normal update syncs dotfiles and reconciles complete agent tooling" {
  run "$UPDATE_ORCHESTRATOR_DIR/update-all.sh" --only brew

  [ "$status" -eq 0 ]
  [ "$(sed -n '1p' "$HOME/update-calls")" = "sync.sh --only dotfiles" ]
  [ "$(sed -n '2p' "$HOME/update-calls")" = "install-agent-tooling.sh " ]
  [ "$(sed -n '3p' "$HOME/update-calls")" = "update.sh --only brew" ]
}

@test "update dry-run checks managed tools without changing configuration" {
  run "$UPDATE_ORCHESTRATOR_DIR/update-all.sh" --dry-run

  [ "$status" -eq 0 ]
  ! grep -F 'sync.sh' "$HOME/update-calls"
  ! grep -F 'backup-all.sh' "$HOME/update-calls"
  grep -F 'install-agent-tooling.sh --dry-run' "$HOME/update-calls"
  grep -F 'update.sh --dry-run' "$HOME/update-calls"
}

@test "managed tool pins have a dedicated update command" {
  update_script=$(jq -r '.scripts["update:tool-pins"]' "$PROJECT_ROOT/package.json")

  [ "$update_script" = "./scripts/update-agent-tool-pins.sh" ]
}

@test "cask updates reconcile the tmux Nerd Font registration" {
  update_source="$(<"$PROJECT_ROOT/scripts/update.sh")"

  [[ "$update_source" == *'ensure_font_registered "font-jetbrains-mono-nerd-font" "JetBrainsMono*Nerd*.ttf"'* ]]
  [[ "$update_source" == *'JetBrainsMono Nerd Font could not be registered'* ]]
}

@test "standard update does not capture live agent configuration" {
  run "$UPDATE_ORCHESTRATOR_DIR/update-all.sh"

  [ "$status" -eq 0 ]
  ! grep -F 'backup-all.sh' "$HOME/update-calls"
}

@test "update --backup captures config before syncing and updating" {
  run "$UPDATE_ORCHESTRATOR_DIR/update-all.sh" --backup

  [ "$status" -eq 0 ]
  [ "$(sed -n '1p' "$HOME/update-calls")" = "backup-all.sh " ]
  [ "$(sed -n '2p' "$HOME/update-calls")" = "sync.sh --only dotfiles" ]
  [ "$(sed -n '3p' "$HOME/update-calls")" = "install-agent-tooling.sh " ]
  [ "$(sed -n '4p' "$HOME/update-calls")" = "update.sh " ]
}

@test "update rejects a mutating backup during dry-run" {
  run "$UPDATE_ORCHESTRATOR_DIR/update-all.sh" --backup --dry-run

  [ "$status" -ne 0 ]
  [ ! -e "$HOME/update-calls" ]
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
  export MOCK_BREW_CALLS_FILE="$TEST_TEMP_DIR/brew-calls"
  mock_brew
  mock_ping_success

  run zsh "$PROJECT_ROOT/scripts/update.sh" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY RUN"* ]]
  [[ "$output" == *"No changes were made"* ]]
  ! grep -Eq '^(update|cleanup)( |$)' "$MOCK_BREW_CALLS_FILE"
}

@test "standard cleanup does not run brew cleanup during a dry-run" {
  source "$PROJECT_ROOT/scripts/utils.sh"
  DRY_RUN=true
  brew() {
    [ "$1" = "cleanup" ] && touch "$TEST_TEMP_DIR/brew-cleanup-called"
  }

  run standard_cleanup "Update"

  [ "$status" -eq 0 ]
  [ ! -e "$TEST_TEMP_DIR/brew-cleanup-called" ]
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
