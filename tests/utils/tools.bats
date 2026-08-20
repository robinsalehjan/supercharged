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
    calls="$TEST_TEMP_DIR/pipx-calls"
    printf '#!/bin/sh\n[ "$1" = "--version" ] && echo "code-review-graph 1.0.0"\nexit 0\n' > "$MOCK_BIN_DIR/code-review-graph"
    chmod +x "$MOCK_BIN_DIR/code-review-graph"
    cat > "$MOCK_BIN_DIR/pipx" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$calls"
exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/pipx"

    run zsh -c "export HOME='$HOME' PATH='$PATH'; source '$PROJECT_ROOT/scripts/utils.sh'; setup_code_review_graph"

    [[ "$status" -eq 0 ]]
    grep -F 'install --force code-review-graph[embeddings,communities]==2.3.7' "$calls"
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

# --- exact XcodeBuildMCP pin ---

@test "setup_xcodebuildmcp verifies and installs the exact release archive" {
    archive="$TEST_TEMP_DIR/xcodebuildmcp.tar.gz"
    staging="$TEST_TEMP_DIR/xcodebuildmcp-9.9.9-darwin-arm64"
    mkdir -p "$staging/bin" "$staging/libexec"
    printf '#!/bin/sh\necho 9.9.9\n' > "$staging/bin/xcodebuildmcp"
    printf '#!/bin/sh\nexit 0\n' > "$staging/bin/xcodebuildmcp-doctor"
    chmod +x "$staging/bin/xcodebuildmcp" "$staging/bin/xcodebuildmcp-doctor"
    tar -czf "$archive" -C "$TEST_TEMP_DIR" "$(basename "$staging")"
    sha=$(shasum -a 256 "$archive" | awk '{print $1}')
    manifest="$TEST_TEMP_DIR/xcode-manifest.json"
    printf '{"tools":{"xcodebuildmcp":{"version":"v9.9.9","repository":"example/xcode","assets":{"darwin-arm64":{"name":"xcodebuildmcp.tar.gz","sha256":"%s"}}}}}\n' "$sha" > "$manifest"
    _ensure_mock_bin_dir
    cat > "$MOCK_BIN_DIR/curl" <<'EOF'
#!/bin/sh
while [ $# -gt 0 ]; do
  [ "$1" = -o ] && { cp "$XCODE_TEST_ARCHIVE" "$2"; exit 0; }
  shift
done
exit 1
EOF
    chmod +x "$MOCK_BIN_DIR/curl"

    run env HOME="$HOME" PATH="$PATH" MANAGED_TOOLS_MANIFEST="$manifest" \
      XCODE_TEST_ARCHIVE="$archive" XCODEBUILDMCP_ARCH=arm64 \
      XCODEBUILDMCP_SKIP_BREW_CLEANUP=1 \
      XCODEBUILDMCP_INSTALL_ROOT="$TEST_TEMP_DIR/xcode-install" \
      XCODEBUILDMCP_BIN_DIR="$HOME/.local/bin" \
      zsh -c "source '$PROJECT_ROOT/scripts/utils.sh'; setup_xcodebuildmcp"

    [ "$status" -eq 0 ]
    short_sha="${sha:0:12}"
    [ -x "$TEST_TEMP_DIR/xcode-install/v9.9.9-$short_sha/bin/xcodebuildmcp" ]
    [ -L "$HOME/.local/bin/xcodebuildmcp" ]
    [ "$(cat "$TEST_TEMP_DIR/xcode-install/.active-archive-sha256")" = "$sha" ]
}
