# Security Setup Quick Reference

This is a quick reference card for the security setup. For full documentation, see [SECURITY.md](../SECURITY.md).

## ✅ Setup (Fully Automated)

```bash
# Clone and run setup
git clone <repo-url>
cd supercharged
npm run setup

# Setup automatically:
# ✅ Installs shellcheck via Homebrew
# ✅ Configures hookify rules for Claude Code sessions
# ✅ Ready to use - zero manual configuration!
```

**No manual setup needed!** Everything is configured automatically during `npm run setup`.

## 🔒 Automated Security Layers

### Hookify Rules (Claude Code Sessions)

8 rules in `.claude/hookify.*.local.md`:
- 🚨 **2 BLOCKING**: dangerous rm, bypass hooks
- ⚠️ **6 WARNING**: code quality, documentation, security

> **Note:** Security checks run within Claude Code sessions via hookify, not as git commit hooks.

## 📝 Normal Workflow

```bash
# Make changes
vim scripts/mac.sh

# Run shellcheck before committing
npm run lint

# Stage and commit
git add scripts/mac.sh
git commit -m "feat(scripts): add new feature"
```

## ⚠️ If Lint Fails

```bash
# Example error
scripts/mac.sh:42: warning: SC2034: variable unused

# Fix the issue
vim scripts/mac.sh

# Re-run lint and commit
npm run lint
git commit -m "feat: add feature"  # ✅ Passes
```

## 🚫 What's Blocked (in Claude Code)

- ❌ `rm -rf /`, `rm -rf ~`, etc. (blocked by hookify)
- ❌ `git commit --no-verify` (blocked by hookify)

## 🚫 What to Avoid

- ❌ Secrets (API keys, tokens, passwords)
- ❌ Hardcoded paths (`/Users/robin/` in dotfiles)
- ❌ Real credentials in .secrets template
- ❌ Files over 1MB

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

# Count hookify rules (should be 8)
ls .claude/hookify.*.local.md | wc -l

# Run shellcheck manually
npm run lint
```

## 📚 Documentation

- **Full security docs**: [SECURITY.md](../SECURITY.md)
- **Agent reference**: [AGENTS.md](../AGENTS.md) (Security & Git Workflow section)
- **Project guide**: [CLAUDE.md](../CLAUDE.md) (Security section)
- **User guide**: [README.md](../README.md) (Security Enforcement section)

## 🆘 Troubleshooting

| Issue | Fix |
|-------|-----|
| Shellcheck not found | `brew install shellcheck` |
| Hookify rule not triggering | Check YAML frontmatter, verify `enabled: true` |

## 📊 Security Stats

- **8** hookify rules
- **2** blocking rules (prevent dangerous operations)
- **6** warning rules (guide best practices)

**Result**: Safe for use on personal AND work machines! 🔒
