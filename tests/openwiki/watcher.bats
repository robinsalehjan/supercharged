#!/usr/bin/env bats

load '../helpers/setup'
load '../helpers/mocks'

setup() {
    setup_test_env
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    WATCHER="$PROJECT_ROOT/scripts/openwiki-watch.sh"
    _ensure_mock_bin_dir
    export OPENWIKI_CONFIG_DIR="$HOME/.openwiki"
    export OPENWIKI_CALLS="$TEST_TEMP_DIR/calls"
    cat > "$MOCK_BIN_DIR/openwiki" <<'EOF'
#!/bin/sh
printf '%s|%s\n' "$PWD" "$*" >> "$OPENWIKI_CALLS"
if [ "${MOCK_OPENWIKI_HANG:-0}" = 1 ]; then
    exec sleep 30
fi
exit "${MOCK_OPENWIKI_EXIT:-0}"
EOF
    chmod +x "$MOCK_BIN_DIR/openwiki"
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
    export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.invalid
    export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.invalid
}

teardown() {
    unset OPENWIKI_CONFIG_DIR OPENWIKI_CALLS MOCK_OPENWIKI_EXIT MOCK_OPENWIKI_HANG OPENWIKI_WATCH_TIMEOUT
    unset GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
    teardown_test_env
}

create_repo() {
    repo="$TEST_TEMP_DIR/repository with spaces"
    git init -q "$repo"
    repo="$(cd "$repo" && pwd -P)"
    mkdir -p "$repo/openwiki"
    echo '# Wiki' > "$repo/openwiki/index.md"
    echo source > "$repo/source.txt"
    git -C "$repo" add .
    git -C "$repo" commit -qm initial
    "$WATCHER" add "$repo"
}

@test "empty enrollment does no work and does not create local state" {
    run "$WATCHER" run
    [ "$status" -eq 0 ]
    [ ! -e "$OPENWIKI_CALLS" ]
    [ ! -d "$OPENWIKI_CONFIG_DIR" ]
}

@test "enrollment is explicit, canonical, idempotent, and removable" {
    create_repo
    run "$WATCHER" add "$repo/openwiki"
    [ "$status" -eq 0 ]
    [ "$(jq '.repositories | length' "$OPENWIKI_CONFIG_DIR/watcher-config.json")" -eq 1 ]
    run "$WATCHER" list
    [ "$status" -eq 0 ]
    [ "$output" = "$repo" ]
    "$WATCHER" remove "$repo"
    [ "$(jq '.repositories | length' "$OPENWIKI_CONFIG_DIR/watcher-config.json")" -eq 0 ]
    [ ! -e "$OPENWIKI_CALLS" ]
}

@test "enrollment refuses repositories without an initialized wiki" {
    git init -q "$TEST_TEMP_DIR/empty"
    run "$WATCHER" add "$TEST_TEMP_DIR/empty"
    [ "$status" -eq 1 ]
    [ ! -e "$OPENWIKI_CALLS" ]
}

@test "linked worktrees cannot be enrolled" {
    create_repo
    git -C "$repo" worktree add -qb linked "$TEST_TEMP_DIR/linked"
    run "$WATCHER" add "$TEST_TEMP_DIR/linked"
    [ "$status" -eq 1 ]
    [ ! -e "$OPENWIKI_CALLS" ]
}

@test "scheduled updates use one-shot code mode in the enrolled repository" {
    create_repo
    run "$WATCHER" run
    [ "$status" -eq 0 ]
    [ "$(cat "$OPENWIKI_CALLS")" = "$repo|code --update --print" ]
}

@test "dirty source and staged edits are left untouched" {
    create_repo
    echo changed > "$repo/source.txt"
    run "$WATCHER" run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Skipping dirty checkout"* ]]
    git -C "$repo" add source.txt
    run "$WATCHER" run
    [ "$status" -eq 0 ]
    [ ! -e "$OPENWIKI_CALLS" ]
    [ "$(cat "$repo/source.txt")" = changed ]
}

@test "untracked files and generated wiki edits pause updates" {
    create_repo
    touch "$repo/untracked.txt"
    run "$WATCHER" run
    [ "$status" -eq 0 ]
    rm "$repo/untracked.txt"
    echo edits >> "$repo/openwiki/index.md"
    run "$WATCHER" run
    [ "$status" -eq 0 ]
    [ ! -e "$OPENWIKI_CALLS" ]
}

@test "unchanged completed baseline skips OpenWiki but a new commit triggers it" {
    create_repo
    baseline=$(git -C "$repo" rev-parse HEAD)
    jq -n --arg head "$baseline" '{status:"complete",gitHead:$head}' > "$repo/openwiki/.last-update.json"
    # Metadata is often ignored locally; do not create a source commit for this fixture.
    echo 'openwiki/.last-update.json' >> "$repo/.git/info/exclude"
    run "$WATCHER" run
    [ "$status" -eq 0 ]
    [ ! -e "$OPENWIKI_CALLS" ]
    echo changed > "$repo/source.txt"
    git -C "$repo" add source.txt
    git -C "$repo" commit -qm change
    run "$WATCHER" run
    [ "$status" -eq 0 ]
    [ -e "$OPENWIKI_CALLS" ]
}

