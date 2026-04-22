# supercharged
[![Tests](https://github.com/robinsalehjan/supercharged/actions/workflows/test.yml/badge.svg)](https://github.com/robinsalehjan/supercharged/actions/workflows/test.yml)

macOS environment setup automation — installs dev tools (Homebrew, ASDF), manages dotfiles, and backs up Claude Code configuration.

## Quick Start

```bash
# Prerequisites: Oh My Zsh, macOS 12.0+, 10GB free space
git clone git@github.com:robinsalehjan/supercharged.git
cd supercharged && npm install && npm run setup
```

Setup copies dotfiles, validates your system, asks for preferences (iOS/data science/dev tools/Claude Code), installs everything, and runs validation.

## Common Commands

```bash
npm run setup              # Fresh install (interactive)
npm run update             # Update all components
npm run validate           # Verify tools installed correctly
npm run backup:claude      # Backup Claude Code config
npm run restore:claude     # Restore Claude Code config
npm run restore            # Restore from last backup
npm test                   # Run all BATS tests
npm run lint               # ShellCheck all scripts
npm run help               # Show all commands
```

## Safety & Security

- **Backups**: Timestamped backups in `~/.supercharged_backups/` (keeps last 5). Restore with `npm run restore`.
- **Logging**: `.supercharged_install.log` with timestamps and levels.
- **Security**: Pre-commit hooks + hookify rules enforce secrets detection, shellcheck, path validation. See [SECURITY.md](./SECURITY.md).

## Documentation

| Document | Content |
|----------|---------|
| [What Gets Installed](./docs/WHAT-GETS-INSTALLED.md) | Tools, languages, apps, config files |
| [Customization](./docs/CUSTOMIZATION.md) | Interactive options, manual configuration |
| [Token Optimization](./docs/TOKEN-OPTIMIZATION.md) | RTK + Dippy + claude-token-efficient (90%+ savings) |
| [Troubleshooting](./docs/TROUBLESHOOTING.md) | Common issues and solutions |
| [Security](./SECURITY.md) | Security enforcement details |
| [AGENTS.md](./AGENTS.md) | Code patterns, testing workflows, how-to guides |
