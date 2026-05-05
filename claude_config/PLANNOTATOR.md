# Plannotator

**Official docs**: https://plannotator.ai  
**GitHub**: https://github.com/backnotprop/plannotator

Visual plan review and code annotation for AI coding agents.

**Access**: Via Claude Code skills (auto-triggered)  
**Browser-based**: Opens visual diff/plan reviewer in browser (runs locally, no server)

## What It Does

- **Plan review**: Annotate agent plans before they run
- **Code review**: Visual diff viewer for agent-written code
- **Annotations**: Select text, mark for deletion, add comments, or write replacements
- **Feedback loop**: Export annotations as structured feedback the agent understands
- **Sharing**: Plans compress into URLs (deflate compression) - share links with full context

All processing happens in your browser. Plans and annotations never leave your machine.

## Quick Start

Plannotator is available as Claude Code skills:

```bash
/plannotator-review     # Open interactive code review with visual diff
/plannotator-last       # Annotate the last rendered plan
/plannotator-annotate   # Open interactive annotation interface
/plannotator-archive    # Browse saved plan decisions
```

## Integration

Works natively with:
- Claude Code (via plugin)
- Codex
- Copilot
- Gemini
- OpenCode
- Pi
- VS Code

Compatible with any agent that supports plan mode.

## Typical Workflow

1. Agent enters plan mode and writes a plan
2. Use `/plannotator-review` or `/plannotator-last` to open visual reviewer
3. Annotate the plan (mark deletions, add comments, suggest replacements)
4. Export annotations back to the agent
5. Agent revises plan based on your feedback

## Features

- **No accounts required**: Completely local, free, open source
- **URL-based sharing**: All data compressed into shareable links
- **Full diff viewer**: Side-by-side code comparison
- **Structured feedback**: Annotations export as agent-readable format
- **Browser-based**: No separate app, runs in your default browser

## Installation

Plannotator is installed as a Claude Code plugin via the marketplace. The binary at `~/.local/bin/plannotator` is invoked automatically by the skills - you don't run it manually.

## See Also

- [Official Documentation](https://plannotator.ai) - Full guide, tutorials, examples
- [GitHub Repository](https://github.com/backnotprop/plannotator) - Source code, issues
- [Introduction Guide](https://www.mintlify.com/backnotprop/plannotator/introduction) - Getting started walkthrough
