## Subagent Model Selection

When spawning subagents via the Agent tool, use `model: "sonnet"` for routine tasks like:
- Codebase exploration and search
- File reading and summarization
- Running tests or builds
- Simple code generation or edits

Reserve the default (Opus) for tasks requiring deep reasoning, complex architecture decisions, or multi-step problem solving.

## MCP Tools: code-review-graph

**IMPORTANT: When a project exposes the code-review-graph MCP server,
ALWAYS use its tools BEFORE Grep/Glob/Read to explore the codebase.**
The graph is faster, cheaper (fewer tokens), and gives structural
context (callers, dependents, test coverage) that file scanning cannot.

See @CRG.md for details.

## References

@CRG.md
@RTK.md
@PLANNOTATOR.md
@CLAUDE-TOKEN-EFFICIENT.md
@WORKTRUNK.md
