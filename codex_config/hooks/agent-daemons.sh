#!/bin/zsh
# SessionStart advisory hook: load an installed daemon without enrolling repos.
set -u

context=""
cleanup() {
    # SessionStart accepts plain text as additional model context. Successful
    # checks stay quiet; setup problems are advisory and never block a session.
    [ -z "$context" ] || printf '%s\n' "$context"
}
trap cleanup EXIT

case "${1:-}" in
    code-review-graph)
        label="com.code-review-graph.watcher"
        repair="Run the repository setup to install its graph watcher."
        ;;
    openwiki)
        label="com.openwiki.watcher"
        repair="Run npm run install:openwiki to install its opt-in updater."
        ;;
    *) context='Unknown agent daemon requested by the SessionStart hook.'; exit 0 ;;
esac

[[ "$(uname -s)" == Darwin ]] || exit 0
if ! command -v launchctl >/dev/null 2>&1; then
    context="Cannot check $label: launchctl is unavailable."
    exit 0
fi
plist="$HOME/Library/LaunchAgents/$label.plist"
if [ ! -f "$plist" ]; then
    context="$label is not configured. $repair"
    exit 0
fi

domain="gui/$(id -u)"
service="$domain/$label"
# A loaded scheduled OpenWiki job may be idle. Do not kickstart it or restart
# a healthy graph watcher just because another Codex session has begun.
if launchctl print "$service" >/dev/null 2>&1; then
    exit 0
fi

# Concurrent sessions may both try to bootstrap; recheck before warning.
if launchctl bootstrap "$domain" "$plist" >/dev/null 2>&1 || \
    launchctl print "$service" >/dev/null 2>&1; then
    context="Loaded $label. Repository enrollment and update policies are unchanged."
else
    context="Could not load $label. Inspect it with launchctl print $service. $repair"
fi

exit 0
