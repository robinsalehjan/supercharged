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

### "Tmux icons render as `?` or boxes"

The tmux status bar uses Nerd Font glyphs (folder, clock, battery, separators). If they render as `?`, ▯, or empty, work down the chain — the failure is almost always one of three steps.

```bash
# 1. Is the Nerd Font registered with macOS?
#    npm run validate reports this; on failure, npm run setup self-heals
#    by reinstalling the cask and copying staged .ttf files into ~/Library/Fonts.
npm run validate                       # look for "✅ font: JetBrainsMono Nerd Font"
ls ~/Library/Fonts/ | grep -i jetbrains  # should list ~96 .ttf files
```

```bash
# 2. Is your terminal profile actually using the Nerd Font?
#    A correctly registered font is invisible until the profile picks it up.
#    Apple Terminal: Settings → Profiles → <your profile> → Text → Font →
#                    Change… → "JetBrainsMono Nerd Font Mono"
#    iTerm2:        Settings → Profiles → Text → Font
#    Ghostty:       font-family = "JetBrainsMono Nerd Font Mono" in config
```

```bash
# 3. Apple Terminal only: enable "Use Option as Meta key"
#    The .tmux.conf prefix is Option-Shift-T (M-T). Without this setting,
#    Terminal swallows Option keys and no prefix-based shortcuts work.
#    Settings → Profiles → Keyboard → "Use Option as Meta key"
```

**Note on Apple Terminal + Plane 15 glyphs.** Apple Terminal cannot render Unicode Plane 15 (SPUA-A, U+F0000+) code points even with a Nerd Font selected. The repo's `.tmux.conf` overrides Catppuccin's defaults with FontAwesome glyphs from the BMP private-use area (U+E000–U+F8FF) so icons render in every Nerd Font-capable terminal. If you've customized icons and see `?`, check your custom code points are in the BMP range, or switch to iTerm2/Ghostty/kitty (which all handle Plane 15 natively).

## Reset Everything
```bash
# Restore from backup first
npm run restore
```
