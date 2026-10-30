# supercharged
[![Release](https://img.shields.io/github/v/release/robinsalehjan/supercharged?sort=semver)](https://github.com/robinsalehjan/supercharged/releases/latest)
[![Tests](https://github.com/robinsalehjan/supercharged/actions/workflows/test.yml/badge.svg)](https://github.com/robinsalehjan/supercharged/actions/workflows/test.yml)
[![Release Workflow](https://github.com/robinsalehjan/supercharged/actions/workflows/release.yml/badge.svg)](https://github.com/robinsalehjan/supercharged/actions/workflows/release.yml)

## Quick Start

Prerequisites: macOS 12.0+, Xcode Command Line Tools, Oh My Zsh, Node.js 20+ with npm, and 10GB free space.

```bash
# Clone the latest release (recommended)
git clone --branch v3.0.0 --depth 1 git@github.com:robinsalehjan/supercharged.git
cd supercharged && npm run setup
```

Or track `main` for the bleeding edge:

```bash
git clone git@github.com:robinsalehjan/supercharged.git
cd supercharged && npm run setup
```

## Commands

```bash
npm run help               # Canonical complete command inventory
npm run setup              # Fresh interactive installation
npm run sync               # Apply managed configuration
npm run update             # Sync dotfiles, update dependencies, reconcile tooling
npm test                   # Run the BATS suite
```

## Reproduced environment

The repository is the portable source of truth for the audited personal-machine setup: Homebrew formulae and applications, Mac App Store applications, VS Code extensions, asdf runtime pins, dotfiles, OpenWiki, and sanitized Claude Code and Codex configuration.

### Existing machine: configuration only

To force the repository versions of Claude Code, Codex, and the managed dotfiles onto an existing machine, regardless of local modification times, run:

```bash
npm run sync -- --force
```

This creates one configuration-only restoration point before changing managed files. It does not install or update packages. See the [reference guide](./docs/REFERENCE.md#existing-machine-sync-configuration-only) for timestamp gates, rollback scope, machine-local state, and agent-tooling behavior.

### New machine: full baseline

Run `npm run setup` when you want the complete interactive package and application baseline. Review or adjust `build_brewfile` in `scripts/mac.sh` before setup if you do not want the tracked personal applications.

Credentials, authentication state, histories, logs, sessions, caches, and other machine-local runtime data are intentionally excluded. Secret files contain variable-name templates only; populate the corresponding values locally. See the [reference guide](./docs/REFERENCE.md#personal-machine-baseline) for the authoritative manifests and synchronization boundaries.

## Terminal font

Setup installs **JetBrainsMono Nerd Font** so the tmux/Catppuccin status bar renders correctly. After install, set your terminal's font to **JetBrainsMono Nerd Font Mono**:

- **Apple Terminal** — Settings → Profiles → Text → Font → Change…
  Also enable Settings → Profiles → Keyboard → "Use Option as Meta key" (the tmux config uses `Option-Shift-T` as prefix).
- **iTerm2** — Settings → Profiles → Text → Font.
- **Ghostty** — set `font-family = "JetBrainsMono Nerd Font Mono"` in `~/.config/ghostty/config`.

If glyphs still appear as boxes, run `npm run validate` — the validator checks the font is registered. Both `npm run setup` and cask-enabled updates self-heal stale Caskroom installs.

## Releases

Versioning follows [SemVer](https://semver.org). Releases are cut with `npm run release -- <bump>` and published automatically by the [Release workflow](./.github/workflows/release.yml) when a `vX.Y.Z` tag is pushed.

See [GitHub Releases](https://github.com/robinsalehjan/supercharged/releases) for the changelog.

## Documentation

| Document | Content |
|----------|---------|
| [Reference](./docs/REFERENCE.md) | Installed tools, setup options, customization, troubleshooting |
| [Security](./SECURITY.md) | Security enforcement details |
| [Agent guidance](./AGENTS.md) | Repository conventions for contributors and coding agents |
