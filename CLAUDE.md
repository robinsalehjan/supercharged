# Supercharged

macOS environment setup automation — installs dev tools (Homebrew, ASDF), manages dotfiles, and backs up Claude Code configuration.

## Project Structure

- `scripts/` - Shell scripts (all zsh-compatible)
  - `mac.sh` - Main installation with system validation and tool setup
  - `update.sh` - Selective component updates
  - `utils.sh` - Shared functions (logging, backup/restore, validation)
  - `setup-profile.sh` - Copy dotfiles and Claude config to `$HOME`
  - `backup-claude.sh` / `restore-claude.sh` - Claude Code config backup/restore
  - `help.sh` - Display available npm commands
- `dot_files/` - Config files copied to `$HOME` (.zshrc, .gitconfig, .tool-versions, etc.)
- `claude_config/` - Claude Code config backup (settings, plugins, marketplaces)
- `.husky/` - Git commit hooks (commitlint)

## Commands

```bash
npm run setup           # Fresh install (interactive)
npm run setup:profile   # Copy dotfiles + Claude config to $HOME
npm run update          # Backup Claude config, copy dotfiles, update all packages
npm run validate        # Verify all tools installed correctly
npm run restore         # Restore from latest backup
npm run backup:claude   # Backup Claude Code config to repo
```

## Code Conventions

**Logging** — always use `log_with_level` from `utils.sh`:
```bash
log_with_level "INFO|WARN|ERROR|SUCCESS" "message"
```

**Error handling** — include cleanup traps in scripts:
```bash
trap cleanup EXIT
```

**Commits** — conventional format: `feat(scope):`, `fix(scope):`, `docs(scope):`, `chore(scope):`, etc.

**Shell scripts** — written for zsh. ShellCheck with `--shell=bash` flags zsh syntax (SC1071, SC2296) — safe to ignore.

**Dotfiles** — comment sections clearly, use env vars for paths (no hardcoded values).

## Security

- Never commit secrets or API keys
- `.secrets` is a template only (in `.gitignore`)
- Claude Code backups are sanitized (work-related marketplaces excluded)
- SSH keys use keychain with 600 permissions

## Reference

See [AGENTS.md](./AGENTS.md) for detailed patterns, testing workflows, and how-to guides.
See [README.md](./README.md) for user-facing documentation.
