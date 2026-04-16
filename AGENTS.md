# AGENTS.md

Detailed reference for AI agents. For project overview, structure, commands, and conventions see [CLAUDE.md](./CLAUDE.md).

## npm Commands Reference

```bash
# Setup and Installation
npm run setup                 # Fresh install (interactive)
npm run setup:profile         # Copy dotfiles + Claude config to $HOME

# Updates
# npm run update runs: backup:claude → setup:profile → update.sh
npm run update                    # Update all components (brew, asdf, zsh, npm, pip)
npm run update:dry-run            # Preview outdated brew/npm packages (read-only)
npm run update:only -- <comp>     # Copy dotfiles + update one component (brew, asdf, zsh, npm, pip)

# Validation and Recovery
npm run validate              # Verify all tools installed correctly
npm run restore               # Restore from latest backup

# Claude Code Configuration
npm run backup:claude         # Backup Claude Code config to repo
npm run restore:claude            # Restore Claude Code config (only if repo is newer)
npm run restore:claude -- --force # Force restore Claude Code config (see Post-Restore Steps below)

# Development
npm run lint                      # ShellCheck all scripts (ignore zsh warnings)
npm test                          # Run all BATS tests
bats tests/<suite>/*.bats        # Run a specific suite (claude, utils, mac, update, setup)
npm run help                      # Display all available commands
```

## ShellCheck Notes

**Safe warnings** (zsh scripts run through `--shell=bash`):
SC1071 (zsh unsupported), SC2296 (zsh `${(%):-%x}`), SC1091 (sourced file), SC2155 (declare+assign), SC2001 (sed vs expansion), SC2012 (ls vs find).

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
- `tests/mac/install.bats` - Smoke tests for mac.sh (validate_system, build_brewfile, install_homebrew, parse_tool_versions)
- `tests/setup/profile.bats` - Smoke tests for setup-profile.sh (dotfile copying, restoration points, version_gte)
- `tests/update/update.bats` - Smoke tests for update.sh (argument parsing, help, dry-run, unknown flags)
- `tests/meta/help.bats` - Tests for help.sh output
- `tests/meta/lint.bats` - Tests for ShellCheck lint script
- `tests/restore/restore.bats` - Tests for restore.sh (system backup restoration)
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

**Pre-commit integration:**
Tests run automatically via `.husky/pre-commit` hook after security checks (if `tests/` directory exists and `bats` is installed).

**CI integration:**
Tests run on push to main and pull requests via `.github/workflows/test.yml`.

### Manual Testing Workflows

**Pre-commit**:
1. `shellcheck --shell=bash scripts/*.sh`
2. Test script functions in isolation
3. Verify logging matches existing patterns

**Manual workflow**:
1. `npm run setup:profile` to copy dotfiles
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
- Secrets: `~/.secrets` is sourced once at restore start; MCP servers are skipped (not partially written) if it's absent
- **Backed up files**: `settings.json`, `installed_plugins.json`, `known_marketplaces.json`, `keybindings.json`, `CLAUDE.md`
- **Post-restore**: Plugins must be manually installed/enabled (see Post-Restore Steps below)

**Post-Restore Steps** (after `npm run restore:claude` or `npm run restore:claude -- --force`):
1. Review `claude_config/installed_plugins.json` to see backed-up official plugins
2. Install/enable plugins via Claude Code `/plugin` command or settings UI
3. Enable work plugins (@vend-plugins) manually if on work machine — these are sanitized from backups for security
4. Run `/reload-plugins` in Claude Code to force registry rescan if plugins don't appear
5. Verify with `/help` that skills and agents are available

Why manual? Plugin installation is stateful and environment-specific. Restore only handles config files, not plugin code or live registry state.

**Script organization**:
- `mac.sh`: validate system → Homebrew → Brewfile (conditional on user prefs) → ZSH plugins → ASDF → optional tools
- `utils.sh`: pure functions, no side effects on import
- `.tool-versions`: one tool per line (`<plugin> <version>`), grouped by category

## RTK (Rust Token Killer)

RTK is automatically installed and configured as part of the setup. It provides 60-90% token savings on dev operations by optimizing CLI command output.

**Installed by**: `brew install rtk` in `scripts/mac.sh`
**Configured by**: `setup_rtk()` in `scripts/utils.sh` (runs `rtk init -g --auto-patch`)
**Hook location**: `~/.claude/hooks/rtk-rewrite.sh`
**Documentation**: `~/.claude/RTK.md`

**Usage:**
```bash
rtk gain              # Show token savings analytics
rtk gain --history    # Command history with savings
rtk discover          # Analyze Claude Code history for missed opportunities
rtk init --show       # Verify installation status
```

All git commands are automatically rewritten by Claude Code hooks (e.g., `git status` → `rtk git status`).

**Setup is automatic** during `npm run setup` or `npm run update`. To manually reconfigure:
```bash
rtk init -g --auto-patch    # Reconfigure hooks
rtk init -g --uninstall     # Remove hooks
```

## Dippy (Permission Automation)

Dippy is an AST-based permission automation tool for Claude Code. It auto-approves safe commands while blocking destructive operations, reducing permission fatigue by ~40%.

