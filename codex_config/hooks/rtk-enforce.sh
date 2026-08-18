#!/usr/bin/env bash

# Codex PreToolUse hook that rewrites noisy commands through RTK. Codex supports
# non-blocking rewrites when a hook returns permissionDecision=allow together
# with hookSpecificOutput.updatedInput.command.

set -u

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

if ! command -v rtk >/dev/null 2>&1; then
  exit 0
fi

input=$(cat)
command=$(jq -r '
  .tool_input.command //
  .input.command //
  .arguments.command //
  .command //
  empty
' <<<"$input" 2>/dev/null || true)

if [ -z "$command" ]; then
  exit 0
fi

# An RTK-wrapped command has already passed through this hook. Do not ask RTK
# to rewrite it again, even if a future RTK release returns a nested wrapper.
case "$command" in
  rtk\ *) exit 0 ;;
esac

rewritten=$(rtk rewrite "$command" 2>/dev/null)
rewrite_status=$?

case "$rewrite_status" in
  0|3)
    ;;
  *)
    exit 0
    ;;
esac

if [ -z "$rewritten" ] || [ "$rewritten" = "$command" ]; then
  exit 0
fi

jq -cn --arg command "$rewritten" \
  '{hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:"allow", updatedInput:{command:$command}}}'
