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

[hooks.state."/Users/rsj/.codex/hooks.json:stop:0:0"]
trusted_hash = "sha256:abc123"
EOF

  run zsh -c "
    source '$RESTORE_SCRIPT'
    extract_local_codex_tables < '$config_file'
  "

  [ "$status" -eq 0 ]
  [[ "$output" == *"[projects."* ]]
  [[ "$output" == *"[notice.model_migrations]"* ]]
  [[ "$output" == *"[hooks.state."* ]]
  [[ "$output" != *"[mcp_servers.docs]"* ]]
  [[ "$output" != *'model = "gpt-5.5"'* ]]
}

@test "filter_shared_codex_config removes hook trust state" {
  config_file="$TEST_TEMP_DIR/config.toml"
  cat > "$config_file" <<'EOF'
model = "gpt-5.5"

[features]
hooks = true

[hooks.state."/Users/rsj/.codex/hooks.json:stop:0:0"]
trusted_hash = "sha256:abc123"
EOF

  run zsh -c "
    source '$BACKUP_SCRIPT'
    filter_shared_codex_config < '$config_file'
  "

  [ "$status" -eq 0 ]
  [[ "$output" == *'hooks = true'* ]]
  [[ "$output" != *"[hooks.state."* ]]
  [[ "$output" != *"trusted_hash"* ]]
}

@test "filter_shared_codex_agents removes Codex-only RTK include" {
  agents_file="$TEST_TEMP_DIR/AGENTS.md"
  cat > "$agents_file" <<EOF
# Shared Agent Instructions

- Prefer RTK wrappers.

@$HOME/.codex/RTK.md
EOF

  run zsh -c "
    source '$BACKUP_SCRIPT'
    filter_shared_codex_agents < '$agents_file'
  "

  [ "$status" -eq 0 ]
  [[ "$output" == *"Prefer RTK wrappers"* ]]
  [[ "$output" != *"RTK.md"* ]]
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

  run grep -F 'hooks = true' "$config"
  [ "$status" -eq 0 ]

  run grep -F '[mcp_servers.code-review-graph]' "$config"
  [ "$status" -eq 0 ]

  run grep -F '[mcp_servers.code-review-graph.tools.query_graph_tool]' "$config"
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

@test "restore_claude_project_skills_for_codex converts Claude skill markdown to Codex skills" {
  mkdir -p "$TEST_TEMP_DIR/.claude/skills" "$TEST_TEMP_DIR/.codex/skills"
  cat > "$TEST_TEMP_DIR/.claude/skills/review-changes.md" <<'EOF'
---
name: Review Changes
description: Perform a structured code review
---

# Review Changes
EOF

  run zsh -c "
    source '$RESTORE_SCRIPT'
    restore_claude_project_skills_for_codex '$TEST_TEMP_DIR/.claude/skills' '$TEST_TEMP_DIR/.codex/skills'
  "

  [ "$status" -eq 0 ]
  [ -f "$TEST_TEMP_DIR/.codex/skills/review-changes/SKILL.md" ]
  grep -F "Perform a structured code review" "$TEST_TEMP_DIR/.codex/skills/review-changes/SKILL.md"
}

@test "restore-codex.sh restores Codex hooks RTK include and Plannotator skills" {
  run "$RESTORE_SCRIPT" --force

  [ "$status" -eq 0 ]
  [ -f "$HOME/.codex/config.toml" ]
  [ -f "$HOME/.codex/hooks.json" ]
  [ -f "$HOME/.codex/RTK.md" ]
  [ -f "$HOME/.codex/AGENTS.md" ]
  [ -f "$HOME/.codex/skills/plannotator-review/SKILL.md" ]

  grep -F 'hooks = true' "$HOME/.codex/config.toml"
  grep -F "\"command\": \"$HOME/.local/bin/plannotator\"" "$HOME/.codex/hooks.json"
  grep -Fx "@$HOME/.codex/RTK.md" "$HOME/.codex/AGENTS.md"
}
