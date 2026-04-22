# supercharged
[![Tests](https://github.com/robinsalehjan/supercharged/actions/workflows/test.yml/badge.svg)](https://github.com/robinsalehjan/supercharged/actions/workflows/test.yml)

A comprehensive set of scripts for setting up a developer-friendly macOS environment with enhanced security, performance, and customization options.

## Features

- **Interactive Setup**: Customize your installation based on your development needs (iOS tools, data science, dev tools)
- **Multi-Machine Security**: Git hooks enforce security for personal/work machines - blocks secrets, hardcoded paths, requires shellcheck
- **Enhanced Security**: Secure SSH key management with keychain integration and proper permission handling
- **Smart Recovery**: Automatic timestamped backups and restoration points for safe rollbacks
- **Performance Optimized**: PATH deduplication and efficient installation processes
- **Comprehensive Logging**: Structured logging with levels (INFO, WARN, ERROR, SUCCESS) for better debugging
- **System Validation**: Pre-installation checks for macOS version, disk space, Xcode tools, and internet connectivity

## System Requirements

- **macOS**: 12.0 (Monterey) or later
- **Disk Space**: At least 10GB free space
- **Internet**: Active internet connection required
- **Oh My Zsh**: Must be installed before running setup
- **Xcode Command Line Tools**: Will be installed automatically if missing

## Quick Start

### Fresh Installation
```bash
git clone git@github.com:robinsalehjan/supercharged.git
cd supercharged && npm install && npm run setup
```

The setup process will:
1. Copy dotfiles and Claude Code configuration to your home directory
2. Validate your system meets requirements (macOS 12.0+, 10GB+ free space, internet)
3. Create a timestamped restoration point for safe rollbacks
4. Ask for your preferences (iOS tools, data science, dev tools, Claude Code)
5. Install Homebrew, selected tools, ZSH plugins, and ASDF languages
6. Run validation to ensure all tools are working correctly

### Update Existing Installation
```bash
npm run update
```

Updates dotfiles, Homebrew packages, ASDF tool versions, ZSH plugins, npm packages, and pip packages. Creates a Claude Code config backup first.

## Commands

| Command | Description |
|---------|-------------|
| **Setup** | |
| `npm run setup` | Complete fresh installation with interactive configuration |
| `npm run setup:profile` | Copy dotfiles and Claude Code configuration to $HOME |
| **Updates** | |
| `npm run update` | Update all installed packages and tools |
| `npm run update:dry-run` | Preview outdated Homebrew and npm packages (read-only) |
| `npm run update:only -- <comp>` | Copy dotfiles, then update one component (brew, asdf, zsh, npm, pip) |
| **Claude Code** | |
| `npm run backup:claude` | Backup Claude Code configuration to claude_config/ |
| `npm run restore:claude` | Restore Claude Code config (only if repo is newer) |
| `npm run restore:claude -- --force` | Force restore Claude Code config |
| **Utilities** | |
| `npm run validate` | Verify all tools are properly installed |
| `npm run restore` | Restore from the most recent backup |
| `npm run lint` | ShellCheck all scripts |
| `npm run help` | Show all available commands |
| **Testing** | |
| `npm test` | Run all BATS tests |
| `bats tests/<suite>/*.bats` | Run a specific test suite |

## Testing

```bash
npm test                       # Run all tests
bats tests/<suite>/*.bats     # Run a specific suite (claude, utils, mac, update, setup)
```

Tests run automatically via pre-commit hook and GitHub Actions. See [AGENTS.md](./AGENTS.md) for test structure and patterns.

## Safety & Security

**Automatic Backups**: Every installation creates a timestamped backup in `~/.supercharged_backups/`. The system keeps the last 5 backups. Restore with `npm run restore`.

**Logging**: All activity logged to `.supercharged_install.log` with timestamps and levels.

**Security Enforcement**: Pre-commit hooks and 11 Claude Code hookify rules enforce secrets detection, shellcheck, and path validation. See [SECURITY.md](./SECURITY.md).

**Token Optimization**: Three-layer stack (RTK + Dippy + claude-token-efficient) for 90%+ savings. See [docs/TOKEN-OPTIMIZATION.md](./docs/TOKEN-OPTIMIZATION.md).

## Documentation

| Document | Description |
|----------|-------------|
| [What Gets Installed](./docs/WHAT-GETS-INSTALLED.md) | Full list of tools, languages, apps, and configuration files |
| [Customization](./docs/CUSTOMIZATION.md) | Interactive options and manual configuration |
| [Token Optimization](./docs/TOKEN-OPTIMIZATION.md) | Three-layer token optimization stack for Claude Code |
| [Troubleshooting](./docs/TROUBLESHOOTING.md) | Common issues and solutions |
| [Security](./SECURITY.md) | Security enforcement and hookify rules |
| [AGENTS.md](./AGENTS.md) | Detailed code patterns, testing workflows, and how-to guides |
