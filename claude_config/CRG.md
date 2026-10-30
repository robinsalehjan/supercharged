# Code Review Graph (CRG)

**Official docs**: https://code-review-graph.com  
**GitHub**: https://github.com/tirth8205/code-review-graph

Claude integration reference for the code-review-graph MCP server.

**CLI tool**: `code-review-graph`  
**Shell helper**: `crg-here` (register + build, idempotent)

Includes local embeddings (sentence-transformers) and community detection (igraph) — no API keys needed.

## Key Tools

| Tool | Use when |
|------|----------|
| `detect_changes` | Review code changes — risk-scored analysis |
| `get_review_context` | Source snippets for review — token-efficient |
| `get_impact_radius` | Blast radius of a change |
| `get_affected_flows` | Which execution paths are impacted |
| `query_graph` | Callers, callees, imports, tests, dependencies |
| `semantic_search_nodes` | Find code by name, keyword, or concept |
| `get_architecture_overview` | High-level codebase structure |
| `list_communities` | Architectural modules via graph clustering |
| `refactor_tool` | Renames, dead code detection |

Graph selection, freshness checks, and fallback policy live in the shared agent instructions (`AGENTS.md`).
