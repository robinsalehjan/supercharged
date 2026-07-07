# AGENTS.md

macOS environment setup automation — installs dev tools (Homebrew, ASDF), manages dotfiles, and backs up Claude Code configuration.

This file is the canonical reference for AI agents and contributors. See [README.md](./README.md) for quick start, [docs/REFERENCE.md](./docs/REFERENCE.md) for user-facing setup details, and [SECURITY.md](./SECURITY.md) for security policy.

## Project Structure

See [README.md](./README.md) and [docs/REFERENCE.md](./docs/REFERENCE.md) for user-facing setup details. Key directories:
- `scripts/` - Shell scripts (mac.sh, update.sh, utils.sh, restore.sh, setup-profile.sh, help.sh, install-plugins.sh; backup-claude.sh/restore-claude.sh for Claude config)
- `dot_files/` - Dotfiles copied to `$HOME`
- `claude_config/` - Claude Code config backup
- `agent_config/` - Shared global agent instructions restored to both Claude and Codex
- `codex_config/` - Codex CLI/IDE config backup
- `.claude/skills/` - Tracked project skills used by Claude and mirrored to Codex when supported

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
- Project skills live in `.claude/skills/*.md` because Claude can consume that format directly.
- `npm run restore:codex` mirrors those Markdown skills into `~/.codex/skills/<name>/SKILL.md`.
- Keep shared project skills plain Markdown with `name` and `description` frontmatter so both tools can use them.
- Tool-specific or unsupported skills stay in the tool-specific config (`claude_config/` or `codex_config/skills/`) instead of being forced into the shared path.

**MCP servers**:
- Keep shared project MCP support in `.mcp.json` for Claude/project clients and in `codex_config/config.toml` for Codex.
- When adding an MCP server that both tools support, add the equivalent entry to both places and document any command differences.
- If Codex does not support a Claude MCP server, leave it in the Claude-specific config and do not add a stub Codex entry.

**Token optimization**:
- RTK reduces shell-output tokens through PreToolUse hooks and command wrappers (`rtk git`, `rtk npm`, `rtk proxy <cmd>`).
- Claude output guidance is restored through `claude_config/CLAUDE-TOKEN-EFFICIENT.md`, referenced by `claude_config/CLAUDE.md`.
- Useful checks: `rtk gain`, `rtk gain --history`, and `rtk discover`.

## npm Commands Reference

```bash
# Setup and Installation
npm run setup                 # Fresh install (interactive)
npm run restore:dotfiles         # Copy dotfiles + Claude config to $HOME

# Updates
# npm run update runs: backup:claude → restore:dotfiles → update.sh
npm run update                    # Update all components (brew, asdf, zsh, npm, pip)
npm run update:dry-run            # Preview outdated brew/npm packages (read-only)
npm run update:only -- <comp>     # Copy dotfiles + update one component (brew, asdf, zsh, npm, pip)

# Validation and Recovery
npm run validate              # Verify all tools installed correctly
npm run restore               # Restore from latest backup

# Claude Code Configuration
npm run backup:claude             # Backup Claude Code config to repo
npm run restore:claude            # Restore Claude Code config (only if repo is newer)
npm run restore:claude -- --force # Force restore Claude Code config (see Post-Restore Steps below)
npm run backup:all                # Backup Claude Code config + Codex config in one step
npm run backup:codex              # Backup Codex config to repo
npm run restore:codex             # Restore Codex config (only if repo is newer)
npm run restore:codex -- --force  # Force restore Codex config
npm run restore:agents            # Restore Claude config + Codex config in one step
npm run restore:all               # Restore Claude config + Codex config + dotfiles in one step
npm run install:plugins           # Install all marketplaces and plugins via claude CLI
npm run install:plugins -- --dry-run # Preview what would be installed
npm run install:skills            # Clone/update git-based skills into Claude Code and Codex
npm run install:skills -- --dry-run # Preview what would be installed/updated

# Versioning and Releases
npm run version:show              # Print version, commit SHA, tag, branch, host
npm run release -- patch          # Cut a release: bump, commit, tag vX.Y.Z, push
npm run release -- minor          # Minor bump
npm run release -- 1.2.3          # Explicit version
npm run release -- --dry-run patch # Preview without making changes

# Development
npm run lint                      # ShellCheck all scripts (including utils/)
npm run scan:secrets              # Scan repository paths for likely secrets
npm test                          # Run all BATS tests
npm run test:watch                # Re-run tests on change (requires nodemon)
bats tests/<suite>/*.bats        # Run a specific suite (claude, utils, mac, update, setup, restore, meta)
npm run help                      # Display all available commands
```

## ShellCheck Notes

**Safe warnings** (zsh scripts run through `--shell=bash`):
SC1071 (zsh unsupported), SC2296 (zsh `${(%):-%x}`), SC1091 (sourced file), SC2001 (sed vs expansion). These are disabled centrally in `.shellcheckrc` so the rule list lives next to the code rather than buried in `package.json`. Also safe but not disabled: SC2155 (declare+assign), SC2012 (ls vs find).

