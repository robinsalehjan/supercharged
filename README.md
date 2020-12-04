# supercharged
supercharged is a script to set up any MacBook with my developer tools and applications.

It can be run multiple times on the same machine safely.
It installs, upgrades, or skips packages
based on what is already installed on the machine.

Install
-------

Download the script and in the terminal type:

```sh
./init.sh
```

Update
------

To update all the installed dependencies run the `update.sh` script by typing in the terminal 

```sh
./update.sh
```

What it sets up
---------------

Terminal tools:
* `Homebrew`
* `Git` for version control
* `OpenSSL` for Transport Layer Security (TLS)
* `keychain` for automatically starting ssh-agent and add public keys
* `htop` for interactively process monitoring
* `nmap` for network exploration and port scanning
* `bash-completion` collection of command line helpers 
* `bash-git-prompt` A bash prompt that displays information about the current git repository
* `pyenv` python environment manager
* `rbenv` ruby environment manager
* `mas` for installing mac applications from the command line
* `google-cloud-sdk` for access to GCP

Applications:
* `docker + virtualbox` for container virtualization
* `tidal` for music
* `fork` Friendly interface for git
* `insomnia` instead of postman
* `visual-studio-code` lightweight editor
* `slack` Modern day jabber


App store:
* `mas install 497799835` Xcode for MacOS/iOS development
* `mas install 1000397973` Wallcat for day by day changing backgrounds
* `mas install 960276676` Taurine to keep the mac sleepless forever
* `mas install 441258766` Magnet to pin to windows however you like  
* `mas install 409203825` Numbers for accounting and charts
* `mas install 668208984` Giphy for recording and creating gifs