@test "unfinished wiki runs require manual recovery even when ignored by Git" {
    create_repo
    echo 'openwiki/.run.json' >> "$repo/.git/info/exclude"
    echo '{}' > "$repo/openwiki/.run.json"
    run "$WATCHER" run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Skipping unfinished wiki run"* ]]
    [ ! -e "$OPENWIKI_CALLS" ]
}

@test "invalid config fails before updating any repository" {
    create_repo
    echo '{"repositories":["relative/path"]}' > "$OPENWIKI_CONFIG_DIR/watcher-config.json"
    run "$WATCHER" run
    [ "$status" -eq 1 ]
    [ ! -e "$OPENWIKI_CALLS" ]
}

@test "failed updates return failure and release the lock for a later run" {
    create_repo
    export MOCK_OPENWIKI_EXIT=7
    run "$WATCHER" run
    [ "$status" -eq 1 ]
    unset MOCK_OPENWIKI_EXIT
    run "$WATCHER" run
    [ "$status" -eq 0 ]
    [ "$(wc -l < "$OPENWIKI_CALLS" | tr -d ' ')" -eq 2 ]
}

@test "a stalled updater times out and returns failure" {
    create_repo
    export MOCK_OPENWIKI_HANG=1 OPENWIKI_WATCH_TIMEOUT=1
    run "$WATCHER" run
    [ "$status" -eq 1 ]
    [[ "$output" == *"failed or timed out"* ]]
}

@test "a concurrent manual run cannot start another update" {
    create_repo
    run zsh -c '
        zmodload zsh/system
        : >> "$OPENWIKI_CONFIG_DIR/watcher.lock"
        zsystem flock -t 0 -f lock_fd "$OPENWIKI_CONFIG_DIR/watcher.lock"
        "$1" run
    ' zsh "$WATCHER"
    [ "$status" -eq 0 ]
    [ ! -e "$OPENWIKI_CALLS" ]
}

@test "setup installs a valid scheduled plist and preserves local enrollment" {
    create_repo
    run env SUPERCHARGED_SKIP_LAUNCHCTL=1 zsh -c 'source "$1/scripts/utils.sh"; setup_openwiki_watcher' zsh "$PROJECT_ROOT"
    [ "$status" -eq 0 ]
    [ -x "$HOME/.local/bin/openwiki-watch" ]
    plist="$HOME/Library/LaunchAgents/com.openwiki.watcher.plist"
    plutil -lint "$plist"
    [ "$(plutil -extract StartInterval raw "$plist")" -eq 1800 ]
    [ "$(jq '.repositories | length' "$OPENWIKI_CONFIG_DIR/watcher-config.json")" -eq 1 ]
    run "$HOME/.local/bin/openwiki-watch" list
    [ "$output" = "$repo" ]
}

@test "setup dry-run creates no daemon files or enrollments" {
    run zsh -c 'source "$1/scripts/utils.sh"; setup_openwiki_watcher --dry-run' zsh "$PROJECT_ROOT"
    [ "$status" -eq 0 ]
    [ ! -d "$OPENWIKI_CONFIG_DIR" ]
    [ ! -e "$HOME/.local/bin/openwiki-watch" ]
}

@test "setup starts empty and repairs an unloaded job without reloading a healthy job" {
    cat > "$MOCK_BIN_DIR/launchctl" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$HOME/launchctl-calls"
case "$1" in
    print) [ -f "$HOME/loaded" ] ;;
    bootstrap) touch "$HOME/loaded" ;;
    bootout) rm -f "$HOME/loaded" ;;
esac
EOF
    chmod +x "$MOCK_BIN_DIR/launchctl"
    for pass in first second; do
        run zsh -c 'source "$1/scripts/utils.sh"; setup_openwiki_watcher' zsh "$PROJECT_ROOT"
        [ "$status" -eq 0 ]
    done
    [ "$(jq '.repositories | length' "$OPENWIKI_CONFIG_DIR/watcher-config.json")" -eq 0 ]
    [ "$(grep -c '^bootstrap ' "$HOME/launchctl-calls")" -eq 1 ]
    rm "$HOME/loaded"
    run zsh -c 'source "$1/scripts/utils.sh"; setup_openwiki_watcher' zsh "$PROJECT_ROOT"
    [ "$status" -eq 0 ]
    [ "$(grep -c '^bootstrap ' "$HOME/launchctl-calls")" -eq 2 ]
    [ ! -e "$OPENWIKI_CALLS" ]
}

@test "one repository failing does not prevent checking another" {
    create_repo
    git clone -q "$repo" "$TEST_TEMP_DIR/another"
    "$WATCHER" add "$TEST_TEMP_DIR/another"
    export MOCK_OPENWIKI_EXIT=7
    run "$WATCHER" run
    [ "$status" -eq 1 ]
    [ "$(wc -l < "$OPENWIKI_CALLS" | tr -d ' ')" -eq 2 ]
}
