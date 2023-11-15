# supercharged
This is a set of scripts wrapped up in a Makefile that I use to boost my MacBook environment for development. It will install the application and dependencies below via `homebrew` along with `python 2.7.18` and `python 3.10.6`. The google cloud sdk depends on python 3 so by default the global version of python will be set to `3.10.6` via `pyenv`.

This script will also configure your environment in the terminal with my `.bash_profile`.

```
coreutils
git
curl
openssl@3
readline
libyaml
gmp
keychain
htop
nmap
bash-completion
bash-git-prompt
asdf
xcodesorg/made/xcodes
kubectl
kubectx

wireshark
google-cloud-sdk
docker
tidal
fork
visual-studio-code
slack
postman
```

To supercharge your MacBook for the first time
```
git clone git@github.com:robinsalehjan/supercharged.git
cd supercharged && make setup
```

To update all the installed apps and tools
```
make update
```
