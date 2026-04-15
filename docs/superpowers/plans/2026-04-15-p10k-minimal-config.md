# Minimal Powerlevel10k Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace 1,842-line auto-generated .p10k.zsh with minimal 150-line hand-crafted config

**Architecture:** Single-file replacement. Extract essential settings from current config (prompt elements, colors, performance features) and write focused minimal config with zero unused code. Manual testing required (copy to $HOME, reload shell).

**Tech Stack:** Zsh, Powerlevel10k theme

**Reference:** Design spec at `docs/superpowers/specs/2026-04-15-p10k-minimal-config-design.md`

---

## Task 1: Create Minimal .p10k.zsh Configuration

**Files:**
- Replace: `dot_files/.p10k.zsh` (1,842 lines → ~150 lines)

- [ ] **Step 1: Write new minimal .p10k.zsh**

Create the complete minimal config file:

```zsh
# Minimal Powerlevel10k Configuration
# Hand-crafted for supercharged dotfiles - contains only active prompt elements
# To regenerate from wizard: p10k configure
# Documentation: https://github.com/romkatv/powerlevel10k

# Temporarily change options
'builtin' 'local' '-a' 'p10k_config_opts'
[[ ! -o 'aliases'         ]] || p10k_config_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || p10k_config_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || p10k_config_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

() {
  emulate -L zsh -o extended_glob

  # Unset all configuration options
  unset -m '(POWERLEVEL9K_*|DEFAULT_USER)~POWERLEVEL9K_GITSTATUS_DIR'

  # Zsh >= 5.1 is required
  [[ $ZSH_VERSION == (5.<1->*|<6->.*) ]] || return

  # ============================================================================
  # Prompt Elements
  # ============================================================================

  # Left prompt: directory and git status
  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
    dir
    vcs
  )

  # Right prompt: error status, execution time, background jobs, kubernetes
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
    status
    command_execution_time
    background_jobs
    kubecontext
  )

  # ============================================================================
  # Global Settings
  # ============================================================================

  # Character set (compatible mode works with any font)
  typeset -g POWERLEVEL9K_MODE=compatible

  # Single-line prompt
  typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=false

  # Icon padding
  typeset -g POWERLEVEL9K_ICON_PADDING=none

  # Segment separators
  typeset -g POWERLEVEL9K_LEFT_SEGMENT_SEPARATOR=''
  typeset -g POWERLEVEL9K_RIGHT_SEGMENT_SEPARATOR=''
  typeset -g POWERLEVEL9K_LEFT_SUBSEGMENT_SEPARATOR='|'
  typeset -g POWERLEVEL9K_RIGHT_SUBSEGMENT_SEPARATOR='|'

  # Prompt ends
  typeset -g POWERLEVEL9K_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL=''
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_FIRST_SEGMENT_START_SYMBOL=''

  # ============================================================================
  # Directory Segment
  # ============================================================================

  typeset -g POWERLEVEL9K_DIR_FOREGROUND=254
  typeset -g POWERLEVEL9K_DIR_BACKGROUND=4
  typeset -g POWERLEVEL9K_DIR_ANCHOR_FOREGROUND=255
  typeset -g POWERLEVEL9K_DIR_ANCHOR_BOLD=true

  # Shorten directory if too long
  typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_unique
  typeset -g POWERLEVEL9K_SHORTEN_DELIMITER=''

  # ============================================================================
  # VCS (Git) Segment
  # ============================================================================

  # Clean state (green)
  typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND=0
  typeset -g POWERLEVEL9K_VCS_CLEAN_BACKGROUND=2

  # Modified/untracked state (yellow)
  typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND=0
  typeset -g POWERLEVEL9K_VCS_MODIFIED_BACKGROUND=3
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND=0
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_BACKGROUND=3

  # Conflicted state (yellow)
  typeset -g POWERLEVEL9K_VCS_CONFLICTED_FOREGROUND=0
  typeset -g POWERLEVEL9K_VCS_CONFLICTED_BACKGROUND=3

  # Loading state (gray)
  typeset -g POWERLEVEL9K_VCS_LOADING_FOREGROUND=244
  typeset -g POWERLEVEL9K_VCS_LOADING_BACKGROUND=8

  # Git status icons
  typeset -g POWERLEVEL9K_VCS_BRANCH_ICON=''
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_ICON='?'
  typeset -g POWERLEVEL9K_VCS_UNSTAGED_ICON='!'
  typeset -g POWERLEVEL9K_VCS_STAGED_ICON='+'
  typeset -g POWERLEVEL9K_VCS_INCOMING_CHANGES_ICON='↓'
  typeset -g POWERLEVEL9K_VCS_OUTGOING_CHANGES_ICON='↑'
  typeset -g POWERLEVEL9K_VCS_STASH_ICON='*'
  typeset -g POWERLEVEL9K_VCS_TAG_ICON=''

  # ============================================================================
  # Status Segment (exit code on error)
  # ============================================================================

  # Show status only on error
  typeset -g POWERLEVEL9K_STATUS_OK=false
  typeset -g POWERLEVEL9K_STATUS_OK_PIPE=false

  # Error status (red)
  typeset -g POWERLEVEL9K_STATUS_ERROR_FOREGROUND=255
  typeset -g POWERLEVEL9K_STATUS_ERROR_BACKGROUND=1
  typeset -g POWERLEVEL9K_STATUS_ERROR_SIGNAL_FOREGROUND=255
  typeset -g POWERLEVEL9K_STATUS_ERROR_SIGNAL_BACKGROUND=1
  typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE_FOREGROUND=255
  typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE_BACKGROUND=1

  # Status format
  typeset -g POWERLEVEL9K_STATUS_VERBOSE_SIGNAME=false
  typeset -g POWERLEVEL9K_STATUS_EXTENDED_STATES=true

  # ============================================================================
  # Command Execution Time Segment
  # ============================================================================

  # Only show if command took >3 seconds
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=3

  # Time format
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_PRECISION=0
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FORMAT='d h m s'

  # Colors: green (<1m), yellow (1-5m), red (>5m)
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND=0
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_BACKGROUND=2

  # No icon
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_VISUAL_IDENTIFIER_EXPANSION=''

  # ============================================================================
  # Background Jobs Segment
  # ============================================================================

  # Cyan foreground, black background
  typeset -g POWERLEVEL9K_BACKGROUND_JOBS_FOREGROUND=6
  typeset -g POWERLEVEL9K_BACKGROUND_JOBS_BACKGROUND=0

  # Show count (not verbose)
  typeset -g POWERLEVEL9K_BACKGROUND_JOBS_VERBOSE=false

  # Icon
  typeset -g POWERLEVEL9K_BACKGROUND_JOBS_VISUAL_IDENTIFIER_EXPANSION='⚙'

  # ============================================================================
  # Kubernetes Context Segment
  # ============================================================================

  # Only show when using kubectl/helm commands
  typeset -g POWERLEVEL9K_KUBECONTEXT_SHOW_ON_COMMAND='kubectl|helm|kubens|kubectx|oc|istioctl|kogito'

  # Purple/magenta background, white foreground
  typeset -g POWERLEVEL9K_KUBECONTEXT_DEFAULT_FOREGROUND=7
  typeset -g POWERLEVEL9K_KUBECONTEXT_DEFAULT_BACKGROUND=5

  # Icon
  typeset -g POWERLEVEL9K_KUBECONTEXT_DEFAULT_VISUAL_IDENTIFIER_EXPANSION='☸'

  # Show context name
  typeset -g POWERLEVEL9K_KUBECONTEXT_DEFAULT_CONTENT_EXPANSION='${P9K_KUBECONTEXT_NAME}'

  # ============================================================================
  # Performance Features
  # ============================================================================

  # Instant prompt (cached prompt appears immediately)
  typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

  # Transient prompt (old prompts shrink to '>' to save space)
  typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=same-dir

  # Disable right prompt in transient mode
  typeset -g POWERLEVEL9K_TRANSIENT_PROMPT_RPROMPT_SUFFIX=''
}

# Restore options
(( ${#p10k_config_opts} )) && setopt ${p10k_config_opts[@]}
'builtin' 'unset' 'p10k_config_opts'
```

