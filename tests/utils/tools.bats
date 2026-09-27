#!/usr/bin/env bats

load '../helpers/setup'
load '../helpers/mocks'

setup() {
    setup_test_env
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

teardown() {
    unmock_all
    teardown_test_env
}

# --- setup_rtk tests ---

@test "setup_openwiki installs the global npm CLI" {
    _ensure_mock_bin_dir
    local version
    version="$(managed_tool_pin '.tools.openwiki.version')"
    calls="$TEST_TEMP_DIR/npm-calls"
    cat > "$MOCK_BIN_DIR/npm" <<EOF
#!/bin/sh
if [ "\$1" = "list" ]; then
  if [ -e "$calls" ]; then
    printf '%s\\n' '{"dependencies":{"openwiki":{"version":"$version"}}}'
  else
    printf '%s\\n' '{}'
  fi
  exit 0
fi
printf '%s\\n' "\$*" >> "$calls"
exit 0
EOF
    cat > "$MOCK_BIN_DIR/openwiki" <<'EOF'
#!/bin/sh
[ "$1" = "--help" ] && exit 0
exit 1
EOF
    chmod +x "$MOCK_BIN_DIR/npm" "$MOCK_BIN_DIR/openwiki"

    run zsh -c "
        export HOME='$HOME' PATH='$PATH'
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_openwiki
    "

    [[ "$status" -eq 0 ]]
    grep -Fx "install --global openwiki@$version" "$calls"
    [[ "$output" == *"OpenWiki $version installed successfully"* ]]
}

@test "setup_openwiki fails clearly when npm is unavailable" {
    run zsh -c "
        export HOME='$HOME' PATH='/usr/bin:/bin'
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_openwiki
    "

    [[ "$status" -ne 0 ]]
    [[ "$output" == *"npm is required"* ]]
}

@test "setup_openwiki dry-run does not invoke npm" {
    _ensure_mock_bin_dir
    local version
    version="$(managed_tool_pin '.tools.openwiki.version')"
    calls="$TEST_TEMP_DIR/npm-calls"
    cat > "$MOCK_BIN_DIR/npm" <<EOF
#!/bin/sh
printf '%s\\n' "\$*" >> "$calls"
exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/npm"

    run zsh -c "
        export HOME='$HOME' PATH='$PATH'
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_openwiki --dry-run
    "

    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Would install managed OpenWiki $version"* ]]
    [[ ! -e "$calls" ]]
}

@test "setup_playwright_cli installs the global npm CLI and skills" {
    _ensure_mock_bin_dir
    local version
    version="$(managed_tool_pin '.tools["playwright-cli"].version')"
    npm_calls="$TEST_TEMP_DIR/npm-calls"
    playwright_calls="$TEST_TEMP_DIR/playwright-calls"
    cat > "$MOCK_BIN_DIR/npm" <<EOF
#!/bin/sh
if [ "\$1" = "list" ]; then
  if [ -e "$npm_calls" ]; then
    printf '%s\\n' '{"dependencies":{"@playwright/cli":{"version":"$version"}}}'
  else
    printf '%s\\n' '{}'
  fi
  exit 0
fi
printf '%s\\n' "\$*" >> "$npm_calls"
exit 0
EOF
    cat > "$MOCK_BIN_DIR/playwright-cli" <<EOF
#!/bin/sh
printf '%s\\n' "\$*" >> "$playwright_calls"
case "\$1" in
  --help) exit 0 ;;
  install) exit 0 ;;
  *) exit 1 ;;
esac
EOF
    chmod +x "$MOCK_BIN_DIR/npm" "$MOCK_BIN_DIR/playwright-cli"

    run zsh -c "
        export HOME='$HOME' PATH='$PATH'
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_playwright_cli
    "

    [[ "$status" -eq 0 ]]
    grep -Fx "install --global @playwright/cli@$version" "$npm_calls"
    grep -Fx -- "--help" "$playwright_calls"
    grep -Fx "install --skills=claude -g" "$playwright_calls"
    grep -Fx "install --skills=agents -g" "$playwright_calls"
    [[ "$output" == *"Playwright CLI $version installed successfully"* ]]
}

@test "setup_playwright_cli fails clearly when npm is unavailable" {
    run zsh -c "
        export HOME='$HOME' PATH='/usr/bin:/bin'
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_playwright_cli
    "

    [[ "$status" -ne 0 ]]
    [[ "$output" == *"npm is required"* ]]
}

@test "setup_playwright_cli dry-run does not invoke npm" {
    _ensure_mock_bin_dir
    local version
    version="$(managed_tool_pin '.tools["playwright-cli"].version')"
    calls="$TEST_TEMP_DIR/npm-calls"
    cat > "$MOCK_BIN_DIR/npm" <<EOF
#!/bin/sh
printf '%s\\n' "\$*" >> "$calls"
exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/npm"

    run zsh -c "
        export HOME='$HOME' PATH='$PATH'
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_playwright_cli --dry-run
    "

    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Would install managed Playwright CLI $version"* ]]
    [[ ! -e "$calls" ]]
}

