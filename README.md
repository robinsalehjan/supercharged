# supercharged
A comprehensive set of scripts wrapped in a `Makefile` for setting up a developer-friendly macOS environment with enhanced security, performance, and customization options.

## 🚀 Features

- **Interactive Setup**: Customize your installation based on your development needs
- **Enhanced Security**: Secure SSH key management and git configuration templating
- **Smart Recovery**: Automatic backup and restoration points for safe rollbacks
- **Performance Optimized**: PATH deduplication and efficient installation processes
- **Comprehensive Logging**: Structured logging with different levels for better debugging
- **System Validation**: Pre-installation checks for compatibility and requirements

## 📋 System Requirements

- **macOS**: 12.0 (Monterey) or later
- **Disk Space**: At least 10GB free space
- **Internet**: Active internet connection required
- **Xcode Command Line Tools**: Will be installed automatically if missing

## 🛠 What Gets Installed

### Core Development Tools
```bash
# Package managers and build tools
coreutils, git, curl, openssl@3, readline, libyaml, gmp
asdf (version manager), keychain, htop, nmap, tree, ripgrep, tmux, aria2

# Development languages (via asdf)
nodejs   22.9.0  # LTS version, minimum 20.0.0 for modern features
python   3.13.0  # Latest stable, minimum 3.10.0 for type hints and match statements
ruby     2.7.7   # Stable version, minimum 2.7.0 for pattern matching
bundler  2.2.32  # Ruby package manager, minimum 2.2.0 for lockfile improvements
gcloud   522.0.0 # Latest stable, minimum 400.0.0 for gke-gcloud-auth-plugin
firebase 14.3.1  # Latest stable, minimum 12.0.0 for modern deployment features
```

### iOS Development Tools
```bash
# Xcode management and Swift tools (tap: xcodesorg/made)
xcodes              # Xcode version manager
xcode-build-server  # Build server for Xcode projects
xcbeautify          # Beautify Xcode build logs
swiftlint           # Swift linting
swift-format        # Swift code formatting
ios-deploy          # Deploy iOS apps from command line
```

### Development Tools
```bash
# Container and Kubernetes tools
k9s             # Kubernetes CLI manager
docker-desktop  # Docker desktop application
```

### Applications
```bash
# Development and productivity
visual-studio-code  # Code editor
slack              # Team communication
postman            # API development
raycast            # macOS productivity launcher

# Utilities
wireshark  # Network protocol analyzer
spotify    # Music streaming
```

### ZSH Enhancements
```bash
# Oh My Zsh and plugins
oh-my-zsh                   # ZSH framework
zsh-autosuggestions         # Command suggestions based on history
zsh-syntax-highlighting     # Syntax highlighting for commands
powerlevel10k              # Modern and customizable prompt theme

# Configured plugins (in .zshrc)
git, asdf, zsh-autosuggestions, zsh-syntax-highlighting, gcloud, docker

# Shell features
- Smart PATH deduplication
- Secure SSH key management with keychain
- Enhanced history settings
- Comprehensive aliases for common commands
- Custom functions for development workflow
```

### Configuration Files
```bash
# Dotfiles installed to $HOME
.gitconfig          # Git configuration
.gitignore_global   # Global gitignore patterns
.tool-versions      # ASDF tool versions
.zshrc              # ZSH configuration
.zprofile           # ZSH profile (environment variables)
.tmux.conf          # tmux configuration
.p10k.zsh           # Powerlevel10k theme configuration
```

### NPM Global Packages
```bash
@github/copilot  # GitHub Copilot CLI
```

### Data Science Tools
```bash
# Python packages (pip)
jupyter         # Interactive computing environment
pandas          # Data manipulation and analysis
numpy           # Numerical computing
matplotlib      # Data visualization
scikit-learn    # Machine learning library
```

## ⚡️ Quick Start

### Fresh Installation
```bash
git clone git@github.com:robinsalehjan/supercharged.git
cd supercharged && make setup
```

The setup process will:
1. **Validate** your system meets requirements (macOS 12.0+, 10GB+ free space)
2. **Create** a timestamped restoration point for safe rollbacks
3. **Ask** for your preferences (iOS tools, data science tools, dev tools)
4. **Configure** your Git identity interactively
5. **Install** Homebrew (if not present)
6. **Install** selected tools and applications via Homebrew
7. **Install** Oh My Zsh and plugins
8. **Configure** ASDF and install language runtimes
9. **Install** NPM global packages (GitHub Copilot CLI)
10. **Validate** everything is working correctly

