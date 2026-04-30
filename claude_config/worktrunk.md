# Worktrunk - Git Worktree Management

**Usage**: Manages git worktrees for parallel AI agent workflows via `wt` CLI.

## Commands

```bash
wt switch -c <branch>   # Create worktree and branch
wt switch <branch>       # Switch to existing worktree
wt list                  # Show all worktrees
wt remove                # Remove worktree; delete branch if merged
wt merge <target>        # Merge current branch into target (auto-cleans)
```

## Workflow Rules

- For any multi-file feature, bug fix, or experimental work, use a worktree.
- Prefer `wt switch -c <branch>` over `git worktree add`.

## Cleanup (mandatory after PR merge)

After a PR is merged, ALWAYS clean up the worktree before starting new work:
- `wt remove` from inside the worktree, or `wt merge main` for local-merge workflow (auto-cleans).
- Plain git fallback: `cd <main-repo> && git worktree remove <path> && git branch -d <branch>`.
- Verify with `wt list` (or `git worktree list`) — no stale entries should remain.

Never leave merged worktrees on disk. If unsure whether a branch is merged, check `gh pr view <branch>` first.
