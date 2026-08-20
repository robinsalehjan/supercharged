#!/usr/bin/env bats

load '../helpers/setup'
load '../helpers/mocks'

setup() {
  setup_test_env
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  AUDIT="$PROJECT_ROOT/scripts/audit-agents.sh"
}

teardown() {
  unmock_all
  teardown_test_env
}

write_version_mock() {
  local command_name="$1"
  local version="$2"
  _ensure_mock_bin_dir
  printf '#!/bin/sh\nif [ "$1" = "--version" ]; then echo "%s %s"; fi\nexit 0\n' \
    "$command_name" "$version" > "$MOCK_BIN_DIR/$command_name"
  chmod +x "$MOCK_BIN_DIR/$command_name"
}

write_compatibility_mocks() {
  local manifest="$1"
  write_version_mock codex "$(jq -r '.compatibility.codex.tested_version' "$manifest")"
  write_version_mock claude "$(jq -r '.compatibility.claude.tested_version' "$manifest")"
  write_version_mock rtk "$(jq -r '.compatibility.rtk.tested_version' "$manifest")"
  write_version_mock wt "$(jq -r '.compatibility.worktrunk.tested_version' "$manifest")"
  write_version_mock code-review-graph "$(jq -r '.tools["code-review-graph"].version' "$manifest")"
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

@test "agent audit fails a compatibility version below its minimum" {
  local manifest="$TEST_TEMP_DIR/managed-tools.json"
  jq '.compatibility.codex.minimum_version = "2.0.0" |
      .compatibility.codex.tested_version = "2.1.0"' \
    "$PROJECT_ROOT/agent_config/managed_tools.json" > "$manifest"
  write_compatibility_mocks "$manifest"
  write_version_mock codex "1.9.9"

  run env MANAGED_TOOLS_MANIFEST="$manifest" "$AUDIT" --json

  [ "$status" -ne 0 ]
  run jq -e '.failures | any(. == "codex 1.9.9 is below the supported minimum 2.0.0")' \
    <<<"$output"
  [ "$status" -eq 0 ]
}

@test "agent audit warns when a compatibility version is newer than tested" {
  local manifest="$TEST_TEMP_DIR/managed-tools.json"
  jq '.compatibility.codex.minimum_version = "2.0.0" |
      .compatibility.codex.tested_version = "2.1.0"' \
    "$PROJECT_ROOT/agent_config/managed_tools.json" > "$manifest"
  write_compatibility_mocks "$manifest"
  write_version_mock codex "2.2.0"

  run env MANAGED_TOOLS_MANIFEST="$manifest" "$AUDIT" --json

  run jq -e '.warnings | any(. == "codex 2.2.0 meets the 2.0.0 minimum but differs from tested 2.1.0")' \
    <<<"$output"
  [ "$status" -eq 0 ]
}
