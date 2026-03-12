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
- `npm run help` - Display all available commands

## Code Conventions

- **Logging**: Use `log_with_level "INFO|WARN|ERROR|SUCCESS" "message"` from `utils.sh`
- **Error handling**: Include `trap cleanup EXIT` in scripts
- **Commits**: Conventional format (`feat(scope):`, `fix(scope):`, `docs(scope):`, `chore(scope):`)
- **Shell scripts**: Written for zsh; ShellCheck `--shell=bash` flags (SC1071, SC2296) are safe to ignore
- **Dotfiles**: Use env vars, no hardcoded paths

See [AGENTS.md](./AGENTS.md) for detailed code patterns and examples.

## Important Files

- `.supercharged_install.log` - Installation/update logs (timestamped with levels)
- `~/.supercharged_preferences` - User setup choices
- `~/.supercharged_backups/` - Backup history with timestamps
- Claude backup/restore uses portable `$HOME` paths, sanitizes work marketplaces, preserves local plugins

## Security

- Never commit secrets (`.secrets` is template only, in `.gitignore`)
- Claude backups sanitized (work marketplaces excluded)

## Reference

See [AGENTS.md](./AGENTS.md) for detailed patterns, testing workflows, and how-to guides.
See [README.md](./README.md) for user-facing documentation.
