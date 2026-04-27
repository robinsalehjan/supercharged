# supercharged
[![Tests](https://github.com/robinsalehjan/supercharged/actions/workflows/test.yml/badge.svg)](https://github.com/robinsalehjan/supercharged/actions/workflows/test.yml)

## Quick Start

```bash
# Prerequisites: Oh My Zsh, macOS 12.0+, 10GB free space
git clone git@github.com:robinsalehjan/supercharged.git
cd supercharged && npm run setup
```

## Commands

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

## Documentation

| Document | Content |
|----------|---------|
| [What Gets Installed](./docs/WHAT-GETS-INSTALLED.md) | Tools, languages, apps, config files |
| [Customization](./docs/CUSTOMIZATION.md) | Interactive options, manual configuration |
| [Token Optimization](./docs/TOKEN-OPTIMIZATION.md) | RTK + claude-token-efficient (significant savings) |
| [Troubleshooting](./docs/TROUBLESHOOTING.md) | Common issues and solutions |
| [Security](./SECURITY.md) | Security enforcement details |
| [AGENTS.md](./AGENTS.md) | Code patterns, testing workflows, how-to guides |
