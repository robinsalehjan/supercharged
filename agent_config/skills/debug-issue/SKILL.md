---
name: Debug Issue
description: Systematically debug issues using graph-powered code navigation
---

## Debug Issue

Use code-review-graph first for source navigation, call-chain tracing, and
impact analysis. Use `rg` directly for configuration, Markdown, TOML, or when
the graph is stale or does not cover the needed code.

### Steps

1. Run `get_minimal_context` first for the debugging task.
2. Use `semantic_search_nodes` to find code related to the issue.
3. Use `query_graph` with `callers_of` and `callees_of` to trace call chains.
4. Use `get_flow` to see full execution paths through suspected areas.
5. Run `detect_changes` to check whether recent changes caused the issue.
6. Use `get_impact_radius` on suspected files to see what else is affected.

### Tips

- Check both callers and callees to understand the full context.
- Check affected flows to find the entry point that triggers the bug.
- Recent changes are a useful lead, but verify the current behavior.

## Token Efficiency Rules

- Start with `get_minimal_context(task="<your task>")` before other graph tools.
- Use `detail_level="minimal"` unless standard detail is necessary.
- Target a debugging pass of five graph calls or fewer and about 800 output tokens.
