# Security Setup for Personal/Work Machines

This repository is designed to run safely on both personal and work machines with comprehensive security checks to prevent credential leaks, hardcoded paths, and other security issues.

## Automated Security Layers

### 1. Git Pre-Commit Hooks (`.husky/pre-commit`)

**Runs automatically before every git commit:**

| Check | What It Does | Action |
|-------|--------------|--------|
| **Shellcheck** | Validates all shell scripts for errors and security issues | ❌ BLOCKS commit |
| **Secrets Detection** | Scans for API keys, tokens, passwords in staged files | ❌ BLOCKS commit |
| **Hardcoded Paths** | Detects `/Users/username/` or `/home/username/` in dotfiles | ❌ BLOCKS commit |
| **.secrets Template** | Ensures .secrets file only contains placeholders | ❌ BLOCKS commit |
| **Claude Config** | Warns about work-related marketplace data | ⚠️ Prompts user |
| **Large Files** | Prevents files >1MB from being committed | ❌ BLOCKS commit |

**Key Features:**
- ✅ Shellcheck is **REQUIRED** (not optional) - commit fails if not installed
- ✅ Checks ALL staged files, not just changed lines
- ✅ Exits immediately on first security issue
- ✅ Provides actionable error messages

### 2. Commit Message Validation (`.husky/commit-msg`)

**Enforces conventional commit format:**
```
feat(scope): description
fix(scope): description
docs(scope): description
chore(scope): description
```

### 3. Claude Code Hookify Rules (11 rules)

**Active for AI-assisted development:**

| Rule | Event | Action | Purpose |
|------|-------|--------|---------|
| dangerous-rm | bash | **BLOCK** | Prevents `rm -rf /`, `rm -rf ~`, etc. |
| no-bypass-hooks | bash | **BLOCK** | Blocks `git commit --no-verify` |
| hardcoded-paths | file | warn | Warns when editing dotfiles with hardcoded paths |
| logging-pattern | file | warn | Reminds to use `log_with_level` instead of echo |
| secrets-template | file | warn | Warns when editing .secrets template |
| claude-config-edit | file | warn | Warns when modifying Claude backups |
| sudo-in-scripts | file | warn | Warns against adding sudo to automation |
| conventional-commits | bash | warn | Reminds about commit format |
| git-security-checks | bash | warn | Reminds about automated security checks |
| shellcheck-reminder | stop | warn | Reminds to run shellcheck before stopping |
| documentation-sync | stop | warn | Reminds to update docs after changes |

**Key Features:**
- 🔒 **2 blocking rules** prevent catastrophic operations
- 📝 **9 warning rules** guide development best practices
- 🤖 Runs within Claude Code sessions
- 🚫 Cannot be committed (`.claude/` is gitignored)

## Security Workflow

### Normal Development

```bash
# 1. Make changes
vim scripts/mac.sh

# 2. Stage changes
git add scripts/mac.sh

# 3. Commit (hooks run automatically)
git commit -m "feat(scripts): add new feature"

# Hooks will:
# ✅ Run shellcheck on all scripts
# ✅ Check for secrets in staged files
# ✅ Verify no hardcoded paths in dotfiles
# ✅ Check .secrets template safety
# ✅ Validate conventional commit format
# ✅ Allow commit if all checks pass
```

### If Hooks Fail

```bash
# Example: Secret detected
git commit -m "feat: add feature"
# ❌ Potential secrets detected in staged files!
#    api_key="sk-1234567890abcdef" in file.txt
#    Use placeholders like: YOUR_API_KEY_HERE

# Fix the issue
vim file.txt  # Change to: api_key="YOUR_API_KEY_HERE"

# Commit again
git add file.txt
git commit -m "feat: add feature"  # ✅ Passes
```

### Emergency Bypass (NOT RECOMMENDED)

```bash
# IF YOU ABSOLUTELY MUST bypass hooks (emergency only):
git commit --no-verify -m "emergency: fix critical issue"

# NOTE: Claude Code will BLOCK this with hookify rule
# You must have explicit user permission
```

## Security Best Practices

### ✅ DO

