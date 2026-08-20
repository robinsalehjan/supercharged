#!/usr/bin/env bats

load '../helpers/setup'

setup() {
  setup_test_env
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  AUDIT="$PROJECT_ROOT/scripts/audit-agents.sh"
}

teardown() {
  teardown_test_env
}

@test "agent audit has deterministic human and JSON repo-only output" {
  run "$AUDIT" --repo-only
  [ "$status" -eq 0 ]
  [[ "$output" == *"Tracked Codex base, Apple, headless Apple, and review TOML profiles parse"* ]]
  [[ "$output" == *"RTK hook rewrites a command without blocking it"* ]]
  [[ "$output" == *"Managed tool manifest pins exact tools, remote commits, and compatibility floors"* ]]

  run "$AUDIT" --repo-only --json
  [ "$status" -eq 0 ]
  run jq -e '.ok == true and .repo_only == true and (.failures | length == 0)' <<<"$output"
  [ "$status" -eq 0 ]
}

@test "agent audit accepts the current Codex pluginId JSON field" {
  run rg -F '.pluginId // .id // .name' "$AUDIT"
  [ "$status" -eq 0 ]
}
