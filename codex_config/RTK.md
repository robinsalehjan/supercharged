# RTK - Rust Token Killer (Codex CLI)

Use RTK as the default wrapper for shell commands when it supports the command.
RTK keeps command output compact while preserving the signal needed for agent
work.

Examples:

```bash
rtk git status
rtk npm test
rtk pytest -q
rtk tsc --noEmit
```

Use `rtk proxy <cmd>` when exact, unfiltered output matters for correctness.
Use the raw command when RTK does not support the command or when a repo-local
instruction explicitly requires the native tool.

Useful checks:

```bash
rtk --version
rtk gain
rtk discover --since 7
```
