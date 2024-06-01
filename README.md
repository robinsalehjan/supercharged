# supercharged
A set of scripts wrapped up in a Makefile that I use to boost my MacBook environment for development. It will install application and dependencies listed down below with `homebrew` along with customizing your environment profile.

Packages installed with `brew`
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
asdf
xcodes
kubectl
kubectx
pack
tmux
spotify
swiftlint
```

Casks installed with `brew`
```
copilot-for-xcode
wireshark
google-cloud-sdk
docker
fork
visual-studio-code
slack
postman
```

Plugins installed with `asdf`
```
ruby
nodejs
deno
python
java
direnv
```

## Supercharging your MacBook
```
git clone git@github.com:robinsalehjan/supercharged.git
cd supercharged && make setup
```

## To update all the installed apps and tools
```
make update
```
