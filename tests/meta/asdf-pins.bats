#!/usr/bin/env bats

load '../helpers/setup'

setup() {
  setup_test_env
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$PROJECT_ROOT/scripts/update-asdf-pins.sh"

  FIXTURES="$TEST_TEMP_DIR/versions"
  mkdir -p "$FIXTURES"
  # Node publishes newer non-LTS majors; Python publishes freethreaded `t`
  # builds alongside the plain ones. Both must be filtered out.
  printf '%s\n' 24.19.0 24.20.0 25.1.0 26.8.1 > "$FIXTURES/nodejs.txt"
  printf '%s\n' 3.14.6 3.14.6t 3.14.7 3.14.7t > "$FIXTURES/python.txt"
  printf '%s\n' 3.4.9 3.4.10 4.0.6 > "$FIXTURES/ruby.txt"
  printf '%s\n' 4.0.18 4.0.19 > "$FIXTURES/bundler.txt"
  printf '%s\n' 581.0.0 583.0.0 > "$FIXTURES/gcloud.txt"
  printf '%s\n' 15.28.1 15.28.2 > "$FIXTURES/firebase.txt"
  printf '%s\n' openjdk-26.0.2.1 openjdk-27 > "$FIXTURES/java.txt"

  TOOL_VERSIONS="$TEST_TEMP_DIR/.tool-versions"
  cat > "$TOOL_VERSIONS" <<'EOF'
# Supercharged Development Tool Versions

nodejs 24.19.0
python 3.14.7
ruby 3.4.10

# Package Managers
bundler 4.0.19

gcloud 581.0.0
firebase 15.28.1
java openjdk-26.0.2.1
EOF
}

teardown() {
  teardown_test_env
}

run_updater() {
  run env \
    ASDF_LIST_FIXTURE_DIR="$FIXTURES" \
    ASDF_TOOL_VERSIONS="$TOOL_VERSIONS" \
    "$SCRIPT" "$@"
}

@test "update-asdf-pins.sh keeps Node.js on its tracked LTS line" {
  run_updater

  [ "$status" -eq 0 ]
  [[ "$output" == *"nodejs: 24.19.0 -> 24.20.0"* ]]
  [[ "$output" != *"25.1.0"* ]]
  [[ "$output" != *"26.8.1"* ]]
}

@test "update-asdf-pins.sh never proposes a freethreaded Python build" {
  run_updater

  [ "$status" -eq 0 ]
  [[ "$output" != *"3.14.7t"* ]]
  [[ "$output" != *"python:"* ]]
}

@test "update-asdf-pins.sh holds Ruby on its tracked line" {
  run_updater

  [ "$status" -eq 0 ]
  [[ "$output" != *"4.0.6"* ]]
  [[ "$output" != *"ruby:"* ]]
}

@test "update-asdf-pins.sh reports held plugins without proposing a bump" {
  run_updater

  [ "$status" -eq 0 ]
  [[ "$output" == *"held:  java openjdk-26.0.2.1"* ]]
  [[ "$output" != *"openjdk-27"* ]]
}

@test "update-asdf-pins.sh reports drift without writing by default" {
  before=$(cat "$TOOL_VERSIONS")

  run_updater

  [ "$status" -eq 0 ]
  [[ "$output" == *"gcloud: 581.0.0 -> 583.0.0"* ]]
  [[ "$output" == *"firebase: 15.28.1 -> 15.28.2"* ]]
  [ "$(cat "$TOOL_VERSIONS")" = "$before" ]
}

@test "update-asdf-pins.sh --apply rewrites only the pin lines" {
  comments_before=$(grep -c '^#' "$TOOL_VERSIONS")

  run_updater --apply

  [ "$status" -eq 0 ]
  grep -Fxq 'nodejs 24.20.0' "$TOOL_VERSIONS"
  grep -Fxq 'gcloud 583.0.0' "$TOOL_VERSIONS"
  grep -Fxq 'firebase 15.28.2' "$TOOL_VERSIONS"
  # Held and line-tracked pins are untouched.
  grep -Fxq 'java openjdk-26.0.2.1' "$TOOL_VERSIONS"
  grep -Fxq 'ruby 3.4.10' "$TOOL_VERSIONS"
  grep -Fxq 'python 3.14.7' "$TOOL_VERSIONS"
  [ "$(grep -c '^#' "$TOOL_VERSIONS")" -eq "$comments_before" ]
}

@test "update-asdf-pins.sh is idempotent" {
  run_updater --apply
  [ "$status" -eq 0 ]

  run_updater

  [ "$status" -eq 0 ]
  [[ "$output" == *"asdf pins are current"* ]]
}

@test "update-asdf-pins.sh rejects unknown flags" {
  run_updater --bogus

  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "every pinned runtime in .tool-versions has a policy" {
  policy="$PROJECT_ROOT/agent_config/asdf_policy.json"
  tracked="$PROJECT_ROOT/dot_files/.tool-versions"

  while read -r plugin _; do
    case "$plugin" in ''|'#'*) continue ;; esac
    run jq -e --arg p "$plugin" '.plugins[$p] != null' "$policy"
    [ "$status" -eq 0 ]
  done < "$tracked"
}
