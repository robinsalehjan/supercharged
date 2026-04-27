@RTK.md
@claude-token-efficient.md

## Subagent Model Selection

When spawning subagents via the Agent tool, use `model: "sonnet"` for routine tasks like:
- Codebase exploration and search
- File reading and summarization
- Running tests or builds
- Simple code generation or edits

Reserve the default (Opus) for tasks requiring deep reasoning, complex architecture decisions, or multi-step problem solving.

## Git Worktrees

For any multi-file feature, bug fix, or experimental work, use a worktree:
- Prefer `wt switch -c <branch>` (worktrunk) over `git worktree add`.
- Alternative: invoke `superpowers:using-git-worktrees` skill, or use Agent tool with `isolation: "worktree"`.

## Worktree Cleanup (mandatory after PR merge)

After a PR is merged, ALWAYS clean up the worktree before starting new work:
- Worktrunk: `wt remove` from inside the worktree, or `wt merge main` for local-merge workflow (auto-cleans).
- Plain git: `cd <main-repo> && git worktree remove <path> && git branch -d <branch>`.
- Verify with `wt list` (or `git worktree list`) — no stale entries should remain.

Never leave merged worktrees on disk. If unsure whether a branch is merged, check `gh pr view <branch>` first.
