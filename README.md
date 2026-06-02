# supercharged
[![Release](https://img.shields.io/github/v/release/robinsalehjan/supercharged?sort=semver)](https://github.com/robinsalehjan/supercharged/releases/latest)
[![Tests](https://github.com/robinsalehjan/supercharged/actions/workflows/test.yml/badge.svg)](https://github.com/robinsalehjan/supercharged/actions/workflows/test.yml)
[![Release Workflow](https://github.com/robinsalehjan/supercharged/actions/workflows/release.yml/badge.svg)](https://github.com/robinsalehjan/supercharged/actions/workflows/release.yml)

## Quick Start

Prerequisites: Oh My Zsh, macOS 12.0+, 10GB free space.

```bash
# Clone the latest release (recommended)
git clone --branch v1.2.1 --depth 1 git@github.com:robinsalehjan/supercharged.git
cd supercharged && npm run setup
```

Or track `main` for the bleeding edge:

```bash
git clone git@github.com:robinsalehjan/supercharged.git
cd supercharged && npm run setup
```

## Commands

```bash
npm run setup              # Fresh install (interactive)
npm run update             # Update all components
npm run validate           # Verify tools installed correctly
npm run restore:all        # Restore Claude Code, Codex, and dotfiles
npm run restore:claude     # Restore Claude Code config
npm run restore:codex      # Restore Codex config
npm run restore:dotfiles   # Copy dotfiles to $HOME
npm run backup:all         # Backup Claude Code and Codex config
npm run backup:claude      # Backup Claude Code config
npm run backup:codex       # Backup Codex config
npm run install:plugins    # Install all Claude Code plugins
npm run install:skills     # Install git-based Claude Code skills
npm run restore            # Restore from last backup
npm run version:show       # Print current version, commit, tag, branch
npm run release -- patch   # Cut a release (patch|minor|major|x.y.z)
npm test                   # Run all BATS tests
npm run lint               # ShellCheck all scripts
npm run help               # Show all commands
```

## Terminal font

Setup installs **JetBrainsMono Nerd Font** so the tmux/Catppuccin status bar renders correctly. After install, set your terminal's font to **JetBrainsMono Nerd Font Mono**:

- **Apple Terminal** — Settings → Profiles → Text → Font → Change…
  Also enable Settings → Profiles → Keyboard → "Use Option as Meta key" (the tmux config uses `Option-Shift-T` as prefix).
- **iTerm2** — Settings → Profiles → Text → Font.
- **Ghostty** — set `font-family = "JetBrainsMono Nerd Font Mono"` in `~/.config/ghostty/config`.

If glyphs still appear as boxes, run `npm run validate` — the validator checks the font is registered and `npm run setup` will self-heal a stale Caskroom install.

## Releases

Versioning follows [SemVer](https://semver.org). Releases are cut with `npm run release -- <bump>` and published automatically by the [Release workflow](./.github/workflows/release.yml) when a `vX.Y.Z` tag is pushed.

See [GitHub Releases](https://github.com/robinsalehjan/supercharged/releases) for the changelog.

## Documentation

| Document | Content |
|----------|---------|
| [What Gets Installed](./docs/WHAT-GETS-INSTALLED.md) | Tools, languages, apps, config files |
| [Customization](./docs/CUSTOMIZATION.md) | Interactive options, manual configuration |
| [Token Optimization](./docs/TOKEN-OPTIMIZATION.md) | RTK + claude-token-efficient (significant savings) |
| [Troubleshooting](./docs/TROUBLESHOOTING.md) | Common issues and solutions |
| [Security](./SECURITY.md) | Security enforcement details |
