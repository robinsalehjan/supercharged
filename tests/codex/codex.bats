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
notify = ["/Applications/Codex.app/Contents/MacOS/helper", "turn-ended"]
service_tier = "priority"

model = "gpt-5.5"

[projects."/Users/rsj/Repositories/supercharged"]
trust_level = "trusted"

[features]
hooks = true
js_repl = false

[mcp_servers.docs]
url = "https://developers.openai.com/mcp"

[mcp_servers.node_repl]
command = "/Applications/Codex.app/Contents/Resources/cua_node/bin/node_repl"

[mcp_servers.plugin_firebase_firebase]
command = "firebase"
args = ["mcp", "--dir", "/Users/example/Repositories/project/firebase"]

[tui.model_availability_nux]
"gpt-5.5" = 4

[notice]
hide_rate_limit_model_nudge = true

[desktop]
conversationDetailMode = "STEPS_COMMANDS"

[marketplaces.openai-bundled]
last_updated = "2026-07-07T17:07:06Z"

[plugins."browser@openai-bundled"]
enabled = true

[apps.connector_abc123.tools."github.create_branch"]
approval_mode = "approve"
EOF

  run zsh -c "
    source '$BACKUP_SCRIPT'
    filter_shared_codex_config < '$config_file'
  "

  [ "$status" -eq 0 ]
  [ "${lines[0]}" = 'model = "gpt-5.5"' ]
  [[ "$output" == *'model = "gpt-5.5"'* ]]
  [[ "$output" == *'hooks = true'* ]]
  [[ "$output" == *"[mcp_servers.docs]"* ]]
  [[ "$output" != *'notify = '* ]]
  [[ "$output" != *'service_tier = '* ]]
  [[ "$output" != *'js_repl = '* ]]
  [[ "$output" != *"[projects."* ]]
  [[ "$output" != *"[mcp_servers.node_repl]"* ]]
  [[ "$output" != *"[mcp_servers.plugin_firebase_firebase]"* ]]
  [[ "$output" != *"[tui.model_availability_nux]"* ]]
  [[ "$output" != *"[notice]"* ]]
  [[ "$output" != *"[desktop]"* ]]
  [[ "$output" != *"[marketplaces."* ]]
  [[ "$output" != *"[plugins."* ]]
  [[ "$output" != *"[apps.connector_"* ]]
}

@test "extract_local_codex_top_level keeps local runtime keys only" {
  config_file="$TEST_TEMP_DIR/config.toml"
  cat > "$config_file" <<'EOF'
model = "gpt-5.5"
notify = ["/Applications/Codex.app/Contents/MacOS/helper", "turn-ended"]
service_tier = "priority"

[mcp_servers.docs]
url = "https://developers.openai.com/mcp"
EOF

  run zsh -c "
    source '$RESTORE_SCRIPT'
    extract_local_codex_top_level < '$config_file'
  "

  [ "$status" -eq 0 ]
  [[ "$output" == *'notify = '* ]]
  [[ "$output" == *'service_tier = "priority"'* ]]
  [[ "$output" != *'model = "gpt-5.5"'* ]]
  [[ "$output" != *"[mcp_servers.docs]"* ]]
}

