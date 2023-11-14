#!/bin/bash

export LANG=en_US.UTF-8
export BASH_SILENCE_DEPRECATION_WARNING=1
export HOMEBREW_NO_ANALYTICS=1
export ASDF_FORCE_PREPEND=yes
export CLICOLOR=1
export LSCOLORS=ExFxBxDxCxegedabagacad
export PS1='\n\u@\h:\e[1;31m \w \[$(tput sgr0)\]'
export LDFLAGS="-L/usr/local/opt:$PATH"
export SSH_KEY_PATH='~/.ssh/'
export CLOUDSDK_PYTHON="$(which python3)"
export PATH="/usr/local/bin/sbin:/usr/local/opt/openssl/bin:/opt/homebrew/opt/coreutils/libexec/gnubin:~/google-cloud-sdk/bin:$PATH"

source "/opt/homebrew/opt/asdf/libexec/asdf.sh"
source "/opt/homebrew/opt/asdf/etc/bash_completion.d/asdf.bash"
source ~/.bashrc
test -f ~/.secrets && source ~/.secrets