#!/usr/bin/env bats

load '../helpers/setup'
load '../helpers/mocks'

setup() {
    setup_test_env
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    HOOK="$PROJECT_ROOT/codex_config/hooks/agent-daemons.sh"
    _ensure_mock_bin_dir
    mkdir -p "$HOME/Library/LaunchAgents"
    export DAEMON_HOOK_CALLS="$TEST_TEMP_DIR/launchctl-calls"
    cat > "$MOCK_BIN_DIR/launchctl" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$DAEMON_HOOK_CALLS"
case "$1" in
    print) [ -f "$HOME/loaded" ] ;;
    bootstrap)
        if [ "${MOCK_BOOTSTRAP_RACE:-0}" = 1 ]; then
            touch "$HOME/loaded"
            exit 1
        fi
        [ "${MOCK_BOOTSTRAP_FAIL:-0}" = 0 ] || exit 1
        touch "$HOME/loaded" ;;
    *) exit 99 ;;
esac
EOF
    chmod +x "$MOCK_BIN_DIR/launchctl"
    # Daemon health must never invoke generation/indexing commands directly.
    for cli in openwiki code-review-graph; do
        printf '#!/bin/sh\ntouch "$HOME/unexpected-cli-call"\nexit 99\n' > "$MOCK_BIN_DIR/$cli"
        chmod +x "$MOCK_BIN_DIR/$cli"
    done
}

teardown() {
    unset DAEMON_HOOK_CALLS MOCK_BOOTSTRAP_FAIL MOCK_BOOTSTRAP_RACE
    teardown_test_env
}

install_plists() {
    touch "$HOME/Library/LaunchAgents/com.code-review-graph.watcher.plist"
    touch "$HOME/Library/LaunchAgents/com.openwiki.watcher.plist"
}

@test "loaded graph watcher is left running without hook output" {
    install_plists
    touch "$HOME/loaded"
    run "$HOOK" code-review-graph
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ "$(wc -l < "$DAEMON_HOOK_CALLS" | tr -d ' ')" -eq 1 ]
    grep -F "print gui/$(id -u)/com.code-review-graph.watcher" "$DAEMON_HOOK_CALLS"
    [ ! -e "$HOME/unexpected-cli-call" ]
}

@test "an idle loaded OpenWiki job is not kickstarted or given new enrollments" {
    install_plists
    touch "$HOME/loaded"
    run "$HOOK" openwiki
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ "$(wc -l < "$DAEMON_HOOK_CALLS" | tr -d ' ')" -eq 1 ]
    [ ! -e "$HOME/.openwiki" ]
    [ ! -e "$HOME/unexpected-cli-call" ]
}

@test "an unloaded installed graph watcher is bootstrapped" {
    install_plists
    run "$HOOK" code-review-graph
    [ "$status" -eq 0 ]
    [[ "$output" == *"Loaded com.code-review-graph.watcher"* ]]
    grep -F "bootstrap gui/$(id -u) $HOME/Library/LaunchAgents/com.code-review-graph.watcher.plist" "$DAEMON_HOOK_CALLS"
    [ ! -e "$HOME/unexpected-cli-call" ]
}

@test "an unloaded installed OpenWiki job is bootstrapped without invoking the CLI" {
    install_plists
    run "$HOOK" openwiki
    [ "$status" -eq 0 ]
    [[ "$output" == *"Loaded com.openwiki.watcher"* ]]
    grep -F "bootstrap gui/$(id -u) $HOME/Library/LaunchAgents/com.openwiki.watcher.plist" "$DAEMON_HOOK_CALLS"
    [ ! -e "$HOME/unexpected-cli-call" ]
}

@test "missing setup is advisory and does not install anything" {
    run "$HOOK" openwiki
    [ "$status" -eq 0 ]
    [[ "$output" == *"not configured"* ]]
    [[ "$output" == *"npm run install:openwiki"* ]]
    [ ! -e "$DAEMON_HOOK_CALLS" ]
    [ ! -e "$HOME/.openwiki" ]
}

@test "launchd errors advise the session without blocking it" {
    install_plists
    export MOCK_BOOTSTRAP_FAIL=1
    run "$HOOK" openwiki
    [ "$status" -eq 0 ]
    [[ "$output" == *"Could not load com.openwiki.watcher"* ]]
    [ ! -e "$HOME/unexpected-cli-call" ]
}

@test "concurrent successful bootstrap is accepted after rechecking launchd" {
    install_plists
    export MOCK_BOOTSTRAP_RACE=1
    run "$HOOK" openwiki
    [ "$status" -eq 0 ]
    [[ "$output" == *"Loaded com.openwiki.watcher"* ]]
    [[ "$output" != *"Could not load"* ]]
}

@test "hook commands respect a custom CODEX_HOME containing spaces" {
    install_plists
    touch "$HOME/loaded"
    local custom_codex="$HOME/custom codex"
    mkdir -p "$custom_codex/hooks"
    cp "$HOOK" "$custom_codex/hooks/agent-daemons.sh"
    local hook_command
    hook_command=$(jq -r '.hooks.SessionStart[0].hooks[1].command' "$PROJECT_ROOT/codex_config/hooks.json")
    run env CODEX_HOME="$custom_codex" zsh -c "$hook_command"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
