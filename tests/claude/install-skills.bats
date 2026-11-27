#!/usr/bin/env bats
load '../helpers/setup'

setup() {
  setup_test_env
  root="$TEST_TEMP_DIR/repo"
  mkdir -p "$root/scripts" "$root/agent_config" "$TEST_TEMP_DIR/bin"
  cp "$BATS_TEST_DIRNAME/../../scripts/shared_skills.py" "$root/scripts/"
  mkdir "$root/agent_config/sample"
  echo fixture > "$root/agent_config/sample/SKILL.md"
  echo '{"tools":{"skills":{"version":"1.9.1"}}}' > "$root/agent_config/managed_tools.json"
  echo '{"skills":{"sample":{"local":"agent_config/sample"}}}' > "$root/agent_config/installed_skills.json"
  echo '{}' > "$root/agent_config/legacy_skill_hashes.json"
  cat > "$TEST_TEMP_DIR/bin/npx" <<'MOCK'
#!/bin/sh
set -eu
[ "$1" = --yes ] && [ "$2" = skills@1.9.1 ] && [ "$3" = add ] || exit 2
mkdir -p .agents/skills
cp -R "$4" .agents/skills/sample
MOCK
  chmod +x "$TEST_TEMP_DIR/bin/npx"
  export PATH="$TEST_TEMP_DIR/bin:$PATH"
}
teardown() { teardown_test_env; }

@test "dry-run previews pinned sources without creating a skill state directory" {
  run python3 "$root/scripts/shared_skills.py" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *sample* ]]
  [ ! -e "$HOME/.local/share/supercharged/skills" ]
}

@test "both harnesses share installed contents and preserve unmanaged skills" {
  mkdir -p "$HOME/.claude/skills/unmanaged"
  run python3 "$root/scripts/shared_skills.py" --harness codex
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.claude/skills/sample" ]
  run python3 "$root/scripts/shared_skills.py"
  [ "$status" -eq 0 ]
  cmp "$HOME/.claude/skills/sample/SKILL.md" "$HOME/.agents/skills/sample/SKILL.md"
  [ -d "$HOME/.claude/skills/unmanaged" ]
  run python3 "$root/scripts/shared_skills.py"
  [ "$status" -eq 0 ]
  [[ "$output" != *journal* ]]
}

@test "migration adopts a matching copy with rollback and rejects unknown content" {
  mkdir -p "$HOME/.claude/skills"
  cp -R "$root/agent_config/sample" "$HOME/.claude/skills/"
  run python3 "$root/scripts/shared_skills.py"
  [ "$status" -ne 0 ]
  [ ! -e "$HOME/.agents/skills/sample" ]
  run python3 "$root/scripts/shared_skills.py" --migrate
  [ "$status" -eq 0 ]
  journal="${output##*journal: }"
  run python3 "$root/scripts/shared_skills.py" --rollback "$journal"
  [ "$status" -eq 0 ]
  [ ! -L "$HOME/.claude/skills/sample" ]
  [ -f "$HOME/.claude/skills/sample/SKILL.md" ]
  echo local > "$HOME/.claude/skills/sample/SKILL.md"
  run python3 "$root/scripts/shared_skills.py" --migrate
  [ "$status" -ne 0 ]
  [ "$(cat "$HOME/.claude/skills/sample/SKILL.md")" = local ]
}

@test "failed npx update keeps both agents on the previous release" {
  run python3 "$root/scripts/shared_skills.py"
  [ "$status" -eq 0 ]
  echo update > "$root/agent_config/sample/SKILL.md"
  echo 'exit 1' > "$TEST_TEMP_DIR/bin/npx"
  run python3 "$root/scripts/shared_skills.py"
  [ "$status" -ne 0 ]
  [ "$(cat "$HOME/.agents/skills/sample/SKILL.md")" = fixture ]
  [ "$(cat "$HOME/.claude/skills/sample/SKILL.md")" = fixture ]
}

@test "reconciliation preserves project plugins and hidden local skill links" {
  mkdir -p "$HOME/.claude/plugins" "$HOME/.agents/skills"
  echo '{"plugins":{"firebase@firebase":[{"scope":"project"}]}}' > "$HOME/.claude/plugins/installed_plugins.json"
  ln -s "$TEST_TEMP_DIR" "$HOME/.agents/skills/.custom"
  run python3 "$root/scripts/shared_skills.py"
  [ "$status" -eq 0 ]
  [ -L "$HOME/.agents/skills/.custom" ]
  [ -f "$HOME/.claude/skills/sample/SKILL.md" ]
}

@test "user plugin requires migration before ordinary install changes the home" {
  mkdir -p "$HOME/.claude/plugins"
  echo '{"plugins":{"firebase@firebase":[{"scope":"user"}]}}' > "$HOME/.claude/plugins/installed_plugins.json"
  run python3 "$root/scripts/shared_skills.py"
  [ "$status" -ne 0 ]
  [ ! -e "$HOME/.local/share/supercharged/skills" ]
  [[ "$output" == *migrate:skills* ]]
}

@test "local override retires only previously managed links" {
  run python3 "$root/scripts/shared_skills.py"
  [ "$status" -eq 0 ]
  mkdir "$HOME/.agents/skills/personal"
  echo '{"removed_skills":{"sample":{"repo":"example/repo"}}}' > "$root/agent_config/installed_skills.local.json"
  run python3 "$root/scripts/shared_skills.py"
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.agents/skills/sample" ]
  [ ! -e "$HOME/.claude/skills/sample" ]
  [ -d "$HOME/.agents/skills/personal" ]
}
