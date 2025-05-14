# supercharged
A set of scripts wrapped neatly into a `Makefile` that I use to setup my MacBook for a developer-friendly environment.

Packages installed with `brew`
```bash
coreutils
git
curl
openssl@3
readline
libyaml
gmp
ripgrep
asdf
xcodesorg/made/xcodes
xcode-build-server
xcbeautify
swiftlint
tree
keychain
htop
nmap
tmux
k9s
aria2
spotify
```

Applications installed with `brew cask`
```bash
wireshark
docker
visual-studio-code
slack
postman
raycast
notion
```

Plugins installed with `asdf` (with default versions)
```bash
nodejs   22.9.0
python   3.13.0
ruby     2.7.7
gcloud   522.0.0
firebase 14.3.1
```

Additional enhancements to `ZSH`:
```bash
zsh-autosuggestions
zsh-syntax-highlighting
powerlevel10k
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
