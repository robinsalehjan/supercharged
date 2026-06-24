# Reference

This document covers installed tools, setup options, customization points, and common recovery steps. `dot_files/.tool-versions` is the source of truth for asdf-managed tool versions.

## Commands

```bash
npm run setup                 # Fresh install
npm run update                # Update installed components
npm run update:dry-run        # Preview outdated packages
npm run update:only -- brew   # Update one component: brew, asdf, zsh, npm, pip
npm run validate              # Verify installed tools and configuration
npm run restore               # Restore from latest backup
npm run restore:all           # Restore Claude, Codex, and dotfiles
npm run backup:all            # Backup Claude and Codex config
npm test                      # Run BATS tests
npm run lint                  # ShellCheck scripts
npm run scan:secrets          # Scan repository paths for likely secrets
```

Run `npm run help` for the complete command list.

## Setup Options

Setup stores interactive choices in `~/.supercharged_preferences`.

| Preference | Default | Installs |
| --- | --- | --- |
| `INSTALL_IOS_TOOLS` | `Y` | Xcode CLI helpers, Swift formatters, iOS deployment tools, XcodeBuildMCP |
| `INSTALL_DATA_SCIENCE` | `N` | Jupyter, pandas, numpy, matplotlib, scikit-learn |
| `INSTALL_DEV_TOOLS` | `Y` | Docker CLI, Docker Compose, Colima, kubectl |
| `INSTALL_CLAUDE_CODE` | `Y` | Claude Code and related agent tooling |
| `INSTALL_JVM_TOOLS` | `N` | Java and Kotlin via asdf |
| `INSTALL_EXTRA_APPS` | `N` | Postman and Google Chrome |
| `INSTALL_CLOUD_TOOLS` | `Y` | gcloud and Firebase CLI via asdf |
| `INSTALL_NETWORK_TOOLS` | `Y` | Wireshark, mitmproxy, Proxyman |

## Installed Tools

Always-installed Homebrew formulae and casks are defined in `build_brewfile` in `scripts/mac.sh`. Core categories include:

- Package and shell tooling: `bash`, `coreutils`, `git`, `curl`, `asdf`, `keychain`, `tmux`, `ripgrep`, `tree`, `aria2`.
- Development utilities: `gh`, `jq`, `shellcheck`, `actionlint`, `bats-core`, `duckdb`, `sqlite`, `btop`, `htop`, `mas`, `pipx`, `uv`, `hey`, `watch`.
- AI and agent tools: `codex`, `codexbar`, `ollama`, `replicate`, `rtk`, `worktrunk`, `plannotator`, `code-review-graph`.
- Applications: Visual Studio Code, Slack, Raycast, Reveal, Spotify, Mullvad VPN.
- Fonts: JetBrainsMono Nerd Font.
- Mac App Store apps: AdBlock and DaisyDisk.

asdf-managed tools are listed in `dot_files/.tool-versions`, including Node.js, Python, Ruby, Bundler, gcloud, Firebase CLI, and optional JVM pins.

Claude Code configuration is backed up under `claude_config/`. Codex configuration is backed up under `codex_config/`. Shared cross-agent instructions live in `agent_config/AGENTS.md`.

## Dotfiles

`npm run restore:dotfiles` copies managed dotfiles from `dot_files/` to `$HOME`:

- `.zshrc`
- `.zprofile`
- `.gitconfig`
- `.gitignore_global`
- `.p10k.zsh`
- `.tool-versions`
- `.tmux.conf`

`~/.supercharged_preferences` is generated at setup time, not tracked in `dot_files/`.

Secret templates live under `dot_files/.secrets/`, but real secrets are machine-local. Create `~/.secrets` or `~/.secrets/*.sh` locally when Claude restore or shell startup needs sensitive environment variables.

## Shell Setup

The repository assumes Oh My Zsh is already installed. Install it first if needed:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

Configured Oh My Zsh plugins are defined in `dot_files/.zshrc`: `git`, `asdf`, `zsh-autosuggestions`, `zsh-syntax-highlighting`, `gcloud`, and `docker`.

Useful shell additions include:

- PATH deduplication.
- Secure SSH key loading through `keychain`.
- Shared zsh history.
- Navigation, Git, Docker, Kubernetes, Python, and macOS aliases.
- Utility functions: `mkcd`, `extract`, `gb`, `gcb`, `gpus`, `gpul`, and `docker-clean`.
- Optional Colima auto-start via `SUPERCHARGED_COLIMA_AUTOSTART=1` in `~/.secrets`.

## Customization

Edit `dot_files/.tool-versions` to change asdf-managed tool versions. Do not duplicate those versions in docs; they drift quickly.

Edit `scripts/mac.sh` to change Homebrew packages. Conditional package groups are controlled by the setup preferences above.

Edit `dot_files/.zshrc`, `dot_files/.tmux.conf`, and `dot_files/.p10k.zsh` for shell, tmux, and prompt behavior.

Edit `agent_config/AGENTS.md` for shared Claude/Codex instructions. Edit `codex_config/config.toml` and `.mcp.json` together when adding shared MCP server support.

## Terminal Font

Setup installs JetBrainsMono Nerd Font for the tmux/Catppuccin status bar. After install, set your terminal profile font to `JetBrainsMono Nerd Font Mono`.

For Apple Terminal, also enable Settings > Profiles > Keyboard > "Use Option as Meta key"; the tmux prefix uses `Option-Shift-T`.

If icons render as boxes:

```bash
npm run validate
ls ~/Library/Fonts/ | grep -i jetbrains
```

`npm run setup` self-heals a stale Homebrew Caskroom font install by copying staged `.ttf` files into `~/Library/Fonts`.

Apple Terminal cannot render Unicode Plane 15 glyphs. The tracked `.tmux.conf` uses BMP private-use glyphs so the status bar renders in Apple Terminal, iTerm2, Ghostty, and similar terminals.

## Troubleshooting

For install failures:

```bash
tail -f .supercharged_install.log
npm run restore
```

For validation failures:

```bash
sw_vers -productVersion
df -h /
xcode-select -p
ping -c 1 google.com
npm run validate
```

For ASDF version issues:

```bash
asdf current
asdf list all nodejs
asdf install nodejs "$(awk '/^nodejs / {print $2}' dot_files/.tool-versions)"
asdf set --home nodejs "$(awk '/^nodejs / {print $2}' dot_files/.tool-versions)"
asdf reshim
```

For Java/Kotlin environment issues:

```bash
asdf current
exec zsh
```

For SSH key issues:

```bash
ls -la ~/.ssh/
ssh-add -l
```

The setup supports `id_ed25519`, `id_rsa`, and `id_ecdsa`, preferring ed25519 when available.

## Reset

```bash
npm run restore
```

This restores from the latest backup recorded by the setup scripts.
