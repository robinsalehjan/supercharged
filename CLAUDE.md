# Supercharged

macOS environment setup automation — installs dev tools (Homebrew, ASDF), manages dotfiles, and backs up Claude Code configuration.

## Project Structure

- `scripts/` - Shell scripts (mac.sh, update.sh, utils.sh, restore.sh, setup-profile.sh, help.sh; backup-claude.sh/restore-claude.sh for Claude config)
- `dot_files/` - Dotfiles copied to `$HOME`
- `claude_config/` - Claude Code config backup

## Code Conventions

- **Logging**: Use `log_with_level "INFO|WARN|ERROR|SUCCESS" "message"` from `utils.sh`
- **Error handling**: Include `trap cleanup EXIT` in scripts
- **Tests**: BATS; test files in `tests/<suite>/`; use `setup_test_env` + `teardown_test_env`. Run `npm test` before committing script changes.
- **Commits**: Conventional format preferred (not enforced). Scope optional.
  - Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `build`, `ci`, `revert`, `wip`, `update`, `add`, `remove`
- **Shell scripts**: Written for zsh; see [AGENTS.md](./AGENTS.md) > ShellCheck Notes for safe-to-ignore warnings.
- **Dotfiles**: Use env vars, no hardcoded paths.

See [AGENTS.md](./AGENTS.md) for npm commands, code patterns, testing details, and how-to guides.

## Security

Used on personal AND work machines; security enforced via hookify rules during Claude Code sessions. See [SECURITY.md](./SECURITY.md).

## Reference

See [README.md](./README.md) for user-facing documentation.
