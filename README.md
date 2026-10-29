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

This creates one configuration-only restoration point before changing Claude Code, Codex, or dotfiles. It does not run the setup installer, Homebrew Bundle, or package updates. Without `--force`, `sync` keeps timestamp gating for Claude and Codex while still taking the single pre-sync snapshot.

Git identity is machine-local in `~/.gitconfig.local`. The first restore migrates existing `user.*` values before replacing `~/.gitconfig`; a new interactive setup prompts for name and email. Noninteractive restores leave missing identity unset and print the commands needed to configure it. Claude restore preserves enabled and explicitly disabled `@vend-plugins` entries plus the `vend-plugins` marketplace.

Restoration points cover managed configuration and registries, including absence information so rollback removes files created by a restore. They intentionally exclude auth, secrets, sessions, histories, logs, databases, plugin caches, and installed packages; plugins may need reinstalling after rollback. Older backups without an absence manifest remain copy-only restorable.

The shared MCP baseline is code-review-graph and OpenAI Developer Docs. Codex provides Axiom through its native plugin (including its skills and optional trusted hooks). Apple’s native Xcode MCP is isolated behind `codex -p apple`: Xcode 26.3+ supports attached use with a project open, and Xcode 27+ also supports headless use through the one-time `sudo xcrun mcp-server enable` opt-in followed by `xcrun mcp-server start`. Both modes retain Apple’s normal per-agent approval flow. Computer Use is supplied by the ChatGPT desktop app's official bundled plugins, which generate the `cua_repl` MCP connection from the installed app runtime; this repository does not track a separate executable path. Playwright MCP remains enabled. `codex -p review` layers xhigh reasoning over the base review tooling. `npm run check:mcps` completes the MCP initialize handshake against every enabled base server; pass `-- --profile apple` to include native Xcode MCP. Agent audits run the same probe. `agent_config/managed_tools.json` exact-pins Firebase CLI, OpenWiki, Playwright CLI, Playwright MCP, Plannotator, code-review-graph, and Obscura while recording tested compatibility floors for Codex, Claude, and Worktrunk. Firebase CLI installs from its exact npm package when cloud tools are enabled. Managed-tool reconciliation also retires known XcodeBuildMCP and MobileBuildMCP installations. Axiom uses an immutable marketplace commit plus an expected plugin version; shared git skills also require commit SHAs. Pins are promoted from installed versions on a validated personal machine with `npm run promote:pins -- --apply`; upstream checks remain read-only. Axiom and compatibility floors move after local validation.

### New machine: full baseline

Run `npm run setup` when you want the complete interactive package and application baseline. It includes personal applications such as Spotify, Mullvad VPN, DaisyDisk, and Numbers; remove unwanted applications afterward or adjust `build_brewfile` before setup.

Credentials, authentication state, histories, logs, sessions, caches, and other machine-local runtime data are intentionally excluded. Secret files contain variable-name templates only; populate the corresponding values locally. See the [reference guide](./docs/REFERENCE.md#personal-machine-baseline) for the tracked inventory and synchronization boundaries.

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
