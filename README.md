# supercharged
[![Release](https://img.shields.io/github/v/release/robinsalehjan/supercharged?sort=semver)](https://github.com/robinsalehjan/supercharged/releases/latest)
[![Tests](https://github.com/robinsalehjan/supercharged/actions/workflows/test.yml/badge.svg)](https://github.com/robinsalehjan/supercharged/actions/workflows/test.yml)
[![Release Workflow](https://github.com/robinsalehjan/supercharged/actions/workflows/release.yml/badge.svg)](https://github.com/robinsalehjan/supercharged/actions/workflows/release.yml)

## Quick Start

Prerequisites: Oh My Zsh, macOS 12.0+, 10GB free space.

```bash
# Clone the latest release (recommended)
git clone --branch v1.3.0 --depth 1 git@github.com:robinsalehjan/supercharged.git
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
npm run update:dry-run     # Read-only report of outdated brew/npm packages
npm run update:only -- brew  # Update one component (brew|asdf|zsh|npm|pip)
npm run validate           # Verify tools installed correctly
npm run restore:all        # Restore Claude Code, Codex, and dotfiles
npm run restore:agents     # Restore Claude Code and Codex agent config
npm run restore:claude     # Restore Claude Code config
npm run restore:codex      # Restore Codex config, rules, and shared skills
npm run restore:dotfiles   # Copy dotfiles to $HOME
npm run backup:all         # Backup Claude Code and Codex config
npm run backup:claude      # Backup Claude Code config
npm run backup:codex       # Backup Codex config, hooks, RTK, and skills
npm run install:plugins    # Install all Claude Code plugins
npm run install:skills     # Install git-based skills for Claude Code and Codex
npm run restore            # Restore from last backup
npm run version:show       # Print current version, commit, tag, branch
npm run release -- patch   # Cut a release (patch|minor|major|x.y.z)
npm test                   # Run all BATS tests
npm run lint               # ShellCheck all scripts
npm run scan:secrets       # Scan repository paths for likely secrets
npm run help               # Show all commands
```

## Reproduced environment

The repository is the portable source of truth for the audited personal-machine setup: Homebrew formulae and applications, Mac App Store applications, VS Code extensions, asdf runtime pins, dotfiles, and sanitized Claude Code and Codex configuration. Run `npm run setup` on a new Mac, or `npm run restore:all` on an existing installation, to apply that baseline.

Credentials, authentication state, histories, logs, sessions, caches, and other machine-local runtime data are intentionally excluded. Secret files contain variable-name templates only; populate the corresponding values locally. See the [reference guide](./docs/REFERENCE.md#personal-machine-baseline) for the tracked inventory and synchronization boundaries.

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
| [Reference](./docs/REFERENCE.md) | Installed tools, setup options, customization, troubleshooting |
| [Security](./SECURITY.md) | Security enforcement details |
