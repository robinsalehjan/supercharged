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
    plutil -lint "$HOME/Library/LaunchAgents/com.code-review-graph.watcher.plist" >/dev/null
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

# --- setup_obscura tests ---

@test "setup_obscura skips when gh CLI not available" {
    run zsh -c "
        export HOME='$HOME' PATH='/usr/bin:/bin'
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_obscura
    "
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"gh CLI required"* ]]
    [[ ! -e "$HOME/.local/bin/obscura" ]]
}

@test "setup_obscura skips when obscura already on PATH" {
    _ensure_mock_bin_dir
    printf '#!/bin/sh\nexit 0\n' > "$MOCK_BIN_DIR/obscura"
    chmod +x "$MOCK_BIN_DIR/obscura"

    run zsh -c "
        export HOME='$HOME' PATH='$PATH'
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_obscura
    "
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"already installed"* ]]
}

@test "setup_obscura installs both binaries on supported arch" {
    mock_gh_release_obscura

    run zsh -c "
        export HOME='$HOME' PATH='$PATH'
        # Force a known arch so the asset name is deterministic
        uname() { [ \"\$1\" = '-m' ] && echo 'arm64' || command uname \"\$@\"; }
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_obscura
    "
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"installed to ~/.local/bin"* ]]
    [[ -x "$HOME/.local/bin/obscura" ]]
    [[ -x "$HOME/.local/bin/obscura-worker" ]]
}

@test "setup_obscura skips unsupported architecture without blocking setup" {
    mock_gh_release_obscura

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
