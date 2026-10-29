#!/usr/bin/env bats

load '../helpers/setup'
load '../helpers/mocks'

setup() {
    setup_test_env
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    _ensure_mock_bin_dir
    export OPENWIKI_CONFIG_DIR="$HOME/.openwiki"
    export OPENWIKI_CALLS="$TEST_TEMP_DIR/calls"
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
    helper="$TEST_TEMP_DIR/helper.zsh"
    # Load only the real function, without starting interactive shell services.
    sed -n '/^openwiki-here() {$/,/^}$/p' "$PROJECT_ROOT/dot_files/.zshrc" > "$helper"
    ln -s "$PROJECT_ROOT/scripts/openwiki-watch.sh" "$MOCK_BIN_DIR/openwiki-watch"
    cat > "$MOCK_BIN_DIR/openwiki" <<'EOF'
#!/bin/sh
printf '%s|%s\n' "$PWD" "$*" >> "$OPENWIKI_CALLS"
[ "${MOCK_OPENWIKI_EXIT:-0}" = 0 ] || exit "$MOCK_OPENWIKI_EXIT"
mkdir -p openwiki
[ "${MOCK_OPENWIKI_NO_INDEX:-0}" = 1 ] || printf '# Wiki\n' > openwiki/index.md
[ "${MOCK_OPENWIKI_INCOMPLETE:-0}" = 0 ] || printf '{}\n' > openwiki/.run.json
exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/openwiki"
    repo="$TEST_TEMP_DIR/repository with spaces"
    git init -q "$repo"
    repo="$(cd "$repo" && pwd -P)"
}

teardown() {
    unset OPENWIKI_CONFIG_DIR OPENWIKI_CALLS MOCK_OPENWIKI_EXIT MOCK_OPENWIKI_NO_INDEX MOCK_OPENWIKI_INCOMPLETE
    unset GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM
    teardown_test_env
}

@test "openwiki-here initializes from a nested directory and enrolls without changing directories" {
    mkdir "$repo/nested"

    run zsh -c 'source "$1"; cd "$2"; openwiki-here; result=$?; [ "$PWD" = "$2" ] || exit 99; exit "$result"' zsh "$helper" "$repo/nested"

    [ "$status" -eq 0 ]
    [ "$(cat "$OPENWIKI_CALLS")" = "$repo|--init" ]
    [ -f "$repo/openwiki/index.md" ]
    jq -e --arg repo "$repo" '.repositories == [$repo]' "$OPENWIKI_CONFIG_DIR/watcher-config.json"
}

@test "openwiki-here accepts an explicit repository path and enrolls it only once" {
    for pass in first second; do
        run zsh -c 'source "$1"; openwiki-here "$2"' zsh "$helper" "$repo"
        [ "$status" -eq 0 ]
    done

    [ "$(cat "$OPENWIKI_CALLS")" = "$repo|--init" ]
    jq -e --arg repo "$repo" '.repositories == [$repo]' "$OPENWIKI_CONFIG_DIR/watcher-config.json"
}

@test "openwiki-here preserves an existing wiki without invoking initialization" {
    mkdir "$repo/openwiki"
    printf 'existing wiki\n' > "$repo/openwiki/index.md"

    run zsh -c 'source "$1"; openwiki-here "$2"' zsh "$helper" "$repo"

    [ "$status" -eq 0 ]
    [ ! -e "$OPENWIKI_CALLS" ]
    [ "$(cat "$repo/openwiki/index.md")" = 'existing wiki' ]
}

@test "openwiki-here propagates initialization failure without enrolling" {
    export MOCK_OPENWIKI_EXIT=7

    run zsh -c 'source "$1"; openwiki-here "$2"' zsh "$helper" "$repo"

    [ "$status" -eq 7 ]
    [ ! -e "$OPENWIKI_CONFIG_DIR/watcher-config.json" ]
}

@test "openwiki-here does not enroll when initialization exits without creating the wiki" {
    export MOCK_OPENWIKI_NO_INDEX=1

    run zsh -c 'source "$1"; openwiki-here "$2"' zsh "$helper" "$repo"

    [ "$status" -eq 1 ]
    [[ "$output" == *"initialization is incomplete"* ]]
    [ ! -e "$OPENWIKI_CONFIG_DIR/watcher-config.json" ]
}

@test "openwiki-here leaves an unfinished run unenrolled even if an index exists" {
    export MOCK_OPENWIKI_INCOMPLETE=1
    run zsh -c 'source "$1"; openwiki-here "$2"' zsh "$helper" "$repo"
    [ "$status" -eq 1 ]
    [ ! -e "$OPENWIKI_CONFIG_DIR/watcher-config.json" ]

    run zsh -c 'source "$1"; openwiki-here "$2"' zsh "$helper" "$repo"
    [ "$status" -eq 1 ]
    [ "$(cat "$OPENWIKI_CALLS")" = "$repo|--init" ]
    [ ! -e "$OPENWIKI_CONFIG_DIR/watcher-config.json" ]
}

@test "openwiki-here rejects non-repositories and linked worktrees before initialization" {
    run zsh -c 'source "$1"; openwiki-here "$2"' zsh "$helper" "$TEST_TEMP_DIR"
    [ "$status" -eq 1 ]
    git -C "$repo" -c user.name=Test -c user.email=test@example.invalid commit --allow-empty -qm initial
    git -C "$repo" worktree add -qb linked "$TEST_TEMP_DIR/linked"

    run zsh -c 'source "$1"; openwiki-here "$2"' zsh "$helper" "$TEST_TEMP_DIR/linked"

    [ "$status" -eq 1 ]
    [ ! -e "$OPENWIKI_CALLS" ]
    [ ! -e "$OPENWIKI_CONFIG_DIR/watcher-config.json" ]
}

@test "openwiki-here rejects extra arguments without initializing or enrolling" {
    run zsh -c 'source "$1"; openwiki-here "$2" extra' zsh "$helper" "$repo"

    [ "$status" -eq 2 ]
    [[ "$output" == *"Usage: openwiki-here"* ]]
    [ ! -e "$OPENWIKI_CALLS" ]
    [ ! -e "$OPENWIKI_CONFIG_DIR/watcher-config.json" ]
}

@test "openwiki-here reports missing OpenWiki before enrolling a new wiki" {
    rm "$MOCK_BIN_DIR/openwiki"

    run env PATH="$MOCK_BIN_DIR:/usr/bin:/bin" zsh -c 'source "$1"; openwiki-here "$2"' zsh "$helper" "$repo"

    [ "$status" -eq 1 ]
    [[ "$output" == *"openwiki not installed"* ]]
    [ ! -e "$OPENWIKI_CONFIG_DIR/watcher-config.json" ]
}
