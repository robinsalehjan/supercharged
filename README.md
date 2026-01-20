# supercharged
A comprehensive set of scripts for setting up a developer-friendly macOS environment with enhanced security, performance, and customization options.

## 🚀 Features

- **Interactive Setup**: Customize your installation based on your development needs (iOS tools, data science, dev tools)
- **Enhanced Security**: Secure SSH key management with keychain integration and proper permission handling
- **Smart Recovery**: Automatic timestamped backups and restoration points for safe rollbacks
- **Performance Optimized**: PATH deduplication and efficient installation processes
- **Comprehensive Logging**: Structured logging with levels (INFO, WARN, ERROR, SUCCESS) for better debugging
- **System Validation**: Pre-installation checks for macOS version, disk space, Xcode tools, and internet connectivity

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
uv (fast Python package installer and resolver)

# Development languages (via asdf)
nodejs   22.9.0  # LTS version, minimum 20.0.0 for modern features
python   3.13.0  # Latest stable, minimum 3.10.0 for type hints
ruby     2.7.7   # Stable version, minimum 2.7.0 for pattern matching
gcloud   522.0.0 # Google Cloud SDK for cloud deployments
firebase 14.3.1  # Firebase CLI for Firebase projects
java     openjdk-23.0.2  # Java for JVM and Android development
kotlin   2.2.21  # Kotlin for Android and multiplatform development
```

### iOS Development Tools (Optional - Interactive Setup)
```bash
# Xcode management and Swift tools (tap: xcodesorg/made)
xcodes              # Xcode version manager
xcode-build-server  # Build server for Xcode projects
xcbeautify          # Beautify Xcode build logs
swiftlint           # Swift linting
swift-format        # Swift code formatting
ios-deploy          # Deploy iOS apps from command line
```

### Development Tools (Optional - Interactive Setup)
```bash
# Container and Kubernetes tools
k9s                # Kubernetes CLI manager
docker             # Docker CLI
docker-compose     # Multi-container orchestration
colima             # Lightweight container runtime for macOS (auto-starts)
```

### Applications
```bash
# Development and productivity
visual-studio-code  # Code editor with shell integration
slack              # Team communication
postman            # API development and testing
raycast            # macOS productivity launcher

# Utilities
wireshark  # Network protocol analyzer
spotify    # Music streaming
```

### ZSH Enhancements
**Note**: This setup assumes Oh My Zsh is already installed on your system. If not, install it first:
```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

```bash
# Oh My Zsh plugins (installed to ~/.oh-my-zsh/custom)
zsh-autosuggestions         # Command suggestions based on history
zsh-syntax-highlighting     # Syntax highlighting for commands
powerlevel10k              # Modern and customizable prompt theme

# Configured plugins (in .zshrc)
git, asdf, zsh-autosuggestions, zsh-syntax-highlighting, gcloud, docker

# Shell features configured in .zshrc
- Smart PATH deduplication function
- Secure SSH key management with keychain (ed25519, rsa, ecdsa)
- Enhanced history settings (50k entries, shared across sessions)
- Comprehensive aliases for navigation, git, docker, kubernetes
- Utility functions (mkcd, extract, docker-clean, weather)
- Auto-start Colima if installed
- VS Code shell integration
```

### Configuration Files
```bash
# Dotfiles installed to $HOME
.gitconfig          # Git configuration
.gitignore_global   # Global gitignore patterns
.tool-versions      # ASDF tool versions (all languages)
.zshrc              # ZSH configuration with plugins and aliases
.zprofile           # ZSH profile (environment variables)
.tmux.conf          # tmux configuration
.p10k.zsh           # Powerlevel10k theme configuration
```

### Data Science Tools (Optional - Interactive Setup)
```bash
# Python packages (pip)
jupyter         # Interactive computing environment
pandas          # Data manipulation and analysis
numpy           # Numerical computing
matplotlib      # Data visualization
scikit-learn    # Machine learning library
```

## ⚡️ Quick Start

### Prerequisites
- **Oh My Zsh**: Must be installed before running setup
  ```bash
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  ```

### Fresh Installation
```bash
git clone git@github.com:robinsalehjan/supercharged.git
cd supercharged && npm install && npm run setup
```

The setup process will:
1. **Copy** dotfiles (.gitconfig, .zshrc, .tool-versions, etc.) to your home directory
2. **Validate** your system meets requirements (macOS 12.0+, 10GB+ free space, internet)
3. **Create** a timestamped restoration point for safe rollbacks
4. **Ask** for your preferences:
   - iOS development tools? (xcodes, ios-deploy, swift tools) [Y/n]
   - Data science tools? (jupyter, pandas, numpy) [y/N]
   - Additional dev tools? (docker, k9s, colima) [Y/n]
   - Claude Code? (AI code assistant) [Y/n]
5. **Install** Homebrew (if not present)
6. **Install** selected tools and applications via Homebrew
7. **Install** ZSH plugins (autosuggestions, syntax-highlighting, powerlevel10k)
8. **Configure** ASDF plugins (python, ruby, nodejs, gcloud, firebase, java, kotlin)
9. **Install** ASDF tool versions from .tool-versions
10. **Install** optional data science tools if selected
11. **Run** validation to ensure all tools are working correctly

### Update Existing Installation
```bash
npm run update
```

This will:
- Copy latest dotfiles to $HOME
- Update Homebrew packages and casks
- Update ASDF plugins
- Install/update tool versions from `.tool-versions`
- Run `asdf reshim` to update shims
- Clean up Homebrew cache

## 🔧 Available Commands

