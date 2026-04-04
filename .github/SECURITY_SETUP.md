# Security Setup Quick Reference

This is a quick reference card for the security setup. For full documentation, see [SECURITY.md](../SECURITY.md).

## ✅ Setup (Fully Automated)

```bash
# Clone and run setup
git clone <repo-url>
cd supercharged
npm install
npm run setup

# Setup automatically:
# ✅ Installs shellcheck via Homebrew (REQUIRED)
# ✅ Configures git hooks path to .husky
# ✅ Makes hooks executable
# ✅ Ready to use - zero manual configuration!

# Verify (optional)
git commit --allow-empty -m "test: verify hooks"
# Should see: 🔒 Running security checks...
```

**No manual setup needed!** Everything is configured automatically during `npm run setup`.

## 🔒 Automated Security Layers

### Git Hooks (Everyone)

**Pre-commit** (`.husky/pre-commit`):
- ✅ Shellcheck validation (REQUIRED)
- ✅ Secrets detection
- ✅ Hardcoded paths detection
- ✅ .secrets template safety
- ✅ Claude config sanitization
- ✅ Large file detection (>1MB)

### Hookify Rules (Claude Code Only)

11 rules in `.claude/hookify.*.local.md`:
- 🚨 **2 BLOCKING**: dangerous rm, bypass hooks
- ⚠️ **9 WARNING**: code quality, documentation, security

## 📝 Normal Workflow

```bash
# Make changes
vim scripts/mac.sh

# Stage and commit (hooks run automatically)
git add scripts/mac.sh
git commit -m "feat(scripts): add new feature"

# Hooks automatically:
# ✅ Run all 6 security checks
# ✅ Block commit if issues found
```

## ⚠️ If Hooks Fail

```bash
# Example error
❌ Potential secrets detected in staged files!
   api_key="sk-1234..." in config.sh

# Fix the issue
vim config.sh  # Change to: YOUR_API_KEY_HERE

# Retry commit
git commit -m "feat: add feature"  # ✅ Passes
```

## 🚫 What's Blocked

- ❌ Secrets (API keys, tokens, passwords)
- ❌ Hardcoded paths (`/Users/robin/` in dotfiles)
- ❌ Real credentials in .secrets template
- ❌ Files over 1MB
- ❌ Missing shellcheck installation
- ❌ `git commit --no-verify` (in Claude Code)
- ❌ `rm -rf /`, `rm -rf ~`, etc. (in Claude Code)

## ✅ What's Allowed

- ✅ Environment variables (`$HOME/path`)
- ✅ Template placeholders (`YOUR_API_KEY_HERE`)
- ✅ Conventional commits preferred (`feat(scope): message`)
- ✅ Clean shell scripts (passing shellcheck)
- ✅ Portable dotfiles (no machine-specific paths)

## 🔍 Testing Security

```bash
# List hookify rules
ls .claude/hookify.*.local.md

# Count hookify rules (should be 11)
ls .claude/hookify.*.local.md | wc -l

# Run shellcheck manually
npm run lint

# Test pre-commit hook manually
./.husky/pre-commit

```

## 📚 Documentation

- **Full security docs**: [SECURITY.md](../SECURITY.md)
- **Agent reference**: [AGENTS.md](../AGENTS.md) (Security & Git Workflow section)
- **Project guide**: [CLAUDE.md](../CLAUDE.md) (Security section)
- **User guide**: [README.md](../README.md) (Security Enforcement section)

## 🆘 Troubleshooting

| Issue | Fix |
|-------|-----|
| Hooks not running | `git config core.hooksPath .husky` + `chmod +x .husky/*` |
| Shellcheck not found | `brew install shellcheck` |
| False positive secret | Review pattern in `.husky/pre-commit`, adjust if needed |
| Hookify rule not triggering | Check YAML frontmatter, verify `enabled: true` |

## 📊 Security Stats

- **11** hookify rules
- **6** pre-commit security checks
- **2** blocking rules (prevent dangerous operations)
- **9** warning rules (guide best practices)

**Result**: Safe for use on personal AND work machines! 🔒
