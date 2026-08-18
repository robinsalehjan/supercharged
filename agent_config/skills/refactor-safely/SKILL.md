---
name: Refactor Safely
description: Plan and execute safe refactoring using dependency analysis
---

## Refactor Safely

Use code-review-graph first to understand source dependencies and impact. Use
`rg` directly for configuration, Markdown, TOML, and graph content that is
stale or unsupported.

### Steps

1. Run `get_minimal_context` first for the refactoring task.
2. Use `refactor_tool` with mode=`suggest` for community-driven suggestions.
3. Use `refactor_tool` with mode=`dead_code` to find unreferenced code, then verify dynamic call sites before removal.
4. For renames, use `refactor_tool` with mode=`rename` to preview all affected locations.
5. Use `apply_refactor_tool` only after reviewing the preview.
6. After changes, run `detect_changes` to verify the refactoring impact.

### Safety Checks

- Check `get_impact_radius` before major refactors.
- Use `get_affected_flows` to ensure critical paths remain intact.
- Run focused tests covering the affected flows.

## Token Efficiency Rules

- Start with `get_minimal_context(task="<your task>")` before other graph tools.
- Use `detail_level="minimal"` unless standard detail is necessary.
- Target a refactoring pass of five graph calls or fewer and about 800 output tokens.
