# Supercharged

macOS environment setup automation — installs dev tools (Homebrew, ASDF), manages dotfiles, and backs up Claude Code configuration.

## Token Efficiency Guidelines

Core rules are in `~/.claude/claude-token-efficient.md` (loaded globally). Project-specific additions:

- Suggest running /cost when a session is running long to monitor cache ratio.
- Recommend starting a new session when switching to an unrelated task.
- User instructions always override this file.

## Project Structure

See [README.md](./README.md) for detailed project structure. Key directories:
- `scripts/` - Shell scripts (mac.sh, update.sh, utils.sh, restore.sh, setup-profile.sh, help.sh; backup-claude.sh/restore-claude.sh for Claude config)
- `dot_files/` - Dotfiles copied to `$HOME`
- `claude_config/` - Claude Code config backup

## Commands

See [AGENTS.md](./AGENTS.md) for complete npm commands reference.

## Code Conventions

- **Logging**: Use `log_with_level "INFO|WARN|ERROR|SUCCESS" "message"` from `utils.sh`
- **Error handling**: Include `trap cleanup EXIT` in scripts
- **Tests**: BATS (Bash Automated Testing System); test files in `tests/`; use `setup_test_env` + `teardown_test_env`
- **Testing workflow**: Add BATS tests in `tests/<script-name>/` for new script features; run `npm test` before committing script changes
- **Commits**: Conventional format preferred (not enforced). Scope optional.
  - Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `build`, `ci`, `revert`, `wip`, `update`, `add`, `remove`
  - Examples: `feat(backup): add new feature`, `fix(restore): handle edge case`, `chore(deps): bump versions`
- **Shell scripts**: Written for zsh; ShellCheck `--shell=bash` flags (SC1071, SC2296) are safe to ignore
- **Dotfiles**: Use env vars, no hardcoded paths

See [AGENTS.md](./AGENTS.md) for detailed code patterns and examples.

## Model Configuration

- **Main model**: Opus 4.6 (maximum capability for complex reasoning and architecture)
- **Subagent model**: Sonnet 4.5 (balanced speed/quality for research and execution)
- **Teammates**: Default to the main model (Opus 4.6) unless overridden per-agent
- Configured in `claude_config/settings.json` for portability across machines

## Git Worktrees

For multi-file features, bug fixes, or experimental work, use a worktree (worktrunk is installed):
- `wt switch -c <branch>` to create + enter, `wt list` to inspect, `wt merge main` for local merge + auto-cleanup, `wt remove` after a PR is merged.
- Fallbacks: `superpowers:using-git-worktrees` skill, or Agent tool with `isolation: "worktree"`.
- **Mandatory cleanup**: after a PR merges, run `wt remove` (or rely on `wt merge`'s auto-clean). Never leave merged worktrees on disk. See [AGENTS.md](./AGENTS.md#worktrunk-git-worktree-manager) for the full workflow.

## Security

**This repository is used on personal AND work machines** — comprehensive security enforced:

**Automated checks**: Hookify rules enforce security during Claude Code sessions. See [SECURITY.md](./SECURITY.md) for details and `.claude/hookify.*.local.md` for rules.

**Key rules**:
- Never commit secrets (`.secrets` is template only, in `.gitignore`)
- No hardcoded paths in dotfiles (use `$HOME`, not `/Users/username/`)
- Shellcheck is required for `npm run lint` (`brew install shellcheck`)
- Claude backups sanitized (work marketplaces excluded)
- No bypassing hooks with `--no-verify` (blocked by hookify)

## Reference

See [AGENTS.md](./AGENTS.md) for detailed patterns, testing workflows, and how-to guides.
See [README.md](./README.md) for user-facing documentation.

<!-- code-review-graph MCP tools -->
## MCP Tools: code-review-graph

**IMPORTANT: This project has a knowledge graph. ALWAYS use the
code-review-graph MCP tools BEFORE using Grep/Glob/Read to explore
the codebase.** The graph is faster, cheaper (fewer tokens), and gives
you structural context (callers, dependents, test coverage) that file
scanning cannot.

### Key Tools

| Tool | Use when |
|------|----------|
| `detect_changes` | Reviewing code changes — gives risk-scored analysis |
| `get_review_context` | Need source snippets for review — token-efficient |
| `get_impact_radius` | Understanding blast radius of a change |
| `get_affected_flows` | Finding which execution paths are impacted |
| `query_graph` | Tracing callers, callees, imports, tests, dependencies |
| `semantic_search_nodes` | Finding functions/classes by name or keyword |
| `get_architecture_overview` | Understanding high-level codebase structure |
| `refactor_tool` | Planning renames, finding dead code |

### Workflow

1. The graph auto-updates on file changes (via hooks).
2. Use `detect_changes` for code review.
3. Use `get_affected_flows` to understand impact.
4. Use `query_graph` pattern="tests_for" to check coverage.
