#!/usr/bin/env bats

load '../helpers/setup'

setup() {
  setup_test_env
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  ORCHESTRATOR_DIR="$TEST_TEMP_DIR/sync-orchestrator"
  mkdir -p "$ORCHESTRATOR_DIR"
  cp "$PROJECT_ROOT/scripts/sync.sh" "$ORCHESTRATOR_DIR/sync.sh"
  chmod +x "$ORCHESTRATOR_DIR/sync.sh"

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

@test "full sync takes one snapshot and propagates force and skip-backup" {
  run "$ORCHESTRATOR_DIR/sync.sh" --force

  [ "$status" -eq 0 ]
  [ "$(grep -c '^snapshot$' "$HOME/calls")" -eq 1 ]
  grep -F 'restore-claude.sh --skip-backup --force' "$HOME/calls"
  grep -F 'restore-codex.sh --skip-backup --force' "$HOME/calls"
  grep -F 'setup-profile.sh --skip-backup' "$HOME/calls"
}

@test "agents-only sync takes one snapshot and skips dotfiles" {
  run "$ORCHESTRATOR_DIR/sync.sh" --only agents

  [ "$status" -eq 0 ]
  [ "$(grep -c '^snapshot$' "$HOME/calls")" -eq 1 ]
  grep -F 'restore-claude.sh --skip-backup' "$HOME/calls"
  grep -F 'restore-codex.sh --skip-backup' "$HOME/calls"
  ! grep -F 'setup-profile.sh' "$HOME/calls"
}

@test "sync supports multiple explicit targets" {
  run "$ORCHESTRATOR_DIR/sync.sh" --only claude --only dotfiles

  [ "$status" -eq 0 ]
  grep -F 'restore-claude.sh --skip-backup' "$HOME/calls"
  ! grep -F 'restore-codex.sh' "$HOME/calls"
  grep -F 'setup-profile.sh --skip-backup' "$HOME/calls"
}

@test "sync rejects unknown targets before creating a snapshot" {
  run "$ORCHESTRATOR_DIR/sync.sh" --only unknown

  [ "$status" -ne 0 ]
  [ ! -e "$HOME/calls" ]
}