@test "extract_local_codex_tables keeps local runtime tables only" {
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

[desktop]
conversationDetailMode = "STEPS_COMMANDS"

[marketplaces.openai-bundled]
last_updated = "2026-07-07T17:07:06Z"

[plugins."browser@openai-bundled"]
enabled = true

[mcp_servers.node_repl]
command = "/Applications/Codex.app/Contents/Resources/cua_node/bin/node_repl"

[mcp_servers.plugin_firebase_firebase]
command = "firebase"
args = ["mcp", "--dir", "/Users/example/Repositories/project/firebase"]

[apps.connector_abc123.tools."github.create_branch"]
approval_mode = "approve"
EOF

  run zsh -c "
    source '$RESTORE_SCRIPT'
    extract_local_codex_tables < '$config_file'
  "

  [ "$status" -eq 0 ]
  [[ "$output" == *"[projects."* ]]
  [[ "$output" == *"[notice.model_migrations]"* ]]
  [[ "$output" == *"[hooks.state."* ]]
  [[ "$output" == *"[desktop]"* ]]
  [[ "$output" == *"[marketplaces.openai-bundled]"* ]]
  [[ "$output" == *"[plugins.\"browser@openai-bundled\"]"* ]]
  [[ "$output" == *"[mcp_servers.node_repl]"* ]]
  [[ "$output" == *"[mcp_servers.plugin_firebase_firebase]"* ]]
  [[ "$output" == *"[apps.connector_abc123.tools.\"github.create_branch\"]"* ]]
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

@test "codex hooks include RTK pre-tool enforcement" {
  hooks="$PROJECT_ROOT/codex_config/hooks.json"
  hook_script="$PROJECT_ROOT/codex_config/hooks/rtk-enforce.sh"

  [ -f "$hook_script" ]

  run grep -F '"PreToolUse"' "$hooks"
  [ "$status" -eq 0 ]

  run grep -F '"command": "bash \"$HOME/.codex/hooks/rtk-enforce.sh\""' "$hooks"
  [ "$status" -eq 0 ]
}

@test "codex_config permission profile mirrors Claude secret path denies" {
  config="$PROJECT_ROOT/codex_config/config.toml"

  run grep -F 'default_permissions = "supercharged"' "$config"
  [ "$status" -eq 0 ]

  run grep -F '[permissions.supercharged]' "$config"
  [ "$status" -eq 0 ]

  run grep -F 'extends = ":workspace"' "$config"
  [ "$status" -eq 0 ]

  run grep -F '[permissions.supercharged.filesystem.":workspace_roots"]' "$config"
  [ "$status" -eq 0 ]

  run grep -F '"**/.env*" = "deny"' "$config"
  [ "$status" -eq 0 ]

  run grep -F '"**/.secrets" = "deny"' "$config"
  [ "$status" -eq 0 ]

  run grep -F '"**/.secrets/**" = "deny"' "$config"
  [ "$status" -eq 0 ]
}

@test "codex_config includes translated Claude command deny rules" {
  rules="$PROJECT_ROOT/codex_config/rules/supercharged.rules"

  [ -f "$rules" ]

  run grep -F 'pattern = ["rm", "-rf"]' "$rules"
  [ "$status" -eq 0 ]

  run grep -F 'pattern = ["sudo"]' "$rules"
  [ "$status" -eq 0 ]

  run grep -F 'pattern = ["git", "reset", "--hard"]' "$rules"
  [ "$status" -eq 0 ]

  run grep -F 'pattern = ["git", "push", "--force"]' "$rules"
  [ "$status" -eq 0 ]
}

@test "translated Codex command deny rules block representative commands when codex is available" {
  if ! command -v codex >/dev/null 2>&1; then
    skip "codex CLI not installed"
  fi

  rules="$PROJECT_ROOT/codex_config/rules/supercharged.rules"

  run codex execpolicy check --pretty --rules "$rules" -- rm -rf build
  [ "$status" -eq 0 ]
  [[ "$output" == *'"decision": "forbidden"'* ]]
  [[ "$output" == *'"rm"'* ]]

  run codex execpolicy check --pretty --rules "$rules" -- sudo make install
  [ "$status" -eq 0 ]
  [[ "$output" == *'"decision": "forbidden"'* ]]
  [[ "$output" == *'"sudo"'* ]]
}

@test "shared AGENTS.md includes Codex tool preferences" {
  instructions="$PROJECT_ROOT/agent_config/AGENTS.md"

  run grep -F 'code-review-graph MCP tools' "$instructions"
  [ "$status" -eq 0 ]

  run grep -F 'RTK wrappers' "$instructions"
  [ "$status" -eq 0 ]

  run grep -F 'XcodeBuildMCP tools' "$instructions"
  [ "$status" -eq 0 ]

  run grep -F 'Use Worktrunk (`wt`) for isolated feature/fix work' "$instructions"
  [ "$status" -eq 0 ]

  run grep -F 'small atomic commits with conventional commit messages' "$instructions"
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

@test "project Claude skills override existing Codex skill directories" {
  mkdir -p "$TEST_TEMP_DIR/project/.claude/skills" \
    "$TEST_TEMP_DIR/.codex/skills/shared-rule"

  cat > "$TEST_TEMP_DIR/.codex/skills/shared-rule/SKILL.md" <<'EOF'
---
name: shared-rule
description: Existing Codex version
---

# Existing Version
EOF

  cat > "$TEST_TEMP_DIR/project/.claude/skills/shared-rule.md" <<'EOF'
---
name: shared-rule
description: Project-level version
---

# Project Version
EOF

  run zsh -c "
    source '$RESTORE_SCRIPT'
    restore_claude_project_skills_for_codex '$TEST_TEMP_DIR/project/.claude/skills' '$TEST_TEMP_DIR/.codex/skills'
  "

  [ "$status" -eq 0 ]
  [ -f "$TEST_TEMP_DIR/.codex/skills/shared-rule/SKILL.md" ]
  grep -F "Project-level version" "$TEST_TEMP_DIR/.codex/skills/shared-rule/SKILL.md"
  ! grep -F "Existing Codex version" "$TEST_TEMP_DIR/.codex/skills/shared-rule/SKILL.md"
}

@test "restore_codex_rules copies managed rules without deleting local rules" {
  mkdir -p "$TEST_TEMP_DIR/repo-rules" "$TEST_TEMP_DIR/.codex/rules"
  echo 'prefix_rule(pattern=["existing"], decision="allow")' \
    > "$TEST_TEMP_DIR/.codex/rules/default.rules"
  echo 'prefix_rule(pattern=["sudo"], decision="forbidden")' \
    > "$TEST_TEMP_DIR/repo-rules/supercharged.rules"

  run zsh -c "
    source '$RESTORE_SCRIPT'
    restore_codex_rules '$TEST_TEMP_DIR/repo-rules' '$TEST_TEMP_DIR/.codex/rules'
  "

  [ "$status" -eq 0 ]
  [ -f "$TEST_TEMP_DIR/.codex/rules/default.rules" ]
  [ -f "$TEST_TEMP_DIR/.codex/rules/supercharged.rules" ]
  grep -F 'pattern=["existing"]' "$TEST_TEMP_DIR/.codex/rules/default.rules"
  grep -F 'pattern=["sudo"]' "$TEST_TEMP_DIR/.codex/rules/supercharged.rules"
}

@test "restore_codex_hook_scripts copies executable hook scripts" {
  mkdir -p "$TEST_TEMP_DIR/repo-hooks" "$TEST_TEMP_DIR/.codex/hooks"
  cat > "$TEST_TEMP_DIR/repo-hooks/test-hook.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

  run zsh -c "
    source '$RESTORE_SCRIPT'
    restore_codex_hook_scripts '$TEST_TEMP_DIR/repo-hooks' '$TEST_TEMP_DIR/.codex/hooks'
  "

  [ "$status" -eq 0 ]
  [ -x "$TEST_TEMP_DIR/.codex/hooks/test-hook.sh" ]
}

@test "rtk-enforce hook blocks when RTK suggests a rewrite" {
  hook="$PROJECT_ROOT/codex_config/hooks/rtk-enforce.sh"
  mock_bin="$TEST_TEMP_DIR/bin"
  mkdir -p "$mock_bin"
  cat > "$mock_bin/rtk" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "rewrite" ] && [ "$2" = "git status" ]; then
  printf '%s\n' "rtk git status"
  exit 0
fi
exit 1
EOF
  chmod +x "$mock_bin/rtk"

  run env PATH="$mock_bin:$PATH" bash "$hook" <<'EOF'
{"tool_input":{"command":"git status"}}
EOF

  [ "$status" -eq 0 ]
  [[ "$output" == *'"decision":"block"'* ]]
  [[ "$output" == *"rtk git status"* ]]
}

@test "restore-codex.sh restores Codex hooks RTK include and Plannotator skills" {
  run "$RESTORE_SCRIPT" --force

  [ "$status" -eq 0 ]
  [ -f "$HOME/.codex/config.toml" ]
  [ -f "$HOME/.codex/hooks.json" ]
  [ -f "$HOME/.codex/RTK.md" ]
  [ -f "$HOME/.codex/AGENTS.md" ]
  [ -f "$HOME/.codex/rules/supercharged.rules" ]
  [ -x "$HOME/.codex/hooks/rtk-enforce.sh" ]
  [ -f "$HOME/.codex/skills/plannotator-review/SKILL.md" ]

  grep -F 'hooks = true' "$HOME/.codex/config.toml"
  grep -F 'default_permissions = "supercharged"' "$HOME/.codex/config.toml"
  grep -F '"**/.secrets/**" = "deny"' "$HOME/.codex/config.toml"
  grep -F "\"command\": \"$HOME/.local/bin/plannotator\"" "$HOME/.codex/hooks.json"
  grep -Fx "@$HOME/.codex/RTK.md" "$HOME/.codex/AGENTS.md"
  grep -F 'pattern = ["rm", "-rf"]' "$HOME/.codex/rules/supercharged.rules"
}
