# Rust Token Killer (RTK)

**Official docs**: https://www.rtk-ai.app

Token-optimized command wrappers that filter noisy output from git, npm, and other CLI tools.

## Meta Commands

```bash
rtk gain              # Show token savings analytics
rtk gain --history    # Show command usage history with savings
rtk discover          # Analyze Claude Code history for missed opportunities
rtk proxy <cmd>       # Execute raw command without filtering (for debugging)
```

## Hook-Based Usage

`git status` → `rtk git status` (transparent, 0 tokens overhead)
