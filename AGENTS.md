# AGENTS.md

macOS environment setup automation — installs dev tools (Homebrew, ASDF), manages dotfiles, and backs up Claude Code configuration.

This file is the canonical reference for AI agents and contributors. See [README.md](./README.md) for user-facing documentation and [SECURITY.md](./SECURITY.md) for security policy.

## Project Structure

See [README.md](./README.md) for detailed project structure. Key directories:
- `scripts/` - Shell scripts (mac.sh, update.sh, utils.sh, restore.sh, setup-profile.sh, help.sh, install-plugins.sh; backup-claude.sh/restore-claude.sh for Claude config)
- `dot_files/` - Dotfiles copied to `$HOME`
- `claude_config/` - Claude Code config backup
- `agent_config/` - Shared global agent instructions restored to both Claude and Codex
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
npm run restore:all               # Restore Claude config + Codex config + dotfiles in one step
npm run install:plugins           # Install all marketplaces and plugins via claude CLI
npm run install:plugins -- --dry-run # Preview what would be installed
npm run install:skills            # Clone/update git-based skills into ~/.claude/skills
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
- Codex settings: `codex_config/config.toml` restores durable defaults such as model, personality, web search, feature flags, MCP settings, hook enablement, and instruction discovery
- Codex hooks and skills: `codex_config/hooks.json`, `codex_config/RTK.md`, and `codex_config/skills/plannotator-*` restore code-review-graph hooks, Plannotator Stop-hook review, Plannotator skills, and the Codex-only RTK instruction include
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

**Homebrew package**: Edit `BREWFILE_CONTENT` in `scripts/mac.sh`, add `brew "name"` or `cask "name"` to the appropriate conditional section. Update README.md.

**ASDF tool**: Add `toolname version` to `dot_files/.tool-versions`. Add `install_asdf_plugin` and `install_asdf_version` calls in `scripts/mac.sh`. Update README.md.

**Optional category**: Follow `INSTALL_IOS_TOOLS` pattern — add prompt in `utils.sh:setup_user_preferences()`, save to `~/.supercharged_preferences`, use conditional in `mac.sh`. Update README.md.

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
| Update shared agent instructions | Edit `agent_config/AGENTS.md`, then run `npm run restore:codex` and `npm run restore:claude` |
| Update Codex defaults | Edit `codex_config/config.toml`, then run `npm run restore:codex` |
| Add/disable hookify rule | Create/edit `.claude/hookify.{name}.local.md` or set `enabled: false` |
| Test security hooks | `git add . && git commit -m "test"` - hooks run automatically |
| List hookify rules | `ls .claude/hookify.*.local.md` |

## PR Checklist

**This repository is used on personal AND work machines** — comprehensive security enforced.

**Automated checks**: Hookify rules enforce security during Claude Code sessions. See [SECURITY.md](./SECURITY.md) for full details and `.claude/hookify.*.local.md` for rules.

**Key rules**:
- Never commit secrets (`.secrets` is template only, in `.gitignore`)
- No hardcoded paths in dotfiles (use `$HOME`, not `/Users/username/`)
- Shellcheck is required for `npm run lint` (`brew install shellcheck`)
- Claude backups sanitized (work marketplaces excluded)
- No bypassing hooks with `--no-verify` (blocked by hookify)

**Conventional commits** (preferred, not enforced): `feat(scripts):`, `fix(zsh):`, `docs(readme):`, `chore(deps):`.

**PR checklist**:
- [ ] Hooks passed (required - can't commit otherwise)
- [ ] README.md updated if user-facing changes
- [ ] Logging follows `log_with_level` pattern
- [ ] No hardcoded paths (use `$HOME`)
- [ ] Shellcheck passed (`npm run lint`)
- [ ] Secret scan passed (`npm run scan:secrets`)

See [SECURITY.md](./SECURITY.md) for security details and [CLAUDE.md](./CLAUDE.md) for commit conventions.

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
- "Hookify rule not triggering" → check YAML frontmatter, verify pattern regex, ensure `enabled: true`
