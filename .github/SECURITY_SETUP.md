# Security Setup Quick Reference

For full documentation, see [SECURITY.md](../SECURITY.md).

## Setup

```bash
git clone <repo-url> && cd supercharged && npm run setup
```

Everything is configured automatically — zero manual steps.

## What's Enforced (in Claude Code)

- **2 blocking rules**: dangerous `rm`, bypass hooks (`--no-verify`)
- **6 warning rules**: code quality, documentation, security

## What to Avoid

- Secrets (API keys, tokens, passwords)
- Hardcoded paths (`/Users/robin/` — use `$HOME`)
- Real credentials in `.secrets` template
- Files over 1MB

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Shellcheck not found | `brew install shellcheck` |
| Hookify rule not triggering | Check YAML frontmatter, verify `enabled: true` |

## More Info

- [SECURITY.md](../SECURITY.md) — full security docs
- [AGENTS.md](../AGENTS.md) — security workflow details
