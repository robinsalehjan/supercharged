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

### Key Tools

| Tool | Use when |
|------|----------|
| `detect_changes` | Reviewing code changes — gives risk-scored analysis |
| `get_review_context` | Need source snippets for review — token-efficient |
| `get_impact_radius` | Understanding blast radius of a change |
| `get_affected_flows` | Finding which execution paths are impacted |
| `query_graph` | Tracing callers, callees, imports, tests, dependencies |
| `semantic_search_nodes` | Finding functions/classes by name or keyword |
| `get_architecture_overview` | Understanding high-level codebase structure |
| `refactor_tool` | Planning renames, finding dead code |

### Workflow

1. The graph auto-updates on file changes (via hooks).
2. Use `detect_changes` for code review.
3. Use `get_affected_flows` to understand impact.
4. Use `query_graph` pattern="tests_for" to check coverage.

## References

@RTK.md
@CLAUDE-TOKEN-EFFICIENT.md
@WORKTRUNK.md
