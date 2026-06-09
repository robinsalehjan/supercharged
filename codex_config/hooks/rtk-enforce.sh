#!/usr/bin/env bash

# Codex PreToolUse hook that mimics Claude's RTK rewrite behavior as closely as
# Codex currently supports: block noisy commands and tell Codex the RTK command
# to retry. Codex documents blocking hook decisions, but not input rewriting.

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

jq -cn --arg reason "Use RTK for concise output. Retry with: $rewritten" \
  '{decision:"block", reason:$reason}'
