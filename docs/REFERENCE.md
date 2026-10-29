# Reference

This document covers installed tools, setup options, customization points, and common recovery steps. `dot_files/.tool-versions` is the source of truth for asdf-managed tool versions.

## Commands

```bash
npm run setup                 # Fresh install
npm run sync                  # Apply Claude, Codex, and dotfiles from the repository
npm run sync -- --force       # Apply all managed config regardless of timestamps
npm run backup                # Capture Claude and Codex config in the repository
npm run update                # Sync dotfiles/skills, then update components
npm run update -- --backup    # Capture live agent config, then update components
npm run update -- --dry-run   # Read-only preview; does not update or clean Homebrew
npm run update -- --only brew # Sync dotfiles/skills, then update one component
npm run validate              # Verify installed tools and configuration
npm run rollback              # Roll back to the latest configuration snapshot
npm run install:agent-tooling # Reconcile shared tooling and both native plugin sets
npm run install:skills        # Install, update, or safely prune shared git skills
npm run install:managed-tools # Reconcile exact-pinned local agent tools
npm run install:firebase     # Install pinned Firebase CLI from npm
npm run install:openwiki    # Install or update OpenWiki for agent documentation
npm run install:plannotator   # Reconcile the checksum-pinned Plannotator binary
npm run update:tool-pins      # Check upstream releases against managed pins
npm test                      # Run BATS tests
npm run lint                  # ShellCheck, zsh syntax checks, and actionlint
npm run scan:secrets          # Scan repository paths for likely secrets
npm run check:agent-tooling   # Report shared capabilities and detect harness drift
```

Run `npm run help` for the complete command list.

### Existing Machine: Sync Configuration Only

Use a forced sync when an existing machine should adopt the repository's Claude Code, Codex, and dotfile defaults even if its local agent configuration has newer modification times:

```bash
npm run sync -- --force
```

The orchestrator creates exactly one configuration-only snapshot, then passes an internal skip flag to each apply stage. It does not run `mac.sh`, Homebrew Bundle, or general dependency updates. Codex sync does reconcile the checksum-pinned Plannotator hook binary before its timestamp gate so a current configuration cannot retain an incompatible executable. Without `--force`, Claude and Codex configuration remains timestamp-gated.

`~/.gitconfig` contains portable shared settings and includes `~/.gitconfig.local` for machine identity. Before the first replacement, existing `user.*` values are migrated when the local file does not yet exist. Interactive setup prompts for non-empty name and email on a new machine; restore-only commands never prompt and warn when identity is unset. Claude restore preserves `@vend-plugins` enabled/disabled values and the matching marketplace entry.

Snapshots cover overwritten dotfiles, Git identity, Claude configuration/registries/instructions/user MCP state, and Codex configuration/hooks/rules/skills. Presence manifests let rollback remove restore-created files. Auth, secrets, sessions, histories, logs, databases, plugin caches, and packages are excluded; plugin reinstall may be necessary after rollback. Legacy backups without a manifest restore available copies but cannot remove newly created files.

### New Machine: Install the Full Baseline

Use `npm run setup` for a new machine when the complete interactive dependency and application baseline is wanted. The baseline includes personal applications such as Spotify, Mullvad VPN, DaisyDisk, and Numbers. Remove unwanted applications after setup or edit `build_brewfile` before running it.

When Apple's Foundation Models CLI (`fm`) is available, setup checks `fm license --status` and runs `sudo fm license` in an interactive terminal if acceptance is needed. Review and accept Apple's machine-wide terms at its prompt. This step runs independently of the iOS tools preference. Setup skips unavailable or already licensed installations; non-interactive runs and failed or declined acceptance warn without stopping setup. To complete acceptance later, run `sudo fm license`.

## Setup Options

Setup stores interactive choices in `~/.supercharged_preferences`.

