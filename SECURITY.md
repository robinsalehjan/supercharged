# Security

This repository is designed to run safely on both personal and work machines. Security checks focus on preventing credential leaks, hardcoded machine paths, and destructive agent commands.

## Automated Security Layers

| Layer | Where | Purpose |
| --- | --- | --- |
| Secret scanner | `scripts/scan-secrets.sh` | Flags likely secrets in tracked repository paths. |
| Shell linting | `npm run lint` | Runs ShellCheck over scripts and test helpers. |
| BATS tests | `npm test` | Exercises backup, restore, install, validation, and safety behavior. |
| GitHub Actions | `.github/workflows/test.yml` | Runs lint, secret scan, and BATS on pushes and pull requests. |
| Codex command rules | `codex_config/rules/*.rules` | Blocks destructive or policy-violating commands in Codex sessions. |
| Codex hooks | `codex_config/hooks/` and `codex_config/hooks.json` | Restores managed Codex hook behavior, including RTK command rewriting. |
| Claude plugin config | `claude_config/installed_plugins.json` and `claude_config/settings.json` | Restores Claude Code plugin settings, including Hookify when installed. |

Claude Code Hookify may be installed as part of the backed-up Claude configuration, but this repository does not track local Hookify rule files.

The secret scanner exempts ordinary code-to-code assignments such as `token=args.token`; it continues to flag credential-shaped literal values assigned to API-key, secret, token, and password fields. This keeps generated or vendored implementation code scannable without weakening checks for actual embedded credentials.

## Security Workflow

### Normal Development

> **Note:** Security checks are a mix of explicit validation commands, CI, Codex rules/hooks, and restored Claude plugin configuration. They are not a substitute for reviewing staged changes before committing.

```bash
# 1. Make changes
vim scripts/mac.sh

# 2. Run validation before committing
npm run lint
npm run scan:secrets
npm test

# 3. Stage and commit
git add scripts/mac.sh
git commit -m "feat(scripts): add new feature"
```

### If Secret Scan Fails

```bash
# Example: Secret detected
# ❌ Potential secrets detected in staged files!
#    api_key="sk-1234567890abcdef" in file.txt
#    Use placeholders like: YOUR_API_KEY_HERE

# Fix the issue
vim file.txt  # Change to: api_key="YOUR_API_KEY_HERE"

# Run the scan again
git add file.txt
npm run scan:secrets
```

## Best Practices

- Use `$HOME/path` instead of `/Users/name/path`
- Use placeholders in templates (`YOUR_API_KEY_HERE`)
- Run `npm run lint` before committing
- Run `npm run scan:secrets` before committing
- Run `npm test` for script or restore-flow changes
- Follow conventional commits (`feat(scope): message`)
- Never commit real credentials or large files
- Keep secret templates empty; `dot_files/.secrets/` records variable names such as `REPLICATE_API_TOKEN`, never values
- Keep tracked paths portable with `$HOME`; do not commit a personal `/Users/<name>` path
- Do not bypass hooks or policy checks with `--no-verify`

## Setup

Security tooling is configured by `npm run setup` and restore commands. See [README.md](./README.md) and [docs/REFERENCE.md](./docs/REFERENCE.md) for setup details.

## Troubleshooting

```bash
# Shellcheck not found
brew install shellcheck

# False positives - review the error, use proper patterns ($HOME vs /Users/name)
```

## Files

| File | Purpose | Committed |
|------|---------|-----------|
| `scripts/scan-secrets.sh` | Repository secret scanner | Yes |
| `codex_config/rules/*.rules` | Managed Codex command deny rules | Yes |
| `codex_config/hooks/` | Managed Codex hook scripts | Yes |
| `claude_config/*.json` | Sanitized Claude plugin/settings backup | Yes |
| `claude_config/*.local.json` | Machine-local Claude plugin/settings overlays | No |
