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
    echo '# worktrunk shell integration' > "$HOME/.zshrc"

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

@test "setup_code_review_graph skips when already configured" {
    mock_pipx
    mock_code_review_graph
    mkdir -p "$HOME/.claude"
    echo '{"code-review-graph": {}}' > "$HOME/.claude/.mcp.json"

    run zsh -c "
        export HOME='$HOME' PATH='$PATH'
        source '$PROJECT_ROOT/scripts/utils.sh'
        setup_code_review_graph
    "
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"already configured"* ]]
    [[ "$output" == *"already installed"* ]]
}
