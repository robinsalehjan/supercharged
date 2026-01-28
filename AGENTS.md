# AGENTS.md

Instructions for AI coding agents working on the Supercharged macOS environment setup tool.

## Project Overview

Supercharged is a macOS environment setup automation tool that:
- Installs and configures development tools via Homebrew and ASDF
- Manages dotfiles (.zshrc, .gitconfig, .tool-versions, etc.)
- Provides interactive installation with optional tool categories
- Creates automatic backups before making changes
- Validates system requirements and tool installations

**Architecture**:
- `scripts/` - Shell scripts for installation, updates, and utilities
- `dot_files/` - Configuration files copied to `$HOME`
- `package.json` - npm scripts for running setup/update workflows
- Backup system in `~/.supercharged_backups/`

## Setup Commands

```bash
# Fresh installation (interactive)
npm install && npm run setup

# Update existing installation
npm run update

# Copy only dotfiles to $HOME
npm run setup:profile

# Validate all tools are installed correctly
npm run validate

# Restore from most recent backup
npm run restore
```

## Build and Test

```bash
# Dry-run to preview changes without installing
npm run update:dry-run

# Update specific components
npm run update:brew      # Only Homebrew packages
npm run update:asdf      # Only ASDF plugins/versions
npm run update:zsh       # Only ZSH plugins

# Manual validation of shell scripts (note: limited zsh support)
shellcheck --shell=bash scripts/*.sh 2>&1 | grep -v SC1071 || true

# Test restoration workflow
source scripts/utils.sh && restore_from_backup ~/.supercharged_backups/<timestamp>
```

**Shellcheck Warnings to Ignore** (safe for zsh scripts):
- `SC1071` - ShellCheck doesn't support zsh (expected, we use `--shell=bash`)
- `SC2296` - Parameter expansions can't start with `(` (zsh-specific `${(%):-%x}` syntax)
- `SC1091` - Not following sourced file (shellcheck limitation)
- `SC2155` - Declare and assign separately (style preference, not a bug)
- `SC2001` - Use `${var//search/replace}` instead of sed (style preference)
- `SC2012` - Use find instead of ls (style preference, our use is safe)

## Code Style and Conventions

### Shell Script Guidelines

**Logging**: Always use `log_with_level` from `utils.sh`:
```bash
log_with_level "INFO" "Starting installation..."
log_with_level "ERROR" "Installation failed: $error_msg"
log_with_level "SUCCESS" "Tool installed successfully"
log_with_level "WARN" "Tool already exists, skipping"
```

**Error Handling**: Include cleanup traps:
```bash
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_with_level "ERROR" "Operation failed"
        # Cleanup logic
    fi
}
trap cleanup EXIT
```

**User Prompts**: Follow existing patterns for interactive questions:
```bash
read -rp "Install iOS Tools? [Y/n]: " response
response=${response:-Y}
if [[ "$response" =~ ^[Yy] ]]; then
    export INSTALL_IOS_TOOLS=Y
fi
```

**Version Parsing**: Read from `.tool-versions`:
```bash
python_version=$(awk '/python/{print $2}' "$TOOL_VERSIONS_FILE")
```

### Dotfile Conventions

- Comment all configuration sections clearly
- Preserve existing user customizations when possible
- Use environment variables for paths, not hardcoded values
- Include inline documentation for complex aliases/functions

### Code Organization

**In `scripts/mac.sh`**:
- System validation first
- Homebrew installation
- Dynamic Brewfile generation based on user preferences
- ZSH plugin installation
- ASDF plugin/version installation
- Optional tool installations (data science, Claude Code)

**In `scripts/utils.sh`**:
- Reusable functions (logging, backup/restore, validation)
- No side effects on import
- Each function documented with purpose

**In `dot_files/.tool-versions`**:
- One tool per line: `<plugin> <version>`
- Include comments with minimum version requirements
- Group by category (languages, cloud tools, etc.)

## Testing Instructions

**Pre-commit Validation**:
1. Run `shellcheck --shell=bash scripts/*.sh` to check syntax (note: scripts use zsh, so some warnings about zsh-specific features can be ignored)
2. Test script functions in isolation when possible
3. Verify logging output format matches existing patterns
4. Check that backup/restore creates expected files

**Manual Testing Workflow**:
1. Create a backup: `npm run restore` should show last backup location
2. Make changes to scripts or dotfiles
3. Run `npm run setup:profile` to copy dotfiles
4. Source `.zshrc` and verify no errors: `source ~/.zshrc`
5. Run `npm run validate` to check installations
6. If issues occur, restore: `npm run restore`

**Validation Checks** (from `utils.sh`):
- Homebrew installed and in PATH
- ASDF installed and plugins present
- Tool versions match `.tool-versions`
- ZSH plugins cloned to correct directories
- Dotfiles present in `$HOME`

## Security Considerations

