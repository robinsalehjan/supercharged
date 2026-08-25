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
  AXIOM_JSON="$TEST_TEMP_DIR/axiom.json"
  AXIOM_PLUGIN_JSON="$TEST_TEMP_DIR/axiom-plugin.json"
  crg=$(jq -r '.tools["code-review-graph"].version' "$MANIFEST")
  xv=$(jq -r '.tools.xcodebuildmcp.version' "$MANIFEST")
  ov=$(jq -r '.tools.obscura.version' "$MANIFEST")
  wv=$(jq -r '.tools.openwiki.version' "$MANIFEST")
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
  printf '{"sha":"%s"}\n' "$ac" > "$AXIOM_JSON"
  printf '{"version":"%s"}\n' "$av" > "$AXIOM_PLUGIN_JSON"
  OPENWIKI_VERSION="$wv"
}

run_updater() {
  env MANAGED_TOOLS_MANIFEST="$MANIFEST" CODEX_PLUGIN_REGISTRY="$PLUGIN_REGISTRY" \
    PLANNOTATOR_RELEASE_JSON="$RELEASE_JSON" CRG_PYPI_JSON="$CRG_JSON" \
    XCODEBUILDMCP_RELEASE_JSON="$XCODE_JSON" OBSCURA_RELEASE_JSON="$OBSCURA_JSON" \
    AXIOM_COMMIT_JSON="$AXIOM_JSON" \
    AXIOM_PLUGIN_JSON="$AXIOM_PLUGIN_JSON" \
    OPENWIKI_NPM_VERSION="$OPENWIKI_VERSION" \
    OBSCURA_ARCHIVES_DIR="${OBSCURA_ARCHIVES_DIR:-}" "$UPDATE_SCRIPT" "$@"
}

