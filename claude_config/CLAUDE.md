## Subagent Model Selection

When spawning subagents via the Agent tool, use `model: "sonnet"` for routine tasks like:
- Codebase exploration and search
- File reading and summarization
- Running tests or builds
- Simple code generation or edits

Reserve the default (Opus) for tasks requiring deep reasoning, complex architecture decisions, or multi-step problem solving.

## MCP Servers

- **code-review-graph**: Project-level (`.mcp.json`) — code knowledge graph for token-efficient exploration
- **OpenAI Developer Docs**: Project-level (`.mcp.json`) — current OpenAI platform and Codex documentation

## Backed-Up Config

Statusline theme config (`statusline/Config.toml`) is backed up and restored with `npm run backup:claude` / `npm run restore:claude`.

## References

@AGENTS.md
@CRG.md
@RTK.md
@PLANNOTATOR.md
@CLAUDE-TOKEN-EFFICIENT.md
@WORKTRUNK.md
