# Reference

This is the canonical user-facing guide for setup behavior, synchronization boundaries, customization, and recovery. `README.md` stays introductory, `AGENTS.md` contains contributor/agent conventions, and `SECURITY.md` owns security policy. Dynamic inventories remain in their executable manifests rather than being copied here.

## Commands

```bash
npm run help   # Canonical complete command inventory
npm run setup  # Fresh install
npm run sync   # Apply managed configuration
npm run update # Update the managed environment
```

`npm run help` is the complete command list; this reference documents behavior and boundaries.

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

The repository deliberately keeps inventory in machine-readable sources:

| Inventory | Authoritative source |
| --- | --- |
| Homebrew formulae, casks, Mac App Store apps, fonts, and VS Code extensions | `build_brewfile` in `scripts/mac.sh` |
| asdf runtimes | `dot_files/.tool-versions` |
| Exact-pinned agent tools and compatibility floors | `agent_config/managed_tools.json` |
| Shared skills CLI catalog | `agent_config/installed_skills.json` |
| Claude native plugins | `claude_config/*.json` |
| MCP servers and profiles | `.mcp.json`, `claude_config/mcp_servers.json` and `codex_config/*.toml` |

Use `npm run help` for reconciliation commands, `npm run check:agent-tooling` for the composed agent inventory, and `npm run audit:agents -- --repo-only` for deterministic tracked-configuration validation.

The base Homebrew setup installs `ast-grep` for syntax-aware code searches. To add it to an existing machine, run `brew install ast-grep`.

The iOS tools group includes `asccli` (the `asc` command) for App Store Connect automation.

Conditional Brewfile groups add iOS, container, cloud, network, and extra application tooling according to the setup preferences above. Dedicated setup helpers reconcile exact-pinned agent tools after the managed runtimes are available. Release archives verify architecture-specific SHA-256 values, and managed-tool reconciliation retires known obsolete MCP installations. Use the dedicated install commands shown by `npm run help`; add `-- --dry-run` to inspect drift.

As part of the profile migration, `npm run sync -- --only codex` treats a local `~/.codex/apple-headless.config.toml` as restore drift even when normal timestamp gating would otherwise skip the restore. The command first preserves the retired profile in its rollback snapshot, then removes it; use `codex -p apple` afterward.

asdf-managed tools are listed in `dot_files/.tool-versions`, including Node.js, Python, Ruby, Bundler, gcloud, and optional JVM pins. Firebase CLI is pinned as `firebase-tools` in `agent_config/managed_tools.json` and installed through the selected Node.js runtime when cloud tools are enabled. Setup removes the retired asdf Firebase plugin after npm installation succeeds so its Intel-only shim cannot mask the working CLI. Run `npm run install:firebase` to reconcile Firebase separately.

Claude Code configuration is backed up under `claude_config/`. Codex configuration is backed up under `codex_config/`. Shared cross-agent instructions live in `agent_config/AGENTS.md`.

### Shared skills and migration

`npm run install:skills` stages the catalog using the exact-pinned npx skills CLI. Git sources use full commits and an optional subdirectory and skill selection. The shared catalog excludes Kinetic’s App Store Connect skill. Per-repository agent instructions cover PR workflow. The four local graph skills encode this repository’s graph freshness conventions. Plannotator’s pinned upstream skills include the bundled goal interview workflow. Cloudflare uses the complete pinned collection. Axiom uses its auditor-as-skill distribution for both agents. Use standalone skill names in place of native plugin-prefixed names. Removing the Axiom plugin also retires its automatic session hints and Swift edit hooks. Its reference files, auditor skills and standalone MCP server are available after migration. Firebase’s Firestore rules skill uses its documented direct-authoring path when the native `firestore-rules-author` subagent is absent.