### Update Existing Installation
```bash
make update
```

This will:
- Update Homebrew packages and casks
- Update ASDF plugins
- Update tool versions from `.tool-versions`
- Run `asdf reshim` to update shims
- Copy latest configuration files to `$HOME`

## 🔧 Available Commands

| Command | Description |
|---------|-------------|
| `make setup` | Complete fresh installation with interactive configuration |
| `make setup_profile` | Copy configuration files (.gitconfig, .zshrc, etc.) to $HOME |
| `make update` | Update all installed packages and tools |
| `make validate` | Verify all tools are properly installed with correct versions |
| `make restore` | Restore from the most recent backup |
| `make help` | Show all available commands |

## 🛡 Safety Features

### Automatic Backups
Every installation creates a timestamped backup of your existing configurations:
```bash
~/.supercharged_backup_20250929_143022/
├── .zshrc
├── .zprofile
├── .gitconfig
├── .p10k.zsh
├── .tool-versions
├── .tmux.conf
├── brew_packages.txt    # List of installed Homebrew packages
└── asdf_versions.txt    # List of installed ASDF versions
```

The backup location is saved to `~/.supercharged_last_backup` for easy restoration.

### Manual Restoration
If something goes wrong, restore your previous setup:
```bash
# Restore from the most recent backup
make restore

# Or restore from a specific backup
source scripts/utils.sh && restore_from_backup ~/.supercharged_backup_20250929_143022
```

### Logging
All installation activities are logged to:
```bash
~/.supercharged_install.log
```

Each log entry includes:
- Timestamp
- Log level (INFO, WARN, ERROR, SUCCESS, DEBUG)
- Message details

## 🎯 Customization

### Interactive Options
During setup, you'll be asked about:
- **iOS Development Tools**: Xcode tools, Swift formatters, iOS deployment tools
- **Data Science Tools**: Jupyter, pandas, numpy, matplotlib, scikit-learn
- **Additional Dev Tools**: Docker, Kubernetes tools (k9s)

Your preferences are saved to `~/.supercharged_preferences` and used for future updates.

### Manual Customization
Edit these files before running setup:

**`dot_files/.tool-versions`** - Add or modify development tool versions:
```bash
nodejs 22.9.0
python 3.13.0
ruby 2.7.7
bundler 2.2.32
gcloud 522.0.0
firebase 14.3.1
```

**`dot_files/.zshrc`** - Customize shell aliases and functions:
```bash
# Already includes aliases for:
# - ls variants (ll, la)
# - Navigation (.., ..., cd shortcuts)
# - Git shortcuts (gst, gco, gp, etc.)
# - Docker shortcuts (d, dc)
# - Kubernetes shortcuts (k, kx)
```

**`scripts/mac.sh`** - Modify package installation lists:
```bash
# Edit BREWFILE_CONTENT to add/remove Homebrew packages
# Conditional sections for iOS tools and dev tools
```

## 🔍 Troubleshooting

### Common Issues

**"Installation failed" message**
```bash
# Check the detailed log
tail -f ~/.supercharged_install.log

# Restore from backup if needed
make restore
```

**"System validation failed"**
```bash
# Ensure you meet requirements:
sw_vers -productVersion  # Check macOS version (needs 12.0+)
df -h /                  # Check disk space (needs 10GB+)
xcode-select -p          # Check command line tools
ping -c 1 google.com     # Check internet connectivity
```

**"Git configuration issues"**
```bash
# Reconfigure Git interactively
source scripts/utils.sh && setup_git_config
```

**"SSH key issues"**
```bash
# Check SSH key status
ls -la ~/.ssh/
ssh-add -l

# The setup will configure keychain for automatic SSH key loading
# Supported key types: ed25519 (preferred), rsa, ecdsa
```

**"ASDF version not found"**
```bash
# List available versions
asdf list all nodejs

# Install specific version
asdf install nodejs 22.9.0

# Set version globally
asdf global nodejs 22.9.0
```

### Debug Mode
Enable verbose logging:
```bash
export DEBUG=1
make setup
```

### Reset Everything
Complete reset (⚠️ **Careful** - this removes all configurations):
```bash
# Remove installed packages
brew uninstall --force $(brew list)
rm -rf ~/.oh-my-zsh ~/.asdf

# Restore from backup
make restore
```
