# Code Review Graph (CRG)

AI-optimized code knowledge graph for token-efficient codebase exploration.

**Official docs**: https://code-review-graph.com  
**GitHub**: https://github.com/tirth8205/code-review-graph

**CLI tool**: `code-review-graph`  
**Shell helper**: `crg-here` (zsh function for register + build)

## Quick Start

```bash
crg-here  # Register + build current repo (idempotent)
```

The launchd watcher keeps indexes fresh automatically.

## Capabilities

This installation includes:
- **Local embeddings** (sentence-transformers): `semantic_search_nodes` finds conceptually similar code, not just keyword matches. Search "authenticate" to find login/auth/credentials/session code.
- **Community detection** (igraph): `list_communities` and `get_architecture_overview` detect architectural modules via graph clustering. Shows how code groups into logical components.

Both run locally, no API keys needed.

## Key Tools

| Tool | Use when |
|------|----------|
| `detect_changes` | Reviewing code changes — gives risk-scored analysis |
| `get_review_context` | Need source snippets for review — token-efficient |
| `get_impact_radius` | Understanding blast radius of a change |
| `get_affected_flows` | Finding which execution paths are impacted |
| `query_graph` | Tracing callers, callees, imports, tests, dependencies |
| `semantic_search_nodes` | Finding functions/classes by name or keyword |
| `get_architecture_overview` | Understanding high-level codebase structure |
| `list_communities` | Show architectural modules detected by graph clustering |
| `refactor_tool` | Planning renames, finding dead code |

## Workflow

1. The graph auto-updates on file changes (via hooks).
2. Use `detect_changes` for code review.
3. Use `get_affected_flows` to understand impact.
4. Use `query_graph` pattern="tests_for" to check coverage.

## Common Patterns

### Finding Related Code

```
# Semantic search (uses embeddings)
semantic_search_nodes(query="authentication logic")
# Finds: login handlers, auth middleware, session management, credential validation

# Graph traversal
query_graph(pattern="callers_of", node="authenticate_user")
query_graph(pattern="callees_of", node="handle_login")
```

### Understanding Impact

```
# Before changing a function
get_impact_radius(function_name="process_payment")
# Shows: direct callers, transitive dependencies, affected test files

# After making changes
detect_changes()
# Risk-scored analysis of what changed and potential impact
```

### Architecture Analysis

```
# High-level structure
get_architecture_overview()
# Shows: major components, dependencies, entry points

# Module detection
list_communities()
# Shows: how code clusters into logical groups (auth module, payment module, etc.)
```

## CLI Commands

### Registry Management

```bash
# View registered repos
cat ~/.code-review-graph/registry.json | jq '.repos'

# Register a repo
code-review-graph register /path/to/repo --alias myproject

# Unregister a repo
code-review-graph unregister myproject

# List all registered repos
code-review-graph repos
```

### Manual Operations

```bash
# Build/rebuild graph for a repo
code-review-graph build --repo /path/to/repo

# Check graph status
code-review-graph status --repo /path/to/repo

# Watch for changes (manual mode)
code-review-graph watch --repo /path/to/repo
```

### Watcher Management

```bash
# Check watcher status
launchctl list | grep code-review-graph

# View watcher logs
tail -f ~/.code-review-graph/watcher.log
tail -f ~/.code-review-graph/watcher.err

# Restart watcher
launchctl stop com.code-review-graph.watcher
launchctl start com.code-review-graph.watcher
```

## Troubleshooting

### Graph Not Updating

```bash
# Check watcher logs
tail -f ~/.code-review-graph/watcher.err

# Restart watcher
launchctl stop com.code-review-graph.watcher
launchctl start com.code-review-graph.watcher

# Force rebuild
crg-here
```

### MCP Server Not Found

```bash
# Verify installation
code-review-graph --version

# Check Claude Code config
jq '.mcpServers."code-review-graph"' ~/.claude/settings.json

# Reinstall MCP integration
code-review-graph install --platform claude-code
```

## See Also

- [Official Documentation](https://code-review-graph.com) - Full API reference, tutorials, architecture
- [GitHub Repository](https://github.com/tirth8205/code-review-graph) - Source code, issues, discussions
- [MCP Protocol](https://modelcontextprotocol.io) - Model Context Protocol specification
