#!/usr/bin/env bats

load '../helpers/setup'

setup() {
  setup_test_env
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  UPDATE_SCRIPT="$PROJECT_ROOT/scripts/update-agent-tool-pins.sh"
  MANIFEST="$TEST_TEMP_DIR/managed-tools.json"
  PLUGIN_REGISTRY="$TEST_TEMP_DIR/plugins.json"
  RELEASE_JSON="$TEST_TEMP_DIR/release.json"
  cp "$PROJECT_ROOT/agent_config/managed_tools.json" "$MANIFEST"
  cp "$PROJECT_ROOT/codex_config/plugins.json" "$PLUGIN_REGISTRY"
  write_other_fixtures
}

write_other_fixtures() {
  CRG_JSON="$TEST_TEMP_DIR/crg.json"
  XCODE_JSON="$TEST_TEMP_DIR/xcode.json"
  OBSCURA_JSON="$TEST_TEMP_DIR/obscura.json"
  STATUSLINE_JSON="$TEST_TEMP_DIR/statusline.json"
  AXIOM_JSON="$TEST_TEMP_DIR/axiom.json"
  AXIOM_PLUGIN_JSON="$TEST_TEMP_DIR/axiom-plugin.json"
  crg=$(jq -r '.tools["code-review-graph"].version' "$MANIFEST")
  xv=$(jq -r '.tools.xcodebuildmcp.version' "$MANIFEST")
  ov=$(jq -r '.tools.obscura.version' "$MANIFEST")
  sc=$(jq -r '.tools["claude-statusline"].commit' "$MANIFEST")
  ac=$(jq -r '.marketplaces[0].ref' "$PLUGIN_REGISTRY")
  av=$(jq -r '.plugins[0].version' "$PLUGIN_REGISTRY")
  printf '{"info":{"version":"%s"}}\n' "$crg" > "$CRG_JSON"
  jq -n --arg tag "$xv" \
    --arg an "$(jq -r '.tools.xcodebuildmcp.assets["darwin-arm64"].name' "$MANIFEST")" \
    --arg as "$(jq -r '.tools.xcodebuildmcp.assets["darwin-arm64"].sha256' "$MANIFEST")" \
    --arg xn "$(jq -r '.tools.xcodebuildmcp.assets["darwin-x64"].name' "$MANIFEST")" \
    --arg xs "$(jq -r '.tools.xcodebuildmcp.assets["darwin-x64"].sha256' "$MANIFEST")" \
    '{tag_name:$tag,assets:[{name:$an,digest:("sha256:"+$as)},{name:$xn,digest:("sha256:"+$xs)}]}' > "$XCODE_JSON"
  jq -n --arg tag "$ov" \
    --arg an "$(jq -r '.tools.obscura.assets["darwin-arm64"].name' "$MANIFEST")" \
    --arg as "$(jq -r '.tools.obscura.assets["darwin-arm64"].sha256' "$MANIFEST")" \
    --arg xn "$(jq -r '.tools.obscura.assets["darwin-x64"].name' "$MANIFEST")" \
    --arg xs "$(jq -r '.tools.obscura.assets["darwin-x64"].sha256' "$MANIFEST")" \
    '{tag_name:$tag,assets:[{name:$an,digest:("sha256:"+$as)},{name:$xn,digest:("sha256:"+$xs)}]}' > "$OBSCURA_JSON"
  printf '{"sha":"%s"}\n' "$sc" > "$STATUSLINE_JSON"
  printf '{"sha":"%s"}\n' "$ac" > "$AXIOM_JSON"
  printf '{"version":"%s"}\n' "$av" > "$AXIOM_PLUGIN_JSON"
}

run_updater() {
  env MANAGED_TOOLS_MANIFEST="$MANIFEST" CODEX_PLUGIN_REGISTRY="$PLUGIN_REGISTRY" \
    PLANNOTATOR_RELEASE_JSON="$RELEASE_JSON" CRG_PYPI_JSON="$CRG_JSON" \
    XCODEBUILDMCP_RELEASE_JSON="$XCODE_JSON" OBSCURA_RELEASE_JSON="$OBSCURA_JSON" \
    STATUSLINE_COMMIT_JSON="$STATUSLINE_JSON" AXIOM_COMMIT_JSON="$AXIOM_JSON" \
    AXIOM_PLUGIN_JSON="$AXIOM_PLUGIN_JSON" "$UPDATE_SCRIPT" "$@"
}

teardown() {
  teardown_test_env
}

write_release() {
  local version="$1"
  local arm64_sha="$2"
  local x64_sha="$3"
  cat > "$RELEASE_JSON" <<EOF
{
  "tag_name": "$version",
  "assets": [
    {
      "name": "plannotator-darwin-arm64",
      "digest": "sha256:$arm64_sha"
    },
    {
      "name": "plannotator-darwin-x64",
      "digest": "sha256:$x64_sha"
    }
  ]
}
EOF
}

@test "managed tool pin updater is executable" {
  [ -x "$UPDATE_SCRIPT" ]
}

@test "managed tool pin check leaves a current manifest unchanged" {
  version=$(jq -r '.tools.plannotator.version' "$MANIFEST")
  arm64_sha=$(jq -r '.tools.plannotator.assets["darwin-arm64"].sha256' "$MANIFEST")
  x64_sha=$(jq -r '.tools.plannotator.assets["darwin-x64"].sha256' "$MANIFEST")
  write_release "$version" "$arm64_sha" "$x64_sha"
  before=$(shasum -a 256 "$MANIFEST" | awk '{print $1}')

  run run_updater

  [ "$status" -eq 0 ]
  [[ "$output" == *"pins are current"* ]]
  [ "$(shasum -a 256 "$MANIFEST" | awk '{print $1}')" = "$before" ]
}

@test "managed tool pin updater applies a release and both architecture checksums" {
  arm64_sha="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  x64_sha="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  write_release "v9.9.9" "$arm64_sha" "$x64_sha"

  run run_updater --apply

  [ "$status" -eq 0 ]
  [[ "$output" == *"Updated managed agent-tool pins"* ]]
  run jq -e \
    --arg arm64 "$arm64_sha" \
    --arg x64 "$x64_sha" \
    '.tools.plannotator.version == "v9.9.9" and
     .tools.plannotator.assets["darwin-arm64"].sha256 == $arm64 and
     .tools.plannotator.assets["darwin-x64"].sha256 == $x64' \
    "$MANIFEST"
  [ "$status" -eq 0 ]
}

@test "managed tool pin updater rejects a release without verified digests" {
  cat > "$RELEASE_JSON" <<'EOF'
{"tag_name":"v9.9.9","assets":[]}
EOF
  before=$(shasum -a 256 "$MANIFEST" | awk '{print $1}')

  run run_updater --apply

  [ "$status" -ne 0 ]
  [ "$(shasum -a 256 "$MANIFEST" | awk '{print $1}')" = "$before" ]
}