The installer publishes verified releases under `~/.local/share/supercharged/skills`. Claude discovers links in `~/.claude/skills`; Codex discovers them in `~/.agents/skills`, which other universal agents may also read. Use `-- --harness claude|codex|both` or `-- --dry-run`. Ignored `installed_skills.local.json` entries override tracked entries by collection key. Retirement records take precedence. Identical inputs reuse the release; a missing discovery link is repaired.

For a previously configured Mac, run `npm run migrate:skills -- --dry-run` and review the listed local skills, MCP registrations, and native plugins. Then run `npm run migrate:skills` from the default agent homes. It snapshots settings and skill directories, archives recognized older copies, checks native discovery and MCP initialization, and retires the superseded user plugins. An unfamiliar same-name directory requires review before replacement. Unrelated local skills, language servers, host plugins, and project Firebase MCP definitions remain independently owned.

Recover a migration with `npm run rollback -- <snapshot-path>` using the path printed before changes. Native plugin caches are excluded from configuration snapshots; reinstall a retired native plugin at its previous pin if reverting after its uninstall. For a skill-only reconciliation, `scripts/install-skills.sh --rollback <journal-directory>` reverses that link transaction. Keep release directories referenced by rollback snapshots. Run `npm run check:skills` to verify the catalog links and discovery in fresh sessions for both agents.

OpenWiki is installed as the exact-pinned `openwiki` CLI. The shared catalog installs its skill and each agent has its own explicit MCP host argument. These integrations use the agent's authenticated session and need no separate model provider configuration. From a repository root, ask the integrated agent to initialize or update its wiki when wanted. The standalone `openwiki --init` and `openwiki --update` commands remain available; their interactive first run stores the selected provider and credentials in `~/.openwiki/.env`, which is local-only and must never be committed or backed up. Before generation, review `.openwikiignore` to exclude sensitive or irrelevant source paths. OpenWiki writes `openwiki/` and maintains marked guidance blocks in root `AGENTS.md` and `CLAUDE.md`; other content remains user-managed. For a concrete question, an integrated agent can use `openwiki_search` and `openwiki_read` to retrieve relevant sections, or read `openwiki/quickstart.md` and linked pages directly. An existing wiki is optional secondary context: corroborate material claims against current source, tests, and a fresh code-review-graph, report conflicts as stale documentation, and treat source and tests as authoritative. Agents do not generate or update a wiki without an explicit user request, including explicit enrollment in the scheduled repository updater described below.

The tracked MCP inventory is defined by `.mcp.json`, `claude_config/mcp_servers.json`, `codex_config/config.toml`, and the profile TOML files; `npm run check:agent-tooling` verifies parity. Computer Use is app-managed rather than a tracked standalone MCP entry. Claude user-local MCP entries are preserved during restore and never imported by backup. Local executables are exact-pinned where this repository controls installation; hosted and platform-native servers follow their respective providers.

Use `codex -p apple` for both native Xcode MCP modes. Xcode 26.3 through 26.x requires Xcode.app running with a project open and external-agent access enabled in Xcode’s Intelligence settings. Xcode 27+ can also run headlessly after a one-time `sudo xcrun mcp-server enable`; start it with `xcrun mcp-server start`. Do not enable the unsafe allow-all-agents option: opening or creating a workspace triggers Apple’s normal agent and folder approval flow.

`npm run install:agent-tooling -- --dry-run` previews the skills, MCP registrations and native plugins. Run `npm run install:agent-tooling` to apply them. Use `-- --harness claude` or `-- --harness codex` to select one agent. Setup checks for conflicting server names before installing tools or skills, skips matching registrations, and preserves unrelated local settings. Existing machines with the old Axiom or Firebase plugins use `npm run migrate:skills` first. Both commands use the same MCP registration code. Plugin removal takes place only during migration.

