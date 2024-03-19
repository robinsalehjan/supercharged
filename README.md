# supercharged
A set of scripts wrapped up in a Makefile that I use to boost my MacBook environment for development. It will install application and dependencies listed down below with `homebrew` along with customizing your environment profile.

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
