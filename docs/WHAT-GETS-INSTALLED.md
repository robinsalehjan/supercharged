# What Gets Installed

## Core Development Tools
```bash
# Package managers and build tools
coreutils, git, curl, openssl@3, readline, libyaml, gmp
asdf (version manager), keychain, nmap, tree, ripgrep, tmux, aria2
gh (GitHub CLI), duckdb (in-process SQL OLAP database)
sqlite (lightweight SQL database)
btop (resource monitor with CPU, memory, disk, network, and process stats)
shellcheck (shell script linter), jq (JSON processor)
rtk (Rust Token Killer - CLI proxy for 60-90% token savings in Claude Code)
dippy (Permission automation for Claude Code - auto-approves safe commands, ~40% faster development)
plannotator (Visual annotation tool for AI coding agents - plan review, code diff annotation)

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

## iOS Development Tools (Optional - Interactive Setup)
```bash
# Xcode management and Swift tools (tap: xcodesorg/made)
xcodes              # Xcode version manager
xcode-build-server  # Build server for Xcode projects
xcbeautify          # Beautify Xcode build logs
swiftlint           # Swift linting
swift-format        # Swift code formatting
ios-deploy          # Deploy iOS apps from command line
```

## Development Tools (Optional - Interactive Setup)
```bash
# Container and Kubernetes tools
docker             # Docker CLI
docker-compose     # Multi-container orchestration
colima             # Lightweight container runtime for macOS (auto-starts)
```

## Applications
```bash
# Development and productivity
visual-studio-code  # Code editor with shell integration
slack              # Team communication
postman            # API development and testing
raycast            # macOS productivity launcher
google-chrome      # Web browser

# Utilities
wireshark    # Network protocol analyzer
spotify      # Music streaming
mullvad-vpn  # Privacy-focused VPN client
```

## ZSH Enhancements
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
- Colima auto-start (opt-in via `SUPERCHARGED_COLIMA_AUTOSTART=1` in `~/.secrets`)
- VS Code shell integration
```

## Configuration Files
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
keybindings.json           # Custom keyboard shortcuts
CLAUDE.md                  # Global personal instructions
```

## Data Science Tools (Optional - Interactive Setup)
```bash
# Python packages (pip)
jupyter         # Interactive computing environment
pandas          # Data manipulation and analysis
numpy           # Numerical computing
matplotlib      # Data visualization
scikit-learn    # Machine learning library
```
