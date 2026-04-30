# Worktrunk

## Commands

```bash
wt switch -c <branch>   # Create worktree and branch
wt switch <branch>       # Switch to existing worktree
wt list                  # Show all worktrees
wt remove                # Remove worktree; delete branch if merged
wt merge <target>        # Merge current branch into target (auto-cleans)
```

## Workflow Rules

- Use a worktree for multi-file changes.
- Prefer `wt switch -c <branch>` over `git worktree add`.

## Cleanup

After a PR is merged, ALWAYS clean up the worktree before starting new work:
- `wt remove` from inside the worktree, or `wt merge main` for local-merge workflow (auto-cleans).
- Verify with `wt list` — no stale entries should remain.

Never leave merged worktrees on disk. If unsure whether a branch is merged, check `gh pr view <branch>` first.
