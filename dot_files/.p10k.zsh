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
  # Color Palette (Rainbow Theme)
  # ============================================================================
  # 0=black, 1=red, 2=green, 3=yellow, 4=blue, 5=purple, 6=cyan, 7=white
  # 8=gray, 254=light gray, 255=bright white

  # ============================================================================
  # Prompt Elements
  # ============================================================================

  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
    dir
    vcs
  )

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


  # ============================================================================
  # VCS (Git) Segment
  # ============================================================================

  typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND=0
  typeset -g POWERLEVEL9K_VCS_CLEAN_BACKGROUND=2

  # Modified/untracked/conflicted all use yellow (intentionally identical)
  typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND=0
  typeset -g POWERLEVEL9K_VCS_MODIFIED_BACKGROUND=3
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND=0
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_BACKGROUND=3
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

  typeset -g POWERLEVEL9K_STATUS_OK=false
  typeset -g POWERLEVEL9K_STATUS_OK_PIPE=false

  # All error states use red (intentionally identical)
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
