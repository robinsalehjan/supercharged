# AGENTS.md

macOS environment setup automation — installs dev tools (Homebrew, ASDF), manages dotfiles, and backs up Claude Code configuration.

This file is the canonical reference for AI agents and contributors. See [README.md](./README.md) for quick start, [docs/REFERENCE.md](./docs/REFERENCE.md) for user-facing setup details, and [SECURITY.md](./SECURITY.md) for security policy.

## Project Structure

See [README.md](./README.md) and [docs/REFERENCE.md](./docs/REFERENCE.md) for user-facing setup details. Key directories:
- `scripts/` - Shell scripts (mac.sh, update-all.sh, update.sh, sync.sh, rollback.sh, utils.sh, setup-profile.sh, help.sh, install-plugins.sh; backup-claude.sh/restore-claude.sh for Claude config)
- `dot_files/` - Dotfiles copied to `$HOME`
- `claude_config/` - Claude Code config backup
- `agent_config/` - Shared global instructions, managed agent-tool pins, and canonical graph skill directories restored to Codex
- `codex_config/` - Codex CLI/IDE config backup

## Code Conventions

- **Logging**: Use `log_with_level "INFO|WARN|ERROR|SUCCESS" "message"` from `utils.sh`
- **Error handling**: Include `trap cleanup EXIT` in scripts
- **Tests**: BATS (Bash Automated Testing System); test files in `tests/`; use `setup_test_env` + `teardown_test_env`
- **Testing workflow**: Add BATS tests in `tests/<script-name>/` for new script features; run `npm test` before committing script changes
- **Commits**: Conventional format preferred (not enforced). Scope optional.
  - Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `build`, `ci`, `revert`, `wip`, `update`, `add`, `remove`
  - Examples: `feat(backup): add new feature`, `fix(restore): handle edge case`, `chore(deps): bump versions`
- **Shell scripts**: Written for zsh; ShellCheck `--shell=bash` flags (SC1071, SC2296) are safe to ignore
- **Dotfiles**: Use env vars, no hardcoded paths

## Shared Agent Capabilities

**Skills**:
- Shared graph skills live canonically in `agent_config/skills/<name>/SKILL.md`.
- `npm run sync -- --only codex` restores those directories directly into `~/.codex/skills/`.
- Tool-specific or unsupported skills stay in the tool-specific config (`claude_config/` or `codex_config/skills/`) instead of being forced into the shared path.

