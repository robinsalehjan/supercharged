# supercharged
A set of scripts wrapped neatly into a `Makefile` that I use to setup my MacBook for a developer-friendly environment.

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
xcodesorg/made/xcodes
tmux
spotify
aria2
k9s
xcode-build-server
xcbeautify
swiftlint
swiftformat
tree
```

Applications installed with `brew cask`
```
Wireshark
Google Cloud SDK
Docker
Visual Studio Code
Slack
Postman
Cursor
Raycast
Notion
```

Plugins installed with `asdf`
```
ruby
nodejs
python
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
