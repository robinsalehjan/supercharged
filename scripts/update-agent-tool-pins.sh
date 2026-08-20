#!/bin/zsh

set -euo pipefail

source "$(dirname "$0")/utils.sh"

MANIFEST="${MANAGED_TOOLS_MANIFEST:-$UTILS_PROJECT_ROOT/agent_config/managed_tools.json}"
PLUGIN_REGISTRY="${CODEX_PLUGIN_REGISTRY:-$UTILS_PROJECT_ROOT/codex_config/plugins.json}"
APPLY=false
[ "${1:-}" = "--apply" ] && APPLY=true
if [ -n "${1:-}" ] && [ "${1:-}" != "--apply" ]; then
    echo "Usage: $(basename "$0") [--apply]" >&2
    exit 2
fi

fetch_json() {
    local fixture="$1" endpoint="$2"
    if [ -n "$fixture" ]; then
        cat "$fixture"
    elif command -v gh >/dev/null 2>&1; then
        gh api "$endpoint"
    else
        curl -fsSL "https://api.github.com/$endpoint"
    fi
}

plannotator_repo=$(jq -r '.tools.plannotator.repository' "$MANIFEST")
xcodebuildmcp_repo=$(jq -r '.tools.xcodebuildmcp.repository' "$MANIFEST")
obscura_repo=$(jq -r '.tools.obscura.repository' "$MANIFEST")
statusline_repo=$(jq -r '.tools["claude-statusline"].repository' "$MANIFEST")

plannotator_json=$(fetch_json "${PLANNOTATOR_RELEASE_JSON:-}" "repos/$plannotator_repo/releases/latest")
xcodebuildmcp_json=$(fetch_json "${XCODEBUILDMCP_RELEASE_JSON:-}" "repos/$xcodebuildmcp_repo/releases/latest")
obscura_json=$(fetch_json "${OBSCURA_RELEASE_JSON:-}" "repos/$obscura_repo/releases/latest")
statusline_json=$(fetch_json "${STATUSLINE_COMMIT_JSON:-}" "repos/$statusline_repo/commits/main")
axiom_json=$(fetch_json "${AXIOM_COMMIT_JSON:-}" "repos/CharlesWiltgen/Axiom/commits/main")
if [ -n "${CRG_PYPI_JSON:-}" ]; then
    crg_json=$(<"$CRG_PYPI_JSON")
