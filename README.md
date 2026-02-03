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
asdf (version manager), keychain, nmap, tree, ripgrep, tmux, aria2
uv (fast Python package installer and resolver), gh (GitHub CLI), duckdb (in-process SQL OLAP database)
sqlite (lightweight SQL database), beads (distributed git-backed issue tracker for AI agents)

# Development languages (via asdf)
nodejs   22.9.0       # LTS version, minimum 20.0.0 for modern features
python   3.13.0       # Latest stable, minimum 3.10.0 for type hints
ruby     2.7.7        # Stable version, minimum 2.7.0 for pattern matching
bundler  2.2.32       # Ruby package manager, minimum 2.2.0
gcloud   522.0.0      # Google Cloud SDK for cloud deployments
firebase 14.3.1       # Firebase CLI for Firebase projects
java     openjdk-23.0.2  # Java for JVM and Android development
kotlin   2.2.21       # Kotlin for Android and multiplatform development
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
google-chrome      # Web browser

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
git, asdf, zsh-autosuggestions, zsh-syntax-highlighting, gcloud, docker, tmux

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
.secrets            # Template for secret environment variables
.p10k.zsh           # Powerlevel10k theme configuration

# Claude Code configuration (backed up to claude_config/)
settings.json              # Claude Code plugin settings
installed_plugins.json     # List of installed plugins with versions
known_marketplaces.json    # Plugin marketplace configurations
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

### Claude Code Configuration Backup
```bash
# Configuration files (backed up to claude_config/)
settings.json              # Plugin enable/disable settings
installed_plugins.json     # List of installed plugins with versions (portable $HOME paths)
known_marketplaces.json    # Plugin marketplace configurations (portable $HOME paths)

# Excluded (session/sensitive data):
# - session-env/, todos/, debug/        # Session-specific data
# - history.jsonl, shell-snapshots/     # Command history
# - projects/, file-history/, plans/    # Project-specific data
# - cache/, downloads/                  # Cache and temporary files
# - statsig/, stats-cache.json          # Analytics data
# - ide/                                # IDE lock files

# Backup your Claude Code configuration (included in npm run update)
npm run backup:claude

# Restore Claude Code configuration (included in npm run setup:profile)
npm run setup:profile
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
2. **Restore** Claude Code configuration (settings, plugins) if available
3. **Validate** your system meets requirements (macOS 12.0+, 10GB+ free space, internet)
4. **Create** a timestamped restoration point for safe rollbacks (includes Claude Code config)
5. **Ask** for your preferences:
   - iOS development tools? (xcodes, ios-deploy, swift tools) [Y/n]
   - Data science tools? (jupyter, pandas, numpy) [y/N]
   - Development tools? (docker, kubernetes, colima) [Y/n]
   - Claude Code? (AI code assistant) [Y/n]
6. **Install** Homebrew (if not present)
7. **Install** selected tools and applications via Homebrew
8. **Install** ZSH plugins (autosuggestions, syntax-highlighting, powerlevel10k)
9. **Configure** ASDF plugins (python, ruby, nodejs, gcloud, firebase, java, kotlin)
10. **Install** ASDF tool versions from .tool-versions
11. **Install** optional data science tools if selected
12. **Run** validation to ensure all tools are working correctly

### Update Existing Installation
```bash
npm run update
```

This will:
- Backup Claude Code configuration (with portable paths)
- Copy latest dotfiles and Claude config to $HOME
- Update Homebrew packages and casks
- Update ASDF plugins
- Install/update tool versions from `.tool-versions`
- Run `asdf reshim` to update shims
- Clean up Homebrew cache

## 🔧 Available Commands

| Command | Description |
|---------|-------------|
| `npm run setup` | Complete fresh installation with interactive configuration |
| `npm run setup:profile` | Copy dotfiles and Claude Code configuration to $HOME |
| `npm run backup:claude` | Backup Claude Code configuration to claude_config/ (with portable paths) |
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
    ├── claude_config/           # Claude Code configuration backup
    │   ├── settings.json
    │   ├── installed_plugins.json
    │   └── known_marketplaces.json
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
<supercharged-directory>/.supercharged_install.log
```

Each log entry includes:
- Timestamp (YYYY-MM-DD HH:MM:SS)
- Log level (❌ ERROR, ⚠️ WARN, ℹ️ INFO, ✅ SUCCESS)
- Message details

View logs:
```bash
cd /path/to/supercharged
tail -f .supercharged_install.log  # Follow logs in real-time
grep ERROR .supercharged_install.log  # Filter for errors
```

## 🎯 Customization

### Interactive Options
During setup, you'll be asked about:
- **iOS Development Tools** [Y/n]: Xcode tools, Swift formatters, iOS deployment tools
- **Data Science Tools** [y/N]: Jupyter, pandas, numpy, matplotlib, scikit-learn
- **Additional Dev Tools** [Y/n]: Docker, Kubernetes tools (k9s), Colima

Your preferences are saved to `~/.supercharged_preferences` and used during setup. These preferences include:
- `INSTALL_IOS_TOOLS`: Whether to install iOS development tools
- `INSTALL_DATA_SCIENCE`: Whether to install data science packages
- `INSTALL_DEV_TOOLS`: Whether to install Docker and Kubernetes tools
- `SETUP_DATE`: When the configuration was last set

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

## 🔍 Troubleshooting

### Common Issues

**"Installation failed" message**
```bash
# Check the detailed log
cd /path/to/supercharged
tail -f .supercharged_install.log

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
# Keys are automatically loaded via keychain in .zshrc
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
cd /path/to/supercharged
cat .supercharged_install.log
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
