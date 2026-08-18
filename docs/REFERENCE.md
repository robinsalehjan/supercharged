# Reference

This document covers installed tools, setup options, customization points, and common recovery steps. `dot_files/.tool-versions` is the source of truth for asdf-managed tool versions.

## Commands

```bash
npm run setup                 # Fresh install
npm run update                # Sync dotfiles/skills, then update components
npm run update:with-backup    # Capture live agent config, then update components
npm run update:dry-run        # Read-only preview; does not update or clean Homebrew
npm run update:only -- brew   # Sync dotfiles/skills, then update one component
npm run validate              # Verify installed tools and configuration
npm run restore               # Restore from latest backup
npm run restore:all           # Restore Claude, Codex, and dotfiles
npm run restore:all -- --force # Force the all-in-one restore
npm run backup:all            # Backup Claude and Codex config
npm run install:skills        # Install, update, or safely prune shared git skills
npm test                      # Run BATS tests
npm run lint                  # ShellCheck, zsh syntax checks, and actionlint
npm run scan:secrets          # Scan repository paths for likely secrets
```

Run `npm run help` for the complete command list.

### Existing Machine: Restore Configuration Only

Use the forced orchestrated restore when an existing machine should adopt the repository's Claude Code, Codex, and dotfile defaults even if its local agent configuration has newer modification times:

```bash
npm run restore:all -- --force
```

The orchestrator creates exactly one configuration-only snapshot, then passes an internal skip flag to each restore stage. It does not run `mac.sh`, Homebrew Bundle, or dependency updates and therefore does not install or remove applications. Without `--force`, Claude and Codex remain timestamp-gated.

`~/.gitconfig` contains portable shared settings and includes `~/.gitconfig.local` for machine identity. Before the first replacement, existing `user.*` values are migrated when the local file does not yet exist. Interactive setup prompts for non-empty name and email on a new machine; restore-only commands never prompt and warn when identity is unset. Claude restore preserves `@vend-plugins` enabled/disabled values and the matching marketplace entry.

Snapshots cover overwritten dotfiles, Git identity, Claude configuration/registries/instructions/statusline/user MCP state, and Codex configuration/hooks/rules/skills. Presence manifests let rollback remove restore-created files. Auth, secrets, sessions, histories, logs, databases, plugin caches, and packages are excluded; plugin reinstall may be necessary after rollback. Legacy backups without a manifest restore available copies but cannot remove newly created files.

### New Machine: Install the Full Baseline

Use `npm run setup` for a new machine when the complete interactive dependency and application baseline is wanted. The baseline includes personal applications such as Spotify, Mullvad VPN, DaisyDisk, and Numbers. Remove unwanted applications after setup or edit `build_brewfile` before running it.

## Setup Options

Setup stores interactive choices in `~/.supercharged_preferences`.

| Preference | Default | Installs |
| --- | --- | --- |
| `INSTALL_IOS_TOOLS` | `Y` | Xcode CLI helpers, Swift formatters, iOS deployment tools, XcodeBuildMCP |
| `INSTALL_DATA_SCIENCE` | `N` | Jupyter, pandas, numpy, matplotlib, scikit-learn |
| `INSTALL_DEV_TOOLS` | `Y` | Docker CLI, Docker Compose, Colima, kubectl |
| `INSTALL_CLAUDE_CODE` | `Y` | Claude Code and related agent tooling |
| `INSTALL_CODEX_APP` | `Y` | ChatGPT desktop app and CodexBar for desktop/mobile Codex access |
| `INSTALL_JVM_TOOLS` | `N` | Java and Kotlin via asdf |
| `INSTALL_EXTRA_APPS` | `N` | Postman and Google Chrome |
| `INSTALL_CLOUD_TOOLS` | `Y` | gcloud and Firebase CLI via asdf, Terraform via Homebrew |
| `INSTALL_NETWORK_TOOLS` | `Y` | Wireshark, mitmproxy, Proxyman |

## Installed Tools

The Homebrew Bundle baseline is defined by `build_brewfile` in `scripts/mac.sh`. Its always-installed core includes:

