eval "$(/opt/homebrew/bin/brew shellenv)"
eval $(keychain --eval ~/.ssh/id)
eval "$(rbenv init -)"
eval "$(nodenv init -)"
eval "$(pyenv init -)"

if [[ -n $SSH_CONNECTION ]]; then
    export EDITOR='vim'
fi

if [ -f $(brew --prefix)/etc/bash_completion ]; then
  . $(brew --prefix)/etc/bash_completion
fi

[[ -s `brew --prefix`/etc/autojump.sh ]] && . `brew --prefix`/etc/autojump.sh
[ -f /usr/local/etc/bash_completion ] && . /usr/local/etc/bash_completion

if [ -f /usr/local/share/gitprompt.sh ]; then
  GIT_PROMPT_THEME=Default
  . /usr/local/share/gitprompt.sh
fi

if [ -f "$(brew --prefix)/opt/bash-git-prompt/share/gitprompt.sh" ]; then
  __GIT_PROMPT_DIR=$(brew --prefix)/opt/bash-git-prompt/share
  source "$(brew --prefix)/opt/bash-git-prompt/share/gitprompt.sh"
fi

alias ls="ls -lGp"
alias ll="ls -FGlAhp"
alias la="ls -a -Gp"
alias cp="cp -iv"
alias mv="mv -iv"
alias mkdir="mkdir -pv"
alias ..="cd ../"
alias f="open -a Finder ./"
alias c="clear"
alias cdr="cd ~/Repositories"

gb() { git branch; }
gcb() { git checkout "$1"; }
gpus() { git push origin "$1"; }
gpul() { git pull origin "$1"; }
cd() { builtin cd "$@"; ll; }
mcd () { mkdir -p "$1" && cd "$1"; }
myps() { ps $@ -u $USER -o pid,%cpu,%mem,start,time,bsdtime,command ; }
cleandd() { rm -rf ~/Library/Developer/Xcode/DerivedData/**; }
code () { VSCODE_CWD="$PWD" open -n -b "com.microsoft.VSCode" --args $* ;}