# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Set ZSH path first
export ZSH="$HOME/.oh-my-zsh"

# Initialize Homebrew (Apple Silicon)
eval "$(/opt/homebrew/bin/brew shellenv)"

# Terminal improvements
export CLICOLOR=1
export LSCOLORS=ExFxBxDxCxegedabagacad
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# History settings
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY          # Write the history file in the ":start:elapsed;command" format.
setopt INC_APPEND_HISTORY       # Write to the history file immediately, not when the shell exits.
setopt SHARE_HISTORY           # Share history between all sessions.
setopt HIST_IGNORE_ALL_DUPS    # Delete old recorded entry if new entry is a duplicate.

# Source ASDF after Homebrew is initialized
if [ -f "$(brew --prefix asdf)/libexec/asdf.sh" ]; then
    source "$(brew --prefix asdf)/libexec/asdf.sh"
fi

# Set JAVA_HOME if Java is installed via ASDF
if command -v asdf >/dev/null 2>&1 && asdf where java >/dev/null 2>&1; then
    export JAVA_HOME=$(asdf where java)
fi

# Set KOTLIN_HOME if Kotlin is installed via ASDF
if command -v asdf >/dev/null 2>&1 && asdf where kotlin >/dev/null 2>&1; then
    export KOTLIN_HOME=$(asdf where kotlin)
fi

# Function to deduplicate PATH
deduplicate_path() {
    local IFS=':'
    local path_array=($PATH)
    local new_path=""
    local seen=""

    for dir in "${path_array[@]}"; do
        # Only check if the directory is not empty and not already seen
        # Don't filter based on directory existence to avoid removing essential system paths
        if [[ -n "$dir" ]] && [[ ! "$seen" =~ (^|:)"$dir"(:|$) ]]; then
            if [ -z "$new_path" ]; then
                new_path="$dir"
            else
                new_path="$new_path:$dir"
            fi
            seen="$seen:$dir"
        fi
    done
    echo "$new_path"
}

# Set PATH after ASDF is loaded
path=(
    $HOME/.asdf/shims       # ASDF shims first
    $HOME/.local/bin        # Local user binaries
    /opt/homebrew/bin       # Apple Silicon Homebrew
    /opt/homebrew/sbin
    /usr/local/bin          # Intel Homebrew (for compatibility)
    /usr/local/sbin
    /usr/bin                # Essential system binaries
    /usr/sbin               # Essential system admin binaries
    /bin                    # Core system binaries
    /sbin                   # Core system admin binaries
    $path                   # Preserve existing path entries
)

# Export the deduplicated PATH (only once per session for performance)
if [ -z "$_SUPERCHARGED_PATH_DEDUPED" ]; then
    export PATH=$(deduplicate_path)
    export _SUPERCHARGED_PATH_DEDUPED=1
fi

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
zstyle ':omz:update' frequency 14

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git asdf zsh-autosuggestions zsh-syntax-highlighting gcloud docker tmux)

source $ZSH/oh-my-zsh.sh

# Source secrets file with validation warning if unconfigured
if [ -f ~/.secrets ]; then
    # Check if secrets file has at least one uncommented export with a value
    # Matches: export VAR="value" or export VAR='value'
    if ! grep -qE "^export [A-Za-z_][A-Za-z0-9_]*=[\"'][^\"']+[\"']" ~/.secrets 2>/dev/null; then
        echo "⚠️  Warning: ~/.secrets appears to be unconfigured (template only)"
    fi
    source ~/.secrets
fi

# SSH key management
# Start ssh-agent if not already running
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)"
fi

# Ensure proper permissions on SSH directory if it exists
if [ -d "$HOME/.ssh" ]; then
    chmod 700 "$HOME/.ssh"

    # Set proper permissions for specific SSH key types
    for key in id_rsa id_ed25519 id_ecdsa; do
        [ -f "$HOME/.ssh/$key" ] && chmod 600 "$HOME/.ssh/$key"
        [ -f "$HOME/.ssh/$key.pub" ] && chmod 644 "$HOME/.ssh/$key.pub"
    done
fi

# Ensure .keychain directory has proper permissions if it exists
[ -d "$HOME/.keychain" ] && chmod -R go-rwx "$HOME/.keychain"

