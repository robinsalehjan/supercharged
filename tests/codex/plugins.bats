#!/usr/bin/env bats

load '../helpers/setup'

setup() {
  setup_test_env
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  INSTALLER="$PROJECT_ROOT/scripts/install-codex-plugins.sh"
  MOCK_BIN="$TEST_TEMP_DIR/bin"
  CALLS="$TEST_TEMP_DIR/codex.calls"
  PINNED_REF=$(jq -r '.marketplaces[0].ref' "$PROJECT_ROOT/codex_config/plugins.json")
  PINNED_VERSION=$(jq -r '.plugins[0].version' "$PROJECT_ROOT/codex_config/plugins.json")
  mkdir -p "$MOCK_BIN"
  cat > "$MOCK_BIN/codex" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$CODEX_CALLS"
case "$1 $2 $3" in
  "plugin marketplace list")
    if [ "${MARKETPLACE_EXISTS:-false}" = true ]; then
      printf '%s\n' '{"marketplaces":[{"name":"axiom-marketplace"}]}'
    else
      printf '%s\n' '{"marketplaces":[]}'
    fi
    ;;
  "plugin list --json")
    printf '{"installed":[{"pluginId":"axiom@axiom-marketplace","version":"%s"}]}\n' "$CODEX_PLUGIN_VERSION"
    ;;
esac
[ "${CODEX_FAIL:-}" = "$1-$2-$3" ] && exit 1
exit 0
EOF
  chmod +x "$MOCK_BIN/codex"
}

teardown() {
  teardown_test_env
}

@test "Codex plugin installer previews without invoking Codex" {
  run "$INSTALLER" --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *"Would pin marketplace: axiom-marketplace"* ]]
  [ ! -e "$CALLS" ]
}

@test "Codex plugin installer adds marketplace and installs Axiom" {
  run env PATH="$MOCK_BIN:$PATH" CODEX_CALLS="$CALLS" CODEX_PLUGIN_VERSION="$PINNED_VERSION" "$INSTALLER"

  [ "$status" -eq 0 ]
  grep -Fx "plugin marketplace add CharlesWiltgen/Axiom --ref $PINNED_REF" "$CALLS"
  grep -Fx 'plugin add axiom@axiom-marketplace' "$CALLS"
}

@test "Codex plugin installer replaces an existing marketplace with the pinned ref" {
  run env PATH="$MOCK_BIN:$PATH" CODEX_CALLS="$CALLS" CODEX_PLUGIN_VERSION="$PINNED_VERSION" MARKETPLACE_EXISTS=true "$INSTALLER"

  [ "$status" -eq 0 ]
  grep -Fx 'plugin marketplace remove axiom-marketplace' "$CALLS"
  grep -Fx "plugin marketplace add CharlesWiltgen/Axiom --ref $PINNED_REF" "$CALLS"
  grep -Fx 'plugin add axiom@axiom-marketplace' "$CALLS"
}

@test "Codex plugin installer preserves unrelated local plugin state" {
  local_config="$TEST_TEMP_DIR/.codex/config.toml"
  mkdir -p "$(dirname "$local_config")"
  printf '%s\n' '[plugins."local@marketplace"]' 'enabled = true' > "$local_config"

  run env PATH="$MOCK_BIN:$PATH" CODEX_CALLS="$CALLS" CODEX_PLUGIN_VERSION="$PINNED_VERSION" CODEX_HOME="$TEST_TEMP_DIR/.codex" "$INSTALLER"

  [ "$status" -eq 0 ]
  grep -F '[plugins."local@marketplace"]' "$local_config"
  grep -F 'enabled = true' "$local_config"
}

@test "Codex plugin installer rejects malformed registries and CLI failures" {
  registry="$TEST_TEMP_DIR/plugins.json"
  printf '%s\n' '{"version":1,"marketplaces":[],"plugins":[]}' > "$registry"

  run env CODEX_PLUGIN_REGISTRY="$registry" "$INSTALLER"
  [ "$status" -ne 0 ]
  [[ "$output" == *"malformed"* ]]

  run env PATH="$MOCK_BIN:$PATH" CODEX_CALLS="$CALLS" CODEX_PLUGIN_VERSION="$PINNED_VERSION" CODEX_FAIL='plugin-marketplace-add' "$INSTALLER"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Failed to add Codex marketplace"* ]]
}