@test "setup_playwright_mcp installs the global npm MCP server" {
    _ensure_mock_bin_dir
    local version
    version="$(managed_tool_pin '.tools["playwright-mcp"].version')"
    npm_calls="$TEST_TEMP_DIR/npm-calls"
    mcp_calls="$TEST_TEMP_DIR/playwright-mcp-calls"
    cat > "$MOCK_BIN_DIR/npm" <<EOF
#!/bin/sh
if [ "\$1" = "list" ]; then
  if [ -e "$npm_calls" ]; then
    printf '%s\\n' '{"dependencies":{"@playwright/mcp":{"version":"$version"}}}'
  else
    printf '%s\\n' '{}'
  fi
  exit 0
fi
printf '%s\\n' "\$*" >> "$npm_calls"
exit 0
EOF
    cat > "$MOCK_BIN_DIR/playwright-mcp" <<EOF
#!/bin/sh
printf '%s\\n' "\$*" >> "$mcp_calls"
[ "\$1" = "--help" ] && exit 0
exit 1
EOF
    chmod +x "$MOCK_BIN_DIR/npm" "$MOCK_BIN_DIR/playwright-mcp"

    run zsh -c "
        export HOME='$HOME' PATH='$PATH'
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_playwright_mcp
    "

    [[ "$status" -eq 0 ]]
    grep -Fx "install --global @playwright/mcp@$version" "$npm_calls"
    grep -Fx -- "--help" "$mcp_calls"
    [[ "$output" == *"Playwright MCP $version installed successfully"* ]]
}

@test "setup_playwright_mcp fails clearly when npm is unavailable" {
    run zsh -c "
        export HOME='$HOME' PATH='/usr/bin:/bin'
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_playwright_mcp
    "

    [[ "$status" -ne 0 ]]
    [[ "$output" == *"npm is required"* ]]
}

@test "setup_playwright_mcp dry-run does not invoke npm" {
    _ensure_mock_bin_dir
    local version
    version="$(managed_tool_pin '.tools["playwright-mcp"].version')"
    calls="$TEST_TEMP_DIR/npm-calls"
    cat > "$MOCK_BIN_DIR/npm" <<EOF
#!/bin/sh
printf '%s\\n' "\$*" >> "$calls"
exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/npm"

    run zsh -c "
        export HOME='$HOME' PATH='$PATH'
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_playwright_mcp --dry-run
    "

    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Would install managed Playwright MCP $version"* ]]
    [[ ! -e "$calls" ]]
}

@test "setup_rtk skips when rtk not installed" {
    run zsh -c "
        export HOME='$HOME' PATH='/usr/bin:/bin'
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_rtk
    "
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"not installed"* ]]
}

@test "setup_rtk skips when already configured" {
    mkdir -p "$HOME/.claude/hooks"
    touch "$HOME/.claude/hooks/rtk-rewrite.sh"
    mock_rtk

    run zsh -c "
        export HOME='$HOME' PATH='$PATH'
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_rtk
    "
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"already configured"* ]]
}

@test "setup_rtk configures when rtk exists but not configured" {
    mock_rtk

    run zsh -c "
        export HOME='$HOME' PATH='$PATH'
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_rtk
    "
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"configured successfully"* ]]
}

@test "setup_rtk logs failure details when rtk init fails" {
    _ensure_mock_bin_dir
    cat > "$MOCK_BIN_DIR/rtk" << 'RTKEOF'
#!/bin/sh
case "$1" in
    init) echo "permission denied" >&2; exit 1 ;;
    --version) echo "rtk 0.5.0" ;;
    *) exit 0 ;;
esac
RTKEOF
    chmod +x "$MOCK_BIN_DIR/rtk"

    run zsh -c "
        export HOME='$HOME' PATH='$PATH'
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_rtk
    "
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"configuration failed"* ]]
}

# --- setup_worktrunk tests ---

@test "setup_worktrunk skips when wt not installed" {
    run zsh -c "
        export HOME='$HOME' PATH='/usr/bin:/bin'
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_worktrunk
    "
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"not installed"* ]]
}

@test "setup_worktrunk skips when shell integration already configured" {
    mock_wt
    echo 'eval "$(command wt config shell init zsh)"' > "$HOME/.zshrc"

    run zsh -c "
        export HOME='$HOME' PATH='$PATH'
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_worktrunk
    "
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"already configured"* ]]
}

@test "setup_worktrunk configures when wt exists but not configured" {
    mock_wt

    run zsh -c "
        export HOME='$HOME' PATH='$PATH'
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_worktrunk
    "
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"shell integration installed"* ]]
}

# --- setup_code_review_graph tests ---

@test "setup_code_review_graph skips without pipx" {
    run zsh -c "
        export HOME='$HOME' PATH='/usr/bin:/bin'
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_code_review_graph
    "
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"pipx not installed"* ]]
}

@test "setup_code_review_graph never invokes 'code-review-graph install'" {
    mock_pipx
    mock_code_review_graph

    run zsh -c "
        export HOME='$HOME' PATH='$PATH'
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_code_review_graph
    "
    [[ "$status" -eq 0 ]]
    # Per-repo MCP/hooks/skills are committed; running 'install' would
    # re-inject boilerplate into CLAUDE.md on every restore.
    [[ "$output" != *"code-review-graph install"* ]]
    [[ "$output" != *"configured for Claude Code"* ]]
}

@test "code-review-graph setup installs the exact managed pipx version when stale" {
    mock_pipx
    mock_code_review_graph
    local spec
    spec="$(managed_tool_pin '.tools["code-review-graph"] | "\(.package)[\(.extras | join(","))]==\(.version)"')"
    calls="$TEST_TEMP_DIR/pipx-calls"
    cat > "$MOCK_BIN_DIR/code-review-graph" <<'EOF'
#!/bin/sh
if [ "$1" = "--version" ]; then
    echo "code-review-graph 1.0.0"
elif [ "$1" = "serve" ]; then
    IFS= read -r request
    printf '%s\n' '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-06-18","capabilities":{},"serverInfo":{"name":"code-review-graph","version":"1.0.0"}}}'
fi
exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/code-review-graph"
    cat > "$MOCK_BIN_DIR/pipx" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$calls"
exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/pipx"

    run zsh -c "export HOME='$HOME' PATH='$PATH'; source '$PROJECT_ROOT/scripts/utils.sh'; setup_code_review_graph"

    [[ "$status" -eq 0 ]]
    grep -F "install --force $spec" "$calls"
}

