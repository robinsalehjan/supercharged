#!/usr/bin/env bats

# Load test helpers
load '../helpers/setup'
load '../helpers/mocks'

setup() {
  setup_test_env

  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  INSTALL_SKILLS="$PROJECT_ROOT/scripts/install-skills.sh"

  # Point the script at an isolated claude_config under $TEST_TEMP_DIR by
  # symlinking it in. install-skills.sh uses $UTILS_PROJECT_ROOT/claude_config
  # (derived from its own location), so the easiest isolation is to override
  # $HOME — skills land in $HOME/.claude/skills regardless.
  TEST_CLAUDE_CONFIG="$PROJECT_ROOT/claude_config"
}

teardown() {
  teardown_test_env
  unmock_jq 2>/dev/null || true
}

# Helper: write installed_skills.json into a temp claude_config dir and run
# the installer against it via a wrapper script that overrides UTILS_PROJECT_ROOT.
run_install_skills() {
  local skills_json="$1"
  local local_json="${2:-}"
  shift 2 || true

  # Build a sandboxed project root mirroring the real layout the script expects.
  local sandbox_root="$TEST_TEMP_DIR/project"
  mkdir -p "$sandbox_root/scripts/utils" "$sandbox_root/claude_config"

  # Copy the script and its deps (utils.sh + utils/* submodules).
  cp "$PROJECT_ROOT/scripts/install-skills.sh" "$sandbox_root/scripts/"
  cp "$PROJECT_ROOT/scripts/utils.sh" "$sandbox_root/scripts/"
  cp -R "$PROJECT_ROOT/scripts/utils/." "$sandbox_root/scripts/utils/"

  printf '%s\n' "$skills_json" > "$sandbox_root/claude_config/installed_skills.json"
  if [ -n "$local_json" ]; then
    printf '%s\n' "$local_json" > "$sandbox_root/claude_config/installed_skills.local.json"
  fi

  "$sandbox_root/scripts/install-skills.sh" "$@"
}

@test "exits successfully when installed_skills.json is missing" {
  local sandbox_root="$TEST_TEMP_DIR/project"
  mkdir -p "$sandbox_root/scripts/utils" "$sandbox_root/claude_config"
  cp "$PROJECT_ROOT/scripts/install-skills.sh" "$sandbox_root/scripts/"
  cp "$PROJECT_ROOT/scripts/utils.sh" "$sandbox_root/scripts/"
  cp -R "$PROJECT_ROOT/scripts/utils/." "$sandbox_root/scripts/utils/"

  run "$sandbox_root/scripts/install-skills.sh"

  [ "$status" -eq 0 ]
  [[ "$output" == *"nothing to do"* ]]
}

@test "--dry-run reports clone for a missing skill" {
  local skills='{"version":1,"skills":{"my-skill":{"repo":"https://example.com/my-skill.git","ref":"main"}}}'

  run run_install_skills "$skills" "" --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] Would clone skill: my-skill"* ]]
  # Crucial: dry-run must not create the target directory.
  [ ! -d "$HOME/.claude/skills/my-skill" ]
}

@test "--dry-run reports update for an existing git checkout" {
  local skills='{"version":1,"skills":{"existing-skill":{"repo":"https://example.com/existing.git","ref":"main"}}}'

  mkdir -p "$HOME/.claude/skills/existing-skill/.git"

  run run_install_skills "$skills" "" --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] Would update skill: existing-skill"* ]]
}

@test "merges installed_skills.local.json on top of the tracked set" {
  local skills='{"version":1,"skills":{"shared-skill":{"repo":"https://example.com/shared.git","ref":"main"}}}'
  local local_skills='{"version":1,"skills":{"local-only":{"repo":"https://example.com/local.git","ref":"main"}}}'

  run run_install_skills "$skills" "$local_skills" --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *"Merged 1 local skill(s)"* ]]
  [[ "$output" == *"shared-skill"* ]]
  [[ "$output" == *"local-only"* ]]
}

