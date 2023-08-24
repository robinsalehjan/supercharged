#!/bin/sh

eval "$(/opt/homebrew/bin/brew shellenv)"
eval "$(keychain --eval ~/.ssh/id)"
eval "$(rbenv init -)"
eval "$(nodenv init -)"
eval "$(pyenv init -)"

source ~/.sdkman/bin/sdkman-init.sh

if [[ -n $SSH_CONNECTION ]]; then
    export EDITOR='vim'
fi

if [ -f $(brew --prefix)/etc/bash_completion ]; then
  . "$(brew --prefix)/etc/bash_completion"
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

alias ls='ls -FGlAhp'
alias cp='cp -iv'
alias mv='mv -iv'
alias mkdir='mkdir -pv'
alias ..='cd ../'
alias f='open -a Finder ./'
alias c='clear'
alias cdr='cd ~/Repositories'

gb() {
  git branch;
}

gcb() {
  git checkout "$1"
}

gpus() {
  git push origin "$1"
}

gpul() {
  git pull origin "$1"
}

myps() {
  ps "$@" -u "$USER" -o pid,%cpu,%mem,start,time,bsdtime,command
}

code() {
  VSCODE_CWD="$PWD" open -n -b 'com.microsoft.VSCode' --args "$*"
}

clean_spm_caches() {
  echo 'Deleting SPM caches'
  rm -rf '~/Library/Caches/org.swift.swiftpm/*'
  echo 'Success!'
}

clean_xcode_builds() {
  echo 'Deleting DerivedData folder'
  rm -rf ~/Library/Developer/Xcode/DerivedData
  echo "Removing module cache"
  rm -rf "$(getconf DARWIN_USER_CACHE_DIR)/org.llvm.clang/ModuleCache"
  echo 'Success!'
}

clean_core_simulator() {
  echo 'Killing CoreSimulator zombie processes'
  pids=`ps axo pid,command | grep CoreSimulator | grep -v "grep CoreSimulator" | cut -c 1-5`

  if [ "$1" = "go" ]; then
    kill -9 $pids
  elif [ "$1" = "echo" ]; then
    echo $pids
  else
    pid_param=`echo $pids | tr -s ' ' ','`
    ps -p $pid_param -o pid,command
  fi

  echo 'Success!'
}

nuke_xcode() {
  killall Xcode > /dev/null
  clean_xcode_builds
  echo 'Removing developer tool caches'
  rm -rf ~/Library/Caches/com.apple.dt.Xcode
  clean_spm_caches
  clean_core_simulator
}
