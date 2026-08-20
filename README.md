# supercharged
[![Release](https://img.shields.io/github/v/release/robinsalehjan/supercharged?sort=semver)](https://github.com/robinsalehjan/supercharged/releases/latest)
[![Tests](https://github.com/robinsalehjan/supercharged/actions/workflows/test.yml/badge.svg)](https://github.com/robinsalehjan/supercharged/actions/workflows/test.yml)
[![Release Workflow](https://github.com/robinsalehjan/supercharged/actions/workflows/release.yml/badge.svg)](https://github.com/robinsalehjan/supercharged/actions/workflows/release.yml)

## Quick Start

Prerequisites: macOS 12.0+, Xcode Command Line Tools, Oh My Zsh, Node.js 20+ with npm, and 10GB free space.

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
npm run update             # Sync dotfiles/skills, then update all components
npm run update:with-backup # Capture live agent config, then update
npm run update:dry-run     # Read-only report of outdated brew/npm packages
npm run update:only -- brew  # Sync dotfiles/skills, then update one component
npm run validate           # Verify tools installed correctly
npm run restore:all        # Restore Claude Code, Codex, and dotfiles
npm run restore:all -- --force # Force the all-in-one restore
npm run restore:agents     # Restore Claude Code and Codex agent config
npm run restore:claude     # Restore Claude Code config
npm run restore:codex      # Restore Codex config, rules, and shared skills
npm run restore:dotfiles   # Copy dotfiles and reapply Worktrunk shell integration
npm run backup:all         # Backup Claude Code and Codex config
npm run backup:claude      # Backup Claude Code config
npm run backup:codex       # Backup Codex config, hooks, RTK, and skills
npm run install:plugins    # Install all Claude Code plugins
npm run install:managed-tools # Reconcile exact-pinned local agent tools
npm run install:plannotator # Install or update the checksum-pinned Plannotator binary
npm run install:skills     # Install, update, or safely prune shared git skills
npm run update:tool-pins   # Check for newer managed tool releases
npm run restore            # Restore from last backup
npm run version:show       # Print current version, commit, tag, branch
npm run release -- patch   # Cut a release (patch|minor|major|x.y.z)
npm test                   # Run all BATS tests
npm run lint               # ShellCheck, zsh syntax checks, and actionlint
npm run scan:secrets       # Scan repository paths for likely secrets
npm run help               # Show all commands
```

## Reproduced environment

The repository is the portable source of truth for the audited personal-machine setup: Homebrew formulae and applications, Mac App Store applications, VS Code extensions, asdf runtime pins, dotfiles, and sanitized Claude Code and Codex configuration.

### Existing machine: configuration only

To force the repository versions of Claude Code, Codex, and the managed dotfiles onto an existing machine, regardless of local modification times, run:

```bash
npm run restore:all -- --force
```

This creates one configuration-only restoration point before changing Claude Code, Codex, or dotfiles. It does not run the setup installer, Homebrew Bundle, or package updates. Without `--force`, `restore:all` keeps timestamp gating for Claude and Codex while still taking the single pre-restore snapshot.

Git identity is machine-local in `~/.gitconfig.local`. The first restore migrates existing `user.*` values before replacing `~/.gitconfig`; a new interactive setup prompts for name and email. Noninteractive restores leave missing identity unset and print the commands needed to configure it. Claude restore preserves enabled and explicitly disabled `@vend-plugins` entries plus the `vend-plugins` marketplace.

Restoration points cover managed configuration and registries, including absence information so rollback removes files created by a restore. They intentionally exclude auth, secrets, sessions, histories, logs, databases, plugin caches, and installed packages; plugins may need reinstalling after rollback. Older backups without an absence manifest remain copy-only restorable.

The shared MCP baseline is code-review-graph and OpenAI Developer Docs. Codex provides Axiom through its native plugin (including its skills and optional trusted hooks). Apple’s native `xcode` bridge is isolated behind `codex -p apple`; use `codex -p apple-headless` for XcodeBuildMCP outside an open Xcode project. The disabled computer-use bridge remains optional. `codex -p review` layers xhigh reasoning over the base review tooling. `agent_config/managed_tools.json` exact-pins Plannotator, code-review-graph, XcodeBuildMCP, Obscura, and the Claude statusline, while recording tested compatibility floors for Codex, Claude, RTK, and Worktrunk. Axiom uses an immutable marketplace commit plus an expected plugin version; shared git skills also require commit SHAs. A weekly workflow proposes reviewed exact-pin updates.

### New machine: full baseline

Run `npm run setup` when you want the complete interactive package and application baseline. It includes personal applications such as Spotify, Mullvad VPN, DaisyDisk, and Numbers; remove unwanted applications afterward or adjust `build_brewfile` before setup.

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
