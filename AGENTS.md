# AGENTS.md

Detailed reference for AI agents. For project overview, structure, commands, and conventions see [CLAUDE.md](./CLAUDE.md).

## Build and Test

```bash
# Dry-run to preview changes
npm run update:dry-run

# Update specific components
npm run update:brew      # Homebrew only
npm run update:asdf      # ASDF only
npm run update:zsh       # ZSH plugins only
npm run update:npm       # npm globals only

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

## Testing

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

## Commits and PRs

**Conventional commits**: `feat(scripts):`, `fix(zsh):`, `docs(readme):`, `chore(deps):`.

**Before committing**:
1. Run shellcheck
2. Test with `npm run setup:profile`
3. Verify no secrets in changed files
4. Update documentation if user-facing

**PR checklist**:
- [ ] README.md updated if user-facing changes
- [ ] Logging follows existing patterns
- [ ] No hardcoded paths or credentials
- [ ] Backup/restore functionality preserved

## Debugging

**Log file**: `.supercharged_install.log` in the repo directory.

**Common issues**:
- "Command not found" → check PATH in `.zshrc`, verify ASDF shims
- "Permission denied" → verify file permissions, check sudo requirements
- "Plugin not found" → ensure ASDF plugin installed before version
- "Backup failed" → check disk space in `~/.supercharged_backups/`
