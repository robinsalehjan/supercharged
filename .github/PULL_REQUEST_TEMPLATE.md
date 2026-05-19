## Summary

<!-- 1–3 bullets describing the change and why. -->

## Checklist

- [ ] Hooks passed (required — commit blocked otherwise)
- [ ] `npm run lint` passes (`brew install shellcheck` if missing)
- [ ] `npm test` passes (BATS); new behavior covered by a test
- [ ] README.md / AGENTS.md updated if user-facing
- [ ] Logging uses `log_with_level` (no bare `echo` in scripts)
- [ ] No hardcoded paths in dotfiles (`$HOME`, not `/Users/<name>/`)
- [ ] Conventional commit prefix (`feat`, `fix`, `chore`, `docs`, …)

See [AGENTS.md](../AGENTS.md) and [SECURITY.md](../SECURITY.md) for the full PR checklist and security policy.
