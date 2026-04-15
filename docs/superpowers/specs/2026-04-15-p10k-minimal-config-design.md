# Powerlevel10k Minimal Configuration Design

**Date:** 2026-04-15  
**Status:** Approved  
**Goal:** Replace 1,842-line auto-generated `.p10k.zsh` with minimal hand-crafted config

## Problem

Current `.p10k.zsh` file issues:
- **Size:** 96KB / 1,842 lines (71% of all dotfile content)
- **Bloat:** Contains 40+ prompt elements, only using 2
- **Maintainability:** Auto-generated with hundreds of commented options
- **Git diffs:** Changes are noisy and hard to review
- **Philosophy mismatch:** Supercharged repo aims for portable, reproducible dotfiles - the current config is neither readable nor maintainable

## Solution: Hand-Crafted Minimal Config

Replace with ~120-150 line file containing only:
- Active prompt elements (6 total: dir, vcs on left; status, command_execution_time, background_jobs, kubecontext on right)
- Essential styling from rainbow theme
- Performance optimizations
- Zero unused code or comments

### Size Comparison
- **Before:** 96KB / 1,842 lines
- **After:** ~6KB / 120-150 lines
- **Reduction:** 94% smaller

## Design

### File Structure

```
1. Header comment (5 lines)
   - What this file is
   - How to regenerate if needed
   - Reference to p10k docs

2. Powerlevel10k boilerplate (5 lines)
   - Options preservation
   - Version check

3. Main configuration function (100-130 lines)
   a. Prompt element arrays (LEFT and RIGHT)
   b. Global style settings (single-line, icons, separators)
   c. Per-segment configuration (dir, vcs, status, etc.)
   d. Transient prompt settings

4. Footer (5 lines)
   - Restore shell options
```

### Prompt Layout

**Single-line prompt** with conditional right-side elements:

**Left side (always visible):**
1. `dir` - current directory with smart truncation
2. `vcs` - git branch + status (✓ clean, ✗ dirty with file count)

**Right side (conditional - only show when relevant):**
1. `status` - exit code (only appears on command failure)
2. `command_execution_time` - duration (only if >3 seconds)
3. `background_jobs` - count (only if background jobs exist)
4. `kubecontext` - kubernetes cluster (only if kubectl context set)

**Example states:**

Normal successful command:
```
~/code/supercharged main ✓ |
```

Slow command (>3s):
```
~/code/supercharged main ✓ | 12s |
```

Failed command with background jobs in k8s context:
```
~/code/supercharged main ✓ | ✗ 1 12s ⚙ 2 ☸ prod-cluster |
```

### Visual Styling

