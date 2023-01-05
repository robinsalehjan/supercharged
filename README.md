# supercharged
This is a set of scripts wrapped up in a Makefile that I use to boost my MacBook environment for development. It will install the application and dependencies below via `homebrew` along with `python 2.7.18` and `python 3.10.6`. The google cloud sdk depends on python 3 so by default the global version of python will be set to `3.10.6` via `pyenv`.

This script will also configure your environment in the terminal with my `.bash_profile`.

```
git
openssl
libyaml
coreutils
keychain
htop
nmap
bash-completion
bash-git-prompt
rbenv
pyenv
nodenv
google-cloud-sdk
docker
tidal
fork
visual-studio-code
```

How to use
-------

```
git clone git@github.com:robinsalehjan/supercharged.git
cd supercharged && make setup
```

To supercharge the MacBook
```
make setup
```

To update installed apps and tools
```
make update
```
