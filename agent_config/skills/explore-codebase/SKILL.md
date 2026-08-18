---
name: Explore Codebase
description: Navigate and understand codebase structure using the knowledge graph
---

## Explore Codebase

Use code-review-graph first for source navigation and architecture. Use `rg`
directly for configuration, Markdown, TOML, and graph content that is stale or
unsupported.

### Steps

1. Run `get_minimal_context` first for the exploration task.
2. Run `list_graph_stats` to see overall codebase metrics.
3. Run `get_architecture_overview` for high-level community structure.
4. Use `list_communities` and `get_community` to understand major modules.
5. Use `semantic_search_nodes` to find specific functions or classes.
6. Use `query_graph` with `callers_of`, `callees_of`, or `imports_of` to trace relationships.
7. Use `list_flows` and `get_flow` to understand execution paths.

### Tips

- Start broad, then narrow to the relevant symbols and flows.
- Use `children_of` on a source file to see its functions and classes.
- Use `find_large_functions` to identify candidates for decomposition.

## Token Efficiency Rules

- Start with `get_minimal_context(task="<your task>")` before other graph tools.
- Use `detail_level="minimal"` unless standard detail is necessary.
- Target an exploration pass of five graph calls or fewer and about 800 output tokens.
