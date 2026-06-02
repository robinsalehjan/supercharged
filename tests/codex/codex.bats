#!/usr/bin/env bats

load '../helpers/setup'

setup() {
  setup_test_env

  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  BACKUP_SCRIPT="$PROJECT_ROOT/scripts/backup-codex.sh"
  RESTORE_SCRIPT="$PROJECT_ROOT/scripts/restore-codex.sh"
}

teardown() {
  teardown_test_env
}

@test "backup-codex.sh script is executable" {
  [ -x "$BACKUP_SCRIPT" ]
}

@test "restore-codex.sh script is executable" {
  [ -x "$RESTORE_SCRIPT" ]
}

@test "backup-codex.sh has zsh shebang" {
  run head -1 "$BACKUP_SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == "#!/bin/zsh" ]]
}

@test "restore-codex.sh has zsh shebang" {
  run head -1 "$RESTORE_SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == "#!/bin/zsh" ]]
}

@test "filter_shared_codex_config removes machine-local tables" {
  config_file="$TEST_TEMP_DIR/config.toml"
  cat > "$config_file" <<'EOF'
model = "gpt-5.5"

[projects."/Users/rsj/Repositories/supercharged"]
trust_level = "trusted"

[mcp_servers.docs]
url = "https://developers.openai.com/mcp"

[tui.model_availability_nux]
"gpt-5.5" = 4
EOF

  run zsh -c "
    source '$BACKUP_SCRIPT'
    filter_shared_codex_config < '$config_file'
  "

  [ "$status" -eq 0 ]
  [[ "$output" == *'model = "gpt-5.5"'* ]]
  [[ "$output" == *"[mcp_servers.docs]"* ]]
  [[ "$output" != *"[projects."* ]]
  [[ "$output" != *"[tui.model_availability_nux]"* ]]
}

@test "extract_local_codex_tables keeps project trust and notices only" {
  config_file="$TEST_TEMP_DIR/config.toml"
  cat > "$config_file" <<'EOF'
model = "gpt-5.5"

[projects."/Users/rsj/Repositories/supercharged"]
trust_level = "trusted"

[mcp_servers.docs]
url = "https://developers.openai.com/mcp"

[notice.model_migrations]
"gpt-5.3-codex" = "gpt-5.4"
EOF

  run zsh -c "
    source '$RESTORE_SCRIPT'
    extract_local_codex_tables < '$config_file'
  "

  [ "$status" -eq 0 ]
  [[ "$output" == *"[projects."* ]]
  [[ "$output" == *"[notice.model_migrations]"* ]]
  [[ "$output" != *"[mcp_servers.docs]"* ]]
  [[ "$output" != *'model = "gpt-5.5"'* ]]
}

@test "restore-codex.sh accepts --force argument" {
  run grep -E -- '--force' "$RESTORE_SCRIPT"
  [ "$status" -eq 0 ]
}

@test "Claude global config references shared AGENTS.md" {
  run grep -Fx '@AGENTS.md' "$PROJECT_ROOT/claude_config/CLAUDE.md"
  [ "$status" -eq 0 ]
}

@test "codex_config includes shared MCP servers" {
  config="$PROJECT_ROOT/codex_config/config.toml"

  run grep -F '[mcp_servers.code-review-graph]' "$config"
  [ "$status" -eq 0 ]

  run grep -F '[mcp_servers.XcodeBuildMCP]' "$config"
  [ "$status" -eq 0 ]

  run grep -F '[mcp_servers.openaiDeveloperDocs]' "$config"
  [ "$status" -eq 0 ]
}

@test "shared AGENTS.md includes Codex tool preferences" {
  instructions="$PROJECT_ROOT/agent_config/AGENTS.md"

  run grep -F 'code-review-graph MCP tools' "$instructions"
  [ "$status" -eq 0 ]

  run grep -F 'RTK wrappers' "$instructions"
  [ "$status" -eq 0 ]

  run grep -F 'XcodeBuildMCP tools' "$instructions"
  [ "$status" -eq 0 ]
}
