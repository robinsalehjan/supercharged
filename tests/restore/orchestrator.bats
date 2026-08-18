#!/usr/bin/env bats

load '../helpers/setup'

setup() {
  setup_test_env
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  ORCHESTRATOR_DIR="$TEST_TEMP_DIR/orchestrator"
  mkdir -p "$ORCHESTRATOR_DIR"
  cp "$PROJECT_ROOT/scripts/restore-all.sh" "$ORCHESTRATOR_DIR/restore-all.sh"
  chmod +x "$ORCHESTRATOR_DIR/restore-all.sh"

  cat > "$ORCHESTRATOR_DIR/utils.sh" <<'EOF'
create_restoration_point() {
  printf '%s\n' snapshot >> "$HOME/calls"
}
log_with_level() { :; }
EOF
  for script in restore-claude.sh restore-codex.sh setup-profile.sh; do
    cat > "$ORCHESTRATOR_DIR/$script" <<EOF
#!/bin/zsh
printf '%s %s\n' '$script' "\$*" >> "\$HOME/calls"
EOF
    chmod +x "$ORCHESTRATOR_DIR/$script"
  done
}

teardown() {
  teardown_test_env
}

@test "all restore takes one snapshot and propagates force and skip-backup" {
  run "$ORCHESTRATOR_DIR/restore-all.sh" --force

  [ "$status" -eq 0 ]
  [ "$(grep -c '^snapshot$' "$HOME/calls")" -eq 1 ]
  grep -F 'restore-claude.sh --skip-backup --force' "$HOME/calls"
  grep -F 'restore-codex.sh --skip-backup --force' "$HOME/calls"
  grep -F 'setup-profile.sh --skip-backup' "$HOME/calls"
}

@test "agents-only restore takes one snapshot and skips dotfiles" {
  run "$ORCHESTRATOR_DIR/restore-all.sh" --agents-only

  [ "$status" -eq 0 ]
  [ "$(grep -c '^snapshot$' "$HOME/calls")" -eq 1 ]
  grep -F 'restore-claude.sh --skip-backup' "$HOME/calls"
  grep -F 'restore-codex.sh --skip-backup' "$HOME/calls"
  ! grep -F 'setup-profile.sh' "$HOME/calls"
}