@test "code-review-graph setup repairs an installed server that cannot initialize" {
    _ensure_mock_bin_dir
    local version
    version="$(managed_tool_pin '.tools["code-review-graph"].version')"
    marker="$TEST_TEMP_DIR/crg-repaired"
    calls="$TEST_TEMP_DIR/pipx-calls"
    cat > "$MOCK_BIN_DIR/code-review-graph" <<EOF
#!/bin/sh
if [ "\$1" = "--version" ]; then
    echo "code-review-graph $version"
elif [ "\$1" = "serve" ]; then
    if [ ! -f "$marker" ]; then
        echo "ImportError: cannot import name FastMCP" >&2
        exit 1
    fi
    IFS= read -r request
    printf '%s\\n' '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-06-18","capabilities":{},"serverInfo":{"name":"code-review-graph","version":"$version"}}}'
fi
EOF
    cat > "$MOCK_BIN_DIR/pipx" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$calls"
[ "\$1 \$2" = "reinstall code-review-graph" ] && touch "$marker"
exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/code-review-graph" "$MOCK_BIN_DIR/pipx"

    run zsh -c "export HOME='$HOME' PATH='$PATH'; source '$PROJECT_ROOT/scripts/utils.sh'; setup_code_review_graph"

    [ "$status" -eq 0 ]
    [[ "$output" == *"MCP handshake repaired"* ]]
    grep -Fx 'reinstall code-review-graph' "$calls"
}

# --- setup_crg_watcher tests ---

@test "setup_crg_watcher skips when code-review-graph not installed" {
    run zsh -c "
        export HOME='$HOME' PATH='/usr/bin:/bin'
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_crg_watcher
    "
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"not installed"* ]]
}

@test "setup_crg_watcher writes executable script and valid plist" {
    mock_code_review_graph

    run zsh -c "
        export HOME='$HOME' PATH='$PATH' SUPERCHARGED_SKIP_LAUNCHCTL=1
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_crg_watcher
    "
    [[ "$status" -eq 0 ]]
    [[ -x "$HOME/.local/bin/crg-watch-all.sh" ]]
    [[ -f "$HOME/Library/LaunchAgents/com.code-review-graph.watcher.plist" ]]
    [[ -f "$HOME/.code-review-graph/watcher-config.json" ]]
    plutil -lint "$HOME/Library/LaunchAgents/com.code-review-graph.watcher.plist" >/dev/null
    grep -F '/opt/homebrew/bin:/usr/local/bin:' "$HOME/Library/LaunchAgents/com.code-review-graph.watcher.plist"
    jq -e '.discovery_roots == []' "$HOME/.code-review-graph/watcher-config.json" >/dev/null
    zsh -n "$HOME/.local/bin/crg-watch-all.sh"
}

@test "setup_crg_watcher is idempotent and skips reload when unchanged" {
    mock_code_review_graph

    # First run: creates files
    run zsh -c "
        export HOME='$HOME' PATH='$PATH' SUPERCHARGED_SKIP_LAUNCHCTL=1
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_crg_watcher
    "
    [[ "$status" -eq 0 ]]

    # Capture mtime to verify second run doesn't rewrite
    local first_mtime
    first_mtime=$(stat -f %m "$HOME/.local/bin/crg-watch-all.sh")

    # Second run: should detect no change
    run zsh -c "
        export HOME='$HOME' PATH='$PATH' SUPERCHARGED_SKIP_LAUNCHCTL=1
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_crg_watcher
    "
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"already up to date"* ]]

    local second_mtime
    second_mtime=$(stat -f %m "$HOME/.local/bin/crg-watch-all.sh")
    [[ "$first_mtime" == "$second_mtime" ]]
}

@test "setup_crg_watcher preserves an existing discovery configuration" {
    mock_code_review_graph
    mkdir -p "$HOME/.code-review-graph"
    cat > "$HOME/.code-review-graph/watcher-config.json" <<'EOF'
{"discovery_roots":[{"path":"/opt/projects/parent","max_depth":2}]}
EOF

    run zsh -c "
        export HOME='$HOME' PATH='$PATH' SUPERCHARGED_SKIP_LAUNCHCTL=1
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_crg_watcher
    "
    [[ "$status" -eq 0 ]]
    jq -e '.discovery_roots == [{"path":"/opt/projects/parent","max_depth":2}]' \
        "$HOME/.code-review-graph/watcher-config.json" >/dev/null
}

@test "setup_crg_watcher honors SUPERCHARGED_SKIP_LAUNCHCTL=1" {
    mock_code_review_graph

    run zsh -c "
        export HOME='$HOME' PATH='$PATH' SUPERCHARGED_SKIP_LAUNCHCTL=1
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_crg_watcher
    "
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"skipping launchctl reload"* ]]
}