- Package and shell tooling: `bash`, `coreutils`, `git`, `curl`, `asdf`, `keychain`, `tmux`, `ripgrep`, `tree`, `aria2`.
- Development utilities: `gh`, `jq`, `shellcheck`, `actionlint`, `bats-core`, `duckdb`, `sqlite`, `btop`, `htop`, `mas`, `pipx`, `uv`, `hey`, `watch`, build libraries, and database client libraries mirrored from the personal machine.
- AI and agent tools: `codex`, `ollama`, `omlx`, `replicate`, `cupertino`, `rtk`, and `worktrunk`. ChatGPT and CodexBar are included when `INSTALL_CODEX_APP=Y`.
- Applications: Visual Studio Code, Slack, Raycast, Reveal, Spotify, Mullvad VPN.
- Fonts: JetBrainsMono Nerd Font.
- Mac App Store apps: AdBlock, DaisyDisk, and Numbers.
- Visual Studio Code extensions: the personal machine's AI, Apple-platform, Python, Rust, TypeScript, container, debugger, and editor-utility extensions declared in `build_brewfile`.

`ollama` above is installed as `cask "ollama"`, not a formula — it installs the `Ollama.app` menu bar GUI and symlinks its bundled CLI onto PATH, so no separate formula is needed (or wanted: a `brew "ollama"` formula alongside it would fight over the same `ollama` binary symlink).