**Colors (rainbow theme palette):**
- Directory: blue background (#005FD7)
- Git clean: green background (#00AF5F)
- Git dirty: yellow background (#FFD700)
- Error status: red background (#D70000)
- Command time: green (<1m), yellow (1-5m), red (>5m)
- Background jobs: cyan
- Kubernetes: purple

**Layout:**
- Single-line prompt (no newlines, no box characters `╭─╰─`)
- Simple `|` separators between segments
- Compatible mode (no special font glyphs required)
- Right prompt auto-hides if line is too long (prevents wrapping)

### Performance Features

1. **Instant prompt:** Cached prompt appears immediately on shell startup
2. **Transient prompt:** After command execution, old prompt shrinks to `>` to save screen space
3. **Gitstatus:** Fast native git status checking (no shell git commands)
4. **Conditional rendering:** Right-side elements only compute when needed

**Key settings:**
```
POWERLEVEL9K_MODE=compatible          # No special fonts needed
POWERLEVEL9K_PROMPT_ADD_NEWLINE=false # Single line
POWERLEVEL9K_TRANSIENT_PROMPT=same-dir # Clean history
POWERLEVEL9K_INSTANT_PROMPT=quiet     # Fast startup
POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=3  # Only show >3s
```

### Removed Elements

The following 35+ prompt elements are removed (were in original config, never used):
- Language version managers: pyenv, nodenv, nvm, rbenv, rvm, goenv, etc.
- Cloud providers: aws, azure, gcloud (keeping kubecontext only)
- ASDF version display (redundant - shown in project's .tool-versions)
- Shell indicators: vim_shell, ranger, nnn, lf, xplr, etc.
- Time tracking: todo, timewarrior, taskwarrior
- System stats: load, disk_usage, ram, swap
- Network: ip, public_ip, vpn_ip, wifi
- Battery, cpu_arch, proxy, etc.

## Implementation Approach

### Phase 1: Create Minimal Config
1. Read current `.p10k.zsh` to extract active color values
2. Write new minimal config with:
   - Header documenting purpose and regeneration steps
   - Powerlevel10k boilerplate (options preservation)
   - Prompt element arrays (left: dir, vcs | right: status, command_execution_time, background_jobs, kubecontext)
   - Global settings (single-line, compatible mode, instant prompt, transient prompt)
   - Per-segment styling (colors for each element)
   - Footer (restore options)

### Phase 2: Validation
1. Shellcheck validation (ensure no syntax errors)
2. Visual inspection of key sections:
   - Prompt element arrays are correct
   - Color codes are valid
   - No commented-out code
   - No placeholder values (TBD, TODO, etc.)

### Phase 3: Git Operations
1. Replace `dot_files/.p10k.zsh` with new minimal version
2. Commit with message documenting the change
3. Update `.gitignore` if needed (ensure p10k cache files are ignored)

## Testing Strategy

**Manual testing after implementation:**
1. Copy new `.p10k.zsh` to `$HOME`
2. Reload shell: `exec zsh`
3. Verify instant prompt works
4. Test prompt elements:
   - Normal command → clean prompt
   - Failed command → red error status appears
   - Slow command (`sleep 5`) → execution time appears
   - Background job (`sleep 60 &`) → job indicator appears
   - Kubernetes context (if available) → context appears
   - Git repo → branch and status appear
5. Verify transient prompt (old prompts shrink to `>`)
6. Check no errors in shell startup

**Success criteria:**
- Shell loads without errors
- Prompt shows only relevant info
- Visual appearance matches rainbow theme
- Performance feels instant
- File is <200 lines

## Rollback Plan

If the new config has issues:
1. The old config is preserved in git history
2. Can restore with: `git checkout HEAD~1 dot_files/.p10k.zsh`
3. Copy to home: `cp dot_files/.p10k.zsh ~/.p10k.zsh`
4. Reload shell: `exec zsh`

Alternatively, regenerate from wizard:
```bash
p10k configure
```

## Documentation Updates

No changes needed to:
- README.md (already documents .p10k.zsh as a dotfile)
- CLAUDE.md (no code conventions affected)
- AGENTS.md (no testing patterns affected)

Optional: Add comment in README.md under "Configuration Files" section noting that .p10k.zsh is minimal hand-crafted config.

## Non-Goals

**Not changing:**
- Other dotfiles (.zshrc, .tmux.conf, etc.) - they're already well-sized
- .gitignore patterns - already comprehensive
- Powerlevel10k theme itself - keeping rainbow theme, just minimizing config

**Not doing:**
- Git-ignoring .p10k.zsh (defeats reproducibility)
- Switching away from Powerlevel10k (it's performant and feature-rich)
- Adding new prompt features (staying minimal)

## Benefits

1. **Readability:** Anyone can understand the entire config in 2 minutes
2. **Maintainability:** Changes are obvious and reviewable
3. **Performance:** Faster parsing, instant startup
4. **Git hygiene:** Smaller diffs, meaningful history
5. **Philosophy alignment:** Matches supercharged's portable, reproducible approach
6. **Size:** 94% reduction frees up mental space and disk space

## Risks & Mitigations

**Risk:** User wants to add new prompt elements later  
**Mitigation:** Document how to add elements (reference p10k docs), or re-run `p10k configure` and cherry-pick

**Risk:** Color codes might not match current theme exactly  
**Mitigation:** Extract exact color codes from current config during implementation

**Risk:** New config doesn't work on fresh install  
**Mitigation:** Test in clean shell, verify all required variables are set

**Risk:** Powerlevel10k updates change API  
**Mitigation:** Config is simple enough to update manually, pin p10k version in Brewfile if needed