@test "crg watcher discovers, registers, builds, and watches nested repositories" {
    mock_code_review_graph
    local calls="$TEST_TEMP_DIR/crg-calls"
    local parent="$TEST_TEMP_DIR/parent"
    local child="$parent/services/child"
    local worktree="$parent/services/child-feature-worktree"
    local canonical_parent canonical_child canonical_worktree
    mkdir -p "$parent/.git" "$child/.git" "$worktree" "$HOME/.code-review-graph"
    printf 'gitdir: /example/.git/worktrees/child-feature\n' > "$worktree/.git"
    canonical_parent="$(cd "$parent" && pwd -P)"
    canonical_child="$(cd "$child" && pwd -P)"
    canonical_worktree="$(cd "$worktree" && pwd -P)"
    cat > "$HOME/.code-review-graph/registry.json" <<EOF
{"repos":[{"path":"$parent","alias":"parent"}]}
EOF
    cat > "$HOME/.code-review-graph/watcher-config.json" <<EOF
{"discovery_roots":[{"path":"$parent","max_depth":4}]}
EOF
    cat > "$MOCK_BIN_DIR/code-review-graph" <<EOF
#!/bin/sh
printf '%s\\n' "\$*" >> "$calls"
exit 0
EOF
    cat > "$MOCK_BIN_DIR/sleep" <<'EOF'
#!/bin/sh
exit 1
EOF
    chmod +x "$MOCK_BIN_DIR/code-review-graph" "$MOCK_BIN_DIR/sleep"

    run zsh -c "
        export HOME='$HOME' PATH='$MOCK_BIN_DIR:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin' SUPERCHARGED_SKIP_LAUNCHCTL=1
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_crg_watcher
        '$HOME/.local/bin/crg-watch-all.sh'
    "
    [[ "$status" -eq 0 ]]
    [[ -f "$calls" ]] || { echo "$output"; false; }
    grep -F "register $canonical_child" "$calls"
    grep -F "build --repo $canonical_child" "$calls"
    grep -F "watch --repo $canonical_parent" "$calls"
    grep -F "watch --repo $canonical_child" "$calls"
    ! grep -F "$canonical_worktree" "$calls"
}

@test "crg watcher periodically discovers nested repositories created after startup" {
    mock_code_review_graph
    local calls="$TEST_TEMP_DIR/crg-calls"
    local parent="$TEST_TEMP_DIR/parent"
    local child="$parent/services/new-child"
    local canonical_child
    mkdir -p "$parent/.git" "$HOME/.code-review-graph"
    canonical_child="$(cd "$parent" && pwd -P)/services/new-child"
    cat > "$HOME/.code-review-graph/registry.json" <<EOF
{"repos":[{"path":"$parent","alias":"parent"}]}
EOF
    cat > "$HOME/.code-review-graph/watcher-config.json" <<EOF
{"discovery_roots":[{"path":"$parent","max_depth":4}]}
EOF
    cat > "$MOCK_BIN_DIR/code-review-graph" <<EOF
#!/bin/sh
printf '%s\\n' "\$*" >> "$calls"
exit 0
EOF
    cat > "$MOCK_BIN_DIR/sleep" <<'EOF'
#!/bin/sh
/bin/mkdir -p "$CRG_TEST_CHILD/.git"
exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/code-review-graph" "$MOCK_BIN_DIR/sleep"

    run zsh -c "
        export HOME='$HOME' PATH='$MOCK_BIN_DIR:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin' \
            SUPERCHARGED_SKIP_LAUNCHCTL=1 CRG_DISCOVERY_INTERVAL=1 CRG_TEST_CHILD='$child'
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_crg_watcher
        '$HOME/.local/bin/crg-watch-all.sh'
    "
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"nested repositories discovered — exiting for reload"* ]]
    grep -F "register $canonical_child" "$calls"
    grep -F "build --repo $canonical_child" "$calls"
}

# --- setup_plannotator tests ---

write_plannotator_manifest() {
    local checksum="$1"
    PLANNOTATOR_TEST_MANIFEST="$TEST_TEMP_DIR/managed-tools.json"
    cat > "$PLANNOTATOR_TEST_MANIFEST" <<EOF
{
  "version": 1,
  "tools": {
    "plannotator": {
      "version": "v9.9.9",
      "repository": "example/plannotator",
      "assets": {
        "darwin-arm64": {
          "name": "plannotator-darwin-arm64",
          "sha256": "$checksum"
        }
      }
    }
  }
}
EOF
    export PLANNOTATOR_TEST_MANIFEST
}

mock_plannotator_curl() {
    _ensure_mock_bin_dir
    PLANNOTATOR_CURL_CALLS="$TEST_TEMP_DIR/plannotator-curl-calls"
    : > "$PLANNOTATOR_CURL_CALLS"
    export PLANNOTATOR_CURL_CALLS
    cat > "$MOCK_BIN_DIR/curl" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$PLANNOTATOR_CURL_CALLS"
destination=""
while [ $# -gt 0 ]; do
    case "$1" in
        -o) destination="$2"; shift 2 ;;
        *) shift ;;
    esac
done
[ -n "$destination" ] && [ -f "$PLANNOTATOR_TEST_BINARY" ] || exit 1
cp "$PLANNOTATOR_TEST_BINARY" "$destination"
EOF
    chmod +x "$MOCK_BIN_DIR/curl"
}

@test "setup_plannotator installs the checksum-pinned binary" {
    PLANNOTATOR_TEST_BINARY="$TEST_TEMP_DIR/release-binary"
    printf '#!/bin/sh\necho managed\n' > "$PLANNOTATOR_TEST_BINARY"
    checksum=$(shasum -a 256 "$PLANNOTATOR_TEST_BINARY" | awk '{print $1}')
    write_plannotator_manifest "$checksum"
    export PLANNOTATOR_TEST_BINARY
    mock_plannotator_curl

    run zsh -c "
        export HOME='$HOME' PATH='$PATH'
        export PLANNOTATOR_ARCH=arm64
        export PLANNOTATOR_MANIFEST='$PLANNOTATOR_TEST_MANIFEST'
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_plannotator
    "

    [[ "$status" -eq 0 ]]
    [[ "$output" == *"v9.9.9 installed successfully"* ]]
    cmp "$PLANNOTATOR_TEST_BINARY" "$HOME/.local/bin/plannotator"
    [[ -x "$HOME/.local/bin/plannotator" ]]
}

