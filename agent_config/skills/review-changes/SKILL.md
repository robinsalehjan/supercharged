---
name: Review Changes
description: Perform a structured code review using change detection and impact
---

## Review Changes

Use code-review-graph first to review source changes and their impact. Use
`rg` directly for configuration, Markdown, TOML, and graph content that is
stale or unsupported.

### Steps

1. Run `get_minimal_context` first for the review task.
2. Run `detect_changes` with minimal detail to get risk-scored change analysis.
3. Run `get_affected_flows` to find impacted execution paths.
4. For each high-risk function, use `query_graph` with pattern=`tests_for` to check test coverage.
5. Run `get_impact_radius` to understand the blast radius.
6. For untested changes, identify focused test cases.

### Output Format

Group findings by risk level and include:

- What changed and why it matters.
- Test coverage status.
- Suggested improvements.
- An overall merge recommendation.

## Token Efficiency Rules

- Start with `get_minimal_context(task="<your task>")` before other graph tools.
- Use `detail_level="minimal"` unless standard detail is necessary.
- Target a review pass of five graph calls or fewer and about 800 output tokens.
