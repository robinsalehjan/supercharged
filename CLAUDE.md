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
- `npm run restore:claude:force` - Restore Claude Code config from repo
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
- Claude backup/restore: sanitizes `@vend-plugins` marketplace and `GITHUB_PERSONAL_ACCESS_TOKEN` from backups, preserves local work plugins via additive merge on restore

## Token Optimization Stack

This repo includes three-layer optimization for ~90% total token savings:

1. **RTK (Input)**: Rust CLI proxy filters command output (60-90% savings on tool results)
2. **Dippy (Flow)**: Permission automation for safe commands (~40% faster development)
3. **claude-token-efficient (Output)**: Behavioral rules reduce verbosity (60% response reduction)

All tools auto-configured during setup/update. See README.md for verification commands.

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

After running `npm run restore:claude` or `npm run restore:claude:force`, plugins must be manually configured:

1. **Review backed-up plugins**: Check `claude_config/installed_plugins.json` to see which official plugins are in the backup
2. **Install/enable plugins**: Use Claude Code's `/plugin` command or settings UI to install and enable required plugins
3. **Enable work plugins** (if on work machine): Work plugins (@vend-plugins) are sanitized from backups for security, so they must be re-enabled manually in `~/.claude/settings.json` or via `/plugin`
4. **Reload plugin registry**: Run `/reload-plugins` in Claude Code to force registry rescan if plugins don't appear in UI
5. **Verify plugins loaded**: Check that skills and agents are available by running `/help` or checking the available tools

**Why manual?** Plugin installation/enablement is stateful and environment-specific (work vs personal). The restore process only restores configuration files — it cannot install plugin code or modify the live plugin registry.

## Reference

See [AGENTS.md](./AGENTS.md) for detailed patterns, testing workflows, and how-to guides.
See [README.md](./README.md) for user-facing documentation.