**Installed by**: `brew install dippy` (tap: `ldayton/dippy`) in `scripts/mac.sh`
**Configured by**: `setup_dippy()` in `scripts/utils.sh`
**Hook location**: PreToolUse hook in `~/.claude/settings.json` (runs before RTK rewrite)

**How it works:**
- Runs as a PreToolUse hook on `Bash` tool calls
- Auto-approves safe, read-only commands (ls, git status, cat, etc.)
- Blocks destructive operations that need human review
- Works alongside RTK — Dippy handles permissions, RTK handles output filtering

**Setup is automatic** during `npm run setup` or `npm run update`. The update script also checks for missing Dippy installation when Claude Code is present.

## Plannotator (Visual Annotation Tool)

Plannotator is a visual annotation tool for AI coding agents. It enables you to mark up and refine plans or code diffs using a visual UI, with team collaboration and encrypted sharing.

**Installed by**: `setup_plannotator()` in `scripts/utils.sh` (downloads from GitHub releases)
**Location**: `~/.local/bin/plannotator`
**Claude Code plugin**: `backnotprop/plannotator` (manual installation required)

**Features:**
- Visual plan review with inline annotations
- Automatic plan diff tracking when agents revise
- Code review for git diffs and remote pull requests
- File annotation and structured feedback
- End-to-end encrypted sharing (auto-deletion after 7 days)

**Usage:**
```bash
plannotator review [PR_URL]       # Review a pull request
plannotator annotate <file>       # Annotate a file or folder
plannotator last                  # Open last review session
plannotator sessions              # List all review sessions
plannotator archive               # Archive old sessions
```

**Claude Code integration:**
After installation, add the plugin marketplace:
```bash
/plugin marketplace add backnotprop/plannotator
```

Then use slash commands in Claude Code:
- `/plannotator-review` - Review code changes
- `/plannotator-annotate` - Annotate plans or files
- `/plannotator-last` - Open last session

**Setup is automatic** during `npm run setup` or `npm run update`. To manually install:
```bash
# Via setup function (recommended)
source scripts/utils.sh && setup_plannotator

# Or manually download latest release from:
# https://github.com/backnotprop/plannotator/releases
```

## Adding New Tools

**Homebrew package**: Edit `BREWFILE_CONTENT` in `scripts/mac.sh`, add `brew "name"` or `cask "name"` to the appropriate conditional section. Update README.md.

**ASDF tool**: Add `toolname version` to `dot_files/.tool-versions`. Add `install_asdf_plugin` and `install_asdf_version` calls in `scripts/mac.sh`. Update README.md.

**Optional category**: Follow `INSTALL_IOS_TOOLS` pattern — add prompt in `utils.sh:setup_user_preferences()`, save to `~/.supercharged_preferences`, use conditional in `mac.sh`. Update README.md.

**Update tool version**: Edit `dot_files/.tool-versions`, check changelog for breaking changes, test with `asdf install <tool> <version>`, run `asdf reshim`, validate with `npm run validate`.

## Common Tasks

| Task | Where |
|---|---|
| Add ZSH alias | `dot_files/.zshrc` aliases section |
| Add Homebrew tap | `BREWFILE_CONTENT` in `scripts/mac.sh`: `tap "owner/repo"` before packages |
| Change log format | `log_with_level()` in `scripts/utils.sh` (preserve timestamp + level) |
| Add backup file | `create_restoration_point()` in `scripts/utils.sh` |
| Update Claude sanitization | `SANITIZE_MARKETPLACES` in `backup-claude.sh`, `PRESERVE_MARKETPLACES` in `restore-claude.sh` |
| Add Claude backup file | Add backup/restore logic in `backup-claude.sh` and `restore-claude.sh` (follow `keybindings.json` pattern) |
| Modify pre-commit checks | `.husky/pre-commit` - add/remove security validations |
| Add/disable hookify rule | Create/edit `.claude/hookify.{name}.local.md` or set `enabled: false` |
| Test security hooks | `git add . && git commit -m "test"` - hooks run automatically |
| List hookify rules | `ls .claude/hookify.*.local.md` |

## Security & Git Workflow

Security is enforced automatically via pre-commit hooks. See [SECURITY.md](./SECURITY.md) for full details.

**Conventional commits** (preferred, not enforced): `feat(scripts):`, `fix(zsh):`, `docs(readme):`, `chore(deps):`.

**PR checklist**:
- [ ] Hooks passed (required - can't commit otherwise)
- [ ] README.md updated if user-facing changes
- [ ] Logging follows `log_with_level` pattern
- [ ] No hardcoded paths (use `$HOME`)
- [ ] Shellcheck passed (`npm run lint`)

## Debugging

**Log file**: `.supercharged_install.log` in the repo directory.

**Common issues**:
- "Command not found" → check PATH in `.zshrc`, verify ASDF shims
- "Permission denied" → verify file permissions, check sudo requirements
- "Plugin not found" → ensure ASDF plugin installed before version
- "Backup failed" → check disk space in `~/.supercharged_backups/`
- "Hooks not running" → verify `git config core.hooksPath` is `.husky`, make hooks executable
- "Shellcheck not found" → install with `brew install shellcheck` (REQUIRED)
- "Secret detected false positive" → review pattern, adjust `.husky/pre-commit` if legitimate
- "Hookify rule not triggering" → check YAML frontmatter, verify pattern regex, ensure `enabled: true`
