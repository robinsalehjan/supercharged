# Troubleshooting

## Common Issues

### "Installation failed" message
```bash
# Check the detailed log
cd /path/to/supercharged
tail -f .supercharged_install.log

# Restore from backup if needed
npm run restore
```

### "System validation failed"
```bash
# Ensure you meet requirements:
sw_vers -productVersion  # Check macOS version (needs 12.0+)
df -h /                  # Check disk space (needs 10GB+)
xcode-select -p          # Check command line tools
ping -c 1 google.com     # Check internet connectivity
```

### "Oh My Zsh plugins not working"
```bash
# Ensure Oh My Zsh is installed first
ls -la ~/.oh-my-zsh

# If not installed:
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Then rerun setup
npm run setup
```

### "SSH key issues"
```bash
# Check SSH key status
ls -la ~/.ssh/
ssh-add -l

# The setup configures keychain for automatic SSH key loading
# Supported key types: ed25519 (preferred), rsa, ecdsa
# Keys are automatically loaded via keychain in .zshrc
```

### "ASDF version not found"
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

### "Java showing wrong version"
```bash
# Check asdf current versions
asdf current

# Reload shell to pick up new PATH
exec zsh

# Or source zshrc
source ~/.zshrc
```

## Reset Everything
```bash
# Restore from backup first
npm run restore
```
