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
npm run backup:claude             # Backup Claude Code config to repo
npm run restore:claude            # Restore Claude Code config (only if repo is newer)
npm run restore:claude -- --force # Force restore Claude Code config (see Post-Restore Steps below)
npm run install:plugins           # Install all marketplaces and plugins via claude CLI
npm run install:plugins -- --dry-run # Preview what would be installed

# Development
npm run lint                      # ShellCheck all scripts (including utils/)
npm test                          # Run all BATS tests
bats tests/<suite>/*.bats        # Run a specific suite (claude, utils, mac, update, setup)
npm run help                      # Display all available commands
```

## ShellCheck Notes

**Safe warnings** (zsh scripts run through `--shell=bash`):
SC1071 (zsh unsupported), SC2296 (zsh `${(%):-%x}`), SC1091 (sourced file), SC2001 (sed vs expansion — excluded in lint). Also safe but not excluded: SC2155 (declare+assign), SC2012 (ls vs find).

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
- **Local-only configs**: Work plugins/marketplaces are saved to `.local.json` files (gitignored) during backup, and merged back during install
- **Post-restore**: Plugins are auto-installed at the end of `restore:claude`. If auto-install fails, run `npm run install:plugins` manually.

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

## RTK (Rust Token Killer)

RTK is automatically installed and configured as part of the setup. It provides 60-90% token savings on dev operations by optimizing CLI command output.

**Installed by**: `brew install rtk` in `scripts/mac.sh`
**Configured by**: `setup_rtk()` in `scripts/utils/tools.sh` (runs `rtk init -g --auto-patch`)
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
**Configured by**: `setup_dippy()` in `scripts/utils/tools.sh`
**Hook location**: PreToolUse hook in `~/.claude/settings.json` (runs before RTK rewrite)

**How it works:**
- Runs as a PreToolUse hook on `Bash` tool calls
- Auto-approves safe, read-only commands (ls, git status, cat, etc.)
- Blocks destructive operations that need human review
- Works alongside RTK — Dippy handles permissions, RTK handles output filtering

**Setup is automatic** during `npm run setup` or `npm run update`. The update script also checks for missing Dippy installation when Claude Code is present.

## Worktrunk (Git Worktree Manager)

Worktrunk is a CLI for git worktree management designed for running parallel AI agents. It makes worktrees as easy as branches and provides a clean merge + cleanup workflow.

**Installed by**: `brew install worktrunk` in `scripts/mac.sh`
**Configured by**: `setup_worktrunk()` in `scripts/utils/tools.sh` (runs `wt config shell install`)
**Shell integration**: auto-configured during `npm run setup` / `npm run update`; restart shell after first install
**Documentation**: <https://worktrunk.dev>

**Core commands:**
```bash
wt switch -c <branch>        # Create branch + worktree, switch to it
wt switch -c -x claude <br>  # Create worktree and start Claude in it
wt list                      # List worktrees with status (HEAD diff, ahead/behind, CI)
wt merge main                # Squash + rebase + fast-forward merge + auto-cleanup
wt remove                    # Remove current worktree + delete branch
```

**Workflow rules** (also enforced via `~/.claude/CLAUDE.md`):
- Use a worktree for any multi-file feature, bug fix, or experimental work — prefer `wt switch -c <branch>` over `git worktree add`.
- After a PR is merged, **always** clean up: `wt remove` from inside the worktree, or `wt merge main` for the local-merge path (auto-cleans).
- Verify with `wt list` — no stale entries should remain.
- For parallel Claude agents: `wt switch -c -x claude <branch> -- '<task>'` spins up an isolated worktree per agent.

**Alternatives** (when worktrunk isn't available):
- `superpowers:using-git-worktrees` skill — invokes the manual git worktree workflow.
- Agent tool with `isolation: "worktree"` — auto-creates and cleans a temporary worktree for a single subagent run.

## Plannotator (Visual Annotation Tool)

Plannotator is a visual annotation tool for AI coding agents. It enables you to mark up and refine plans or code diffs using a visual UI, with team collaboration and encrypted sharing.

**Installed by**: `setup_plannotator()` in `scripts/utils/tools.sh` (downloads from GitHub releases)
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
| Change log format | `log_with_level()` in `scripts/utils/logging.sh` (preserve timestamp + level) |
| Add utility function | Appropriate file in `scripts/utils/` (logging, backup, validation, tools, json) |
| Add backup file | `create_restoration_point()` in `scripts/utils/backup.sh` |
| Update Claude sanitization | `SANITIZE_MARKETPLACES` in `backup-claude.sh`, `PRESERVE_MARKETPLACES` in `restore-claude.sh`; sanitized entries auto-saved to `.local.json` files |
| Add Claude backup file | Add backup/restore logic in `backup-claude.sh` and `restore-claude.sh` (follow `keybindings.json` pattern) |
| Add/disable hookify rule | Create/edit `.claude/hookify.{name}.local.md` or set `enabled: false` |
| Test security hooks | `git add . && git commit -m "test"` - hooks run automatically |
| List hookify rules | `ls .claude/hookify.*.local.md` |

## Security & Git Workflow

Security is enforced automatically via hookify rules during Claude Code sessions. See [SECURITY.md](./SECURITY.md) for full details.

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
- "Shellcheck not found" → install with `brew install shellcheck` (REQUIRED)
- "Hookify rule not triggering" → check YAML frontmatter, verify pattern regex, ensure `enabled: true`