| Preference | Default | Installs |
| --- | --- | --- |
| `INSTALL_IOS_TOOLS` | `Y` | Xcode CLI helpers, Swift formatters, iOS deployment/simulator tools, native Xcode MCP setup |
| `INSTALL_DATA_SCIENCE` | `N` | Jupyter, pandas, numpy, matplotlib, scikit-learn |
| `INSTALL_DEV_TOOLS` | `Y` | Docker CLI, Docker Compose, Colima, kubectl |
| `INSTALL_CLAUDE_CODE` | `Y` | Claude Code and related agent tooling |
| `INSTALL_CODEX_APP` | `Y` | ChatGPT desktop app and CodexBar for desktop/mobile Codex access |
| `INSTALL_JVM_TOOLS` | `N` | Java and Kotlin via asdf |
| `INSTALL_EXTRA_APPS` | `N` | Postman and Google Chrome |
| `INSTALL_CLOUD_TOOLS` | `Y` | gcloud via asdf, Firebase CLI via exact-pinned npm package, Terraform via Homebrew |
| `INSTALL_NETWORK_TOOLS` | `Y` | Wireshark, mitmproxy, Proxyman |

## Installed Tools

The Homebrew Bundle baseline is defined by `build_brewfile` in `scripts/mac.sh`. Its always-installed core includes:

- Package and shell tooling: `bash`, `coreutils`, `git`, `curl`, `asdf`, `keychain`, `tmux`, `ripgrep`, `tree`, `aria2`.
- Development utilities: `gh`, `jq`, `shellcheck`, `actionlint`, `bats-core`, Danger JS, Danger Swift, `duckdb`, `sqlite`, `btop`, `htop`, `mas`, `pipx`, `uv`, `hey`, `watch`, `watchexec` for `npm run test:watch`, build libraries, and database client libraries mirrored from the personal machine.
- AI and agent tools: `codex`, `ollama`, `replicate`, `worktrunk`, OpenWiki, Playwright CLI, Playwright MCP, and Obscura. ChatGPT and CodexBar are included when `INSTALL_CODEX_APP=Y`.
- Applications: Visual Studio Code, Slack, Raycast, Reveal, Spotify, Mullvad VPN.
- Fonts: JetBrainsMono Nerd Font.
- Mac App Store apps: AdBlock, DaisyDisk, and Numbers.
- Visual Studio Code extensions: the personal machine's AI, Apple-platform, Python, Rust, TypeScript, container, debugger, and editor-utility extensions declared in `build_brewfile`.

`ollama` above is installed as `cask "ollama"`, not a formula — it installs the `Ollama.app` menu bar GUI and symlinks its bundled CLI onto PATH, so no separate formula is needed (or wanted: a `brew "ollama"` formula alongside it would fight over the same `ollama` binary symlink).

Conditional Brewfile groups add iOS, container, cloud (`hashicorp/tap/terraform`), network, and extra application tooling according to the setup preferences above. The iOS group includes SimSlim for simulator resource trimming alongside the Xcode and Swift command-line tools. Third-party Homebrew entries grant formula-level trust only; setup and updates also remove known retired taps when they no longer provide an installed item. Dedicated setup helpers install Claude Code and the exact-pinned Firebase CLI, OpenWiki, Playwright CLI, Playwright MCP, Plannotator, code-review-graph, and Obscura. Firebase CLI, OpenWiki, Playwright CLI, and Playwright MCP install from npm after the managed Node.js runtime is active; Playwright browser binaries are left to `playwright-cli install-browser` or first use. `agent_config/managed_tools.json` is the desired-state source for the exact-pinned tools. Release archives verify architecture-specific SHA-256 values before installation; code-review-graph uses an exact PyPI package version, while Firebase CLI, OpenWiki, Playwright CLI, and Playwright MCP use exact npm package versions. Managed-tool reconciliation removes known repository-managed, Homebrew, and global npm installations of the retired XcodeBuildMCP and MobileBuildMCP integrations; executables at unknown manual paths are reported for manual cleanup. Run `npm run install:firebase`, `npm run install:openwiki`, or `npm run install:managed-tools` to reconcile the relevant tools; add `-- --dry-run` to inspect drift.

As part of the profile migration, `npm run sync -- --only codex` treats a local `~/.codex/apple-headless.config.toml` as restore drift even when normal timestamp gating would otherwise skip the restore. The command first preserves the retired profile in its rollback snapshot, then removes it; use `codex -p apple` afterward.

asdf-managed tools are listed in `dot_files/.tool-versions`, including Node.js, Python, Ruby, Bundler, gcloud, and optional JVM pins. Firebase CLI is pinned as `firebase-tools` in `agent_config/managed_tools.json` and installed through the selected Node.js runtime when cloud tools are enabled. Setup removes the retired asdf Firebase plugin after npm installation succeeds so its Intel-only shim cannot mask the working CLI. Run `npm run install:firebase` to reconcile Firebase separately.

