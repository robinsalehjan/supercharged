#!/usr/bin/env bats

load '../helpers/setup'

setup() {
  setup_test_env
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  BACKUP_ORCHESTRATOR_DIR="$TEST_TEMP_DIR/backup-orchestrator"
  mkdir -p "$BACKUP_ORCHESTRATOR_DIR"
  cp "$PROJECT_ROOT/scripts/backup-all.sh" "$BACKUP_ORCHESTRATOR_DIR/backup-all.sh"
  chmod +x "$BACKUP_ORCHESTRATOR_DIR/backup-all.sh"

  cat > "$BACKUP_ORCHESTRATOR_DIR/utils.sh" <<'EOF'
log_with_level() { :; }
EOF
  for script in backup-claude.sh backup-codex.sh; do
    cat > "$BACKUP_ORCHESTRATOR_DIR/$script" <<EOF
#!/bin/zsh
printf '%s\n' '$script' >> "\$HOME/backup-calls"
EOF
    chmod +x "$BACKUP_ORCHESTRATOR_DIR/$script"
  done
}

teardown() {
  teardown_test_env
}

@test "backup captures both agent configurations by default" {
  run "$BACKUP_ORCHESTRATOR_DIR/backup-all.sh"

  [ "$status" -eq 0 ]
  [ "$(sed -n '1p' "$HOME/backup-calls")" = "backup-claude.sh" ]
  [ "$(sed -n '2p' "$HOME/backup-calls")" = "backup-codex.sh" ]
}

@test "backup supports one or more explicit targets" {
  run "$BACKUP_ORCHESTRATOR_DIR/backup-all.sh" --only codex

  [ "$status" -eq 0 ]
  [ "$(<"$HOME/backup-calls")" = "backup-codex.sh" ]
}

@test "backup rejects unknown targets before capturing configuration" {
  run "$BACKUP_ORCHESTRATOR_DIR/backup-all.sh" --only unknown

  [ "$status" -ne 0 ]
  [ ! -e "$HOME/backup-calls" ]
}

@test "consolidated command help documents selectors" {
  run "$PROJECT_ROOT/scripts/sync.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--only TARGET"* ]]
  [[ "$output" == *"agents, claude, codex, dotfiles"* ]]

  run "$PROJECT_ROOT/scripts/backup-all.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"claude, codex"* ]]

  run "$PROJECT_ROOT/scripts/update-all.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--backup"* ]]
  [[ "$output" == *"--dry-run"* ]]
  [[ "$output" == *"--only COMPONENT"* ]]
}