@test "setup_plannotator skips a binary whose checksum matches the managed pin" {
    mkdir -p "$HOME/.local/bin"
    printf '#!/bin/sh\necho managed\n' > "$HOME/.local/bin/plannotator"
    chmod +x "$HOME/.local/bin/plannotator"
    checksum=$(shasum -a 256 "$HOME/.local/bin/plannotator" | awk '{print $1}')
    write_plannotator_manifest "$checksum"
    PLANNOTATOR_TEST_BINARY="$TEST_TEMP_DIR/unused-release-binary"
    printf 'unused\n' > "$PLANNOTATOR_TEST_BINARY"
    export PLANNOTATOR_TEST_BINARY
    mock_plannotator_curl

    run zsh -c "
        export HOME='$HOME' PATH='$PATH'
        export PLANNOTATOR_ARCH=arm64
        export PLANNOTATOR_MANIFEST='$PLANNOTATOR_TEST_MANIFEST'
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_plannotator
    "

    [[ "$status" -eq 0 ]]
    [[ "$output" == *"v9.9.9 already installed"* ]]
    [[ ! -s "$PLANNOTATOR_CURL_CALLS" ]]
}

@test "setup_plannotator atomically upgrades a stale binary" {
    mkdir -p "$HOME/.local/bin"
    printf '#!/bin/sh\necho stale\n' > "$HOME/.local/bin/plannotator"
    chmod +x "$HOME/.local/bin/plannotator"
    PLANNOTATOR_TEST_BINARY="$TEST_TEMP_DIR/release-binary"
    printf '#!/bin/sh\necho managed\n' > "$PLANNOTATOR_TEST_BINARY"
    checksum=$(shasum -a 256 "$PLANNOTATOR_TEST_BINARY" | awk '{print $1}')
    write_plannotator_manifest "$checksum"
    export PLANNOTATOR_TEST_BINARY
    mock_plannotator_curl

    run zsh -c "
        export HOME='$HOME' PATH='$PATH'
        export PLANNOTATOR_ARCH=arm64
        export PLANNOTATOR_MANIFEST='$PLANNOTATOR_TEST_MANIFEST'
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_plannotator
    "

    [[ "$status" -eq 0 ]]
    cmp "$PLANNOTATOR_TEST_BINARY" "$HOME/.local/bin/plannotator"
    [[ -x "$HOME/.local/bin/plannotator" ]]
}

@test "setup_plannotator preserves the old binary when checksum verification fails" {
    mkdir -p "$HOME/.local/bin"
    printf '#!/bin/sh\necho working-old\n' > "$HOME/.local/bin/plannotator"
    chmod +x "$HOME/.local/bin/plannotator"
    old_checksum=$(shasum -a 256 "$HOME/.local/bin/plannotator" | awk '{print $1}')
    write_plannotator_manifest "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    PLANNOTATOR_TEST_BINARY="$TEST_TEMP_DIR/tampered-release-binary"
    printf '#!/bin/sh\necho tampered\n' > "$PLANNOTATOR_TEST_BINARY"
    export PLANNOTATOR_TEST_BINARY
    mock_plannotator_curl

    run zsh -c "
        export HOME='$HOME' PATH='$PATH'
        export PLANNOTATOR_ARCH=arm64
        export PLANNOTATOR_MANIFEST='$PLANNOTATOR_TEST_MANIFEST'
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_plannotator
    "

    [[ "$status" -ne 0 ]]
    [[ "$output" == *"checksum verification failed"* ]]
    [[ "$(shasum -a 256 "$HOME/.local/bin/plannotator" | awk '{print $1}')" = "$old_checksum" ]]
    [ "$(find "$HOME/.local/bin" -maxdepth 1 -type d -name '.plannotator.*' | wc -l | tr -d ' ')" -eq 0 ]
}

@test "setup_plannotator dry-run reports drift without downloading" {
    write_plannotator_manifest "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    PLANNOTATOR_TEST_BINARY="$TEST_TEMP_DIR/unused-release-binary"
    printf 'unused\n' > "$PLANNOTATOR_TEST_BINARY"
    export PLANNOTATOR_TEST_BINARY
    mock_plannotator_curl

    run zsh -c "
        export HOME='$HOME' PATH='$PATH'
        export PLANNOTATOR_ARCH=arm64
        export PLANNOTATOR_MANIFEST='$PLANNOTATOR_TEST_MANIFEST'
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_plannotator --dry-run
    "

    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Would install Plannotator v9.9.9"* ]]
    [[ ! -s "$PLANNOTATOR_CURL_CALLS" ]]
    [[ ! -e "$HOME/.local/bin/plannotator" ]]
}

# --- setup_obscura tests ---

@test "setup_obscura dry-run reports the exact managed release" {
    mock_obscura_release
    run zsh -c "
        export HOME='$HOME' PATH='$PATH' OBSCURA_ARCH=arm64
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_obscura --dry-run
    "
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Would install Obscura v9.9.9"* ]]
    [[ ! -e "$HOME/.local/bin/obscura" ]]
}

@test "setup_obscura skips when both binaries exist at ~/.local/bin" {
    mkdir -p "$HOME/.local/bin"
    mock_obscura_release
    tar -xzf "$OBSCURA_TEST_ARCHIVE" -C "$HOME/.local/bin"

    run zsh -c "
        export HOME='$HOME' PATH='$PATH'
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_obscura
    "
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"already installed"* ]]
}

@test "setup_obscura installs both binaries on supported arch" {
    mock_obscura_release

    run zsh -c "
        export HOME='$HOME' PATH='$PATH'
        # Force a known arch so the asset name is deterministic
        uname() { [ \"\$1\" = '-m' ] && echo 'arm64' || command uname \"\$@\"; }
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_obscura
    "
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"installed to"* ]]
    [[ -x "$HOME/.local/bin/obscura" ]]
    [[ -x "$HOME/.local/bin/obscura-worker" ]]
}

