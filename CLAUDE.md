# Supercharged

macOS environment setup automation — installs dev tools (Homebrew, ASDF), manages dotfiles, and backs up Claude Code configuration.

## Token Efficiency Guidelines

- Think before acting. Read existing files before writing code.
- Be concise in output but thorough in reasoning.
- Prefer editing over rewriting whole files.
- Do not re-read files you have already read unless the file may have changed.
- Skip files over 100KB unless explicitly required.
- Suggest running /cost when a session is running long to monitor cache ratio.
- Recommend starting a new session when switching to an unrelated task.
- Test your code before declaring done.
- No sycophantic openers or closing fluff.
- Keep solutions simple and direct.
- User instructions always override this file.

## Project Structure

See [README.md](./README.md) for detailed project structure. Key directories:
- `scripts/` - Shell scripts (mac.sh, update.sh, utils.sh, restore.sh, setup-profile.sh, help.sh; backup-claude.sh/restore-claude.sh for Claude config)
- `dot_files/` - Dotfiles copied to `$HOME`
- `claude_config/` - Claude Code config backup

## Commands

See [AGENTS.md](./AGENTS.md) for complete npm commands reference.

**Most common**:
- `npm run setup` - Fresh install (interactive)
- `npm run update` - Update all components
- `npm run validate` - Verify all tools installed correctly
- `npm run update:dry-run` - Preview outdated packages (read-only, safe)
- `npm run backup:claude` - Backup Claude Code config to repo
- `npm run restore:claude -- --force` - Force restore Claude Code config from repo
- `npm run lint` - ShellCheck all scripts
- `npm test` - Run all BATS tests (requires `brew install bats-core`); covers mac, update, setup, utils, claude, restore, meta
- `npm run test:watch` - Watch mode (requires: `brew install watch`)
- `npm run help` - Display all available commands

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

## Important Files

- `.supercharged_install.log` - Installation/update logs in repo root (timestamped with levels)
- `~/.supercharged_preferences` - User setup choices
- `~/.supercharged_backups/` - Backup history with timestamps
- `.claude/` - Claude Code config: 11 hookify rules for security/conventions
- `dot_files/.tool-versions` - ASDF tool versions (one tool per line); edit here to add/change a tool
- Claude backup/restore: backs up `settings.json`, `installed_plugins.json`, `known_marketplaces.json`, `keybindings.json`, and `CLAUDE.md`; sanitizes `@vend-plugins` marketplace and `GITHUB_PERSONAL_ACCESS_TOKEN` from backups; preserves local work plugins via additive merge on restore

## Token Optimization Stack

This repo includes three-layer optimization for ~90% total token savings:

1. **RTK (Input)**: Rust CLI proxy filters command output (60-90% savings on tool results)
2. **Dippy (Flow)**: Permission automation for safe commands (~40% faster development)
3. **claude-token-efficient (Output)**: Behavioral rules reduce verbosity (60% response reduction)

All tools auto-configured during setup/update. See README.md for verification commands.

## Model Configuration

- **Main model**: Opus 4.6 (maximum capability for complex reasoning and architecture)
- **Subagent model**: Sonnet 4.5 (balanced speed/quality for research and execution)
- **Teammates**: Default to the main model (Opus 4.6) unless overridden per-agent
- Configured in `claude_config/settings.json` for portability across machines

## Security

**This repository is used on personal AND work machines** — comprehensive security enforced:

**Automated checks**: Pre-commit (secrets, paths, shellcheck) and hookify rules. See [SECURITY.md](./SECURITY.md) for details and `.claude/hookify.*.local.md` for rules.

**Key rules**:
- Never commit secrets (`.secrets` is template only, in `.gitignore`)
- No hardcoded paths in dotfiles (use `$HOME`, not `/Users/username/`)
- Shellcheck is REQUIRED (commit fails if not installed: `brew install shellcheck`)
- Claude backups sanitized (work marketplaces excluded)
- No bypassing hooks with `--no-verify` (blocked by hookify)

## Post-Restore Steps

After `npm run restore:claude`, plugins must be manually installed/enabled — restore only handles config files, not live plugin state. See [AGENTS.md](./AGENTS.md) for the full procedure.

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

### When to use graph tools FIRST

- **Exploring code**: `semantic_search_nodes` or `query_graph` instead of Grep
- **Understanding impact**: `get_impact_radius` instead of manually tracing imports
- **Code review**: `detect_changes` + `get_review_context` instead of reading entire files
- **Finding relationships**: `query_graph` with callers_of/callees_of/imports_of/tests_for
- **Architecture questions**: `get_architecture_overview` + `list_communities`

Fall back to Grep/Glob/Read **only** when the graph doesn't cover what you need.

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