Claude Code configuration is backed up under `claude_config/`. Codex configuration is backed up under `codex_config/`. Shared cross-agent instructions live in `agent_config/AGENTS.md`.

Shared git-cloned skills are declared in `agent_config/installed_skills.json`. Active entries must use immutable 40-character commit refs. Its `removed_skills` tombstones safely prune retired managed clones from both agent homes during `npm run install:skills`; removal is limited to git checkouts whose origin matches the retired registry entry, so unrelated local skills are preserved.

### Shared Agent Capabilities

The four graph skills live canonically in `agent_config/skills/<name>/SKILL.md`. `npm run sync -- --only codex` applies those directories directly to Codex. This repository does not maintain project-local Claude skills. Git-cloned skills in `agent_config/installed_skills.json` are also installed into both agent homes. Claude plugins and Codex plugins can contribute additional tool-specific skills, so the complete runtime skill lists are intentionally not identical.

OpenWiki is installed as the exact-pinned `openwiki` CLI. To use it inside Codex or Claude Code, run `openwiki integrations install codex` or `openwiki integrations install claude`, then restart that agent; `openwiki integrations list` shows installation status. These integrations use the agent's authenticated session and need no separate model provider configuration. From a repository root, ask the integrated agent to initialize or update its wiki when wanted. The standalone `openwiki --init` and `openwiki --update` commands remain available; their interactive first run stores the selected provider and credentials in `~/.openwiki/.env`, which is local-only and must never be committed or backed up. Before generation, review `.openwikiignore` to exclude sensitive or irrelevant source paths. OpenWiki writes `openwiki/` and maintains marked guidance blocks in root `AGENTS.md` and `CLAUDE.md`; other content remains user-managed. For a concrete question, an integrated agent can use `openwiki_search` and `openwiki_read` to retrieve relevant sections, or read `openwiki/quickstart.md` and linked pages directly. An existing wiki is optional secondary context: corroborate material claims against current source, tests, and a fresh code-review-graph, report conflicts as stale documentation, and treat source and tests as authoritative. Agents do not generate or update a wiki without an explicit user request, including explicit enrollment in the scheduled repository updater described below.

The canonical MCP inventory is: shared code-review-graph and OpenAI Developer Docs; Codex-native Axiom plugin; native Xcode MCP in the Apple profile; and enabled Playwright MCP. Computer Use is not a tracked standalone MCP entry: install and enable it in the ChatGPT desktop app so the official `unified-computer-use` plugin can generate the `cua_repl` connection with absolute paths to the app runtime and the service installed under `$CODEX_HOME/computer-use`. Claude user-local MCP entries are preserved during restore and never imported by backup. Local MCP executables are exact-pinned where this repository controls installation. The hosted OpenAI Developer Docs MCP has no local executable to pin; native Xcode MCP follows the selected Xcode installation.

Use `codex -p apple` for both native Xcode MCP modes. Xcode 26.3 through 26.x requires Xcode.app running with a project open and external-agent access enabled in Xcode’s Intelligence settings. Xcode 27+ can also run headlessly after a one-time `sudo xcrun mcp-server enable`; start it with `xcrun mcp-server start`. Do not enable the unsafe allow-all-agents option: opening or creating a workspace triggers Apple’s normal agent and folder approval flow.

`npm run install:agent-tooling` is the harness-neutral reconciliation entry point. It installs the shared host CLIs and shared skills first, then invokes the native Claude and Codex marketplace installers when those harnesses are available. Its dry-run previews both desired plugin sets even when a client is not installed; use `-- --harness claude` or `-- --harness codex` to target one adapter. `npm run check:agent-tooling` reports the composed inventory and fails when shared MCP definitions differ between harnesses. Harness-native plugins remain intentionally different.