@test "setup_obscura installs both binaries on x86_64" {
    mock_obscura_release

    run zsh -c "
        export HOME='$HOME' PATH='$PATH'
        uname() { [ \"\$1\" = '-m' ] && echo 'x86_64' || command uname \"\$@\"; }
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_obscura
    "
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"installed to"* ]]
    [[ -x "$HOME/.local/bin/obscura" ]]
    [[ -x "$HOME/.local/bin/obscura-worker" ]]
}

@test "setup_obscura logs download failure details and leaves no binaries behind" {
    mock_obscura_release
    cat > "$MOCK_BIN_DIR/curl" << 'CURLEOF'
#!/bin/sh
echo "HTTP 401: Bad credentials" >&2
exit 1
CURLEOF
    chmod +x "$MOCK_BIN_DIR/curl"

    run zsh -c "
        export HOME='$HOME' PATH='$PATH'
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_obscura
    "
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"Failed to download"* ]]
    [[ "$output" == *"HTTP 401"* ]]
    [[ ! -e "$HOME/.local/bin/obscura" ]]
    [[ ! -e "$HOME/.local/bin/obscura-worker" ]]
}

@test "setup_obscura errors when archive is missing required binaries" {
    mock_obscura_release
    tar -czf "$OBSCURA_TEST_ARCHIVE" -C "$TEST_TEMP_DIR/obscura-staging" obscura
    bad_sha=$(shasum -a 256 "$OBSCURA_TEST_ARCHIVE" | awk '{print $1}')
    jq --arg sha "$bad_sha" '.tools.obscura.assets["darwin-arm64"].sha256 = $sha' \
      "$MANAGED_TOOLS_MANIFEST" > "$MANAGED_TOOLS_MANIFEST.tmp"
    mv "$MANAGED_TOOLS_MANIFEST.tmp" "$MANAGED_TOOLS_MANIFEST"

    run zsh -c "
        export HOME='$HOME' PATH='$PATH'
        uname() { [ \"\$1\" = '-m' ] && echo 'arm64' || command uname \"\$@\"; }
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_obscura
    "
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"missing expected binaries"* ]]
    [[ ! -e "$HOME/.local/bin/obscura" ]]
    [[ ! -e "$HOME/.local/bin/obscura-worker" ]]
}