The `omlx` CLI above is scripted via its own tap. Its optional menu bar app (`oMLX.app`) has no Homebrew cask — download the `.dmg` for your macOS version from [github.com/jundot/omlx/releases](https://github.com/jundot/omlx/releases) and drag it into `/Applications` manually. If its installer offers to add a shell PATH entry for its bundled CLI shim, decline it — the Homebrew-installed `omlx` is already on PATH and having two competing binaries just causes ambiguity.

Conditional Brewfile groups add iOS, container, cloud (`hashicorp/tap/terraform`), network, and extra application tooling according to the setup preferences above. Dedicated setup helpers install Claude Code, Plannotator, code-review-graph, Obscura, and the Claude statusline; these tools are not Homebrew Bundle entries.

asdf-managed tools are listed in `dot_files/.tool-versions`, including Node.js, Python, Ruby, Bundler, gcloud, Firebase CLI, and optional JVM pins.

Claude Code configuration is backed up under `claude_config/`. Codex configuration is backed up under `codex_config/`. Shared cross-agent instructions live in `agent_config/AGENTS.md`.

Shared git-cloned skills are declared in `agent_config/installed_skills.json`. Its `removed_skills` tombstones safely prune retired managed clones from both agent homes during `npm run install:skills`; removal is limited to git checkouts whose origin matches the retired registry entry, so unrelated local skills are preserved.

### Shared Agent Capabilities

The four graph skills live canonically in `agent_config/skills/<name>/SKILL.md`. `restore:codex` restores those directories directly into Codex; `.claude/skills/*.md` is a generated one-way Claude compatibility mirror and `scripts/generate-claude-skill-mirrors.sh --check` detects drift. Git-cloned skills in `agent_config/installed_skills.json` are also installed into both agent homes. Claude plugins and Codex plugins can contribute additional tool-specific skills, so the complete runtime skill lists are intentionally not identical.

The canonical MCP inventory is: shared code-review-graph and OpenAI Developer Docs; Codex-native Axiom plugin; Apple-profile-only XcodeBuildMCP, Cupertino, and `xcode`; and optional disabled Computer Use. Claude user-local MCP entries are preserved during restore and never imported by backup. code-review-graph intentionally follows latest: setup and update upgrade its pipx installation, while MCP clients invoke the installed `code-review-graph serve` binary directly.

## Personal Machine Baseline

The repository was audited against the personal Mac and records the reproducible portion of that machine's setup. The authoritative locations are:

| Configuration | Source of truth |
| --- | --- |
| Homebrew formulae, casks, Mac App Store apps, and VS Code extensions | `build_brewfile` in `scripts/mac.sh` |
| asdf runtimes | `dot_files/.tool-versions` |
| Shell and terminal configuration | `dot_files/` |
| Shared Claude/Codex instructions | `agent_config/AGENTS.md` |
| Sanitized Claude Code state | `claude_config/` |
| Durable Codex defaults, permissions, MCP servers, hooks, and skills | `codex_config/` |
| Legacy Claude user-scoped MCP registry (empty by default) | `claude_config/mcp_servers.json` |
| Shared project MCP servers | `.mcp.json` and compatible entries in `codex_config/config.toml` |

The audited VS Code extension inventory is installed through Homebrew Bundle:

```text
anthropic.claude-code
creevekcz.idx-xcode
dustypomerleau.rust-syntax
formulahendry.code-runner
ibm.output-colorizer
llvm-vs-code-extensions.lldb-dap
mariomatheu.syntax-project-pbxproj
ms-azuretools.vscode-containers
ms-azuretools.vscode-docker
ms-python.debugpy
ms-python.python
ms-python.vscode-pylance
ms-python.vscode-python-envs
ms-vscode-remote.remote-containers
ms-vscode.makefile-tools
ms-vscode.remote-explorer
ms-vscode.vscode-typescript-next
openai.chatgpt
robinsalehjan.xcode-vscode-shortcuts
rust-lang.rust-analyzer
sweetpad.sweetpad
swiftlang.swift-vscode
tomsmartinez.localhost-browser
typescriptteam.native-preview
usernamehw.errorlens
vadimcn.vscode-lldb
vscode-icons-team.vscode-icons
```

The current Codex baseline selects `gpt-5.6-sol`, high reasoning effort, the pragmatic personality, live web search, disabled memories, the `supercharged` permission profile, and the configured status line. Its lean base MCP inventory contains code-review-graph, OpenAI Developer Docs, and disabled Computer Use. Use `codex -p apple` for XcodeBuildMCP, Cupertino, and Apple’s `xcode` bridge, or `codex -p review` for xhigh review reasoning. Axiom is installed only through `npm run install:codex-plugins`, not as a duplicate MCP server. Codex asks for a one-time trust review before Axiom’s bundled hooks can run.

Run `npm run audit:agents` for a local health check, `npm run audit:agents -- --json` for machine-readable output, or `npm run audit:agents -- --repo-only` for deterministic tracked-config validation. Apple tools are required only with `npm run audit:agents -- --profile apple`.

The audit intentionally does not copy credentials or runtime state. Codex authentication, histories, logs, sessions, memories, databases, caches, project trust, connector state, desktop state, local approval rules, and project-specific MCP servers such as the personal Firebase entry remain machine-local. Backup and restore preserve those Firebase and runtime tables without writing them to `codex_config/config.toml`. Claude work-only marketplaces and plugins are kept in ignored `.local.json` overlays. Files under `dot_files/.secrets/` are templates only, including the `REPLICATE_API_TOKEN` placeholder.

VS Code extensions are reproduced, but VS Code user `settings.json`, `keybindings.json`, and `tasks.json` are not tracked because they can contain machine-, account-, or project-specific state. Use VS Code Settings Sync or manage sanitized copies separately when identical editor preferences are required.

To refresh the tracked agent configuration after intentionally changing the personal machine, run:

```bash
npm run backup:all
npm run scan:secrets
git diff --check
```

Review the diff before committing. Package inventory changes must still be made in `scripts/mac.sh`; the backup commands cover agent configuration, not Homebrew, Mac App Store, or VS Code inventories.

## Codex Desktop Access

When `INSTALL_CODEX_APP=Y`, setup installs the current ChatGPT desktop app with Homebrew cask `chatgpt`, plus CodexBar. The preference name is retained for compatibility with existing `~/.supercharged_preferences` files. Sign in with the ChatGPT account or workspace that has Codex access.

Remote access uses the host Mac's projects, credentials, plugins, MCP servers, browser setup, and local tools. Keep the host awake and online while you want remote Codex access available.

In the ChatGPT desktop app, use **Set up Remote** and follow the current [OpenAI remote connections guide](https://learn.chatgpt.com/docs/remote-connections) to make this Mac available from another device.

## Dotfiles

`npm run restore:dotfiles` copies managed dotfiles from `dot_files/` to `$HOME`:

- `.zshrc`
- `.zprofile`
- `.gitconfig`
- `.gitconfig.local` is not copied from the repository; it stores machine-local identity and is included in rollback snapshots
- `.gitignore_global`
- `.p10k.zsh`
- `.tool-versions`
- `.tmux.conf`

`~/.supercharged_preferences` is generated at setup time, not tracked in `dot_files/`.

Restoring `.zshrc` can remove Worktrunk's generated shell integration, so `restore:dotfiles` reapplies that integration when `wt` is installed. It does not restore Claude/Codex configuration or initialize code-review-graph; use `restore:agents` or `restore:all` for agent configuration.

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

Edit `agent_config/AGENTS.md` for shared Claude/Codex instructions. Keep the tracked Claude user registry empty unless a compatibility requirement warrants a sanitized entry. For shared project servers, edit `.mcp.json` and add the compatible Codex entry together; put Apple-only servers in `codex_config/apple.config.toml`.

`npm run update:dry-run` is non-mutating: it suppresses Homebrew auto-update, skips `brew update`, and skips cleanup. It reports outdated Homebrew formulae, casks, and global npm packages, then exits before asdf, zsh, npm, or pip updates.

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

`npm run validate` prepends the active asdf shim directory before checking versions, including when npm invokes it from a non-interactive shell. Suggested remediation uses the current `asdf set --home` command.

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
