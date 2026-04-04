# Security

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
| **BATS Tests** | Runs test suite if bats is installed | ❌ BLOCKS commit |

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

## Best Practices

- Use `$HOME/path` instead of `/Users/name/path`
- Use placeholders in templates (`YOUR_API_KEY_HERE`)
- Run `npm run lint` before committing
- Follow conventional commits (`feat(scope): message`)
- Never commit real credentials or large files
- Never bypass hooks with `--no-verify` (blocked by hookify)

## Setup

Security is configured automatically by `npm run setup` (installs shellcheck, configures git hooks path to `.husky`, sets permissions). See [README.md](./README.md) for installation instructions.

## Troubleshooting

```bash
# Hooks not running
git config core.hooksPath              # Should output: .husky
chmod +x .husky/pre-commit .husky/commit-msg

# Shellcheck not found
brew install shellcheck

# False positives - review the error, use proper patterns ($HOME vs /Users/name)
```

## Files

| File | Purpose | Committed |
|------|---------|-----------|
| `.husky/pre-commit` | Git pre-commit security checks | Yes |
| `.husky/commit-msg` | Commit message validation | Yes |
| `.claude/hookify.*.local.md` | Claude Code behavior rules (11 files) | No (gitignored) |
