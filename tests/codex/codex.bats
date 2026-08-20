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
  [[ "$output" != *"[mcp_servers.node_repl]"* ]]
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

@test "codex configuration scopes base, native Apple, and headless Apple MCP servers" {
  config="$PROJECT_ROOT/codex_config/config.toml"
  apple_config="$PROJECT_ROOT/codex_config/apple.config.toml"
  apple_headless_config="$PROJECT_ROOT/codex_config/apple-headless.config.toml"
  review_config="$PROJECT_ROOT/codex_config/review.config.toml"

  run grep -F 'hooks = true' "$config"
  [ "$status" -eq 0 ]

  run grep -F '[mcp_servers.code-review-graph]' "$config"
  [ "$status" -eq 0 ]

  run grep -F '[mcp_servers.code-review-graph.tools.query_graph_tool]' "$config"
  [ "$status" -eq 0 ]

  run grep -F '[mcp_servers.openaiDeveloperDocs]' "$config"
  [ "$status" -eq 0 ]

  run grep -F '[mcp_servers.XcodeBuildMCP]' "$apple_headless_config"
  [ "$status" -eq 0 ]

  run grep -F '[mcp_servers.xcode]' "$apple_config"
  [ "$status" -eq 0 ]

  ! grep -F '[mcp_servers.axiom]' "$config"
  ! grep -F '[mcp_servers.XcodeBuildMCP]' "$config"
  ! grep -F '[mcp_servers.XcodeBuildMCP]' "$apple_config"
  ! grep -F '[mcp_servers.xcode]' "$apple_headless_config"
  ! grep -F '[mcp_servers.cupertino]' "$apple_config"
  grep -F 'model_reasoning_effort = "xhigh"' "$review_config"
  grep -F 'memories = false' "$config"
  grep -F 'web_search = "live"' "$config"
}

@test "tracked Claude configuration retains only language-server fallback plugins" {
  settings="$PROJECT_ROOT/claude_config/settings.json"
  plugins="$PROJECT_ROOT/claude_config/installed_plugins.json"
  marketplaces="$PROJECT_ROOT/claude_config/known_marketplaces.json"

  run jq -e '
    (.enabledPlugins | keys | sort) == [
      "pyright-lsp@claude-plugins-official",
      "swift-lsp@claude-plugins-official",
      "typescript-lsp@claude-plugins-official"
    ]
  ' "$settings"
  [ "$status" -eq 0 ]

  run jq -e '
    (.plugins | keys | sort) == [
      "pyright-lsp@claude-plugins-official",
      "swift-lsp@claude-plugins-official",
      "typescript-lsp@claude-plugins-official"
    ]
  ' "$plugins"
  [ "$status" -eq 0 ]

  run jq -e '(.extraKnownMarketplaces | keys) == ["claude-plugins-official"]' "$settings"
  [ "$status" -eq 0 ]

  run jq -e 'keys == ["claude-plugins-official"]' "$marketplaces"
  [ "$status" -eq 0 ]
}