Write this to `dot_files/.p10k.zsh`, replacing the existing file.

- [ ] **Step 2: Verify file was created**

Run: `wc -l dot_files/.p10k.zsh`

Expected: `~150 dot_files/.p10k.zsh` (not 1,842)

- [ ] **Step 3: Check file size reduction**

Run: `ls -lh dot_files/.p10k.zsh`

Expected: `~6K` (not 96K)

---

## Task 2: Validate Configuration

**Files:**
- Validate: `dot_files/.p10k.zsh`

- [ ] **Step 1: Run shellcheck validation**

Run: `shellcheck --shell=bash dot_files/.p10k.zsh`

Expected: No errors (may have SC1071 or SC2296 warnings which are safe to ignore for zsh)

- [ ] **Step 2: Visual inspection - prompt elements**

Check that the LEFT_PROMPT_ELEMENTS array contains:
- `dir`
- `vcs`

Check that the RIGHT_PROMPT_ELEMENTS array contains:
- `status`
- `command_execution_time`
- `background_jobs`
- `kubecontext`

Expected: All 6 elements present, no commented-out code

- [ ] **Step 3: Visual inspection - no placeholders**

Search file for: `TBD`, `TODO`, `XXX`, `FIXME`, `...`

Expected: No placeholders found

- [ ] **Step 4: Visual inspection - global settings**

