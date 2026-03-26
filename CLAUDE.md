# Supercharged

macOS environment setup automation — installs dev tools (Homebrew, ASDF), manages dotfiles, and backs up Claude Code configuration.

## Project Structure

See [README.md](./README.md) for detailed project structure. Key directories:
- `scripts/` - Shell scripts (mac.sh, update.sh, utils.sh, backup/restore)
- `dot_files/` - Dotfiles copied to `$HOME`
- `claude_config/` - Claude Code config backup

## Commands

See [AGENTS.md](./AGENTS.md) for complete npm commands reference.

**Most common**:
- `npm run setup` - Fresh install (interactive)
- `npm run update` - Update all components
- `npm run backup:claude` - Backup Claude Code config to repo
- `npm run restore:claude:force` - Restore Claude Code config from repo
- `npm run lint` - ShellCheck all scripts
- `npm test` - Run all BATS tests (requires `brew install bats-core`)
- `npm run help` - Display all available commands

## Code Conventions

- **Logging**: Use `log_with_level "INFO|WARN|ERROR|SUCCESS" "message"` from `utils.sh`
- **Error handling**: Include `trap cleanup EXIT` in scripts
- **Tests**: BATS (Bash Automated Testing System); test files in `tests/`; use `setup_test_env` + `teardown_test_env`
- **Commits**: Conventional format enforced by commitlint (`@commitlint/config-conventional`):

  | Type | When to use |
  |------|-------------|
  | `feat` | New feature or capability |
  | `fix` | Bug fix |
  | `docs` | Documentation only |
  | `refactor` | Code change that neither fixes a bug nor adds a feature |
  | `test` | Adding or updating tests |
  | `chore` | Maintenance tasks (deps, config, CI, backups) |
  | `style` | Formatting, whitespace (no logic change) |
  | `perf` | Performance improvement |
  | `build` | Build system or tooling changes |
  | `ci` | CI/CD pipeline changes |
  | `revert` | Reverting a previous commit |

  Scope is optional but encouraged: `feat(backup):`, `fix(restore):`, `chore(deps):`
- **Shell scripts**: Written for zsh; ShellCheck `--shell=bash` flags (SC1071, SC2296) are safe to ignore
- **Dotfiles**: Use env vars, no hardcoded paths

See [AGENTS.md](./AGENTS.md) for detailed code patterns and examples.

## Important Files

- `.supercharged_install.log` - Installation/update logs in repo root (timestamped with levels)
- `~/.supercharged_preferences` - User setup choices
- `~/.supercharged_backups/` - Backup history with timestamps
- Claude backup/restore uses portable `$HOME` paths, sanitizes work marketplaces, preserves local plugins

## Security

**This repository is used on personal AND work machines** — comprehensive security enforced:

**Automated checks** (see [SECURITY.md](./SECURITY.md) for details):
- ✅ **Pre-commit hook** - Blocks secrets, hardcoded paths, requires shellcheck (Claude Code PreToolUse hook)
- ✅ **Commitlint** - Enforces conventional commits (Claude Code PostToolUse hook with rollback)
- ✅ **Hookify rules** - 11 Claude Code behavior rules (`.claude/hookify.*.local.md`)

**Key rules**:
- Never commit secrets (`.secrets` is template only, in `.gitignore`)
- No hardcoded paths in dotfiles (use `$HOME`, not `/Users/username/`)
- Shellcheck is REQUIRED (commit fails if not installed: `brew install shellcheck`)
- Claude backups sanitized (work marketplaces excluded)
- No bypassing hooks with `--no-verify` (blocked by hookify)

## Reference

See [AGENTS.md](./AGENTS.md) for detailed patterns, testing workflows, and how-to guides.
See [README.md](./README.md) for user-facing documentation.
