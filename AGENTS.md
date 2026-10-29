# AGENTS.md

macOS environment setup automation — installs dev tools (Homebrew, ASDF), manages dotfiles, and backs up Claude Code configuration.

This file is the canonical reference for AI agents and contributors. See [README.md](./README.md) for quick start, [docs/REFERENCE.md](./docs/REFERENCE.md) for user-facing setup details, and [SECURITY.md](./SECURITY.md) for security policy.

## Project Structure

See [README.md](./README.md) and [docs/REFERENCE.md](./docs/REFERENCE.md) for user-facing setup details. Key directories:
- `scripts/` - Shell scripts (mac.sh, update-all.sh, update.sh, sync.sh, rollback.sh, utils.sh, setup-profile.sh, help.sh, install-plugins.sh; backup-claude.sh/restore-claude.sh for Claude config)
- `dot_files/` - Dotfiles copied to `$HOME`
- `claude_config/` - Claude Code config backup
- `agent_config/` - Shared global instructions, managed agent-tool pins, and canonical graph skill directories restored to Codex
- `codex_config/` - Codex CLI/IDE config backup

## Code Conventions

- **Logging**: Use `log_with_level "INFO|WARN|ERROR|SUCCESS" "message"` from `utils.sh`
- **Error handling**: Include `trap cleanup EXIT` in scripts
- **Tests**: BATS (Bash Automated Testing System); test files in `tests/`; use `setup_test_env` + `teardown_test_env`
- **Testing workflow**: Add BATS tests in `tests/<script-name>/` for new script features; run `npm test` before committing script changes
- **Commits**: Conventional format preferred (not enforced). Scope optional.
  - Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `build`, `ci`, `revert`, `wip`, `update`, `add`, `remove`
  - Examples: `feat(backup): add new feature`, `fix(restore): handle edge case`, `chore(deps): bump versions`
- **Shell scripts**: Written for zsh; ShellCheck `--shell=bash` flags (SC1071, SC2296) are safe to ignore
- **Dotfiles**: Use env vars, no hardcoded paths

## Shared Agent Capabilities

**Skills**:
- Shared graph skills live canonically in `agent_config/skills/<name>/SKILL.md`.
- `npm run sync -- --only codex` restores those directories directly into `~/.codex/skills/`.
- Tool-specific or unsupported skills stay in the tool-specific config (`claude_config/` or `codex_config/skills/`) instead of being forced into the shared path.

