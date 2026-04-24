# Security

This repository is designed to run safely on both personal and work machines with comprehensive security checks to prevent credential leaks, hardcoded paths, and other security issues.

## Automated Security Layers

### 1. Claude Code Hookify Rules (8 rules)

**Active for AI-assisted development:**

| Rule | Event | Action | Purpose |
|------|-------|--------|---------|
| dangerous-rm | bash | **BLOCK** | Prevents `rm -rf /`, `rm -rf ~`, etc. |
| no-bypass-hooks | bash | **BLOCK** | Blocks `git commit --no-verify` |
| git-conventions | bash | warn | Conventional commits + security check reminders |
| hardcoded-paths | file | warn | Warns when editing dotfiles with hardcoded paths |
| code-quality | file | warn | Logging patterns + no sudo in scripts |
| secrets-template | file | warn | Warns when editing .secrets template |
| claude-config-edit | Edit,Write | warn | Warns when modifying Claude backups |
| session-end-checks | stop | warn | Shellcheck + documentation sync reminders |

**Key Features:**
- 🔒 **2 blocking rules** prevent catastrophic operations
- 📝 **6 warning rules** guide development best practices
- 🤖 Runs within Claude Code sessions
- 🚫 Cannot be committed (`.claude/` is gitignored)

## Security Workflow

### Normal Development

> **Note:** Security checks run within Claude Code sessions via hookify rules, not as git commit hooks.

```bash
# 1. Make changes
vim scripts/mac.sh

# 2. Run shellcheck before committing
npm run lint

# 3. Stage and commit
git add scripts/mac.sh
git commit -m "feat(scripts): add new feature"
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

Security is configured automatically by `npm run setup` (installs shellcheck, configures hookify rules). See [README.md](./README.md) for installation instructions.

## Troubleshooting

```bash
# Shellcheck not found
brew install shellcheck

# False positives - review the error, use proper patterns ($HOME vs /Users/name)
```

## Files

| File | Purpose | Committed |
|------|---------|-----------|
| `.claude/hookify.*.local.md` | Claude Code behavior rules (8 files) | No (gitignored) |
