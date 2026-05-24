# Claude Code Token Optimization

**Three-layer stack**: RTK optimizes inputs, claude-token-efficient controls outputs, ccusage measures everything.

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

## 3. ccusage (Measurement)
- **What**: Reads `~/.claude/projects/*.jsonl` and reports token usage / cost
- **Cost**: Free — no API calls, parses local logs only
- **Integration**: Installed globally via npm by `setup_ccusage` in `scripts/utils/tools.sh`
- **Aliases** (in `dot_files/.zshrc`):
  - `cct` — daily summary
  - `cclive` — real-time monitor (polls active 5-hour block every 5s; `Ctrl+C` to exit)

## Verify Setup
```bash
# RTK (input savings)
rtk gain              # Show token savings analytics
rtk gain --history    # Command usage history with savings
rtk discover          # Find missed optimization opportunities

# ccusage (measurement)
cct                   # Daily token usage + cost
cct monthly           # Monthly rollup
cclive                # Live 5-hour block monitor
ccusage session       # Per-session breakdown
```