| Scope | Tracked source | Availability |
| --- | --- | --- |
| Claude project | `.mcp.json` | code-review-graph and OpenAI Developer Docs when this repository is open and approved |
| Claude user | `claude_config/mcp_servers.json` | Axiom, Cloudflare over HTTP, Firebase, OpenWiki and headless Playwright across projects |
| Claude iOS tools | `claude_config/apple.mcp_servers.json` | Native Xcode at user scope when `INSTALL_IOS_TOOLS=Y` is selected in the environment or saved setup preferences |
| Codex base | `codex_config/config.toml` | Shared servers and their Codex tool approval settings |
| Codex Apple profile | `codex_config/apple.config.toml` | Native Xcode with `codex -p apple` |

Registration and login are separate steps. Use the agent’s MCP interface to authorize Cloudflare when prompted. `npm run check:agent-tooling` checks configuration parity. `claude mcp list` reports the local Claude connection status.

The standalone configuration audit and MCP/tooling check commands require Python 3.11+ for the standard-library `tomllib` parser. Fresh setup installs the managed Python before final audits.

Pin updates follow the personal machine. Run `npm run update:tool-pins` or `npm run update:asdf-pins` to inspect upstream candidates without changing tracked files. Install and validate the chosen versions on this machine, then run `npm run promote:pins` to preview the resulting pin changes and `npm run promote:pins -- --apply` to write them. Use `-- --only asdf` or `-- --only agents` to limit promotion. The promoter reads active, installed asdf versions within `agent_config/asdf_policy.json`, global npm package versions (including Firebase CLI), and installed agent CLI versions; release binaries must match published checksums, and the Firebase command must run at its installed package version. Missing tools are skipped. Skill source commits and Codex, Claude, and Worktrunk compatibility versions remain manual after local validation. CI checks repository changes but never proposes new pins.

Version and checksum policy is authoritative in `agent_config/managed_tools.json`, `agent_config/installed_skills.json`, and the harness plugin registries. The audit and tooling checker validate those manifests; prose should describe the workflow without copying their inventories.

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

Review `.openwikiignore` and any `openwiki/INSTRUCTIONS.md` scope brief before initialization. `openwiki-here` initializes a missing wiki interactively and then enrolls the repository. The first run can configure the standalone OpenWiki provider. Scheduled runs use `openwiki code --update --print` with provider configuration from local `~/.openwiki/.env`; they do not use Codex or Claude subscription authentication. Model calls may incur provider charges. To enroll an already initialized wiki directly:

```bash
npm run install:openwiki
openwiki-watch add /path/to/repository  # Defaults to the current Git repository
openwiki-watch list
openwiki-watch run                      # Check enrolled repositories now
openwiki-watch remove /path/to/repository
```

After syncing dotfiles and opening a new shell, run `openwiki-here` from anywhere inside a repository, or `openwiki-here /path/to/repository` for a specific checkout. If `openwiki/index.md` is missing, the helper runs `openwiki --init` interactively from the repository root, then calls `openwiki-watch add` after successful generation. Existing wikis are enrolled without regeneration. Failed or unfinished generation is not enrolled; finish it manually and rerun the helper. Review and commit generated wiki and instruction changes so the checkout becomes eligible for scheduled updates. Linked worktrees are rejected before initialization.

The same commands are available from this repository as `npm run openwiki:watch -- add /path/to/repository` (or `list`, `run`, and `remove`). Enrollment is kept locally in `~/.openwiki/watcher-config.json` as `{"repositories":["/absolute/path/to/repository"]}` and survives setup and updates. `OPENWIKI_CONFIG_DIR` selects a different local state directory for both the CLI and updater; rerun installation with that variable to use it in launchd. Credentials, enrollment paths, and logs are never backed up to this repository.

Only existing wikis with `openwiki/index.md` in main Git checkouts are eligible. Linked worktrees, missing checkouts, unfinished `openwiki/.run.json` runs, and any staged, unstaged, or untracked changes cause a skip. A completed `.last-update.json` baseline at the current Git HEAD also skips execution. Updates run sequentially with an exclusive lock and a 30-minute timeout per repository. Generated wiki and instruction changes remain local for review; commit or otherwise resolve them before another scheduled update. Failed runs with partial edits require manual recovery. There is no auto-commit or push.