- **Use environment variables:** `$HOME/path` instead of `/Users/robin/path`
- **Use placeholders in templates:** `YOUR_API_KEY_HERE`
- **Run shellcheck:** `npm run lint` before committing
- **Follow conventional commits:** `feat(scope): message`
- **Keep .secrets as template:** Never commit real credentials
- **Run security checks:** Let pre-commit hook validate everything

### ❌ DON'T

- **Hardcode paths:** `/Users/yourname/` or `/home/yourname/`
- **Commit secrets:** API keys, tokens, passwords
- **Bypass hooks:** `--no-verify` circumvents all security
- **Use sudo in automation:** Scripts should prompt if needed
- **Skip shellcheck:** Required for security and quality
- **Commit large files:** Keep repository lightweight

## Installation/Setup

### Fresh Machine Setup

```bash
# 1. Clone repository
git clone https://github.com/yourusername/supercharged.git
cd supercharged

# 2. Install dependencies and run setup
npm install
npm run setup

# Setup automatically:
# ✅ Installs shellcheck via Homebrew
# ✅ Configures git hooks path (.husky)
# ✅ Makes hooks executable
# ✅ Copies dotfiles to $HOME
# ✅ Restores Claude Code config

# 3. Test hooks work (optional verification)
git commit --allow-empty -m "test: verify hooks"
# Should see: 🔒 Running security checks...
```

### Verifying Security Setup

```bash
# Check shellcheck installed (automatically via setup)
shellcheck --version

# Check git hooks path (automatically configured via setup)
git config core.hooksPath
# Should output: .husky

# Check hook permissions (automatically set via setup)
ls -la .husky/
# Should show executable bits (rwxr-xr-x)

# Count hookify rules (created by Claude Code)
ls .claude/hookify.*.local.md 2>/dev/null | wc -l
# Should output: 11 (if using Claude Code)

# Test hooks work
git commit --allow-empty -m "test: verify hooks"
# Should see: 🔒 Running security checks...
```

## Troubleshooting

### Hooks Not Running

```bash
# Verify git hooks path
git config core.hooksPath
# If empty or wrong: git config core.hooksPath .husky

# Make hooks executable
chmod +x .husky/pre-commit .husky/commit-msg

# Test manually
./.husky/pre-commit
```

### Shellcheck Not Found

```bash
# Install shellcheck
brew install shellcheck

# Verify installation
shellcheck --version

# Test manually
npm run lint
```

### False Positives

If the security checks flag legitimate code:

1. **Review the error** - Is it actually a security issue?
2. **Fix if possible** - Use proper patterns (e.g., $HOME vs /Users/robin)
3. **If truly legitimate** - Contact maintainer to adjust patterns
4. **Emergency only** - Get user permission for `--no-verify`

## Files Modified for Security

| File | Purpose | Committed |
|------|---------|-----------|
| `.husky/pre-commit` | Git pre-commit security checks | ✅ Yes |
| `.husky/commit-msg` | Commit message validation | ✅ Yes |
| `.claude/hookify.*.local.md` | Claude Code behavior rules (11 files) | ❌ No (gitignored) |
| `SECURITY.md` | This documentation | ✅ Yes |

## Questions?

- **"Can I disable security checks?"** - Not recommended. Use `--no-verify` only in emergencies with explicit permission.
- **"Why is shellcheck required?"** - Prevents security vulnerabilities and errors in shell scripts.
- **"Why block hardcoded paths?"** - Dotfiles must work on both personal and work machines.
- **"What about Claude backups?"** - Automatically sanitized to remove work marketplace data.
- **"Why prevent --no-verify?"** - Bypassing security is dangerous; hookify blocks this in Claude Code sessions.

## Summary

Your supercharged repository is now protected with:

- ✅ **11 hookify rules** (2 blocking, 9 warning)
- ✅ **6 automated security checks** in pre-commit hook
- ✅ **Conventional commit enforcement**
- ✅ **Multi-machine safety** (no hardcoded paths)
- ✅ **Credential protection** (no secrets)
- ✅ **Code quality** (shellcheck required)

**Safe for use on personal and work machines!** 🔒
