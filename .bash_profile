export LANG=en_US.UTF-8
export BASH_SILENCE_DEPRECATION_WARNING=1
export CLICOLOR=1
export LSCOLORS=ExFxBxDxCxegedabagacad
export PS1="\n\u@\h:\e[1;31m \w \[$(tput sgr0)\]"
export LDFLAGS="-L/usr/local/opt:$PATH"
export SSH_KEY_PATH="~/.ssh/"

export PATH="/usr/local/bin/sbin:$PATH"
export PATH="/usr/local/opt/openssl/bin:$PATH"
export PATH="~/google-cloud-sdk/bin:$PATH"

export CLOUDSDK_PYTHON=$(which python3)