@test "setup_obscura skips unsupported architecture without blocking setup" {
    mock_obscura_release

    run zsh -c "
        export HOME='$HOME' PATH='$PATH'
        uname() { [ \"\$1\" = '-m' ] && echo 'powerpc' || command uname \"\$@\"; }
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_obscura
    "
    # WARN + return 0: don't abort the larger setup pipeline over optional tooling
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Unsupported architecture"* ]]
    [[ "$output" == *"skipping"* ]]
    [[ ! -e "$HOME/.local/bin/obscura" ]]
}

# --- native Xcode MCP and retired integration cleanup ---

write_native_xcode_mocks() {
    _ensure_mock_bin_dir
    export XCODE_MCP_CALLS="$TEST_TEMP_DIR/xcode-mcp-calls"
    cat > "$MOCK_BIN_DIR/xcodebuild" <<'EOF'
#!/bin/sh
printf 'Xcode %s\nBuild version TEST\n' "${XCODE_TEST_VERSION:-27.0}"
EOF
    cat > "$MOCK_BIN_DIR/xcrun" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$XCODE_MCP_CALLS"
if [ "$1" = "--find" ]; then
  [ "$2" = "mcpbridge" ] || [ "$2" = "mcp-server" ]
elif [ "$1 $2" = "mcp-server status" ]; then
  printf '%s\n' "${XCODE_MCP_STATUS:-Permission: disabled}"
elif [ "$1 $2" = "mcp-server start" ]; then
  exit "${XCODE_MCP_START_EXIT:-0}"
fi
EOF
    cat > "$MOCK_BIN_DIR/sudo" <<'EOF'
#!/bin/sh
printf 'sudo %s\n' "$*" >> "$XCODE_MCP_CALLS"
exit "${XCODE_MCP_ENABLE_EXIT:-0}"
EOF
    chmod +x "$MOCK_BIN_DIR/xcodebuild" "$MOCK_BIN_DIR/xcrun" "$MOCK_BIN_DIR/sudo"
}

@test "setup_xcode_mcp warns without aborting when Xcode is missing" {
    run zsh -c "
        source '$PROJECT_ROOT/scripts/utils.sh'
        command_exists() { [ \"\$1\" != xcodebuild ]; }
        setup_xcode_mcp
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"Xcode is not installed"* ]]
}

@test "setup_xcode_mcp warns without aborting for Xcode older than 26.3" {
    write_native_xcode_mocks
    run env HOME="$HOME" PATH="$PATH" XCODE_TEST_VERSION=26.2 XCODE_MCP_CALLS="$XCODE_MCP_CALLS" \
      zsh -c "source '$PROJECT_ROOT/scripts/utils.sh'; setup_xcode_mcp"
    [ "$status" -eq 0 ]
    [[ "$output" == *"requires Xcode 26.3 or later"* ]]
}

@test "setup_xcode_mcp treats Xcode 26.3 through 26.x as attached-only" {
    write_native_xcode_mocks
    run env HOME="$HOME" PATH="$PATH" XCODE_TEST_VERSION=26.4 XCODE_MCP_CALLS="$XCODE_MCP_CALLS" \
      zsh -c "source '$PROJECT_ROOT/scripts/utils.sh'; setup_xcode_mcp"
    [ "$status" -eq 0 ]
    [[ "$output" == *"attached mode is available"* ]]
    [[ "$output" == *"attached MCP only"* ]]
    ! grep -Fq 'mcp-server status' "$XCODE_MCP_CALLS"
}

@test "setup_xcode_mcp starts an already-enabled Xcode 27 service" {
    write_native_xcode_mocks
    run env HOME="$HOME" PATH="$PATH" XCODE_TEST_VERSION=27.0 \
      XCODE_MCP_STATUS='Permission: enabled' XCODE_MCP_CALLS="$XCODE_MCP_CALLS" \
      zsh -c "source '$PROJECT_ROOT/scripts/utils.sh'; setup_xcode_mcp"
    [ "$status" -eq 0 ]
    grep -Fxq 'mcp-server status' "$XCODE_MCP_CALLS"
    grep -Fxq 'mcp-server start' "$XCODE_MCP_CALLS"
    [[ "$output" == *"enabled and started"* ]]
}

@test "setup_xcode_mcp enables Xcode 27 headless mode after interactive consent" {
    write_native_xcode_mocks
    run sh -c "printf 'y\n' | env HOME='$HOME' PATH='$PATH' XCODE_TEST_VERSION=27.0 \
      XCODE_MCP_SETUP_INTERACTIVE=1 XCODE_MCP_CALLS='$XCODE_MCP_CALLS' \
      zsh -c \"source '$PROJECT_ROOT/scripts/utils.sh'; setup_xcode_mcp\""
    [ "$status" -eq 0 ]
    grep -Fxq 'sudo xcrun mcp-server enable' "$XCODE_MCP_CALLS"
    grep -Fxq 'mcp-server start' "$XCODE_MCP_CALLS"
    ! grep -Fq -- '--unsafe-always-allow-all-agents' "$XCODE_MCP_CALLS"
}

@test "setup_xcode_mcp decline preserves attached mode and prints manual commands" {
    write_native_xcode_mocks
    run sh -c "printf 'n\n' | env HOME='$HOME' PATH='$PATH' XCODE_TEST_VERSION=27.0 \
      XCODE_MCP_SETUP_INTERACTIVE=1 XCODE_MCP_CALLS='$XCODE_MCP_CALLS' \
      zsh -c \"source '$PROJECT_ROOT/scripts/utils.sh'; setup_xcode_mcp\""
    [ "$status" -eq 0 ]
    ! grep -Fq 'sudo xcrun mcp-server enable' "$XCODE_MCP_CALLS"
    [[ "$output" == *"enablement declined"* ]]
    [[ "$output" == *"sudo xcrun mcp-server enable"* ]]
}

@test "retire_legacy_xcode_mcps removes known installs and is idempotent" {
    _ensure_mock_bin_dir
    managed_root="$HOME/.local/share/supercharged"
    managed_bin="$HOME/.local/bin"
    mkdir -p "$managed_root/xcodebuildmcp" "$managed_root/mobilebuildmcp" "$managed_bin"
    touch "$managed_bin/xcodebuildmcp" "$managed_bin/xcodebuildmcp-doctor"
    touch "$managed_bin/mobilebuildmcp" "$managed_bin/mobilebuildmcp-doctor"
    export RETIRED_BREW_STATE="$TEST_TEMP_DIR/brew-state"
    export RETIRED_TAP_STATE="$TEST_TEMP_DIR/tap-state"
    export RETIRED_NPM_STATE="$TEST_TEMP_DIR/npm-state"
    printf '%s\n' xcodebuildmcp mobilebuildmcp > "$RETIRED_BREW_STATE"
    printf '%s\n' getsentry/xcodebuildmcp > "$RETIRED_TAP_STATE"
    printf '%s\n' xcodebuildmcp mobilebuildmcp > "$RETIRED_NPM_STATE"
    cat > "$MOCK_BIN_DIR/brew" <<'EOF'
#!/bin/sh
if [ "$1 $2" = "list --formula" ]; then grep -Fxq "$3" "$RETIRED_BREW_STATE"; exit; fi
if [ "$1" = uninstall ]; then grep -Fxv "$2" "$RETIRED_BREW_STATE" > "$RETIRED_BREW_STATE.tmp" || true; mv "$RETIRED_BREW_STATE.tmp" "$RETIRED_BREW_STATE"; exit; fi
if [ "$1" = tap ] && [ "$#" -eq 1 ]; then cat "$RETIRED_TAP_STATE"; exit; fi
if [ "$1 $2" = "untap getsentry/xcodebuildmcp" ]; then : > "$RETIRED_TAP_STATE"; exit; fi
exit 0
EOF
    cat > "$MOCK_BIN_DIR/npm" <<'EOF'
#!/bin/sh
package="${6:-}"
if [ "$1" = list ]; then
  [ -z "$package" ] && package="${5:-}"
  if grep -Fxq "$package" "$RETIRED_NPM_STATE"; then printf '{"dependencies":{"%s":{"version":"1.0.0"}}}\n' "$package"; else printf '{}\n'; fi
  exit 0
fi
if [ "$1 $2" = "uninstall --global" ]; then grep -Fxv "$3" "$RETIRED_NPM_STATE" > "$RETIRED_NPM_STATE.tmp" || true; mv "$RETIRED_NPM_STATE.tmp" "$RETIRED_NPM_STATE"; fi
EOF
    chmod +x "$MOCK_BIN_DIR/brew" "$MOCK_BIN_DIR/npm"

    run env HOME="$HOME" PATH="$PATH" RETIRED_BREW_STATE="$RETIRED_BREW_STATE" \
      RETIRED_TAP_STATE="$RETIRED_TAP_STATE" RETIRED_NPM_STATE="$RETIRED_NPM_STATE" \
      zsh -c "source '$PROJECT_ROOT/scripts/utils.sh'; retire_legacy_xcode_mcps; retire_legacy_xcode_mcps"
    [ "$status" -eq 0 ]
    [ ! -e "$managed_root/xcodebuildmcp" ]
    [ ! -e "$managed_root/mobilebuildmcp" ]
    [ ! -e "$managed_bin/xcodebuildmcp" ]
    [ ! -s "$RETIRED_BREW_STATE" ]
    [ ! -s "$RETIRED_TAP_STATE" ]
    [ ! -s "$RETIRED_NPM_STATE" ]
}

@test "retire_legacy_xcode_mcps dry-run preserves installs" {
    managed_root="$HOME/.local/share/supercharged"
    mkdir -p "$managed_root/xcodebuildmcp"
    run env HOME="$HOME" PATH="/usr/bin:/bin" \
      zsh -c "source '$PROJECT_ROOT/scripts/utils.sh'; retire_legacy_xcode_mcps --dry-run"
    [ "$status" -eq 0 ]
    [ -d "$managed_root/xcodebuildmcp" ]
    [[ "$output" == *"Would remove retired managed Apple MCP path"* ]]
}

@test "retire_legacy_xcode_mcps reports package removal failures" {
    _ensure_mock_bin_dir
    cat > "$MOCK_BIN_DIR/brew" <<'EOF'
#!/bin/sh
if [ "$1 $2 $3" = "list --formula xcodebuildmcp" ]; then exit 0; fi
if [ "$1 $2" = "list --formula" ]; then exit 1; fi
if [ "$1" = uninstall ]; then exit 1; fi
if [ "$1" = tap ]; then exit 0; fi
EOF
    chmod +x "$MOCK_BIN_DIR/brew"
    run env HOME="$HOME" PATH="$PATH" zsh -c "source '$PROJECT_ROOT/scripts/utils.sh'; retire_legacy_xcode_mcps"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Could not uninstall retired Homebrew formula: xcodebuildmcp"* ]]
}

@test "retire_legacy_xcode_mcps reports an npm install it cannot inspect without jq" {
    _ensure_mock_bin_dir
    npm_root="$TEST_TEMP_DIR/npm-root"
    mkdir -p "$npm_root/xcodebuildmcp"
    cat > "$MOCK_BIN_DIR/npm" <<EOF
#!/bin/sh
if [ "\$1 \$2" = "root --global" ]; then printf '%s\n' "$npm_root"; fi
EOF
    chmod +x "$MOCK_BIN_DIR/npm"

    run env HOME="$HOME" PATH="$PATH" zsh -c "
      source '$PROJECT_ROOT/scripts/utils.sh'
      command_exists() {
        [ \"\$1\" = jq ] && return 1
        command -v \"\$1\" >/dev/null 2>&1
      }
      retire_legacy_xcode_mcps
    "

    [ "$status" -ne 0 ]
    [[ "$output" == *"Retired global npm package detected but jq is unavailable: xcodebuildmcp"* ]]
}

@test "retire_legacy_xcode_mcps reports but preserves unknown manual binaries" {
    _ensure_mock_bin_dir
    manual_dir="$TEST_TEMP_DIR/manual-bin"
    mkdir -p "$manual_dir"
    printf '#!/bin/sh\nexit 0\n' > "$manual_dir/xcodebuildmcp"
    chmod +x "$manual_dir/xcodebuildmcp"
    run env HOME="$HOME" PATH="$manual_dir:/usr/bin:/bin" RETIRED_XCODE_MCP_BIN_DIR="$HOME/.local/bin" \
      zsh -c "source '$PROJECT_ROOT/scripts/utils.sh'; retire_legacy_xcode_mcps"
    [ "$status" -eq 0 ]
    [ -x "$manual_dir/xcodebuildmcp" ]
    [[ "$output" == *"unknown/manual path: $manual_dir/xcodebuildmcp"* ]]
}
# --- download robustness ---

@test "managed downloads pass explicit curl timeout and retry options" {
    _ensure_mock_bin_dir
    calls="$TEST_TEMP_DIR/curl-opts"
    cat > "$MOCK_BIN_DIR/curl" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$calls"
exit 1
EOF
    chmod +x "$MOCK_BIN_DIR/curl"
    write_plannotator_manifest "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

    run zsh -c "
        export HOME='$HOME' PATH='$PATH'
        export PLANNOTATOR_ARCH=arm64
        export PLANNOTATOR_MANIFEST='$PLANNOTATOR_TEST_MANIFEST'
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_plannotator
    "

    [[ "$status" -ne 0 ]]
    grep -F -- '--connect-timeout 10' "$calls"
    grep -F -- '--max-time 300' "$calls"
    grep -F -- '--retry 3' "$calls"
}

@test "an interrupted managed download leaves no staging directory behind" {
    _ensure_mock_bin_dir
    # Interrupt the install mid-download the way Ctrl-C would.
    cat > "$MOCK_BIN_DIR/curl" <<'EOF'
#!/bin/sh
kill -INT "$PPID"
sleep 5
EOF
    chmod +x "$MOCK_BIN_DIR/curl"
    write_plannotator_manifest "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    mkdir -p "$HOME/.local/bin"

    run zsh -c "
        export HOME='$HOME' PATH='$PATH'
        export PLANNOTATOR_ARCH=arm64
        export PLANNOTATOR_MANIFEST='$PLANNOTATOR_TEST_MANIFEST'
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_plannotator
    "

    # The signal must not be reported as a successful install.
    [[ "$status" -ne 0 ]]
    [ "$(find "$HOME/.local/bin" -maxdepth 1 -type d -name '.plannotator.*' | wc -l | tr -d ' ')" -eq 0 ]
}
