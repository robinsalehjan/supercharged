# Claude Code Token Optimization

**Two-layer optimization stack** for significant token savings.

## 1. RTK (Input Token Optimization)
- **What**: Rust-based CLI proxy that filters command output
- **Savings**: 60-90% reduction on tool output (git, npm, shell commands)
- **Integration**: PreToolUse hook (automatic, transparent)
- **Example**: `git status` -> `rtk git status` (filtered for relevance)

## 2. claude-token-efficient (Output Token Optimization)
- **What**: CLAUDE.md behavioral rules that reduce verbosity
- **Savings**: 60% reduction in Claude's response length
- **Rules**: No sycophantic openers, prefer editing over rewriting, test before declaring done
- **Integration**: Merged into project CLAUDE.md (automatic via prompt caching)

**Combined result**: RTK optimizes inputs, claude-token-efficient controls outputs.

## Verify RTK Setup
```bash
rtk gain              # Show token savings analytics
rtk gain --history    # Command usage history with savings
rtk discover          # Find missed optimization opportunities
```