**Knowledge and graph tooling**:
- [code-review-graph](https://github.com/tirth8205/code-review-graph) is the preferred live-source layer for navigation, impact analysis, debugging, and review when its graph is current and covers the code in question. Shared selection and freshness rules live in `agent_config/AGENTS.md`; the graph-backed skills live in `agent_config/skills/`.
- [OpenWiki](https://github.com/langchain-ai/openwiki) is an opt-in repository knowledge layer for architecture, terminology, invariants, and intended workflows. Agents use an existing `openwiki/` as secondary context, verify material claims against current source and tests, and do not initialize or update it without an explicit user request.
- Both CLIs are exact-pinned in `agent_config/managed_tools.json` and reconciled by `npm run install:agent-tooling`. OpenWiki coding-agent integrations use the agent's authenticated session; the opt-in `openwiki-watch` launchd updater uses standalone CLI provider configuration, and credentials remain machine-local in `~/.openwiki/.env`.

**MCP servers**:
- Keep repo-managed user-scoped Claude MCP servers in `claude_config/mcp_servers.json` and compatible Codex entries in `codex_config/config.toml`; backup never imports live user MCP definitions into the tracked registry.
- Keep shared project MCP support in `.mcp.json` for Claude/project clients and in `codex_config/config.toml` for Codex.
- When adding an MCP server that both tools support, add the equivalent entry to both places and document any command differences.
- If Codex does not support a Claude MCP server, leave it in the Claude-specific config and do not add a stub Codex entry.

**Token optimization**:
- Claude output guidance is restored through `claude_config/CLAUDE-TOKEN-EFFICIENT.md`, referenced by `claude_config/CLAUDE.md`.

## Commands

Run `npm run help` for the canonical complete command inventory. Keep detailed behavior and selector boundaries in [docs/REFERENCE.md](./docs/REFERENCE.md); do not duplicate the inventory here.

## ShellCheck Notes

**Safe warnings** (zsh scripts run through `--shell=bash`):
SC1071 (zsh unsupported), SC2296 (zsh `${(%):-%x}`), SC1091 (dynamic sources), SC2001 (intentional sed), SC2329 (BATS/mock callbacks), and SC2016 (intentional literals) are disabled centrally in `.shellcheckrc`. Also safe but not disabled: SC2155 (declare+assign), SC2012 (ls vs find).

`npm run lint` runs ShellCheck with `--severity=info`; suppressions are maintained only in `.shellcheckrc`.

**Zsh-specific syntax** used in scripts:
`${(%):-%x}`, `${(%):-%n}`, `&!` (disown), `path=(...)`, `setopt`.

## Testing

### BATS Testing Infrastructure

This project uses [BATS (Bash Automated Testing System)](https://github.com/bats-core/bats-core) for testing shell scripts.

**Running tests:**
```bash
npm test                          # Run all BATS tests
bats tests/claude/*.bats          # Claude backup/restore tests
bats tests/utils/*.bats           # Utility function tests
bats tests/mac/*.bats             # mac.sh smoke tests
bats tests/update/*.bats          # update.sh smoke tests
bats tests/setup/*.bats           # setup-profile.sh smoke tests
npm test -- --filter "pattern"    # Run specific tests
```

**Test structure:**
- `tests/claude/backup.bats` - Tests for Claude Code backup sanitization
- `tests/claude/restore.bats` - Tests for Claude Code restore merging
- `tests/claude/install-skills.bats` - Tests shared skill install/update and safe retired-skill pruning
- `tests/codex/codex.bats` - Tests Codex backup/restore filtering, hooks, rules, and skill mirroring
- `tests/utils/portability.bats` - Tests for portable path handling
- `tests/utils/tools.bats` - Tests for `setup_*` helpers in `scripts/utils/tools.sh`
- `tests/utils/validate.bats` - Tests for validation helpers in `scripts/utils/validation.sh`
- `tests/mac/install.bats` - Smoke tests for mac.sh (validate_system, build_brewfile, install_homebrew, parse_tool_versions)
- `tests/setup/profile.bats` - Smoke tests for setup-profile.sh (dotfile copying, restoration points, version_gte)
- `tests/update/update.bats` - Smoke tests for update.sh (argument parsing, help, dry-run, unknown flags)
- `tests/meta/help.bats` - Tests for help.sh output (includes drift check against `package.json` scripts)
- `tests/meta/lint.bats` - Tests for ShellCheck lint script (validates `.shellcheckrc` rule set)
- `tests/meta/secrets.bats` - Tests repository secret-scanner detection and exclusions
- `tests/openwiki/watcher.bats` - Tests explicit OpenWiki enrollment, update guards, locking, timeout, and launchd setup
- `tests/openwiki/here.bats` - Tests interactive wiki initialization and enrollment through `openwiki-here`
- `tests/restore/restore.bats` - Tests for rollback.sh and configuration snapshot restoration
- `tests/install-plugins/install-plugins.bats` - Smoke tests for `install-plugins.sh` (dry-run, prerequisites, arg parsing)
- `tests/restore-claude/restore-claude.bats` - Smoke tests for `restore-claude.sh` helpers (`get_file_mtime`, `get_newest_mtime`)
- `tests/helpers/setup.bash` - Test environment setup and teardown utilities
- `tests/helpers/assertions.bash` - jq-based JSON assertion utilities
- `tests/helpers/mocks.bash` - Command mocking utilities
- `tests/fixtures/` - Test data (JSON configs with `$HOME` placeholders)

**Key test patterns:**
- Use `setup()` for test initialization (calls `setup_test_env`)
- Use `teardown()` for cleanup (calls `teardown_test_env`)
- Load helpers: `load '../helpers/setup'`, `load '../helpers/assertions'`, `load '../helpers/mocks'`
- Test environment creates isolated temp directories with mocked `$HOME`
- Fixtures use `$HOME` placeholders, not hardcoded paths
- JSON assertions: `assert_json_field`, `assert_json_equals`
- Domain assertions: `assert_plugin_exists`, `assert_plugin_not_exists`, `assert_marketplace_exists`, `assert_marketplace_not_exists`
- Zsh-only functions tested via `run zsh -c "source script; function_call"` subprocess pattern
- PATH-based mocking with `MOCK_BIN_DIR` for zsh subprocesses (bash `export -f` doesn't propagate to zsh)

**CI integration:**
ShellCheck, secret scanning, and BATS tests run on push to main and pull requests via `.github/workflows/test.yml`.

### Manual Testing Workflows

**Pre-commit**:
1. `shellcheck --shell=bash scripts/*.sh`
2. `npm run scan:secrets`
3. Test script functions in isolation
4. Verify logging matches existing patterns

**Manual workflow**:
1. `npm run sync` to restore agent configuration and dotfiles
2. `source ~/.zshrc` — verify no errors
3. `npm run validate` — check installations
4. If issues: `npm run rollback`

**Validation checks** (from `utils.sh`):
Homebrew in PATH, ASDF plugins present, tool versions match `.tool-versions`, ZSH plugins cloned, dotfiles in `$HOME`, Claude Code config restored.

## Code Patterns

**User prompts** — follow existing interactive pattern:
```bash
read -rp "Install iOS Tools? [Y/n]: " response
response=${response:-Y}
if [[ "$response" =~ ^[Yy] ]]; then
    export INSTALL_IOS_TOOLS=Y
fi
```

**Version parsing** from `.tool-versions`:
```bash
python_version=$(awk '/python/{print $2}' "$TOOL_VERSIONS_FILE")
```

**Claude Code backup/restore** (`scripts/backup-claude.sh`, `scripts/restore-claude.sh`):
- Portable paths: `$HOME` placeholder for cross-machine compatibility
- Sanitization: work-related marketplaces (e.g., `vend-plugins`) excluded
- Merge logic: restore preserves local work plugins while applying repo settings
- Timestamp comparison: only restores when repo config is newer (unless `--force`)
- Secrets: `~/.secrets` is sourced once at restore start (single file, or every `*.sh` in a `~/.secrets/` directory — non-shell files like GCP JSON are ignored by the loader); an MCP server with an unresolved environment placeholder is skipped as a unit while secret-free servers still restore
- **Backed up files**: `settings.json`, `installed_plugins.json`, `known_marketplaces.json`, `CLAUDE.md`, plus any `*.md` files referenced from `CLAUDE.md` via `@filename` (e.g. `CRG.md`, `WORKTRUNK.md`, `PLANNOTATOR.md`, `CLAUDE-TOKEN-EFFICIENT.md`) — auto-detected
- **Managed MCP registry**: `claude_config/mcp_servers.json` is restored to user scope but is not populated from live `~/.claude.json`; edit it intentionally so credentials and machine-specific paths cannot enter through backup
- **Local-only configs**: Work plugins/marketplaces are saved to `.local.json` files (gitignored) during backup, and merged back during install
- **Post-sync**: Plugins are auto-installed when Claude config is applied. If auto-install fails, run `npm run install:plugins` manually.

**Codex backup/restore** (`scripts/backup-codex.sh`, `scripts/restore-codex.sh`):
- Shared instructions: `agent_config/AGENTS.md` is restored to both `~/.codex/AGENTS.md` and `~/.claude/AGENTS.md`
- Codex settings: `codex_config/config.toml` restores lean durable defaults such as model, personality, live web search, disabled memories, base MCP settings, hook enablement, instruction discovery, and a permission profile that denies `.env*`/`.secrets` paths; `apple.config.toml` provides native Xcode MCP for attached and headless use with `codex -p apple`, while `review.config.toml` provides the `codex -p review` overlay
- Codex hooks and skills: `codex_config/hooks.json`, `codex_config/hooks/`, and `codex_config/skills/plannotator-*` restore the Plannotator Stop hook, advisory SessionStart checks for both installed launchd daemons, and skills. New hook definitions require local `/hooks` trust review; the daemon hooks preserve existing registration and enrollment policies.
- Codex plugins: `codex_config/plugins.json` is a sanitized desired-state registry; `npm run install:codex-plugins` uses the Codex CLI to manage Axiom while marketplace snapshots, plugin caches, credentials, and hook trust state stay local
- Managed tools: `agent_config/managed_tools.json` exact-pins local release/PyPI/npm tools—including Firebase CLI, code-review-graph, and OpenWiki—and records tested compatibility floors; Firebase CLI is installed from npm when cloud tools are enabled, while gcloud remains on asdf; code-review-graph stays current through its launchd watcher and explicit audits; Axiom and shared git skills use immutable commits; pin changes are promoted from validated personal-machine installations
- Codex rules: `codex_config/rules/*.rules` restores repo-managed command deny rules that mirror the Claude hard-deny list where Codex prefix rules can express it; local approval rules in `~/.codex/rules/default.rules` remain local
- Shared git skills: `agent_config/installed_skills.json` is installed into both `~/.claude/skills/*` and `~/.codex/skills/*` by `npm run install:skills`
- Shared graph skills: `agent_config/skills/<name>/SKILL.md` is the canonical source; `npm run sync -- --only codex` applies those directories directly to Codex
- Local-only state excluded: `auth.json`, history, logs, sessions, memories, SQLite databases, shell snapshots, and model caches
- Machine-local tables preserved on restore include `[projects.*]`, `[tui.model_availability_nux]`, `[notice*]`, `[hooks.state*]`, `[desktop]`, marketplace/plugin/connector tables, and plugin-provided MCP tables
- Profile migration: the Codex sync preserves a stale `~/.codex/apple-headless.config.toml` in the pre-sync snapshot, removes it locally, and directs users to `codex -p apple`
- Project guidance: keep repo-specific behavior in `AGENTS.md`; keep cross-agent global preferences in `agent_config/AGENTS.md`

For Apple-platform work, prefer native Xcode MCP tools for Xcode, Swift, simulator, device, build, test, preview, and debugging tasks when configured and available. Xcode 26.3+ supports attached mode; Xcode 27+ also supports headless mode through the same `codex -p apple` profile.

**Post-Sync Steps** (after `npm run sync -- --only claude` or `npm run sync -- --only claude --force`):
1. Enable work plugins (@vend-plugins) manually if on work machine — these are sanitized from backups for security
2. Run `/reload-plugins` in Claude Code to force registry rescan if plugins don't appear
3. Verify with `/help` that skills and agents are available

Plugins are auto-installed during sync. `install:plugins` merges repo configs with `.local.json` files (work plugins/marketplaces), so work-specific configs survive across machines without being committed.

**Script organization**:
- `mac.sh`: validate system → Homebrew → Brewfile (conditional on user prefs) → ZSH plugins → ASDF → optional tools
- `utils.sh`: thin loader sourcing submodules from `utils/` (logging, backup, validation, tools, json)
- `utils/`: focused submodules — no side effects on import
- `.tool-versions`: one tool per line (`<plugin> <version>`), grouped by category

## Adding New Tools

**Homebrew package**: Edit `BREWFILE_CONTENT` in `scripts/mac.sh`, add `brew "name"` or `cask "name"` to the appropriate conditional section. Update `docs/REFERENCE.md` if the user-facing installed-tool set changes.

**ASDF tool**: Add `toolname version` to `dot_files/.tool-versions`. Add `install_asdf_plugin` and `install_asdf_version` calls in `scripts/mac.sh`. Keep docs pointed at `.tool-versions` instead of duplicating pinned versions.

**Optional category**: Follow `INSTALL_IOS_TOOLS` pattern — add prompt in `utils.sh:setup_user_preferences()`, save to `~/.supercharged_preferences`, use conditional in `mac.sh`. Update `docs/REFERENCE.md`.

**Update tool version**: Edit `dot_files/.tool-versions`, check changelog for breaking changes, test with `asdf install <tool> <version>`, run `asdf reshim`, validate with `npm run validate`.

## Common Tasks

| Task | Where |
|---|---|
| Add ZSH alias | `dot_files/.zshrc` aliases section |
| Onboard a repo to code-review-graph | `cd <repo> && crg-here` (registers + builds; the launchd watcher picks it up automatically). For opt-in nested-repo discovery, configure `~/.code-review-graph/watcher-config.json`. |
| Refresh a stale code-review-graph graph | From the repository, run `code-review-graph update`; use `code-review-graph status` to check availability and freshness first. |
| Initialize or refresh OpenWiki | Only when explicitly requested, use an installed coding-agent integration or run standalone `openwiki --init`/`openwiki --update` from the target repository; review `.openwikiignore`, generated `openwiki/` content, and managed instruction blocks before committing. |
| Add Homebrew tap | `BREWFILE_CONTENT` in `scripts/mac.sh`: `tap "owner/repo"` before packages |
| Change log format | `log_with_level()` in `scripts/utils/logging.sh` (preserve timestamp + level) |
| Add utility function | Appropriate file in `scripts/utils/` (logging, backup, validation, tools, json) |
| Add backup file | `create_restoration_point()` in `scripts/utils/backup.sh` |
| Update Claude sanitization | `SANITIZE_MARKETPLACES` in `backup-claude.sh`, `PRESERVE_MARKETPLACES` in `restore-claude.sh`; sanitized entries auto-saved to `.local.json` files |
| Add Claude backup file | Add backup/restore logic in `backup-claude.sh` and `restore-claude.sh` (follow `keybindings.json` pattern) |
| Update shared agent instructions | Edit `agent_config/AGENTS.md`, then run `npm run sync -- --only agents` |
| Update Codex defaults | Edit `codex_config/config.toml`, then run `npm run sync -- --only codex` |
| Update Codex command deny rules | Edit `codex_config/rules/*.rules`, then run `npm run sync -- --only codex` |
| Update managed agent-tool pins | Install and validate locally, run `npm run promote:pins`, then `npm run promote:pins -- --apply` and review the diff |
| Add shared project skill rule | Create/edit `agent_config/skills/<name>/SKILL.md`, then run `npm run sync -- --only codex` |
| Add shared MCP server | Add compatible entries to `.mcp.json` and `codex_config/config.toml`; skip Codex if unsupported |
| Update security policy | Edit `SECURITY.md`, `scripts/scan-secrets.sh`, `codex_config/rules/*.rules`, or `codex_config/hooks/` as appropriate |
| Test security checks | Run `npm run lint`, `npm run scan:secrets`, and `npm test` |

## PR Checklist

**This repository is used on personal AND work machines** — comprehensive security enforced.

**Automated checks**: CI runs lint, secret scan, and BATS. Codex command rules and hooks are tracked under `codex_config/`. Claude plugin configuration is restored from `claude_config/`. See [SECURITY.md](./SECURITY.md) for details.

**Key rules**:
- Never commit real secrets; only templates under `dot_files/.secrets/` belong in the repo
- No hardcoded paths in dotfiles (use `$HOME`, not `/Users/username/`)
- Shellcheck is required for `npm run lint` (`brew install shellcheck`)
- Claude backups sanitized (work marketplaces excluded)
- Do not bypass hooks or policy checks with `--no-verify`

**Conventional commits** (preferred, not enforced): `feat(scripts):`, `fix(zsh):`, `docs(readme):`, `chore(deps):`.

**PR checklist**:
- [ ] Validation passed (`npm run lint`, `npm run scan:secrets`, and relevant BATS tests)
- [ ] README.md or `docs/REFERENCE.md` updated if user-facing behavior changed
- [ ] Logging follows `log_with_level` pattern
- [ ] No hardcoded paths (use `$HOME`)
- [ ] Shellcheck passed (`npm run lint`)
- [ ] Secret scan passed (`npm run scan:secrets`)

See [SECURITY.md](./SECURITY.md) for security details; commit conventions are documented above.

## Releases

Versioning lives in `package.json` (SemVer). To compare what's installed across machines:

```bash
npm run version:show
# supercharged v1.3.0
#   describe : v1.3.0
#   commit   : a1b2c3d
#   tag      : v1.3.0
#   branch   : main
#   host     : RSJ-MBP
```

To cut a release:

```bash
npm run release -- patch       # or: minor | major | 1.4.0
```

The release script (`scripts/release.sh`) refuses to run on a dirty tree, requires the local branch to be in sync with `origin`, bumps `package.json`, commits as `chore(release): vX.Y.Z`, tags `vX.Y.Z`, and pushes both. The `release.yml` workflow then verifies the tag matches `package.json` and publishes a GitHub Release with auto-generated notes from conventional commits.

## Debugging

**Log file**: `.supercharged_install.log` in the repo directory.

**Common issues**:
- "Command not found" → check PATH in `.zshrc`, verify ASDF shims
- "Permission denied" → verify file permissions, check sudo requirements
- "Plugin not found" → ensure ASDF plugin installed before version
- "Backup failed" → check disk space in `~/.supercharged_backups/`
- "Shellcheck not found" → install with `brew install shellcheck` (REQUIRED)