@test "local override takes precedence when both define the same skill" {
  # repo points at original.git @ main; local pins it to a fork @ dev.
  local skills='{"version":1,"skills":{"pinned":{"repo":"https://example.com/original.git","ref":"main"}}}'
  local local_skills='{"version":1,"skills":{"pinned":{"repo":"https://example.com/fork.git","ref":"dev"}}}'

  run run_install_skills "$skills" "$local_skills" --dry-run

  [ "$status" -eq 0 ]
  # Dry-run output includes the resolved repo+ref tuple.
  [[ "$output" == *"fork.git @ dev"* ]]
  [[ "$output" != *"original.git @ main"* ]]
}

@test "missing ref defaults to main" {
  local skills='{"version":1,"skills":{"no-ref-skill":{"repo":"https://example.com/no-ref.git"}}}'

  run run_install_skills "$skills" "" --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *"no-ref-skill (https://example.com/no-ref.git @ main)"* ]]
}

@test "degenerate installed_skills.json is a clean no-op" {
  # Missing .skills key — must not crash, must not iterate.
  local skills='{"version":1}'

  run run_install_skills "$skills" "" --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *"Skill installation complete"* ]]
  [[ "$output" != *"Would clone"* ]]
  [[ "$output" != *"Would update"* ]]
}

@test "empty skills object is a clean no-op" {
  local skills='{"version":1,"skills":{}}'

  run run_install_skills "$skills" "" --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *"Skill installation complete"* ]]
  [[ "$output" != *"Would clone"* ]]
}

@test "skips a target that exists but is not a git checkout" {
  # Pre-create a plain directory at the target path. Production behavior is to
  # log a warning and continue — must not rm-rf or attempt a clone over it.
  local skills='{"version":1,"skills":{"squatted":{"repo":"https://example.com/squatted.git","ref":"main"}}}'

  mkdir -p "$HOME/.claude/skills/squatted"
  echo "user data" > "$HOME/.claude/skills/squatted/important.txt"

  run run_install_skills "$skills" ""

  [ "$status" -eq 0 ]
  [[ "$output" == *"Skipping squatted"* ]]
  [[ "$output" == *"is not a git checkout"* ]]
  # Critical: user content must survive untouched.
  [ -f "$HOME/.claude/skills/squatted/important.txt" ]
  [ "$(cat "$HOME/.claude/skills/squatted/important.txt")" = "user data" ]
}

@test "failed clone surfaces git stderr and continues to the next skill" {
  # Bogus URL forces a clone failure; the WARN line must include git's actual
  # error rather than the silent "(continuing)" we used to print. The second
  # skill should still be processed.
  local skills='{"version":1,"skills":{"bad-repo":{"repo":"file:///nonexistent/path.git","ref":"main"},"second":{"repo":"file:///also-nonexistent.git","ref":"main"}}}'

  run run_install_skills "$skills" ""

  [ "$status" -eq 0 ]
  [[ "$output" == *"Failed to clone skill: bad-repo"* ]]
  # git's actual error should appear after the dash separator.
  [[ "$output" == *"Failed to clone skill: bad-repo (continuing) — "* ]]
  # Second skill is still attempted even after the first failed.
  [[ "$output" == *"Cloning skill: second"* ]]
  [[ "$output" == *"Skill installation complete"* ]]
}

@test "malformed installed_skills.local.json surfaces a warning and falls back to the base file" {
  local skills='{"version":1,"skills":{"only-base":{"repo":"https://example.com/base.git","ref":"main"}}}'
  local bad_local='{not valid json'

  run run_install_skills "$skills" "$bad_local" --dry-run

  [ "$status" -eq 0 ]
  # The merge failure should be visible (not silently dropped as it was before).
  [[ "$output" == *"Failed to merge skills JSON"* ]]
  # Base file still drives the install.
  [[ "$output" == *"only-base"* ]]
}
