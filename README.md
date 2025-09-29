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
asdf (version manager), keychain, htop, nmap, tree, ripgrep, tmux

# Development languages (via asdf)
nodejs   22.9.0  # >= 20.0.0 for modern features
python   3.13.0  # >= 3.10.0 for type hints and match statements
ruby     2.7.7   # >= 2.7.0 for pattern matching
gcloud   522.0.0 # >= 400.0.0 for gke-gcloud-auth-plugin
firebase 14.3.1  # >= 12.0.0 for modern deployment features
```

### Optional iOS Development Tools (Customizable)
```bash
xcodes, xcode-build-server, xcbeautify, swiftlint, swift-format, ios-deploy
```

### Optional Development Tools (Customizable)
```bash
k9s (Kubernetes), docker-desktop
```

### Applications
```bash
# Productivity and development
visual-studio-code, slack, postman, raycast, notion

# Utilities and tools
wireshark, docker, spotify
```

### ZSH Enhancements
```bash
# Plugins and themes
zsh-autosuggestions    # Command suggestions
zsh-syntax-highlighting # Syntax highlighting
powerlevel10k          # Modern prompt theme

# Enhanced shell features
- Smart PATH deduplication
- Secure SSH key management
- Enhanced history settings
- Comprehensive aliases and functions
```

## ⚡️ Quick Start

### Fresh Installation
```bash
git clone git@github.com:robinsalehjan/supercharged.git
cd supercharged && make setup
```

The setup process will:
1. **Validate** your system meets requirements
2. **Create** a restoration point for safe rollbacks
3. **Ask** for your preferences (iOS tools, data science tools, etc.)
4. **Configure** your Git identity interactively
5. **Install** selected tools and applications
6. **Validate** everything is working correctly

### Update Existing Installation
```bash
make update
```

## 🔧 Available Commands

| Command | Description |
|---------|-------------|
| `make setup` | Complete fresh installation with interactive configuration |
| `make setup_profile` | Copy configuration files only |
| `make update` | Update all installed packages and tools |
| `make validate` | Verify all tools are properly installed |
| `make clean_xcode` | Clean Xcode caches and derived data |
| `make help` | Show all available commands |

## 🛡 Safety Features

### Automatic Backups
Every installation creates a timestamped backup of your existing configurations:
```bash
~/.supercharged_backup_20250929_143022/
├── .zshrc
├── .gitconfig
├── .p10k.zsh
├── brew_packages.txt
└── asdf_versions.txt
```

### Manual Restoration
If something goes wrong, restore your previous setup:
```bash
# Restore from the most recent backup
source scripts/utils.sh && restore_from_backup

# Or restore from a specific backup
source scripts/utils.sh && restore_from_backup ~/.supercharged_backup_20250929_143022
```

## 🎯 Customization

### Interactive Options
During setup, you'll be asked about:
- **iOS Development Tools**: Xcode tools, Swift formatters, iOS deployment tools
- **Data Science Tools**: Jupyter, pandas, numpy (future feature)
- **Additional Dev Tools**: Docker, Kubernetes tools, etc.

### Manual Customization
Edit these files before running setup:
- `dot_files/.tool-versions` - Add or modify development tool versions
- `dot_files/.zshrc` - Customize shell aliases and functions
- `scripts/mac.sh` - Modify package installation lists

## 🔍 Troubleshooting

### Common Issues

**"Installation failed" message**
```bash
# Check the detailed log
tail -f ~/.supercharged_install.log

# Restore from backup if needed
source scripts/utils.sh && restore_from_backup
```

**"System validation failed"**
```bash
# Ensure you meet requirements:
sw_vers -productVersion  # Check macOS version (needs 12.0+)
df -h /                  # Check disk space (needs 10GB+)
xcode-select -p          # Check command line tools
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

# Regenerate SSH key if needed
ssh-keygen -t ed25519 -C "your_email@example.com"
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
source scripts/utils.sh && restore_from_backup
```

## 📚 What's New

### v2.0 Improvements
- ✅ **Enhanced Security**: Secure SSH key management, git config templating
- ✅ **Interactive Setup**: Customize installation based on your needs
- ✅ **Smart Recovery**: Automatic backups and easy restoration
- ✅ **Performance**: PATH deduplication, optimized installations
- ✅ **Better Logging**: Structured logging with different levels
- ✅ **System Validation**: Pre-installation compatibility checks
- ✅ **Comprehensive Testing**: Validation of all installed tools

## 🤝 Contributing

Found an issue or want to add a feature?
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

MIT License - feel free to use and modify as needed!

---

**Happy coding! 🚀**