`npm run lint` runs with `--severity=warning` to keep `info`/`style` notes from cluttering output without changing what the rule set considers failing.

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
- `tests/utils/portability.bats` - Tests for portable path handling
- `tests/utils/tools.bats` - Tests for `setup_*` helpers in `scripts/utils/tools.sh`
- `tests/utils/validate.bats` - Tests for validation helpers in `scripts/utils/validation.sh`
- `tests/mac/install.bats` - Smoke tests for mac.sh (validate_system, build_brewfile, install_homebrew, parse_tool_versions)
- `tests/setup/profile.bats` - Smoke tests for setup-profile.sh (dotfile copying, restoration points, version_gte)
- `tests/update/update.bats` - Smoke tests for update.sh (argument parsing, help, dry-run, unknown flags)
- `tests/meta/help.bats` - Tests for help.sh output (includes drift check against `package.json` scripts)
- `tests/meta/lint.bats` - Tests for ShellCheck lint script (validates `.shellcheckrc` rule set)
- `tests/restore/restore.bats` - Tests for restore.sh (system backup restoration)
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
1. `npm run restore:dotfiles` to copy dotfiles
2. `source ~/.zshrc` — verify no errors
3. `npm run validate` — check installations
4. If issues: `npm run restore`

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
- Secrets: `~/.secrets` is sourced once at restore start (single file, or every `*.sh` in a `~/.secrets/` directory — non-shell files like GCP JSON are ignored by the loader); MCP servers are skipped (not partially written) if no shell exports are loaded
- **Backed up files**: `settings.json`, `installed_plugins.json`, `known_marketplaces.json`, `mcp_servers.json`, `statusline/Config.toml`, `CLAUDE.md`, plus any `*.md` files referenced from `CLAUDE.md` via `@filename` (e.g. `CRG.md`, `RTK.md`, `WORKTRUNK.md`, `PLANNOTATOR.md`, `CLAUDE-TOKEN-EFFICIENT.md`) — auto-detected
- **Local-only configs**: Work plugins/marketplaces are saved to `.local.json` files (gitignored) during backup, and merged back during install
- **Post-restore**: Plugins are auto-installed at the end of `restore:claude`. If auto-install fails, run `npm run install:plugins` manually.

**Codex backup/restore** (`scripts/backup-codex.sh`, `scripts/restore-codex.sh`):
- Shared instructions: `agent_config/AGENTS.md` is restored to both `~/.codex/AGENTS.md` and `~/.claude/AGENTS.md`
- Codex settings: `codex_config/config.toml` restores durable defaults such as model, personality, web search, feature flags, MCP settings, hook enablement, instruction discovery, and a permission profile that denies `.env*`/`.secrets` paths
- Codex hooks and skills: `codex_config/hooks.json`, `codex_config/RTK.md`, and `codex_config/skills/plannotator-*` restore code-review-graph hooks, Plannotator Stop-hook review, Plannotator skills, and the Codex-only RTK instruction include
- Codex rules: `codex_config/rules/*.rules` restores repo-managed command deny rules that mirror the Claude hard-deny list where Codex prefix rules can express it; local approval rules in `~/.codex/rules/default.rules` remain local
- Shared git skills: `agent_config/installed_skills.json` is installed into both `~/.claude/skills/*` and `~/.codex/skills/*` by `npm run install:skills`
- Claude project skills: tracked `.claude/skills/*.md` files are the project-level source of truth for reusable shared skills; `restore:codex` mirrors supported Markdown skills into `~/.codex/skills/<name>/SKILL.md`
- Local-only state excluded: `auth.json`, history, logs, sessions, memories, SQLite databases, shell snapshots, and model caches
- Machine-local tables preserved on restore: `[projects.*]`, `[tui.model_availability_nux]`, `[notice.model_migrations]`, and `[hooks.state*]`
- Project guidance: keep repo-specific behavior in `AGENTS.md`; keep cross-agent global preferences in `agent_config/AGENTS.md`

**Post-Restore Steps** (after `npm run restore:claude` or `npm run restore:claude -- --force`):
1. Enable work plugins (@vend-plugins) manually if on work machine — these are sanitized from backups for security
2. Run `/reload-plugins` in Claude Code to force registry rescan if plugins don't appear
3. Verify with `/help` that skills and agents are available

Plugins are auto-installed during restore. `install:plugins` merges repo configs with `.local.json` files (work plugins/marketplaces), so work-specific configs survive across machines without being committed.

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
| Onboard a repo to code-review-graph | `cd <repo> && crg-here` (registers + builds; the launchd watcher picks it up automatically) |
| Add Homebrew tap | `BREWFILE_CONTENT` in `scripts/mac.sh`: `tap "owner/repo"` before packages |
| Change log format | `log_with_level()` in `scripts/utils/logging.sh` (preserve timestamp + level) |
| Add utility function | Appropriate file in `scripts/utils/` (logging, backup, validation, tools, json) |
| Add backup file | `create_restoration_point()` in `scripts/utils/backup.sh` |
| Update Claude sanitization | `SANITIZE_MARKETPLACES` in `backup-claude.sh`, `PRESERVE_MARKETPLACES` in `restore-claude.sh`; sanitized entries auto-saved to `.local.json` files |
| Add Claude backup file | Add backup/restore logic in `backup-claude.sh` and `restore-claude.sh` (follow `keybindings.json` pattern) |
| Update shared agent instructions | Edit `agent_config/AGENTS.md`, then run `npm run restore:agents` |
| Update Codex defaults | Edit `codex_config/config.toml`, then run `npm run restore:codex` |
| Update Codex command deny rules | Edit `codex_config/rules/*.rules`, then run `npm run restore:codex` |
| Add shared project skill rule | Create/edit `.claude/skills/<name>.md`, then run `npm run restore:codex` |
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
# supercharged v1.2.3
#   describe : v1.2.3
#   commit   : a1b2c3d
#   tag      : v1.2.3
#   branch   : main
#   host     : RSJ-MBP
```

To cut a release:

```bash
npm run release -- patch       # or: minor | major | 1.2.3
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
