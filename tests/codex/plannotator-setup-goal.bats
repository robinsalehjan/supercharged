#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SKILL="${SUPERCHARGED_TEST_SKILL_ROOT:-}/plannotator-setup-goal/SKILL.md"
}

require_installed_fixture() {
  [ -n "${SUPERCHARGED_TEST_SKILL_ROOT:-}" ] || skip "set SUPERCHARGED_TEST_SKILL_ROOT to exercise the upstream skill in a staged install"
}

@test "setup-goal catalog pins the upstream bundled-interview workflow" {
  run jq -e '.skills["plannotator-setup-goal"] | .repo == "backnotprop/plannotator" and (.ref | test("^[a-f0-9]{40}$")) and .names == ["plannotator-setup-goal"]' "$PROJECT_ROOT/agent_config/installed_skills.json"
  [ "$status" -eq 0 ]
}

@test "setup-goal skill uses the bundled interview and facts workflow" {
  require_installed_fixture
  grep -F "Build a compact bundle of questions" "$SKILL"
  grep -F "plannotator setup-goal interview" "$SKILL"
  grep -F "goals/<slug>/interview-result.json" "$SKILL"
  grep -F "Before moving to facts, read every answer and note carefully" "$SKILL"
  grep -F "plannotator setup-goal facts" "$SKILL"
  grep -F "goals/<slug>/facts-result.json" "$SKILL"
  grep -F "automatedVerification" "$SKILL"
  ! grep -F "setup-goal interview -" "$SKILL"
  ! grep -F "setup-goal facts -" "$SKILL"
}

@test "setup-goal skill keeps opt-in grilling before the interview bundle" {
  require_installed_fixture
  grill_line=$(grep -nF "**Optional: grill first" "$SKILL" | cut -d: -f1)
  bundle_line=$(grep -nF "### 2. Interview Bundle" "$SKILL" | cut -d: -f1)

  [ -n "$grill_line" ]
  [ -n "$bundle_line" ]
  [ "$grill_line" -lt "$bundle_line" ]
  sed -n "${grill_line},${bundle_line}p" "$SKILL" | grep -F "This is opt-in"
  sed -n "${grill_line},${bundle_line}p" "$SKILL" | grep -F "Ask the questions one at a time."
}
