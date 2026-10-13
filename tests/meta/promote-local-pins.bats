#!/usr/bin/env bats

load '../helpers/setup'

setup() {
  setup_test_env
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$PROJECT_ROOT/scripts/promote-local-pins.sh"
  TOOL_VERSIONS="$TEST_TEMP_DIR/.tool-versions"
  MOCK_BIN="$TEST_TEMP_DIR/bin"
  mkdir -p "$MOCK_BIN"
  printf 'nodejs 24.20.0\npython 3.14.7\n' > "$TOOL_VERSIONS"
  MANIFEST="$TEST_TEMP_DIR/managed-tools.json"
  PLUGINS="$TEST_TEMP_DIR/plugins.json"
  cp "$PROJECT_ROOT/agent_config/managed_tools.json" "$MANIFEST"
  cp "$PROJECT_ROOT/codex_config/plugins.json" "$PLUGINS"
  cat > "$MOCK_BIN/asdf" <<'EOF'
#!/bin/sh
case "$1:$2:$3" in
  current:nodejs:)
    printf 'Name Version Source Installed\nnodejs 24.21.0 /mock true\n'
    ;;
  current:python:)
    printf 'Name Version Source Installed\npython 3.14.8 /mock false\n'
    ;;
  where:nodejs:24.21.0)
    printf '/mock/nodejs/24.21.0\n'
    ;;
  *) exit 1 ;;
esac
EOF
  chmod +x "$MOCK_BIN/asdf"
}

teardown() {
  teardown_test_env
}

run_promoter() {
  run env PATH="$MOCK_BIN:$PATH" ASDF_TOOL_VERSIONS="$TOOL_VERSIONS" \
    "$SCRIPT" --only asdf "$@"
}

@test "local promotion previews installed versions without changing pins" {
  run_promoter

  [ "$status" -eq 0 ]
  [[ "$output" == *"asdf nodejs: 24.20.0 -> 24.21.0"* ]]
  [[ "$output" != *"python:"* ]]
  grep -Fxq 'nodejs 24.20.0' "$TOOL_VERSIONS"
}

@test "local promotion applies only active installed versions" {
  run_promoter --apply

  [ "$status" -eq 0 ]
  grep -Fxq 'nodejs 24.21.0' "$TOOL_VERSIONS"
  grep -Fxq 'python 3.14.7' "$TOOL_VERSIONS"
}

@test "local agent promotion uses the installed npm package version" {
  cat > "$MOCK_BIN/npm" <<'EOF'
#!/bin/sh
case "$*" in
  *openwiki*) printf '{"dependencies":{"openwiki":{"version":"9.9.9"}}}\n' ;;
  *) printf '{"dependencies":{}}\n' ;;
esac
EOF
  chmod +x "$MOCK_BIN/npm"

  run env PATH="$MOCK_BIN:$PATH" MANAGED_TOOLS_MANIFEST="$MANIFEST" \
    CODEX_PLUGIN_REGISTRY="$PLUGINS" "$SCRIPT" --only agents --apply

  [ "$status" -eq 0 ]
  run jq -e '.tools.openwiki.version == "9.9.9"' "$MANIFEST"
  [ "$status" -eq 0 ]
}

@test "local promotion captures a working Firebase npm installation" {
  cat > "$MOCK_BIN/npm" <<'EOF'
#!/bin/sh
case "$*" in
  *firebase-tools*) printf '{"dependencies":{"firebase-tools":{"version":"15.29.0"}}}\n' ;;
  *) printf '{"dependencies":{}}\n' ;;
esac
EOF
  chmod +x "$MOCK_BIN/npm"
  cat > "$MOCK_BIN/firebase" <<'EOF'
#!/bin/sh
printf '15.29.0\n'
EOF
  chmod +x "$MOCK_BIN/firebase"

  run env PATH="$MOCK_BIN:$PATH" MANAGED_TOOLS_MANIFEST="$MANIFEST" \
    CODEX_PLUGIN_REGISTRY="$PLUGINS" "$SCRIPT" --only agents --apply

  [ "$status" -eq 0 ]
  run jq -e '.tools.firebase.version == "15.29.0"' "$MANIFEST"
  [ "$status" -eq 0 ]
}

@test "local promotion skips a Firebase package whose command cannot run" {
  cat > "$MOCK_BIN/npm" <<'EOF'
#!/bin/sh
case "$*" in
  *firebase-tools*) printf '{"dependencies":{"firebase-tools":{"version":"15.29.0"}}}\n' ;;
  *) printf '{"dependencies":{}}\n' ;;
esac
EOF
  cat > "$MOCK_BIN/firebase" <<'EOF'
#!/bin/sh
exit 1
EOF
  chmod +x "$MOCK_BIN/npm" "$MOCK_BIN/firebase"

  run env PATH="$MOCK_BIN:$PATH" MANAGED_TOOLS_MANIFEST="$MANIFEST" \
    CODEX_PLUGIN_REGISTRY="$PLUGINS" "$SCRIPT" --only agents --apply

  [ "$status" -eq 0 ]
  [[ "$output" == *"Skipping firebase: no local installation detected"* ]]
  run jq -e '.tools.firebase.version == "15.28.2"' "$MANIFEST"
  [ "$status" -eq 0 ]
}