teardown() {
  unset OBSCURA_ARCHIVES_DIR
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

write_current_release() {
  write_release \
    "$(jq -r '.tools.plannotator.version' "$MANIFEST")" \
    "$(jq -r '.tools.plannotator.assets["darwin-arm64"].sha256' "$MANIFEST")" \
    "$(jq -r '.tools.plannotator.assets["darwin-x64"].sha256' "$MANIFEST")"
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

@test "managed tool pin updater applies a code-review-graph release" {
  write_current_release
  printf '{"info":{"version":"9.9.9"}}\n' > "$CRG_JSON"

  run run_updater --apply

  [ "$status" -eq 0 ]
  run jq -e '.tools["code-review-graph"].version == "9.9.9"' "$MANIFEST"
  [ "$status" -eq 0 ]
}

@test "managed tool pin updater applies an OpenWiki release" {
  write_current_release
  OPENWIKI_VERSION="9.9.9"

  run run_updater --apply

  [ "$status" -eq 0 ]
  run jq -e '.tools.openwiki.version == "9.9.9"' "$MANIFEST"
  [ "$status" -eq 0 ]
}

@test "managed tool pin updater applies an XcodeBuildMCP release and checksums" {
  write_current_release
  local arm64_sha="cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
  local x64_sha="dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
  jq -n --arg arm64 "$arm64_sha" --arg x64 "$x64_sha" '{
    tag_name: "v9.9.9",
    assets: [
      {name: "xcodebuildmcp-9.9.9-darwin-arm64.tar.gz", digest: ("sha256:" + $arm64)},
      {name: "xcodebuildmcp-9.9.9-darwin-x64.tar.gz", digest: ("sha256:" + $x64)}
    ]
  }' > "$XCODE_JSON"

  run run_updater --apply

  [ "$status" -eq 0 ]
  run jq -e --arg arm64 "$arm64_sha" --arg x64 "$x64_sha" '
    .tools.xcodebuildmcp.version == "v9.9.9" and
    .tools.xcodebuildmcp.assets["darwin-arm64"] == {
      name: "xcodebuildmcp-9.9.9-darwin-arm64.tar.gz", sha256: $arm64
    } and
    .tools.xcodebuildmcp.assets["darwin-x64"] == {
      name: "xcodebuildmcp-9.9.9-darwin-x64.tar.gz", sha256: $x64
    }' "$MANIFEST"
  [ "$status" -eq 0 ]
}

@test "managed tool pin updater applies an Obscura release and derived binary checksums" {
  write_current_release
  local archives="$TEST_TEMP_DIR/obscura-archives"
  local arm64_dir="$TEST_TEMP_DIR/obscura-arm64"
  local x64_dir="$TEST_TEMP_DIR/obscura-x64"
  mkdir -p "$archives" "$arm64_dir" "$x64_dir"
  printf '#!/bin/sh\necho arm64-obscura\n' > "$arm64_dir/obscura"
  printf '#!/bin/sh\necho arm64-worker\n' > "$arm64_dir/obscura-worker"
  printf '#!/bin/sh\necho x64-obscura\n' > "$x64_dir/obscura"
  printf '#!/bin/sh\necho x64-worker\n' > "$x64_dir/obscura-worker"
  chmod +x "$arm64_dir/obscura" "$arm64_dir/obscura-worker" \
    "$x64_dir/obscura" "$x64_dir/obscura-worker"

  local arm64_name="obscura-aarch64-macos.tar.gz"
  local x64_name="obscura-x86_64-macos.tar.gz"
  tar -czf "$archives/$arm64_name" -C "$arm64_dir" .
  tar -czf "$archives/$x64_name" -C "$x64_dir" .
  local arm64_archive_sha
  local x64_archive_sha
  local arm64_binary_sha
  local arm64_worker_sha
  local x64_binary_sha
  local x64_worker_sha
  arm64_archive_sha=$(shasum -a 256 "$archives/$arm64_name" | awk '{print $1}')
  x64_archive_sha=$(shasum -a 256 "$archives/$x64_name" | awk '{print $1}')
  arm64_binary_sha=$(shasum -a 256 "$arm64_dir/obscura" | awk '{print $1}')
  arm64_worker_sha=$(shasum -a 256 "$arm64_dir/obscura-worker" | awk '{print $1}')
  x64_binary_sha=$(shasum -a 256 "$x64_dir/obscura" | awk '{print $1}')
  x64_worker_sha=$(shasum -a 256 "$x64_dir/obscura-worker" | awk '{print $1}')
  jq -n \
    --arg arm64_name "$arm64_name" --arg arm64_sha "$arm64_archive_sha" \
    --arg x64_name "$x64_name" --arg x64_sha "$x64_archive_sha" '{
      tag_name: "v9.9.9",
      assets: [
        {name: $arm64_name, digest: ("sha256:" + $arm64_sha)},
        {name: $x64_name, digest: ("sha256:" + $x64_sha)}
      ]
    }' > "$OBSCURA_JSON"
  export OBSCURA_ARCHIVES_DIR="$archives"

  run run_updater --apply

  [ "$status" -eq 0 ]
  run jq -e \
    --arg arm64_archive "$arm64_archive_sha" --arg arm64_bin "$arm64_binary_sha" \
    --arg arm64_worker "$arm64_worker_sha" --arg x64_archive "$x64_archive_sha" \
    --arg x64_bin "$x64_binary_sha" --arg x64_worker "$x64_worker_sha" '
      .tools.obscura.version == "v9.9.9" and
      .tools.obscura.assets["darwin-arm64"].sha256 == $arm64_archive and
      .tools.obscura.assets["darwin-arm64"].binaries.obscura == $arm64_bin and
      .tools.obscura.assets["darwin-arm64"].binaries["obscura-worker"] == $arm64_worker and
      .tools.obscura.assets["darwin-x64"].sha256 == $x64_archive and
      .tools.obscura.assets["darwin-x64"].binaries.obscura == $x64_bin and
      .tools.obscura.assets["darwin-x64"].binaries["obscura-worker"] == $x64_worker
    ' "$MANIFEST"
  [ "$status" -eq 0 ]
}

@test "managed tool pin updater applies an Axiom commit and plugin version" {
  write_current_release
  local commit="2222222222222222222222222222222222222222"
  printf '{"sha":"%s"}\n' "$commit" > "$AXIOM_JSON"
  printf '{"version":"9.9.9"}\n' > "$AXIOM_PLUGIN_JSON"

  run run_updater --apply

  [ "$status" -eq 0 ]
  run jq -e --arg commit "$commit" '
    .marketplaces[0].ref == $commit and
    .plugins[0].version == "9.9.9"
  ' "$PLUGIN_REGISTRY"
  [ "$status" -eq 0 ]
}