**Never**:
- Commit secrets or API keys to repository
- Store credentials in dotfiles (use `.secrets` template)
- Skip permission validation for SSH configs
- Remove backup creation logic

**Always**:
- Review commands that modify system settings
- Validate file permissions after copying dotfiles
- Ensure `.secrets` file is in `.gitignore`
- Use keychain for SSH key management (configured in `.zshrc`)

**SSH Key Configuration**:
- Supports ed25519, rsa, ecdsa keys
- Automatically loads into keychain via `.zshrc`
- Sets correct permissions (600) on private keys

## Adding New Tools

### Homebrew Package
1. Edit `scripts/mac.sh` in the `BREWFILE_CONTENT` section
2. Add to appropriate conditional (iOS tools, dev tools) or core section:
   ```bash
   brew "package-name"        # Formula
   cask "app-name"           # Application
   ```
3. Update README.md "What Gets Installed" section
4. Test with `brew bundle --file=-` using your modified content

### ASDF Tool
1. Add version to `dot_files/.tool-versions`:
   ```
   toolname 1.2.3  # Comment with minimum version
   ```
2. Add plugin installation in `scripts/mac.sh`:
   ```bash
   install_asdf_plugin toolname
   install_asdf_version toolname "$tool_version"
   ```
3. Update README.md with tool description
4. Run `npm run validate` after installation

### Optional Tool Category
Follow the `INSTALL_IOS_TOOLS` or `INSTALL_DEV_TOOLS` pattern:
1. Add prompt in `scripts/utils.sh:setup_user_preferences()`
2. Save preference to `~/.supercharged_preferences`
3. Use conditional in `scripts/mac.sh`:
   ```bash
   if [[ "${INSTALL_YOUR_CATEGORY:-N}" =~ ^[Yy] ]]; then
       # Add tools here
   fi
   ```
4. Document in README.md interactive setup section

## Updating Tool Versions

1. Modify version in `dot_files/.tool-versions`
2. Update minimum version comment if requirements change
3. Check for breaking changes in tool's changelog
4. Update README.md if behavior changes significantly
5. Test installation: `asdf install <tool> <version>`
6. Run `asdf reshim` to update shims
7. Validate with `npm run validate`

## Common Tasks

**Add a new ZSH alias**:
Edit `dot_files/.zshrc` in the aliases section, following existing format.

**Modify Homebrew tap**:
Add tap to `BREWFILE_CONTENT` before any packages from that tap:
```bash
tap "owner/repo"
brew "owner/repo/package"
```

**Change log output format**:
Modify `log_with_level()` in `scripts/utils.sh`, but preserve timestamp and level format.

**Add backup file**:
Include in `create_restoration_point()` backup loop in `scripts/utils.sh`.

## PR and Commit Guidelines

**Commit Format**: Use conventional commits
```
feat(scripts): add PostgreSQL installation
fix(zsh): correct PATH deduplication logic
docs(readme): update tool version requirements
chore(deps): update asdf plugin versions
```

**Before Committing**:
1. Run `shellcheck scripts/*.sh`
2. Test locally with `npm run setup:profile`
3. Verify no secrets in changed files
4. Update relevant documentation
5. Ensure backup logic still works

**PR Checklist**:
- [ ] README.md updated if user-facing changes
- [ ] AGENTS.md updated if workflow changes
- [ ] Logging follows existing patterns
- [ ] Tested on clean macOS environment (if possible)
- [ ] No hardcoded paths or credentials
- [ ] Backup/restore functionality unchanged

## Debugging and Logs

**Log Location**: `<supercharged-directory>/.supercharged_install.log`

**View Logs**:
```bash
tail -f .supercharged_install.log           # Follow in real-time
grep ERROR .supercharged_install.log        # Find errors
grep -A 5 "Installation started" *.log      # Context after start
```

**Common Issues**:
- "Command not found": Check PATH in `.zshrc`, verify ASDF shims
- "Permission denied": Verify file permissions, check for sudo requirements
- "Plugin not found": Ensure ASDF plugin installed before version
- "Backup failed": Check disk space in `~/.supercharged_backups/`

## Additional Context

**System Requirements** (validated in `scripts/mac.sh:validate_system()`):
- macOS 12.0 (Monterey) or later
- 10GB free disk space minimum
- Xcode Command Line Tools
- Active internet connection

**Prerequisites**:
- Oh My Zsh must be installed before running setup
- Git configured with SSH keys for cloning repos

**User Preferences File** (`~/.supercharged_preferences`):
```bash
INSTALL_IOS_TOOLS=Y
INSTALL_DATA_SCIENCE=N
INSTALL_DEV_TOOLS=Y
INSTALL_CLAUDE_CODE=Y
```

**Related Documentation**:
- See [README.md](./README.md) for user-facing documentation
- See [CLAUDE.md](./CLAUDE.md) for Claude Code-specific usage patterns