Pin updates follow the personal machine. Run `npm run update:tool-pins` or `npm run update:asdf-pins` to inspect upstream candidates without changing tracked files. Install and validate the chosen versions on this machine, then run `npm run promote:pins` to preview the resulting pin changes and `npm run promote:pins -- --apply` to write them. Use `-- --only asdf` or `-- --only agents` to limit promotion. The promoter reads active, installed asdf versions within `agent_config/asdf_policy.json`, global npm package versions (including Firebase CLI), and installed agent CLI versions; release binaries must match published checksums, and the Firebase command must run at its installed package version. Missing tools are skipped. Axiom plugin refs and Codex, Claude, and Worktrunk compatibility versions remain manual after local validation. CI checks repository changes but never proposes new pins.

Version policy depends on the integration boundary:

| Integration | Policy |
| --- | --- |
| Plannotator Stop-hook binary | Exact release and SHA-256 per macOS architecture |
| code-review-graph local MCP | Exact PyPI version with required extras |
| Firebase CLI, OpenWiki, Playwright CLI, and Playwright MCP | Exact npm package versions |
| Obscura | Exact release archive and SHA-256 per macOS architecture; binaries are verified after extraction |
| Axiom | Immutable Codex marketplace commit plus expected plugin version |
| Claude plugins | Native marketplace installation verified against tracked plugin versions |
| Shared git skills | Immutable commit SHA; mutable branches are rejected |
| Codex, Claude, Worktrunk | Minimum compatible and last-tested versions; newer versions warn until validated |
| OpenAI Developer Docs MCP | Hosted HTTP service; there is no local server binary to pin |
| Native Xcode MCP bridge | Ships with Xcode and follows the selected Xcode installation |

### Nested repository graph discovery

The launchd watcher starts one `code-review-graph watch` process for each registered repository. To index a repository once, run `crg-here` from its root; it registers and fully builds the graph, then the watcher keeps it current.

For a checkout that contains several independent Git repositories, opt in to automatic discovery by adding a registered parent root to the local, untracked `~/.code-review-graph/watcher-config.json` file:

```json
{
  "discovery_roots": [
    {
      "path": "/absolute/path/to/ios-harness",
      "max_depth": 4
    }
  ]
}
```

The supervisor discovers nested repositories with `.git` directories, registers and fully builds each one, and starts an independent watcher for it. Linked Git worktrees use `.git` files and are intentionally skipped to avoid duplicate graphs. The discovery root itself must already be registered. Changes to this config reload the supervisor; new child repositories are discovered within five minutes by default.

### Scheduled repository wiki updates

Setup, managed-tool reconciliation, updates, and `npm run install:openwiki` install the `com.openwiki.watcher` launchd job and `~/.local/bin/openwiki-watch`. The job checks enrolled repositories at login and every 30 minutes. Installation starts with an empty list: enrollment explicitly authorizes ongoing model-backed updates for that repository. It never initializes a wiki or discovers repositories automatically.

Initialize the wiki interactively first, review `.openwikiignore` and `openwiki/INSTRUCTIONS.md`, and configure the standalone OpenWiki provider. Scheduled runs use `openwiki code --update --print` with provider configuration from local `~/.openwiki/.env`; they do not use Codex or Claude subscription authentication. Model calls may incur provider charges. Then enroll a clean main checkout:

```bash
npm run install:openwiki
openwiki-watch add /path/to/repository  # Defaults to the current Git repository
openwiki-watch list
openwiki-watch run                      # Check enrolled repositories now
openwiki-watch remove /path/to/repository
```

After syncing dotfiles and opening a new shell, run `openwiki-here` from anywhere inside a repository to enroll it, or `openwiki-here /path/to/repository` to enroll a specific checkout. This is shorthand for `openwiki-watch add` and keeps the same existing-wiki requirements.

The same commands are available from this repository as `npm run openwiki:watch -- add /path/to/repository` (or `list`, `run`, and `remove`). Enrollment is kept locally in `~/.openwiki/watcher-config.json` as `{"repositories":["/absolute/path/to/repository"]}` and survives setup and updates. `OPENWIKI_CONFIG_DIR` selects a different local state directory for both the CLI and updater; rerun installation with that variable to use it in launchd. Credentials, enrollment paths, and logs are never backed up to this repository.

Only existing wikis with `openwiki/index.md` in main Git checkouts are eligible. Linked worktrees, missing checkouts, unfinished `openwiki/.run.json` runs, and any staged, unstaged, or untracked changes cause a skip. A completed `.last-update.json` baseline at the current Git HEAD also skips execution. Updates run sequentially with an exclusive lock and a 30-minute timeout per repository. Generated wiki and instruction changes remain local for review; commit or otherwise resolve them before another scheduled update. Failed runs with partial edits require manual recovery. There is no auto-commit or push.