Inspect `~/.openwiki/watcher.log` and `~/.openwiki/watcher.err`, or `launchctl print gui/$(id -u)/com.openwiki.watcher`, for status. Removing an enrollment stops future checks for that repository; an update already running finishes. The job is idle between scheduled checks, so an idle service is expected. Installation dry-runs preview the schedule without creating files or loading launchd; `SUPERCHARGED_SKIP_LAUNCHCTL=1` writes the managed files without loading the job.

### Codex daemon startup hooks

`codex_config/hooks.json` adds two `SessionStart` command handlers for startup and resume, alongside the existing Plannotator `Stop` hook. `npm run sync -- --only codex` restores the definitions and executable `agent-daemons.sh` under the active Codex home. Each handler checks whether its installed launchd job is registered, bootstraps it if needed, and reports setup failures as advisory session context. Checks time out after 10 seconds and run independently. A loaded OpenWiki job may be idle between scheduled checks; the hook leaves that schedule alone. It does not restart a loaded graph watcher, enroll repositories, or invoke generation/indexing commands directly. Bootstrapping an unloaded job follows its normal `RunAtLoad` behavior and existing enrollment rules.

After syncing, restart Codex and use `/hooks` to review and trust the new command definitions. Codex keeps that trust state locally and skips new or changed definitions until reviewed; see the [official hook documentation](https://learn.chatgpt.com/docs/hooks#review-and-trust-hooks). The hooks use `CODEX_HOME` when set, otherwise `~/.codex`. Missing daemon installation produces a setup hint and leaves the session usable. No turn-end wiki refresh is added: the graph watcher handles file changes and OpenWiki follows its opt-in commit schedule.

## Personal Machine Baseline

The repository records only the reproducible portion of the audited personal Mac. Package and agent inventories use the authoritative sources listed under [Installed Tools](#installed-tools); shell configuration lives in `dot_files/`, shared instructions in `agent_config/`, and sanitized harness state in `claude_config/` and `codex_config/`.

Run `npm run check:mcps` to verify that every enabled base MCP server completes
the protocol initialize handshake. Use `npm run check:mcps -- --profile apple`
to include native Xcode MCP. Disabled MCPs are reported and skipped. The local
agent audit runs the same check. To inspect the installed configuration rather
than the tracked baseline, run `npm run check:mcps -- --config-dir "$HOME/.codex"`.
The checker reports missing `env_vars` by name before launching a stdio server;
it never substitutes fabricated app connection values.

If Codex reports `MCP tool call requires approval, but approval policy is never`,
check the active session policy as well as the saved configuration. The tracked
baseline uses `on-request`; a session or CLI override can still select `never`,
which rejects required approvals instead of prompting. Restart with
`codex --ask-for-approval on-request` (add `-p apple` for Xcode). Do not broadly
approve tools to work around the session policy. See the
[Codex approval documentation](https://learn.chatgpt.com/docs/agent-approvals-security).

Run `npm run sync -- --only codex --force` to reapply the tracked baseline and
profiles when local settings have drifted. Restore detects retired manual Node
REPL and Computer Use tables even when local config has a newer timestamp,
backs up the previous configuration, and removes those tables while preserving
supported machine-local state. Browser connection variables belong to the
app-managed integration. The Apple profile supplies `xcrun mcpbridge`; use the
profile rather than maintaining a duplicate Xcode entry in the base config.

The Codex baseline and profiles are defined in `codex_config/config.toml` and `codex_config/*.config.toml`; do not duplicate model names or MCP inventories in prose. Use `codex -p apple` for Apple’s native Xcode MCP profile and `codex -p review` for the review profile. Computer Use remains app-managed, while Axiom and Firebase use the shared skill catalog.

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

### Standalone MCP servers

Claude user MCP definitions live in `claude_config/mcp_servers.json`; Codex has corresponding entries in its base TOML. Axiom uses the pinned axiom-mcp package. Firebase’s standalone MCP registration is named `firebase-tools` and uses a separate package pin from the host Firebase CLI. Project selection follows the launch directory. OpenWiki receives the host-specific argument for Claude or Codex. Restore manages these registrations; skill installation does not enroll repositories, initialize wikis or copy authentication state.

## Codex Desktop Access

When `INSTALL_CODEX_APP=Y`, setup installs the current ChatGPT desktop app with Homebrew cask `chatgpt`, plus CodexBar. The preference name is retained for compatibility with existing `~/.supercharged_preferences` files. Sign in with the ChatGPT account or workspace that has Codex access.

Remote access uses the host Mac's projects, credentials, plugins, MCP servers, browser setup, and local tools. Keep the host awake and online while you want remote Codex access available.

In the ChatGPT desktop app, use **Set up Remote** and follow the current [OpenAI remote connections guide](https://learn.chatgpt.com/docs/remote-connections) to make this Mac available from another device.

## Dotfiles

`npm run sync -- --only dotfiles` copies the files declared by `MANAGED_DOTFILES` in `scripts/utils.sh` from `dot_files/` to `$HOME`. Machine-local `.gitconfig.local` is not copied from the repository, but it is included in rollback snapshots.

`~/.supercharged_preferences` is generated at setup time, not tracked in `dot_files/`.

Applying `.zshrc` can remove Worktrunk's generated shell integration, so `npm run sync -- --only dotfiles` reapplies that integration when `wt` is installed. It does not apply Claude/Codex configuration or initialize code-review-graph; use `npm run sync -- --only agents` or `npm run sync` for agent configuration.

Secret templates live under `dot_files/.secrets/`, but real secrets are machine-local. Create `~/.secrets` or `~/.secrets/*.sh` locally when Claude restore or shell startup needs sensitive environment variables.

## Shell Setup

The repository assumes Oh My Zsh is already installed. Install it first if needed:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

Oh My Zsh plugin selection is defined in `dot_files/.zshrc`.

Useful shell additions include:

- PATH deduplication.
- Secure SSH key loading through `keychain`.
- Shared zsh history.
- Navigation, Git, Docker, Kubernetes, Python, and macOS aliases.
- Utility functions: `mkcd`, `extract`, `gpus`, `gpul`, and `docker-clean`. The enabled Oh My Zsh Git plugin provides `gb` (list branches) and `gcb <name>` (create and check out a branch).
- Optional Colima auto-start via `SUPERCHARGED_COLIMA_AUTOSTART=1` in `~/.secrets`.

## Customization

Edit `dot_files/.tool-versions` to change asdf-managed tool versions. Do not duplicate those versions in docs; they drift quickly.

Edit `scripts/mac.sh` to change Homebrew packages. Conditional package groups are controlled by the setup preferences above.

Edit `dot_files/.zshrc`, `dot_files/.tmux.conf`, and `dot_files/.p10k.zsh` for shell, tmux, and prompt behavior.

Edit `agent_config/AGENTS.md` for shared Claude/Codex instructions. Edit `claude_config/mcp_servers.json` for repository-managed user-scoped Claude servers and add the compatible entry to the Codex base config. For shared project servers, edit `.mcp.json` and add the compatible Codex entry together; put Apple-only servers in the appropriate `codex_config/apple*.config.toml` profile.

`npm run update -- --dry-run` is non-mutating: it suppresses Homebrew auto-update, reports the tap trust and retirement actions it would take, skips `brew update` and cleanup, and reports outdated Homebrew formulae, casks, and unpinned global npm packages before exiting ahead of asdf, zsh, npm, or pip updates.

Every normal update first syncs dotfiles, updates the selected dependency components, then performs one complete agent-tooling reconciliation. `--only` limits dependency updates only; it does not skip dotfile sync or final tooling reconciliation. Exact-pinned npm packages are excluded from generic npm upgrades and are reconciled by the managed-tool installer.

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
