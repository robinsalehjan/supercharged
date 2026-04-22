# Claude Code Token Optimization

**Three-layer optimization stack** for 90%+ total token savings.

## 1. RTK (Input Token Optimization)
- **What**: Rust-based CLI proxy that filters command output
- **Savings**: 60-90% reduction on tool output (git, npm, shell commands)
- **Integration**: PreToolUse hook (automatic, transparent)
- **Example**: `git status` -> `rtk git status` (filtered for relevance)

## 2. Dippy (Permission Flow Optimization)
- **What**: AST-based permission automation
- **Savings**: ~40% faster development (reduced permission fatigue)
- **How**: Auto-approves safe commands (ls, git status, cat) while blocking destructive ops
- **Integration**: Installed via Homebrew (`ldayton/dippy` tap), runs as PreToolUse hook alongside RTK

## 3. claude-token-efficient (Output Token Optimization)
- **What**: CLAUDE.md behavioral rules that reduce verbosity
- **Savings**: 60% reduction in Claude's response length
- **Rules**: No sycophantic openers, prefer editing over rewriting, test before declaring done
- **Integration**: Merged into project CLAUDE.md (automatic via prompt caching)

**Combined result**: RTK optimizes inputs, Dippy streamlines workflow, claude-token-efficient controls outputs.

## Verify RTK Setup
```bash
rtk gain              # Show token savings analytics
rtk gain --history    # Command usage history with savings
rtk discover          # Find missed optimization opportunities
```