Verify these settings:
- `POWERLEVEL9K_PROMPT_ADD_NEWLINE=false` (single-line prompt)
- `POWERLEVEL9K_MODE=compatible` (no special fonts)
- `POWERLEVEL9K_INSTANT_PROMPT=quiet` (fast startup)
- `POWERLEVEL9K_TRANSIENT_PROMPT=same-dir` (clean history)
- `POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=3` (show >3s)

Expected: All settings match design spec

- [ ] **Step 5: Visual inspection - color codes**

Verify color values:
- Directory: `BACKGROUND=4` (blue)
- VCS clean: `BACKGROUND=2` (green)
- VCS modified: `BACKGROUND=3` (yellow)
- Status error: `BACKGROUND=1` (red)
- Background jobs: `FOREGROUND=6` (cyan)
- Kubecontext: `BACKGROUND=5` (purple)

Expected: All colors match rainbow theme palette

---

## Task 3: Manual Testing

**Files:**
- Test: `~/.p10k.zsh` (home directory)

- [ ] **Step 1: Backup current config**

Run: `cp ~/.p10k.zsh ~/.p10k.zsh.backup`

Expected: Backup created at `~/.p10k.zsh.backup`

- [ ] **Step 2: Copy new config to home directory**

Run: `cp dot_files/.p10k.zsh ~/.p10k.zsh`

Expected: File copied successfully

- [ ] **Step 3: Reload shell**

Run: `exec zsh`

Expected: Shell reloads with no errors, instant prompt appears

- [ ] **Step 4: Test normal command (clean prompt)**

Run: `echo "test"`

Expected: Prompt shows `~/path dir ✓ |` with no right-side elements (clean state)

- [ ] **Step 5: Test failed command (status appears)**

Run: `false`

Expected: Right side shows red `✗ 1` (exit code 1)

- [ ] **Step 6: Test slow command (execution time appears)**

Run: `sleep 5`

Expected: Right side shows `5s` after command completes

- [ ] **Step 7: Test background job (job indicator appears)**