Inspect `~/.openwiki/watcher.log` and `~/.openwiki/watcher.err`, or `launchctl print gui/$(id -u)/com.openwiki.watcher`, for status. Removing an enrollment stops future checks for that repository; an update already running finishes. The job is idle between scheduled checks, so an idle service is expected. Installation dry-runs preview the schedule without creating files or loading launchd; `SUPERCHARGED_SKIP_LAUNCHCTL=1` writes the managed files without loading the job.

### Codex daemon startup hooks

`codex_config/hooks.json` adds two `SessionStart` command handlers for startup and resume, alongside the existing Plannotator `Stop` hook. `npm run sync -- --only codex` restores the definitions and executable `agent-daemons.sh` under the active Codex home. Each handler checks whether its installed launchd job is registered, bootstraps it if needed, and reports setup failures as advisory session context. Checks time out after 10 seconds and run independently. A loaded OpenWiki job may be idle between scheduled checks; the hook leaves that schedule alone. It does not restart a loaded graph watcher, enroll repositories, or invoke generation/indexing commands directly. Bootstrapping an unloaded job follows its normal `RunAtLoad` behavior and existing enrollment rules.

After syncing, restart Codex and use `/hooks` to review and trust the new command definitions. Codex keeps that trust state locally and skips new or changed definitions until reviewed; see the [official hook documentation](https://learn.chatgpt.com/docs/hooks#review-and-trust-hooks). The hooks use `CODEX_HOME` when set, otherwise `~/.codex`. Missing daemon installation produces a setup hint and leaves the session usable. No turn-end wiki refresh is added: the graph watcher handles file changes and OpenWiki follows its opt-in commit schedule.

## Personal Machine Baseline

The repository was audited against the personal Mac and records the reproducible portion of that machine's setup. The authoritative locations are:

| Configuration | Source of truth |
| --- | --- |
| Homebrew formulae, casks, Mac App Store apps, and VS Code extensions | `build_brewfile` in `scripts/mac.sh` |
| asdf runtimes | `dot_files/.tool-versions` |
| Shell and terminal configuration | `dot_files/` |
| Shared Claude/Codex instructions | `agent_config/AGENTS.md` |
| Managed agent-tool versions and release checksums | `agent_config/managed_tools.json` |
| Sanitized Claude Code state | `claude_config/` |
| Durable Codex defaults, permissions, MCP servers, hooks, and skills | `codex_config/` |
| Legacy Claude user-scoped MCP registry (empty by default) | `claude_config/mcp_servers.json` |
| Shared project MCP servers | `.mcp.json` and compatible entries in `codex_config/config.toml` |

Run `npm run check:mcps` to verify that every enabled base MCP server completes
the protocol initialize handshake. Use `npm run check:mcps -- --profile apple`
to include native Xcode MCP. Disabled MCPs are reported and skipped. The local
agent audit runs the same check.

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

The current Codex baseline selects `gpt-5.6-sol`, medium reasoning effort, the pragmatic personality, live web search, disabled memories, the `supercharged` permission profile, and the configured status line. Its lean tracked MCP inventory contains code-review-graph, OpenAI Developer Docs, and enabled Playwright MCP. When the ChatGPT desktop app's Computer Use plugin is installed and enabled, Codex discovers the app-managed `cua_repl` connection separately from this tracked baseline. Use `codex -p apple` for Apple’s native Xcode MCP in attached or headless mode, or `codex -p review` for xhigh review reasoning. Axiom is installed only through `npm run install:codex-plugins`, not as a duplicate MCP server. Codex asks for a one-time trust review before Axiom’s bundled hooks can run.

Run `npm run audit:agents` for a local health check, `npm run audit:agents -- --json` for machine-readable output, or `npm run audit:agents -- --repo-only` for deterministic tracked-config validation. Check native Xcode MCP with `npm run audit:agents -- --profile apple`.

The audit intentionally does not copy credentials or runtime state. Codex authentication, histories, logs, sessions, memories, databases, caches, project trust, connector state, desktop state, local approval rules, and project-specific MCP servers such as the personal Firebase entry remain machine-local. Backup and restore preserve those Firebase and runtime tables without writing them to `codex_config/config.toml`. Claude work-only marketplaces and plugins are kept in ignored `.local.json` overlays. Files under `dot_files/.secrets/` are templates only, including the `REPLICATE_API_TOKEN` placeholder.

VS Code extensions are reproduced, but VS Code user `settings.json`, `keybindings.json`, and `tasks.json` are not tracked because they can contain machine-, account-, or project-specific state. Use VS Code Settings Sync or manage sanitized copies separately when identical editor preferences are required.

To refresh the tracked agent configuration after intentionally changing the personal machine, run:

```bash
npm run backup
npm run scan:secrets
git diff --check
```

Review the diff before committing. Package inventory changes must still be made in `scripts/mac.sh`; the backup commands cover agent configuration, not Homebrew, Mac App Store, or VS Code inventories.

## Codex Desktop Access

When `INSTALL_CODEX_APP=Y`, setup installs the current ChatGPT desktop app with Homebrew cask `chatgpt`, plus CodexBar. The preference name is retained for compatibility with existing `~/.supercharged_preferences` files. Sign in with the ChatGPT account or workspace that has Codex access.

Remote access uses the host Mac's projects, credentials, plugins, MCP servers, browser setup, and local tools. Keep the host awake and online while you want remote Codex access available.

In the ChatGPT desktop app, use **Set up Remote** and follow the current [OpenAI remote connections guide](https://learn.chatgpt.com/docs/remote-connections) to make this Mac available from another device.

## Dotfiles

`npm run sync -- --only dotfiles` copies managed dotfiles from `dot_files/` to `$HOME`:

- `.zshrc`
- `.zprofile`
- `.gitconfig`
- `.gitconfig.local` is not copied from the repository; it stores machine-local identity and is included in rollback snapshots
- `.gitignore_global`
- `.p10k.zsh`
- `.tool-versions`
- `.tmux.conf`

`~/.supercharged_preferences` is generated at setup time, not tracked in `dot_files/`.

Applying `.zshrc` can remove Worktrunk's generated shell integration, so `npm run sync -- --only dotfiles` reapplies that integration when `wt` is installed. It does not apply Claude/Codex configuration or initialize code-review-graph; use `npm run sync -- --only agents` or `npm run sync` for agent configuration.

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

Edit `agent_config/AGENTS.md` for shared Claude/Codex instructions. Keep the tracked Claude user registry empty unless a compatibility requirement warrants a sanitized entry. For shared project servers, edit `.mcp.json` and add the compatible Codex entry together; put Apple-only servers in the appropriate `codex_config/apple*.config.toml` profile.

`npm run update -- --dry-run` is non-mutating: it suppresses Homebrew auto-update, reports the tap trust and retirement actions it would take, skips `brew update` and cleanup, and reports outdated Homebrew formulae, casks, and global npm packages before exiting ahead of asdf, zsh, npm, or pip updates.

Normal updates install `xcodes` only when Homebrew can use the tap's prebuilt bottle. This avoids Homebrew silently falling back to a long Swift source build on newer macOS releases after printing outdated Xcode or Command Line Tools warnings; if no usable bottle is available, the update warns and leaves `xcodes` unchanged.

## Terminal Font

Setup installs JetBrainsMono Nerd Font for the tmux/Catppuccin status bar. After install, set your terminal profile font to `JetBrainsMono Nerd Font Mono`.

For Apple Terminal, also enable Settings > Profiles > Keyboard > "Use Option as Meta key"; the tmux prefix uses `Option-Shift-T`.

If icons render as boxes:

```bash
npm run validate
ls ~/Library/Fonts/ | grep -i jetbrains
```

`npm run setup` and cask-enabled updates self-heal stale Homebrew Caskroom font installs by registering staged `.ttf` files or reinstalling the cask when its staged files are unusable.

Apple Terminal cannot render Unicode Plane 15 glyphs. The tracked `.tmux.conf` uses BMP private-use glyphs so the status bar renders in Apple Terminal, iTerm2, Ghostty, and similar terminals.

## Troubleshooting

For install failures:

```bash
tail -f .supercharged_install.log
npm run rollback
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
npm run rollback
```

This restores from the latest backup recorded by the setup scripts.