| Command | Description |
|---------|-------------|
| `npm run setup` | Complete fresh installation with interactive configuration |
| `npm run setup:profile` | Copy configuration files (.gitconfig, .zshrc, etc.) to $HOME |
| `npm run update` | Update all installed packages and tools |
| `npm run update:dry-run` | Preview updates without making changes |
| `npm run update:brew` | Update only Homebrew (formulae + casks) |
| `npm run update:asdf` | Update only asdf plugins and versions |
| `npm run update:zsh` | Update only zsh plugins |
| `npm run update:npm` | Update only npm global packages |
| `npm run validate` | Verify all tools are properly installed with correct versions |
| `npm run restore` | Restore from the most recent backup |
| `npm run help` | Show all available commands |

## 🛡 Safety Features

### Automatic Backups
Every installation creates a timestamped backup of your existing configurations in a shared backup directory:
```bash
~/.supercharged_backups/          # Hidden shared backup directory
└── 20250929_143022/             # Timestamped backup subdirectory
    ├── .zshrc
    ├── .zprofile
    ├── .gitconfig
    ├── .p10k.zsh
    ├── .tool-versions
    ├── .tmux.conf
    ├── brew_packages.txt    # List of installed Homebrew packages
    ├── brew_casks.txt       # List of installed Homebrew casks
    ├── asdf_plugins.txt     # List of ASDF plugins
    └── asdf_versions.txt    # List of installed ASDF versions
```

**Automatic Cleanup**: The system keeps only the last 5 backups and automatically removes older ones to save disk space.

The most recent backup location is saved to `~/.supercharged_last_backup` for easy restoration.

### Manual Restoration
If something goes wrong, restore your previous setup:
```bash
# Restore from the most recent backup
npm run restore

# Or restore from a specific backup
source scripts/utils.sh && restore_from_backup ~/.supercharged_backups/20250929_143022

# List all available backups
ls -1t ~/.supercharged_backups/
```

### Logging
All installation activities are logged to:
```bash
~/.supercharged_install.log
```

Each log entry includes:
- Timestamp (YYYY-MM-DD HH:MM:SS)
- Log level (❌ ERROR, ⚠️ WARN, ℹ️ INFO, ✅ SUCCESS)
- Message details

View logs:
```bash
tail -f ~/.supercharged_install.log  # Follow logs in real-time
grep ERROR ~/.supercharged_install.log  # Filter for errors
```

## 🎯 Customization

### Interactive Options
During setup, you'll be asked about:
- **iOS Development Tools** [Y/n]: Xcode tools, Swift formatters, iOS deployment tools
- **Data Science Tools** [y/N]: Jupyter, pandas, numpy, matplotlib, scikit-learn
- **Additional Dev Tools** [Y/n]: Docker, Kubernetes tools (k9s), Colima

Your preferences are saved to `~/.supercharged_preferences` and used for reference.

### Manual Customization
Edit these files before running setup:

**`dot_files/.tool-versions`** - Add or modify development tool versions:
```bash
nodejs 22.9.0
python 3.13.0
ruby 2.7.7
gcloud 522.0.0
firebase 14.3.1
java openjdk-23.0.2
kotlin 2.2.21
# Add more tools as needed
```

**`dot_files/.zshrc`** - Customize shell aliases and functions:
```bash
# Already includes aliases for:
# Navigation: ll, la, .., ..., ...., cd shortcuts
# Git: gst, gd, gco, gcm, gp, glog
# Docker: d, dc
# Kubernetes: k, kx
# Development: py (python3), pip (pip3)
# macOS: showfiles, hidefiles, cleanup

# Includes utility functions:
# mkcd, extract, docker-clean, weather, and more
```

**`scripts/mac.sh`** - Modify package installation lists:
```bash
# Edit BREWFILE_CONTENT to add/remove Homebrew packages
# Conditional sections based on INSTALL_IOS_TOOLS, INSTALL_DEV_TOOLS flags
```

## 🔍 Troubleshooting

### Common Issues

**"Installation failed" message**
```bash
# Check the detailed log
tail -f ~/.supercharged_install.log

# Restore from backup if needed
npm run restore
```

**"System validation failed"**
```bash
# Ensure you meet requirements:
sw_vers -productVersion  # Check macOS version (needs 12.0+)
df -h /                  # Check disk space (needs 10GB+)
xcode-select -p          # Check command line tools
ping -c 1 google.com     # Check internet connectivity
```

**"Oh My Zsh plugins not working"**
```bash
# Ensure Oh My Zsh is installed first
ls -la ~/.oh-my-zsh

# If not installed:
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Then rerun setup
npm run setup
```

**"SSH key issues"**
```bash
# Check SSH key status
ls -la ~/.ssh/
ssh-add -l

# The setup configures keychain for automatic SSH key loading
# Supported key types: ed25519 (preferred), rsa, ecdsa
# Keys are automatically loaded in .zshrc
```

**"ASDF version not found"**
```bash
# List available versions
asdf list all nodejs

# Install specific version
asdf install nodejs 22.9.0

# Set version globally (note: use 'asdf set' not 'asdf global')
asdf set --home nodejs 22.9.0

# Reshim to update PATH
asdf reshim
```

**"Java showing wrong version"**
```bash
# Check asdf current versions
asdf current

# Reload shell to pick up new PATH
exec zsh

# Or source zshrc
source ~/.zshrc
```

### Debug Mode
Enable verbose logging by checking:
```bash
cat ~/.supercharged_install.log
```

### Reset Everything
Complete reset (⚠️ **Careful** - this removes all configurations):
```bash
# Restore from backup first
npm run restore

# Optional: Remove installed packages (use with extreme caution)
# brew list | xargs brew uninstall --force
# rm -rf ~/.oh-my-zsh ~/.asdf
```
