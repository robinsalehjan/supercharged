# What Gets Installed

## Core Development Tools
```bash
# Package managers and build tools
bash, coreutils, git, curl, openssl@3, readline, libyaml, gmp
asdf (version manager), keychain, nmap, tree, ripgrep, tmux, aria2
gh (GitHub CLI), duckdb (in-process SQL OLAP database)
sqlite (lightweight SQL database)
btop (resource monitor), htop (process viewer)
shellcheck (shell script linter), actionlint (GitHub Actions workflow linter), jq (JSON processor)
bats-core (Bash Automated Testing System)
mas (Mac App Store CLI)
pipx (install Python CLI tools in isolated environments)
uv (fast Python package installer and resolver)
ollama (CLI to run large language models locally)
codex (OpenAI Codex CLI - run the Codex coding agent locally)
codexbar (macOS menu bar companion app for OpenAI Codex)
replicate (Replicate CLI - run AI models from the Replicate platform)
rtk (Rust Token Killer - CLI proxy for 60-90% token savings in Claude Code)
worktrunk (Git worktree manager designed for parallel AI agents - `wt switch`, `wt merge`, `wt remove`)
plannotator (Visual annotation tool for AI coding agents - plan review, code diff annotation)
code-review-graph (AI-optimized code knowledge graph - installed via pipx with embeddings + communities extras)
hey (HTTP load generator for benchmarking web endpoints)
watch (re-run a command periodically and display its output - e.g. `watch -n 2 'ccusage blocks --active'`)

# Development languages (via asdf)
nodejs   22.9.0       # LTS version, minimum 20.0.0 for modern features
python   3.13.0       # Latest stable, minimum 3.10.0 for type hints
ruby     2.7.7        # Stable version, minimum 2.7.0 for pattern matching
bundler  2.2.32       # Ruby package manager, minimum 2.2.0
```

## Cloud SDKs (Default on - Opt-out via INSTALL_CLOUD_TOOLS=N)
```bash
gcloud   522.0.0      # Google Cloud SDK for cloud deployments
firebase 14.3.1       # Firebase CLI for Firebase projects
```

## Network Tools (Default on - Opt-out via INSTALL_NETWORK_TOOLS=N)
```bash
wireshark    # Network protocol analyzer (CLI + GUI)
mitmproxy    # Interactive HTTPS proxy for debugging
proxyman     # macOS HTTP debugging proxy (cask)
```

## JVM Toolchain (Optional - Interactive Setup)
Installed only when `INSTALL_JVM_TOOLS=Y` (default: N). With no pin in
`.tool-versions`, setup resolves `asdf latest java openjdk` and
`asdf latest kotlin` and installs whatever's current. To pin a specific
version, add lines to your `dot_files/.tool-versions` before running setup,
e.g.:
```bash
java     openjdk-25.0.2  # Java for JVM and Android development
kotlin   2.3.20          # Kotlin for Android and multiplatform development
```

## iOS Development Tools (Optional - Interactive Setup)
```bash
# Xcode management and Swift tools (tap: xcodesorg/made)
xcodes              # Xcode version manager
xcode-build-server  # Build server for Xcode projects
xcbeautify          # Beautify Xcode build logs
swiftlint           # Swift linting
swift-format        # Swift code formatting (Apple)
swiftformat         # Swift code formatting (nicklockwood)
ios-deploy          # Deploy iOS apps from command line
periphery           # Dead code detection for Swift (tap: peripheryapp/periphery)
xcodebuildmcp       # Xcode MCP build server (tap: getsentry/xcodebuildmcp)
```

## Development Tools (Optional - Interactive Setup)
```bash
# Container and Kubernetes tools
docker             # Docker CLI
docker-compose     # Multi-container orchestration
colima             # Lightweight container runtime for macOS (auto-starts)
kubernetes-cli     # kubectl for Kubernetes cluster management
```

## Applications
```bash
# Development and productivity
visual-studio-code  # Code editor with shell integration
slack              # Team communication
reveal             # Runtime view debugging for iOS apps
raycast            # macOS productivity launcher

# Utilities
spotify      # Music streaming
mullvad-vpn  # Privacy-focused VPN client

# Fonts
font-jetbrains-mono-nerd-font  # JetBrains Mono with Nerd Font icons

# Mac App Store
AdBlock      # Ad blocker for Safari
DaisyDisk    # Disk usage analyzer
```

## Extra GUI Apps (Optional - Interactive Setup)
Installed only when `INSTALL_EXTRA_APPS=Y` (default: N).
```bash
postman         # API client / HTTP request builder
google-chrome   # Chromium-based browser
```

## AI Coding Tools (Installed with Claude Code)
```bash
ccusage      # Claude Code token usage measurement (installed globally via npm)
             # Aliases: cct (daily summary), cclive (real-time monitor)
obscura      # Rust-based headless browser for AI agents / web scraping
             # (h4ckf0r0day/obscura — GitHub release binary to ~/.local/bin)
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
.secrets/           # Template for secret env vars (*.sh sourced) and blob credentials (e.g. GCP JSON)
.p10k.zsh           # Powerlevel10k theme configuration

# Claude Code configuration (backed up to claude_config/)
settings.json              # Claude Code settings (permissions, env, hooks, plugins)
installed_plugins.json     # List of installed plugins with versions
known_marketplaces.json    # Plugin marketplace configurations
mcp_servers.json           # MCP server definitions (XcodeBuildMCP, etc.)
statusline/Config.toml     # Statusline theme and display configuration
CLAUDE.md                  # Global personal instructions
CRG.md, RTK.md, ...        # @-referenced from CLAUDE.md (auto-detected)
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
