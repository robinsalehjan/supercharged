# AGENTS.md

Detailed reference for AI agents. For project overview, structure, commands, and conventions see [CLAUDE.md](./CLAUDE.md).

## npm Commands Reference

```bash
# Setup and Installation
npm run setup                 # Fresh install (interactive)
npm run setup:profile         # Copy dotfiles + Claude config to $HOME

# Updates
# npm run update runs: backup:claude → setup:profile → update.sh
# update:brew and update:asdf also copy dotfiles first (via setup:profile)
npm run update                # Update all components (brew, asdf, zsh, npm, pip)
npm run update:dry-run        # Preview outdated brew/npm packages (read-only)
npm run update:brew           # Copy dotfiles + update Homebrew (formulae + casks)
npm run update:asdf           # Copy dotfiles + update ASDF plugins and versions
npm run update:zsh            # Update only ZSH plugins
npm run update:npm            # Update only npm global packages
npm run update:pip            # Update only pip data science packages

# Validation and Recovery
npm run validate              # Verify all tools installed correctly
npm run restore               # Restore from latest backup

# Claude Code Configuration
npm run backup:claude         # Backup Claude Code config to repo
npm run restore:claude        # Restore Claude Code config (only if repo is newer)
npm run restore:claude:force  # Force restore Claude Code config

# Development
npm run lint                  # ShellCheck all scripts (ignore zsh warnings)
npm test                      # Run BATS tests
npm run help                  # Display all available commands
```

## Build and Test

```bash
# Dry-run to preview changes
npm run update:dry-run

# Update specific components
npm run update:brew      # Homebrew only
npm run update:asdf      # ASDF only
npm run update:zsh       # ZSH plugins only
npm run update:npm       # npm globals only
npm run update:pip       # pip data science packages only

# Lint shell scripts
shellcheck --shell=bash scripts/*.sh 2>&1 | grep -v SC1071 || true

# Test Claude Code backup/restore
./scripts/backup-claude.sh
./scripts/restore-claude.sh --force
```

**Safe ShellCheck warnings** (zsh scripts run through `--shell=bash`):
SC1071 (zsh unsupported), SC2296 (zsh `${(%):-%x}`), SC1091 (sourced file), SC2155 (declare+assign), SC2001 (sed vs expansion), SC2012 (ls vs find).

**Zsh-specific syntax** used in scripts:
`${(%):-%x}`, `${(%):-%n}`, `&!` (disown), `path=(...)`, `setopt`.

## Testing

### BATS Testing Infrastructure

This project uses [BATS (Bash Automated Testing System)](https://github.com/bats-core/bats-core) for testing shell scripts.

**Running tests:**
```bash
npm test                          # Run all BATS tests
npm test -- --filter "pattern"    # Run specific tests
```

**Test structure:**
- `tests/claude/backup.bats` - Tests for Claude Code backup sanitization
- `tests/claude/restore.bats` - Tests for Claude Code restore merging
- `tests/utils/portability.bats` - Tests for portable path handling
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

**Script organization**:
- `mac.sh`: validate system → Homebrew → Brewfile (conditional on user prefs) → ZSH plugins → ASDF → optional tools
- `utils.sh`: pure functions, no side effects on import
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
| Add Homebrew tap | `BREWFILE_CONTENT` in `scripts/mac.sh`: `tap "owner/repo"` before packages |
| Change log format | `log_with_level()` in `scripts/utils.sh` (preserve timestamp + level) |
| Add backup file | `create_restoration_point()` in `scripts/utils.sh` |
| Update Claude sanitization | `SANITIZE_MARKETPLACES` in `backup-claude.sh`, `PRESERVE_MARKETPLACES` in `restore-claude.sh` |
| Modify pre-commit checks | `.husky/pre-commit` - add/remove security validations |
| Add/disable hookify rule | Create/edit `.claude/hookify.{name}.local.md` or set `enabled: false` |
| Test security hooks | `git add . && git commit -m "test"` - hooks run automatically |
| List hookify rules | `ls .claude/hookify.*.local.md` |

## Security & Git Workflow

**IMPORTANT**: This repository runs on personal AND work machines. Security is enforced automatically.

### Automated Security (Git Hooks)

**Pre-commit** (`.husky/pre-commit`) runs 7 checks:
1. ✅ **Shellcheck** - REQUIRED (commit fails if not installed)
2. ✅ **Secrets detection** - Blocks API keys, tokens, passwords
3. ✅ **Hardcoded paths** - Blocks `/Users/username/` in dotfiles
4. ✅ **.secrets safety** - Ensures template-only, no real credentials
5. ✅ **Claude config** - Warns about work marketplace data
6. ✅ **File size** - Blocks files >1MB
7. ✅ **BATS tests** - Runs test suite if bats is installed

**Commit-msg** (`.husky/commit-msg`) enforces conventional commits.

**Setup** (automated via `npm run setup`):
```bash
# Setup automatically configures:
# ✅ Installs shellcheck via Homebrew (REQUIRED)
# ✅ Sets git hooks path to .husky
# ✅ Makes hooks executable

# No manual configuration needed!
# Just run: npm run setup
```

### Hookify Rules (Claude Code)

11 active rules in `.claude/hookify.*.local.md` (gitignored, local-only):

**Blocking** (prevent operations):
- `dangerous-rm` - Blocks `rm -rf /`, `rm -rf ~`, etc.
- `no-bypass-hooks` - Blocks `git commit --no-verify`

**Warnings** (guide behavior):
- `hardcoded-paths` - Warn when editing dotfiles with machine-specific paths
- `logging-pattern` - Remind to use `log_with_level` instead of echo
- `secrets-template` - Warn when editing `.secrets`
- `claude-config-edit` - Warn when modifying Claude backups
- `sudo-in-scripts` - Warn against adding sudo
- `conventional-commits` - Remind about commit format
- `git-security-checks` - Show security check summary
- `shellcheck-reminder` - Remind to run shellcheck
- `documentation-sync` - Remind to update docs

### Commits and PRs

**Conventional commits**: `feat(scripts):`, `fix(zsh):`, `docs(readme):`, `chore(deps):`.

**Normal workflow**:
```bash
# Make changes
vim scripts/mac.sh

# Stage and commit (hooks run automatically)
git add scripts/mac.sh
git commit -m "feat(scripts): add new feature"

# Hooks will:
# 🔒 Run all 6 security checks
# ✅ Enforce conventional commit format
# ✅ Allow commit only if all checks pass
```

**If hooks fail**:
```bash
# Example: Secret detected
❌ Potential secrets detected in staged files!
   api_key="sk-1234..." in file.txt

# Fix the issue
vim file.txt  # Change to: YOUR_API_KEY_HERE

# Commit again
git commit -m "feat: add feature"  # ✅ Passes
```

**PR checklist**:
- [ ] Hooks passed (required - can't commit otherwise)
- [ ] README.md updated if user-facing changes
- [ ] Logging follows `log_with_level` pattern
- [ ] No hardcoded paths (use `$HOME`)
- [ ] Shellcheck passed (`npm run lint`)
- [ ] Documentation updated

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
