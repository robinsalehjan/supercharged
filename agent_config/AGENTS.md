# Shared Agent Instructions

These instructions are restored to both `~/.codex/AGENTS.md` and `~/.claude/AGENTS.md`.
Keep tool-specific behavior in the tool-specific config files; keep cross-agent working agreements here.

## Working Agreements

- Prefer the repository's local instructions and conventions over generic defaults.
- Inspect the relevant files before proposing or making code changes.
- Use `rg` or `rg --files` for text and file searches when available.
- Keep changes focused on the requested task and avoid unrelated refactors.
- Do not use destructive git commands unless explicitly requested.
- Preserve user changes in a dirty worktree.
- Run the narrowest useful validation after code or script changes.
- Never commit secrets, tokens, machine-specific paths, or work-only configuration.

## Tooling Preferences

- When code-review-graph MCP tools are available, use them before broad file scans for codebase exploration, impact analysis, and code review context.
- Use `rg`/`rg --files` as the fallback when code-review-graph is unavailable, stale, or does not cover the needed detail.
- Prefer RTK wrappers for noisy shell output when practical, such as `rtk git`, `rtk test`, `rtk npm`, `rtk pytest`, and `rtk tsc`.
- Use `rtk proxy <cmd>` or the raw command when full unfiltered output is required for correctness.
- Use Worktrunk (`wt`) for deliberate multi-branch or multi-worktree workflows; clean up completed worktrees with `wt remove` or `wt merge`.
- Use XcodeBuildMCP tools for iOS, macOS, simulator, Swift package, and Xcode project work when available.
- Use OpenAI Docs MCP for current OpenAI API, Codex, model, and platform documentation when available.

## Communication

- Be concise and direct.
- State assumptions when they affect behavior or risk.
- Call out commands that were not run when verification is incomplete.