else
    crg_json=$(curl -fsSL https://pypi.org/pypi/code-review-graph/json)
fi

plannotator_version=$(jq -er '.tag_name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))' <<<"$plannotator_json")
plannotator_arm_sha=$(jq -er '.assets[] | select(.name == "plannotator-darwin-arm64") | .digest | sub("^sha256:"; "") | select(test("^[0-9a-f]{64}$"))' <<<"$plannotator_json")
plannotator_x64_sha=$(jq -er '.assets[] | select(.name == "plannotator-darwin-x64") | .digest | sub("^sha256:"; "") | select(test("^[0-9a-f]{64}$"))' <<<"$plannotator_json")
crg_version=$(jq -er '.info.version | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))' <<<"$crg_json")
xcodebuildmcp_version=$(jq -er '.tag_name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))' <<<"$xcodebuildmcp_json")
xcodebuildmcp_plain="${xcodebuildmcp_version#v}"
xcodebuildmcp_arm_name="xcodebuildmcp-${xcodebuildmcp_plain}-darwin-arm64.tar.gz"
xcodebuildmcp_x64_name="xcodebuildmcp-${xcodebuildmcp_plain}-darwin-x64.tar.gz"
xcodebuildmcp_arm_sha=$(jq -er --arg name "$xcodebuildmcp_arm_name" '.assets[] | select(.name == $name) | .digest | sub("^sha256:"; "") | select(test("^[0-9a-f]{64}$"))' <<<"$xcodebuildmcp_json")
xcodebuildmcp_x64_sha=$(jq -er --arg name "$xcodebuildmcp_x64_name" '.assets[] | select(.name == $name) | .digest | sub("^sha256:"; "") | select(test("^[0-9a-f]{64}$"))' <<<"$xcodebuildmcp_json")
obscura_version=$(jq -er '.tag_name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))' <<<"$obscura_json")
obscura_arm_name="obscura-aarch64-macos.tar.gz"
obscura_x64_name="obscura-x86_64-macos.tar.gz"
obscura_arm_sha=$(jq -er --arg name "$obscura_arm_name" '.assets[] | select(.name == $name) | .digest | sub("^sha256:"; "") | select(test("^[0-9a-f]{64}$"))' <<<"$obscura_json")
obscura_x64_sha=$(jq -er --arg name "$obscura_x64_name" '.assets[] | select(.name == $name) | .digest | sub("^sha256:"; "") | select(test("^[0-9a-f]{64}$"))' <<<"$obscura_json")
statusline_commit=$(jq -er '.sha | select(test("^[0-9a-f]{40}$"))' <<<"$statusline_json")
axiom_commit=$(jq -er '.sha | select(test("^[0-9a-f]{40}$"))' <<<"$axiom_json")
if [ -n "${AXIOM_PLUGIN_JSON:-}" ]; then
    axiom_plugin_json=$(<"$AXIOM_PLUGIN_JSON")
else
    axiom_plugin_json=$(curl -fsSL "https://raw.githubusercontent.com/CharlesWiltgen/Axiom/$axiom_commit/axiom-codex/.codex-plugin/plugin.json")
fi
axiom_version=$(jq -er '.version | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+([.-][0-9A-Za-z.-]+)?$"))' <<<"$axiom_plugin_json")

updates=$(jq -n \
    --arg p_current "$(jq -r '.tools.plannotator.version' "$MANIFEST")" --arg p_latest "$plannotator_version" \
    --arg p_arm_current "$(jq -r '.tools.plannotator.assets["darwin-arm64"].sha256' "$MANIFEST")" --arg p_arm_latest "$plannotator_arm_sha" \
    --arg p_x64_current "$(jq -r '.tools.plannotator.assets["darwin-x64"].sha256' "$MANIFEST")" --arg p_x64_latest "$plannotator_x64_sha" \
    --arg c_current "$(jq -r '.tools["code-review-graph"].version' "$MANIFEST")" --arg c_latest "$crg_version" \
    --arg x_current "$(jq -r '.tools.xcodebuildmcp.version' "$MANIFEST")" --arg x_latest "$xcodebuildmcp_version" \
    --arg x_arm_current "$(jq -r '.tools.xcodebuildmcp.assets["darwin-arm64"].sha256' "$MANIFEST")" --arg x_arm_latest "$xcodebuildmcp_arm_sha" \
    --arg x_x64_current "$(jq -r '.tools.xcodebuildmcp.assets["darwin-x64"].sha256' "$MANIFEST")" --arg x_x64_latest "$xcodebuildmcp_x64_sha" \
    --arg o_current "$(jq -r '.tools.obscura.version' "$MANIFEST")" --arg o_latest "$obscura_version" \
    --arg o_arm_current "$(jq -r '.tools.obscura.assets["darwin-arm64"].sha256' "$MANIFEST")" --arg o_arm_latest "$obscura_arm_sha" \
    --arg o_x64_current "$(jq -r '.tools.obscura.assets["darwin-x64"].sha256' "$MANIFEST")" --arg o_x64_latest "$obscura_x64_sha" \
    --arg s_current "$(jq -r '.tools["claude-statusline"].commit' "$MANIFEST")" --arg s_latest "$statusline_commit" \
    --arg a_current "$(jq -r '.marketplaces[0].ref' "$PLUGIN_REGISTRY")" --arg a_latest "$axiom_commit" \
    --arg av_current "$(jq -r '.plugins[0].version' "$PLUGIN_REGISTRY")" --arg av_latest "$axiom_version" \
    '[
      (select($p_current != $p_latest or $p_arm_current != $p_arm_latest or $p_x64_current != $p_x64_latest) | "Plannotator: \($p_current) -> \($p_latest)"),
      (select($c_current != $c_latest) | "code-review-graph: \($c_current) -> \($c_latest)"),
      (select($x_current != $x_latest or $x_arm_current != $x_arm_latest or $x_x64_current != $x_x64_latest) | "XcodeBuildMCP: \($x_current) -> \($x_latest)"),
      (select($o_current != $o_latest or $o_arm_current != $o_arm_latest or $o_x64_current != $o_x64_latest) | "Obscura: \($o_current) -> \($o_latest)"),
      (select($s_current != $s_latest) | "Claude statusline commit changed"),
      (select($a_current != $a_latest or $av_current != $av_latest) | "Axiom marketplace commit changed")
    ]')

if [ "$(jq 'length' <<<"$updates")" -eq 0 ]; then
    echo "Managed agent-tool pins are current"
    exit 0
fi
jq -r '.[]' <<<"$updates"
if ! $APPLY; then
    echo "Run: npm run update:tool-pins -- --apply"
    exit 0
fi

obscura_arm_bin=$(jq -r '.tools.obscura.assets["darwin-arm64"].binaries.obscura' "$MANIFEST")
obscura_arm_worker=$(jq -r '.tools.obscura.assets["darwin-arm64"].binaries["obscura-worker"]' "$MANIFEST")
obscura_x64_bin=$(jq -r '.tools.obscura.assets["darwin-x64"].binaries.obscura' "$MANIFEST")
obscura_x64_worker=$(jq -r '.tools.obscura.assets["darwin-x64"].binaries["obscura-worker"]' "$MANIFEST")
if [ "$(jq -r '.tools.obscura.version' "$MANIFEST")" != "$obscura_version" ] || \
   [ "$(jq -r '.tools.obscura.assets["darwin-arm64"].sha256' "$MANIFEST")" != "$obscura_arm_sha" ] || \
   [ "$(jq -r '.tools.obscura.assets["darwin-x64"].sha256' "$MANIFEST")" != "$obscura_x64_sha" ]; then
    obscura_tmp=$(mktemp -d)
    for arch in arm x64; do
        if [ "$arch" = arm ]; then asset_name="$obscura_arm_name"; else asset_name="$obscura_x64_name"; fi
        archive="$obscura_tmp/$asset_name"
        if [ -n "${OBSCURA_ARCHIVES_DIR:-}" ]; then
            cp "$OBSCURA_ARCHIVES_DIR/$asset_name" "$archive"
        else
            curl -fsSL "https://github.com/$obscura_repo/releases/download/$obscura_version/$asset_name" -o "$archive"
        fi
        mkdir -p "$obscura_tmp/$arch"
        tar -xzf "$archive" -C "$obscura_tmp/$arch"
        bin_path=$(find "$obscura_tmp/$arch" -type f -name obscura -perm -u+x | head -1)
        worker_path=$(find "$obscura_tmp/$arch" -type f -name obscura-worker -perm -u+x | head -1)
        [ "$arch" = arm ] && obscura_arm_bin=$(shasum -a 256 "$bin_path" | awk '{print $1}')
        [ "$arch" = arm ] && obscura_arm_worker=$(shasum -a 256 "$worker_path" | awk '{print $1}')
        [ "$arch" = x64 ] && obscura_x64_bin=$(shasum -a 256 "$bin_path" | awk '{print $1}')
        [ "$arch" = x64 ] && obscura_x64_worker=$(shasum -a 256 "$worker_path" | awk '{print $1}')
    done
    rm -rf "$obscura_tmp"
fi

manifest_tmp=$(mktemp "${MANIFEST}.XXXXXX")
jq \
  --arg pv "$plannotator_version" --arg pas "$plannotator_arm_sha" --arg pxs "$plannotator_x64_sha" \
  --arg cv "$crg_version" \
  --arg xv "$xcodebuildmcp_version" --arg xan "$xcodebuildmcp_arm_name" --arg xas "$xcodebuildmcp_arm_sha" --arg xxn "$xcodebuildmcp_x64_name" --arg xxs "$xcodebuildmcp_x64_sha" \
  --arg ov "$obscura_version" --arg oan "$obscura_arm_name" --arg oas "$obscura_arm_sha" --arg oab "$obscura_arm_bin" --arg oaw "$obscura_arm_worker" \
  --arg oxn "$obscura_x64_name" --arg oxs "$obscura_x64_sha" --arg oxb "$obscura_x64_bin" --arg oxw "$obscura_x64_worker" \
  --arg sc "$statusline_commit" '
    .tools.plannotator.version = $pv |
    .tools.plannotator.assets["darwin-arm64"].sha256 = $pas |
    .tools.plannotator.assets["darwin-x64"].sha256 = $pxs |
    .tools["code-review-graph"].version = $cv |
    .tools.xcodebuildmcp.version = $xv |
    .tools.xcodebuildmcp.assets["darwin-arm64"] = {name: $xan, sha256: $xas} |
    .tools.xcodebuildmcp.assets["darwin-x64"] = {name: $xxn, sha256: $xxs} |
    .tools.obscura.version = $ov |
    .tools.obscura.assets["darwin-arm64"] = {name: $oan, sha256: $oas, binaries: {obscura: $oab, "obscura-worker": $oaw}} |
    .tools.obscura.assets["darwin-x64"] = {name: $oxn, sha256: $oxs, binaries: {obscura: $oxb, "obscura-worker": $oxw}} |
    .tools["claude-statusline"].commit = $sc
  ' "$MANIFEST" > "$manifest_tmp"
mv "$manifest_tmp" "$MANIFEST"

plugin_tmp=$(mktemp "${PLUGIN_REGISTRY}.XXXXXX")
jq --arg ref "$axiom_commit" --arg version "$axiom_version" \
  '.marketplaces[0].ref = $ref | .plugins[0].version = $version' \
  "$PLUGIN_REGISTRY" > "$plugin_tmp"
mv "$plugin_tmp" "$PLUGIN_REGISTRY"
echo "Updated managed agent-tool pins"
