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
- Use Worktrunk (`wt`) for isolated feature/fix work when the task is more than a trivial single-file edit or when a separate branch/worktree is requested.
- Do not commit unless explicitly requested. When asked to commit, create small atomic commits with conventional commit messages; do not bundle unrelated changes.
- Run the narrowest useful validation after code or script changes.
- Never commit secrets, tokens, machine-specific paths, or work-only configuration.

## Tooling Preferences

- Use code-review-graph first for source navigation, impact analysis, debugging, and code review when its graph is fresh and covers the code in question.
- Before graph-dependent work in a Git repository, check that its graph is available and current. If it is missing or stale, tell the user; run `crg-here` to register and build it, or `code-review-graph update` to refresh it, only when that local state change is within the task's authorization.
- Use `rg`/`rg --files` directly for configuration, Markdown, TOML, generated content, and any source graph that is unavailable, stale, or unsupported.
- Prefer RTK wrappers for noisy shell output when practical, such as `rtk git`, `rtk test`, `rtk npm`, `rtk pytest`, and `rtk tsc`.
- Use `rtk proxy <cmd>` or the raw command when full unfiltered output is required for correctness.
- Clean up completed Worktrunk worktrees with `wt remove` or `wt merge`.
- Use XcodeBuildMCP tools for iOS, macOS, simulator, Swift package, and Xcode project work when Apple development tools are configured and available. Its build/test structured results are schema version 3; request an explicit configuration when Debug is required.
- Use OpenAI Docs MCP for current OpenAI API, Codex, model, and platform documentation when available.

## Communication

- Be concise and direct.
- State assumptions when they affect behavior or risk.
- Call out commands that were not run when verification is incomplete.