@test "code-review-graph MCP uses the exact managed pipx installation" {
  ! grep -R -E 'code-review-graph@[0-9]|uvx' "$PROJECT_ROOT/.mcp.json" "$PROJECT_ROOT/codex_config/config.toml"
  grep -F 'command = "code-review-graph"' "$PROJECT_ROOT/codex_config/config.toml"
  grep -F 'managed_spec="${package}[${extras}]==${managed_version}"' "$PROJECT_ROOT/scripts/utils/tools.sh"
  jq -e '.tools["code-review-graph"].policy == "exact-pypi"' "$PROJECT_ROOT/agent_config/managed_tools.json"
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

  run grep -F 'code-review-graph first' "$instructions"
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

@test "restore_shared_agent_skills copies canonical skills into Codex" {
  mkdir -p "$TEST_TEMP_DIR/agent_config/skills/review-changes" "$TEST_TEMP_DIR/.codex/skills"
  cat > "$TEST_TEMP_DIR/agent_config/skills/review-changes/SKILL.md" <<'EOF'
---
name: Review Changes
description: Perform a structured code review
---

# Review Changes
EOF

  run zsh -c "
    source '$RESTORE_SCRIPT'
    AGENT_CONFIG_DIR='$TEST_TEMP_DIR/agent_config'
    CODEX_HOME='$TEST_TEMP_DIR/.codex'
    restore_shared_agent_skills
  "

  [ "$status" -eq 0 ]
  [ -f "$TEST_TEMP_DIR/.codex/skills/review-changes/SKILL.md" ]
  grep -F "Perform a structured code review" "$TEST_TEMP_DIR/.codex/skills/review-changes/SKILL.md"
}

@test "canonical shared skills override existing Codex skill directories" {
  mkdir -p "$TEST_TEMP_DIR/agent_config/skills/shared-rule" \
    "$TEST_TEMP_DIR/.codex/skills/shared-rule"

  cat > "$TEST_TEMP_DIR/.codex/skills/shared-rule/SKILL.md" <<'EOF'
---
name: shared-rule
description: Existing Codex version
---

# Existing Version
EOF

  cat > "$TEST_TEMP_DIR/agent_config/skills/shared-rule/SKILL.md" <<'EOF'
---
name: shared-rule
description: Project-level version
---

# Project Version
EOF

  run zsh -c "
    source '$RESTORE_SCRIPT'
    AGENT_CONFIG_DIR='$TEST_TEMP_DIR/agent_config'
    CODEX_HOME='$TEST_TEMP_DIR/.codex'
    restore_shared_agent_skills
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

@test "Codex profiles restore directly and participate in timestamp gating" {
  repo_config="$TEST_TEMP_DIR/repo-codex-config"
  codex_home="$TEST_TEMP_DIR/.codex"
  mkdir -p "$repo_config" "$codex_home"
  printf '%s\n' '[mcp_servers.xcode]' 'command = "xcrun"' > "$repo_config/apple.config.toml"
  printf '%s\n' '[mcp_servers.XcodeBuildMCP]' 'command = "xcodebuildmcp"' > "$repo_config/apple-headless.config.toml"
  printf '%s\n' 'model_reasoning_effort = "xhigh"' > "$repo_config/review.config.toml"

  run zsh -c "
    source '$RESTORE_SCRIPT'
    CODEX_CONFIG_DIR='$repo_config'
    CODEX_HOME='$codex_home'
    restore_codex_profile apple
    restore_codex_profile apple-headless
    restore_codex_profile review
  "
  [ "$status" -eq 0 ]
  [ -f "$codex_home/apple.config.toml" ]
  [ -f "$codex_home/apple-headless.config.toml" ]
  [ -f "$codex_home/review.config.toml" ]

  touch -t 202501010000 "$codex_home/config.toml"
  touch -t 202501010000 "$codex_home/apple.config.toml"
  touch -t 209901010000 "$repo_config/apple-headless.config.toml"
  run zsh -c "
    source '$RESTORE_SCRIPT'
    CODEX_CONFIG_DIR='$repo_config'
    CODEX_HOME='$codex_home'
    AGENT_CONFIG_DIR='$TEST_TEMP_DIR/missing-agent-config'
    is_repo_newer
  "
  [ "$status" -eq 0 ]
}

@test "rtk-enforce hook rewrites when RTK suggests a rewrite" {
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
  [[ "$output" == *'"permissionDecision":"allow"'* ]]
  [[ "$output" == *'"updatedInput":{"command":"rtk git status"}'* ]]
}

@test "rtk-enforce hook leaves unchanged commands, malformed input, and missing RTK alone" {
  hook="$PROJECT_ROOT/codex_config/hooks/rtk-enforce.sh"
  mock_bin="$TEST_TEMP_DIR/bin"
  mkdir -p "$mock_bin"
  cat > "$mock_bin/rtk" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "rewrite" ]; then
  printf '%s\n' "$2"
  exit 3
fi
exit 1
EOF
  chmod +x "$mock_bin/rtk"

  run env PATH="$mock_bin:$PATH" bash "$hook" <<'EOF'
{"tool_input":{"command":"git status"}}
EOF
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  run env PATH="$mock_bin:$PATH" bash "$hook" <<'EOF'
not-json
EOF
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  ln -s "$(command -v jq)" "$TEST_TEMP_DIR/jq"
  run env PATH="$TEST_TEMP_DIR" /bin/bash "$hook" <<'EOF'
{"tool_input":{"command":"git status"}}
EOF
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "rtk-enforce hook prevents a rewrite loop for RTK commands" {
  hook="$PROJECT_ROOT/codex_config/hooks/rtk-enforce.sh"
  mock_bin="$TEST_TEMP_DIR/bin"
  marker="$TEST_TEMP_DIR/rtk-called"
  mkdir -p "$mock_bin"
  cat > "$mock_bin/rtk" <<EOF
#!/usr/bin/env bash
touch "$marker"
printf '%s\\n' "rtk rtk git status"
EOF
  chmod +x "$mock_bin/rtk"

  run env PATH="$mock_bin:$PATH" bash "$hook" <<'EOF'
{"tool_input":{"command":"rtk git status"}}
EOF

  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$marker" ]
}

@test "restore-codex.sh restores Codex hooks RTK include and Plannotator skills" {
  mock_bin="$TEST_TEMP_DIR/bin"
  mkdir -p "$mock_bin"
  cat > "$mock_bin/codex" <<'EOF'
#!/bin/sh
case "$1 $2 $3" in
  "plugin marketplace list") printf '%s\n' '{"marketplaces":[]}' ;;
esac
exit 0
EOF
  chmod +x "$mock_bin/codex"

  run env PATH="$mock_bin:$PATH" SUPERCHARGED_SKIP_MANAGED_TOOL_INSTALLS=1 "$RESTORE_SCRIPT" --force

  [ "$status" -eq 0 ]
  [ -f "$HOME/.codex/config.toml" ]
  [ -f "$HOME/.codex/hooks.json" ]
  [ -f "$HOME/.codex/RTK.md" ]
  [ -f "$HOME/.codex/AGENTS.md" ]
  [ -f "$HOME/.codex/apple.config.toml" ]
  [ -f "$HOME/.codex/apple-headless.config.toml" ]
  [ -f "$HOME/.codex/review.config.toml" ]
  [ -f "$HOME/.codex/rules/supercharged.rules" ]
  [ -x "$HOME/.codex/hooks/rtk-enforce.sh" ]
  [ -f "$HOME/.codex/skills/plannotator-review/SKILL.md" ]
  [ -f "$HOME/.codex/skills/review-changes/SKILL.md" ]

  grep -F 'hooks = true' "$HOME/.codex/config.toml"
  grep -F 'default_permissions = "supercharged"' "$HOME/.codex/config.toml"
  grep -F '"**/.secrets/**" = "deny"' "$HOME/.codex/config.toml"
  grep -F "\"command\": \"$HOME/.local/bin/plannotator\"" "$HOME/.codex/hooks.json"
  grep -Fx "@$HOME/.codex/RTK.md" "$HOME/.codex/AGENTS.md"
  grep -F 'pattern = ["rm", "-rf"]' "$HOME/.codex/rules/supercharged.rules"
  grep -F 'model_reasoning_effort = "xhigh"' "$HOME/.codex/review.config.toml"
}
