#!/bin/zsh
# Repository wiki updates; provider configuration stays in OpenWiki's local state.
set -euo pipefail

STATE_DIR="${OPENWIKI_CONFIG_DIR:-$HOME/.openwiki}"
CONFIG="$STATE_DIR/watcher-config.json"
config_tmp=""
child_pid=""
timer_pid=""

log_with_level() {
    printf '[%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$2"
}

cleanup() {
    [ -z "$timer_pid" ] || kill "$timer_pid" 2>/dev/null || true
    [ -z "$child_pid" ] || kill "$child_pid" 2>/dev/null || true
    [ -z "$config_tmp" ] || rm -f "$config_tmp"
    wait 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

usage() {
    echo 'Usage: openwiki-watch [add [repo] | remove [repo] | list | run]'
}

action="${1:-run}"
case "$action" in
    -h|--help) usage; exit 0 ;;
    add|remove) [ "$#" -le 2 ] || { usage >&2; exit 2; } ;;
    list|run) [ "$#" -le 1 ] || { usage >&2; exit 2; } ;;
    *) usage >&2; exit 2 ;;
esac

command -v jq >/dev/null || { log_with_level ERROR 'jq is required'; exit 1; }
if [ ! -f "$CONFIG" ]; then
    case "$action" in
        run|list) exit 0 ;;
        remove) log_with_level ERROR "No configuration at $CONFIG"; exit 1 ;;
    esac
    mkdir -p "$STATE_DIR"
    printf '{"repositories":[]}\n' > "$CONFIG"
fi

if ! jq -e 'type == "object" and (.repositories | type == "array" and all(.[];
    type == "string" and startswith("/") and (test("[\\r\\n\\t]") | not)))' "$CONFIG" >/dev/null; then
    log_with_level ERROR "Invalid repositories in $CONFIG (expected absolute paths)"
    exit 1
fi

case "$action" in
    add|remove)
        candidate="${2:-$PWD}"
        if [ "$action" = add ]; then
            repo=$(git -C "$candidate" rev-parse --show-toplevel) || exit 1
            repo=$(cd "$repo" && pwd -P)
            if [ ! -d "$repo/.git" ] || [ ! -f "$repo/openwiki/index.md" ]; then
                log_with_level ERROR 'Enrollment requires a main Git checkout with an initialized openwiki/index.md'
                exit 1
            fi
        else
            # An absolute path can remove an enrollment even after the checkout is deleted.
            if [ -d "$candidate" ]; then
                repo=$(git -C "$candidate" rev-parse --show-toplevel 2>/dev/null) || repo="$candidate"
                repo=$(cd "$repo" && pwd -P)
            else
                repo="$candidate"
            fi
        fi
        if [[ "$repo" != /* || "$repo" == *[$'\r\n\t']* ]]; then
            log_with_level ERROR 'Repository paths must be absolute and contain no tabs or newlines'
            exit 1
        fi
        config_tmp=$(mktemp "$STATE_DIR/watcher-config.XXXXXX")
        if [ "$action" = add ]; then
            jq --arg repo "$repo" '.repositories = ((.repositories + [$repo]) | unique)' "$CONFIG" > "$config_tmp"
        else
            jq --arg repo "$repo" '.repositories -= [$repo]' "$CONFIG" > "$config_tmp"
        fi
        mv "$config_tmp" "$CONFIG"
        config_tmp=""
        log_with_level SUCCESS "$action: $repo"
        exit 0
        ;;
    list) jq -r '.repositories[]' "$CONFIG"; exit 0 ;;
esac

# The kernel releases this lock on exit, including crashes. launchd also keeps
# a single instance; the lock covers manual runs started while it is active.
zmodload zsh/system
zmodload zsh/zselect
: >> "$STATE_DIR/watcher.lock"
zsystem flock -t 0 -f lock_fd "$STATE_DIR/watcher.lock" 2>/dev/null || exit 0

timeout_seconds="${OPENWIKI_WATCH_TIMEOUT:-1800}"
if [[ ! "$timeout_seconds" =~ ^[1-9][0-9]*$ ]]; then
    log_with_level ERROR 'OPENWIKI_WATCH_TIMEOUT must be a positive number of seconds'
    exit 1
fi

failed=0
while IFS= read -r repo; do
    [ -n "$repo" ] || continue
    if [ ! -d "$repo/.git" ] || [ ! -f "$repo/openwiki/index.md" ]; then
        log_with_level WARN "Skipping missing wiki or main checkout: $repo"
        continue
    fi
    if [ -e "$repo/openwiki/.run.json" ]; then
        log_with_level WARN "Skipping unfinished wiki run; resume it manually: $repo"
        continue
    fi
    # git status includes staged edits and untracked files. Never discard or
    # commit changes, including documentation produced by an earlier update.
    if ! changes=$(git -C "$repo" status --porcelain --untracked-files=all); then
        log_with_level ERROR "Could not inspect checkout: $repo"
        failed=1
        continue
    fi
    if [ -n "$changes" ]; then
        log_with_level INFO "Skipping dirty checkout (review and commit changes first): $repo"
        continue
    fi
    head=$(git -C "$repo" rev-parse HEAD) || { failed=1; continue; }
    baseline=$(jq -r 'select(.status == "complete") | .gitHead // empty' \
        "$repo/openwiki/.last-update.json" 2>/dev/null) || baseline=""
    [ "$head" != "$baseline" ] || continue

    if ! command -v openwiki >/dev/null; then
        log_with_level ERROR 'OpenWiki is not on PATH; run npm run install:openwiki'
        exit 1
    fi
    log_with_level INFO "Updating wiki: $repo"
    (cd "$repo" && exec openwiki code --update --print </dev/null) &
    child_pid=$!
    # Bound a stalled provider call. A failed or interrupted run stays available
    # for manual recovery, rather than being retried over partial wiki edits.
    (
        zselect -t "$((timeout_seconds * 100))" || true
        kill -TERM "$child_pid" 2>/dev/null || exit 0
        zselect -t 500 || true
        kill -KILL "$child_pid" 2>/dev/null || true
    ) &
    timer_pid=$!
    if wait "$child_pid"; then
        log_with_level SUCCESS "Wiki updated; review local changes: $repo"
    else
        log_with_level ERROR "Wiki update failed or timed out; inspect watcher logs and resume manually: $repo"
        failed=1
    fi
    kill "$timer_pid" 2>/dev/null || true
    wait "$timer_pid" 2>/dev/null || true
    timer_pid=""
    child_pid=""
done < <(jq -r '.repositories | unique[]' "$CONFIG")

exit "$failed"