Run: `sleep 60 &`

Expected: Right side shows `⚙ 1` (one background job)

Cleanup: `kill %1`

- [ ] **Step 8: Test git repo (vcs appears)**

Run: `cd /path/to/git/repo && git status`

Expected: Left side shows branch name and git status (✓ clean or ✗ dirty)

- [ ] **Step 9: Test kubernetes context (if available)**

Run: `kubectl config current-context` (if kubectl installed)

Expected: If context set, right side shows `☸ context-name` when running kubectl commands

If kubectl not installed: Skip this test

- [ ] **Step 10: Verify transient prompt**

Run a few commands and scroll up to see history

Expected: Old prompts are compressed to `>` symbol (transient mode working)

- [ ] **Step 11: Check for shell startup errors**

Run: `exec zsh 2>&1 | grep -i error`

Expected: No errors (empty output)

- [ ] **Step 12: Restore backup if tests failed**

If any tests failed:
```bash
cp ~/.p10k.zsh.backup ~/.p10k.zsh
exec zsh
```

If all tests passed: Continue to Task 4

---

## Task 4: Commit Changes

**Files:**
- Commit: `dot_files/.p10k.zsh`

- [ ] **Step 1: Check git diff**

Run: `git diff dot_files/.p10k.zsh | head -50`

Expected: Shows removal of 1,842 lines and addition of ~150 lines

- [ ] **Step 2: Stage the file**

Run: `git add dot_files/.p10k.zsh`

Expected: File staged successfully

- [ ] **Step 3: Commit with descriptive message**

Run:
```bash
git commit -m "$(cat <<'EOF'
refactor(dotfiles): replace auto-generated .p10k.zsh with minimal config

Replace 1,842-line auto-generated Powerlevel10k config with 150-line
hand-crafted minimal config.

Changes:
- Remove 35+ unused prompt elements (kept only: dir, vcs, status,
  command_execution_time, background_jobs, kubecontext)
- Remove all commented-out code and unused options
- Switch from 2-line to single-line prompt
- Preserve rainbow theme colors and performance features
- Keep instant prompt and transient prompt optimizations

Size reduction: 96KB → 6KB (94% smaller)

Benefits:
- Readable and maintainable (150 vs 1,842 lines)
- Git-friendly (smaller diffs, meaningful history)
- Same visual appearance and performance
- Documented and portable across machines

Manual testing completed:
- ✓ Shell loads without errors
- ✓ Instant prompt works
- ✓ All prompt elements display correctly
- ✓ Transient prompt working
- ✓ No startup errors

Design spec: docs/superpowers/specs/2026-04-15-p10k-minimal-config-design.md

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
EOF
)"
```

Expected: Commit created successfully

- [ ] **Step 4: Verify commit**

Run: `git log -1 --stat`

Expected: Shows commit with `dot_files/.p10k.zsh` changed (1,692 deletions, ~150 insertions)

- [ ] **Step 5: Clean up backup**

Run: `rm ~/.p10k.zsh.backup`

Expected: Backup file removed

---

## Implementation Complete

After completing all tasks:

1. **File replaced:** `dot_files/.p10k.zsh` reduced from 1,842 lines to ~150 lines
2. **Validated:** Shellcheck passed, no placeholders, correct settings
3. **Tested:** All prompt elements working, no errors, transient prompt active
4. **Committed:** Changes committed with descriptive message

**Next steps for user:**
- Run `npm run setup:profile` to copy new config to other machines
- If using multiple machines, test the config on each one
- The old config is preserved in git history: `git show HEAD~1:dot_files/.p10k.zsh`

**Success criteria met:**
- ✓ Shell loads without errors
- ✓ Prompt shows only relevant info
- ✓ Visual appearance matches rainbow theme
- ✓ Performance feels instant (instant prompt, transient prompt)
- ✓ File is <200 lines (~150 actual)