**Knowledge and graph tooling**:
- [code-review-graph](https://github.com/tirth8205/code-review-graph) is the preferred live-source layer for navigation, impact analysis, debugging, and review when its graph is current and covers the code in question. Shared selection and freshness rules live in `agent_config/AGENTS.md`; the graph-backed skills live in `agent_config/skills/`.
- [OpenWiki](https://github.com/langchain-ai/openwiki) is an opt-in repository knowledge layer for architecture, terminology, invariants, and intended workflows. Agents use an existing `openwiki/` as secondary context, verify material claims against current source and tests, and do not initialize or update it without an explicit user request.
- Both CLIs are exact-pinned in `agent_config/managed_tools.json` and reconciled by `npm run install:agent-tooling`. OpenWiki coding-agent integrations use the agent's authenticated session; the opt-in `openwiki-watch` launchd updater uses standalone CLI provider configuration, and credentials remain machine-local in `~/.openwiki/.env`.

**MCP servers**:
- Keep repo-managed user-scoped Claude MCP servers in `claude_config/mcp_servers.json` and compatible Codex entries in `codex_config/config.toml`; backup never imports live user MCP definitions into the tracked registry.
- Keep shared project MCP support in `.mcp.json` for Claude/project clients and in `codex_config/config.toml` for Codex.
- When adding an MCP server that both tools support, add the equivalent entry to both places and document any command differences.
- If Codex does not support a Claude MCP server, leave it in the Claude-specific config and do not add a stub Codex entry.

**Token optimization**:
- Claude output guidance is restored through `claude_config/CLAUDE-TOKEN-EFFICIENT.md`, referenced by `claude_config/CLAUDE.md`.

## Commands

Run `npm run help` for the canonical complete command inventory. Keep detailed behavior and selector boundaries in [docs/REFERENCE.md](./docs/REFERENCE.md); do not duplicate the inventory here.

## ShellCheck Notes

**Safe warnings** (zsh scripts run through `--shell=bash`):
SC1071 (zsh unsupported), SC2296 (zsh `${(%):-%x}`), SC1091 (dynamic sources), SC2001 (intentional sed), SC2329 (BATS/mock callbacks), and SC2016 (intentional literals) are disabled centrally in `.shellcheckrc`. Also safe but not disabled: SC2155 (declare+assign), SC2012 (ls vs find).

`npm run lint` runs ShellCheck with `--severity=info`; suppressions are maintained only in `.shellcheckrc`.

**Zsh-specific syntax** used in scripts:
`${(%):-%x}`, `${(%):-%n}`, `&!` (disown), `path=(...)`, `setopt`.

## Testing

Use BATS for shell behavior and keep fixtures synthetic. Run the narrowest affected suite while iterating, then the complete acceptance checks before delivery:

```bash
npm run lint
npm run scan:secrets
bats tests/<suite>/*.bats
npm test
```

- Use `setup()` for test initialization (calls `setup_test_env`)
- Use `teardown()` for cleanup (calls `teardown_test_env`)
- Load helpers: `load '../helpers/setup'`, `load '../helpers/assertions'`, `load '../helpers/mocks'`
- Test environment creates isolated temp directories with mocked `$HOME`
- Fixtures use `$HOME` placeholders, not hardcoded paths
- JSON assertions: `assert_json_field`, `assert_json_equals`
- Domain assertions: `assert_plugin_exists`, `assert_plugin_not_exists`, `assert_marketplace_exists`, `assert_marketplace_not_exists`
- Zsh-only functions tested via `run zsh -c "source script; function_call"` subprocess pattern
- PATH-based mocking with `MOCK_BIN_DIR` for zsh subprocesses (bash `export -f` doesn't propagate to zsh)

CI runs lint, secret scanning, and BATS through `.github/workflows/test.yml`. Discover the current suite from `tests/**/*.bats`; do not maintain a duplicate file inventory here.

## Implementation Invariants

- Portable paths: `$HOME` placeholder for cross-machine compatibility
- Preserve local work plugins, machine-local tables, secrets, and rollback compatibility during restore.
- Keep `claude_config/mcp_servers.json` intentional; backup must not import live user MCP definitions.
- Keep exact tool pins in `agent_config/managed_tools.json` and runtime pins in `dot_files/.tool-versions`.
- Keep repo-specific guidance here and cross-agent global preferences in `agent_config/AGENTS.md`.
- Prefer native Xcode MCP tools for Apple-platform work when configured.
- Detailed synchronization and tooling behavior belongs in [docs/REFERENCE.md](./docs/REFERENCE.md), not here.

Script organization:
- `mac.sh`: validate system → Homebrew → Brewfile (conditional on user prefs) → ZSH plugins → ASDF → optional tools
- `utils.sh`: thin loader sourcing focused, side-effect-free modules from `scripts/utils/`
- `utils/`: focused submodules — no side effects on import
- `.tool-versions`: one tool per line (`<plugin> <version>`), grouped by category

## Adding New Tools

**Homebrew package**: Edit `BREWFILE_CONTENT` in `scripts/mac.sh`, add `brew "name"` or `cask "name"` to the appropriate conditional section. Update `docs/REFERENCE.md` if the user-facing installed-tool set changes.

**ASDF tool**: Add `toolname version` to `dot_files/.tool-versions`. Add `install_asdf_plugin` and `install_asdf_version` calls in `scripts/mac.sh`. Keep docs pointed at `.tool-versions` instead of duplicating pinned versions.

**Optional category**: Follow `INSTALL_IOS_TOOLS` pattern — add prompt in `utils.sh:setup_user_preferences()`, save to `~/.supercharged_preferences`, use conditional in `mac.sh`. Update `docs/REFERENCE.md`.

**Update tool version**: Edit `dot_files/.tool-versions`, check changelog for breaking changes, test with `asdf install <tool> <version>`, run `asdf reshim`, validate with `npm run validate`.

## Common Tasks

| Task | Where |
|---|---|
| Add ZSH alias | `dot_files/.zshrc` aliases section |
| Onboard a repo to code-review-graph | `cd <repo> && crg-here` (registers + builds; the launchd watcher picks it up automatically). For opt-in nested-repo discovery, configure `~/.code-review-graph/watcher-config.json`. |
| Refresh a stale code-review-graph graph | From the repository, run `code-review-graph update`; use `code-review-graph status` to check availability and freshness first. |
| Initialize or refresh OpenWiki | Only when explicitly requested, use an installed coding-agent integration or run standalone `openwiki --init`/`openwiki --update` from the target repository; review `.openwikiignore`, generated `openwiki/` content, and managed instruction blocks before committing. |
| Add Homebrew tap | `BREWFILE_CONTENT` in `scripts/mac.sh`: `tap "owner/repo"` before packages |
| Change log format | `log_with_level()` in `scripts/utils/logging.sh` (preserve timestamp + level) |
| Add utility function | Appropriate file in `scripts/utils/` (logging, backup, validation, tools, json) |
| Add backup file | `create_restoration_point()` in `scripts/utils/backup.sh` |
| Update Claude sanitization | `SANITIZE_MARKETPLACES` in `backup-claude.sh`, `PRESERVE_MARKETPLACES` in `restore-claude.sh`; sanitized entries auto-saved to `.local.json` files |
| Add Claude backup file | Add backup/restore logic in `backup-claude.sh` and `restore-claude.sh` (follow `keybindings.json` pattern) |
| Update shared agent instructions | Edit `agent_config/AGENTS.md`, then run `npm run sync -- --only agents` |
| Update Codex defaults | Edit `codex_config/config.toml`, then run `npm run sync -- --only codex` |
| Update Codex command deny rules | Edit `codex_config/rules/*.rules`, then run `npm run sync -- --only codex` |
| Update managed agent-tool pins | Install and validate locally, run `npm run promote:pins`, then `npm run promote:pins -- --apply` and review the diff |
| Add shared project skill rule | Create/edit `agent_config/skills/<name>/SKILL.md`, then run `npm run sync -- --only codex` |
| Add shared MCP server | Add compatible entries to `.mcp.json` and `codex_config/config.toml`; skip Codex if unsupported |
| Update security policy | Edit `SECURITY.md`, `scripts/scan-secrets.sh`, `codex_config/rules/*.rules`, or `codex_config/hooks/` as appropriate |
| Test security checks | Run `npm run lint`, `npm run scan:secrets`, and `npm test` |

## PR Checklist

**This repository is used on personal AND work machines** — comprehensive security enforced.

**Automated checks**: CI runs lint, secret scan, and BATS. Codex command rules and hooks are tracked under `codex_config/`. Claude plugin configuration is restored from `claude_config/`. See [SECURITY.md](./SECURITY.md) for details.

**Key rules**:
- Never commit real secrets; only templates under `dot_files/.secrets/` belong in the repo
- No hardcoded paths in dotfiles (use `$HOME`, not `/Users/username/`)
- Shellcheck is required for `npm run lint` (`brew install shellcheck`)
- Claude backups sanitized (work marketplaces excluded)
- Do not bypass hooks or policy checks with `--no-verify`

**Conventional commits** (preferred, not enforced): `feat(scripts):`, `fix(zsh):`, `docs(readme):`, `chore(deps):`.

**PR checklist**:
- [ ] Validation passed (`npm run lint`, `npm run scan:secrets`, and relevant BATS tests)
- [ ] README.md or `docs/REFERENCE.md` updated if user-facing behavior changed
- [ ] Logging follows `log_with_level` pattern
- [ ] No hardcoded paths (use `$HOME`)
- [ ] Shellcheck passed (`npm run lint`)
- [ ] Secret scan passed (`npm run scan:secrets`)

See [SECURITY.md](./SECURITY.md) for security details; commit conventions are documented above.

Release and troubleshooting workflows are documented in [README.md](./README.md) and [docs/REFERENCE.md](./docs/REFERENCE.md).