# Load SSH key using keychain - prefer ed25519, then rsa, then ecdsa
if command -v keychain >/dev/null 2>&1; then
    if [ -f "$HOME/.ssh/id_ed25519" ]; then
        eval "$(keychain --eval --quiet $HOME/.ssh/id_ed25519)"
    elif [ -f "$HOME/.ssh/id_rsa" ]; then
        eval "$(keychain --eval --quiet $HOME/.ssh/id_rsa)"
    elif [ -f "$HOME/.ssh/id_ecdsa" ]; then
        eval "$(keychain --eval --quiet $HOME/.ssh/id_ecdsa)"
    fi
fi

if [[ -n $SSH_CONNECTION ]]; then
   export EDITOR='vim'
elif command -v code >/dev/null 2>&1; then
   export EDITOR='code --wait'
else
   export EDITOR='vim'
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Navigation
alias ls='ls -FGlAhp'
alias ll='ls -laF'
alias la='ls -lAF'
alias cp='cp -iv'
alias mv='mv -iv'
alias mkdir='mkdir -pv'
alias ..='cd ../'
alias ...='cd ../../'
alias ....='cd ../../../'
alias f='open -a Finder ./'
alias c='clear'
alias cdr='cd $HOME/Repositories'
alias path='echo -e ${PATH//:/\\n}'  # Print each PATH entry on a new line

# Development
alias d='docker'
alias dc='docker-compose'
alias k='kubectl'
alias kx='kubectx'
alias py='python3'
alias pip='pip3'

# Git shortcuts
alias gst='git status'
alias gd='git diff'
alias gco='git checkout'
alias gcm='git checkout main'
alias gcd='git checkout develop'
alias gcp='git cherry-pick'
alias gl='git pull'
alias gp='git push'
alias glog='git log --oneline --decorate --graph'

# macOS specific
alias showfiles="defaults write com.apple.finder AppleShowAllFiles YES && killall Finder"
alias hidefiles="defaults write com.apple.finder AppleShowAllFiles NO && killall Finder"
alias cleanup="find . -name '.DS_Store' -type f -delete"

# Functions
function mkcd() {
    mkdir -p "$1" && cd "$1"
}

function extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2)   tar xjf "$1"     ;;
            *.tar.gz)    tar xzf "$1"     ;;
            *.bz2)       bunzip2 "$1"     ;;
            *.rar)       unrar e "$1"     ;;
            *.gz)        gunzip "$1"      ;;
            *.tar)       tar xf "$1"      ;;
            *.tbz2)      tar xjf "$1"     ;;
            *.tgz)       tar xzf "$1"     ;;
            *.zip)       unzip "$1"       ;;
            *.Z)         uncompress "$1"  ;;
            *.7z)        7z x "$1"        ;;
            *)          echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Git functions
function gb() { git branch; }
function gcb() { git checkout "$1"; }
function gpus() { git push origin "$1"; }
function gpul() { git pull origin "$1"; }

# Docker cleanup
function docker-clean() {
    docker container prune -f
    docker image prune -f
    docker network prune -f
    docker volume prune -f
}

# Process management
function myps() {
    ps "$@" -u "$USER" -o pid,%cpu,%mem,start,time,bsdtime,command
}

# VSCode
function code() {
    VSCODE_CWD="$PWD" open -n -b 'com.microsoft.VSCode' --args "$*"
}

# Check if command exists
function exists() {
    command -v "$1" >/dev/null 2>&1
}

# Auto-start Colima if installed and not running
# Set to 1 to enable auto-start (opt-in for performance)
# Example: export SUPERCHARGED_COLIMA_AUTOSTART=1 in ~/.secrets
if [[ "${SUPERCHARGED_COLIMA_AUTOSTART:-0}" == "1" ]] && command -v colima >/dev/null 2>&1; then
    colima_status=$(colima status 2>&1)
    if [[ "$colima_status" != *"colima is running"* ]]; then
        colima start >/dev/null 2>&1 &!
    fi
fi

# VSCode shell integration
[[ "$TERM_PROGRAM" == "vscode" ]] && . "$(/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code --locate-shell-integration-path zsh)"
