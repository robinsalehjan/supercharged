# Customization

## Interactive Options
During setup, you'll be asked about:
- **iOS Development Tools** [Y/n]: Xcode tools, Swift formatters, iOS deployment tools
- **Data Science Tools** [y/N]: Jupyter, pandas, numpy, matplotlib, scikit-learn
- **Additional Dev Tools** [Y/n]: Docker, Colima

Your preferences are saved to `~/.supercharged_preferences` and used during setup. These preferences include:
- `INSTALL_IOS_TOOLS`: Whether to install iOS development tools
- `INSTALL_DATA_SCIENCE`: Whether to install data science packages
- `INSTALL_DEV_TOOLS`: Whether to install Docker and Kubernetes tools
- `INSTALL_CLAUDE_CODE`: Whether to install Claude Code AI assistant
- `SETUP_DATE`: When the configuration was last set

## Manual Customization
Edit these files before running setup:

**`dot_files/.tool-versions`** - Add or modify development tool versions:
```bash
nodejs 22.9.0
python 3.13.0
ruby 2.7.7
bundler 2.2.32
gcloud 522.0.0
firebase 14.3.1
java openjdk-23.0.2
kotlin 2.2.21
# Add more tools as needed
```

**`dot_files/.zshrc`** - Customize shell configuration:
```bash
# Navigation aliases: ls, ll, la, cp, mv, mkdir, .., ..., ...., f, c, cdr, path
# Git aliases: gst, gd, gco, gcm, gcd, gcp, gl, gp, glog
# Docker aliases: d, dc
# Kubernetes aliases: k, kx
# Development aliases: py (python3), pip (pip3)
# macOS aliases: showfiles, hidefiles, cleanup

# Utility functions included:
# mkcd      - Create directory and cd into it
# extract   - Extract various archive formats
# docker-clean - Clean up Docker containers and images
# gb, gcb, gpus, gpul - Git branch utilities
```

**`scripts/mac.sh`** - Modify package installation lists:
```bash
# Edit BREWFILE_CONTENT to add/remove Homebrew packages
# Conditional sections based on INSTALL_IOS_TOOLS, INSTALL_DEV_TOOLS flags

# Core packages always installed:
# coreutils, git, curl, asdf, keychain, tmux, ripgrep, etc.

# iOS tools (conditional):
# xcodes, swift-format, swiftlint, ios-deploy, etc.

# Dev tools (conditional):
# docker, docker-compose, k9s, colima

# Apps always installed:
# VS Code, Slack, Postman, Raycast, Chrome, Wireshark, Spotify
```
