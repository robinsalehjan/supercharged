#!/usr/bin/env bats

load '../helpers/setup'
load '../helpers/assertions'
load '../helpers/mocks'

setup() {
  setup_test_env

  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

  # Capture real PATH before any modification (needed to pass to zsh subprocesses)
  REAL_PATH="$PATH"

  # Create a temp bin directory for mock executables visible to zsh subprocesses
  MOCK_BIN_DIR="$TEST_TEMP_DIR/mock_bin"
  mkdir -p "$MOCK_BIN_DIR"
  export MOCK_BIN_DIR REAL_PATH
}

teardown() {
  unmock_all
  teardown_test_env
}

# Create a mock executable script in MOCK_BIN_DIR
# Usage: create_mock_bin "sw_vers" "echo 14.0"
create_mock_bin() {
  local name="$1"
  local body="$2"
  printf '#!/bin/sh\n%s\n' "$body" > "$MOCK_BIN_DIR/$name"
  chmod +x "$MOCK_BIN_DIR/$name"
}

# Helper: run a zsh function from mac.sh with mock PATH
run_zsh_func() {
  local func_name="$1"
  shift
  run zsh -c "
    export PATH='$MOCK_BIN_DIR:$REAL_PATH'
    source '$PROJECT_ROOT/scripts/utils.sh'
    source '$PROJECT_ROOT/scripts/mac.sh'
    $func_name $*
  "
}

# =============================================================================
# Foundation Models CLI license tests
# =============================================================================

@test "setup_foundation_models skips when fm is unavailable" {
  run zsh -c "
    source '$PROJECT_ROOT/scripts/utils.sh'
    source '$PROJECT_ROOT/scripts/mac.sh'
    command_exists() { [[ \"\$1\" != fm ]]; }
    sudo() { echo unexpected-sudo; return 1; }
    setup_foundation_models
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"unavailable; skipping"* ]]
  [[ "$output" != *"unexpected-sudo"* ]]
}

@test "setup_foundation_models skips an already accepted license" {
  create_mock_bin "fm" '[ "$*" = "license --status" ]'
  create_mock_bin "sudo" 'echo unexpected-sudo; exit 1'

  run_zsh_func "setup_foundation_models"

  [ "$status" -eq 0 ]
  [[ "$output" == *"license already accepted"* ]]
  [[ "$output" != *"unexpected-sudo"* ]]
}

@test "setup_foundation_models prints manual steps without a terminal" {
  create_mock_bin "fm" 'exit 69'
  create_mock_bin "sudo" 'echo unexpected-sudo; exit 1'

  run_zsh_func "setup_foundation_models" </dev/null

  [ "$status" -eq 0 ]
  [[ "$output" == *"requires an interactive terminal; run: sudo fm license"* ]]
  [[ "$output" != *"unexpected-sudo"* ]]
}

# A pseudo-terminal exercises the interactive path without touching the real
# machine license or invoking real sudo. Both commands are PATH-based mocks.
run_foundation_models_interactive() {
  run script -q /dev/null zsh -c "
    export PATH='$MOCK_BIN_DIR:$REAL_PATH'
    source '$PROJECT_ROOT/scripts/utils.sh'
    source '$PROJECT_ROOT/scripts/mac.sh'
    setup_foundation_models
    echo setup-continued
  " </dev/null
}

@test "setup_foundation_models runs sudo fm license and verifies acceptance" {
  create_mock_bin "fm" "[ \"\$*\" = 'license --status' ] && [ -f '$TEST_TEMP_DIR/accepted' ]"
  create_mock_bin "sudo" "
    [ \"\$*\" = 'fm license' ] || exit 1
    echo sudo-fm-license
    touch '$TEST_TEMP_DIR/accepted'
  "

  run_foundation_models_interactive

  [ "$status" -eq 0 ]
  [[ "$output" == *"sudo-fm-license"* ]]
  [[ "$output" == *"Foundation Models CLI license accepted"* ]]
  [[ "$output" == *"setup-continued"* ]]
}

@test "setup_foundation_models continues when license acceptance fails or is declined" {
  create_mock_bin "fm" 'exit 69'
  create_mock_bin "sudo" 'echo sudo-fm-license; exit 69'

  run_foundation_models_interactive

  [ "$status" -eq 0 ]
  [[ "$output" == *"sudo-fm-license"* ]]
  [[ "$output" == *"license was not accepted; retry with: sudo fm license"* ]]
  [[ "$output" == *"setup-continued"* ]]
}

@test "setup_foundation_models warns if sudo succeeds without accepting the license" {
  create_mock_bin "fm" 'exit 69'
  create_mock_bin "sudo" 'exit 0'

  run_foundation_models_interactive

  [ "$status" -eq 0 ]
  [[ "$output" == *"license was not accepted"* ]]
  [[ "$output" != *"SUCCESS"* ]]
  [[ "$output" == *"setup-continued"* ]]
}

# =============================================================================
# validate_system tests
# =============================================================================

@test "validate_system passes with valid system" {
  create_mock_bin "sw_vers" "echo 14.0"
  create_mock_bin "df" 'echo "Filesystem 1024-blocks Used Available Capacity Mounted"; echo "/dev/disk1s1 483041280 209715200 52428800 50% /"'
  create_mock_bin "xcode-select" "echo /Applications/Xcode.app/Contents/Developer; exit 0"
  create_mock_bin "ping" "exit 0"
  mkdir -p "$HOME/.oh-my-zsh"

  run_zsh_func "validate_system"
  [ "$status" -eq 0 ]
  [[ "$output" == *"System validation passed"* ]]
}

@test "validate_system rejects old macOS version" {
  create_mock_bin "sw_vers" "echo 11.0"
  create_mock_bin "df" 'echo "Filesystem 1024-blocks Used Available Capacity Mounted"; echo "/dev/disk1s1 483041280 209715200 52428800 50% /"'
  create_mock_bin "xcode-select" "echo /Applications/Xcode.app/Contents/Developer; exit 0"
  create_mock_bin "ping" "exit 0"
  mkdir -p "$HOME/.oh-my-zsh"

  run_zsh_func "validate_system"
  [ "$status" -ne 0 ]
  [[ "$output" == *"macOS"*"required"* ]]
}

@test "validate_system rejects insufficient disk space" {
  create_mock_bin "sw_vers" "echo 14.0"
  create_mock_bin "df" 'echo "Filesystem 1024-blocks Used Available Capacity Mounted"; echo "/dev/disk1s1 483041280 419430400 5242880 90% /"'
  create_mock_bin "xcode-select" "echo /Applications/Xcode.app/Contents/Developer; exit 0"
  create_mock_bin "ping" "exit 0"
  mkdir -p "$HOME/.oh-my-zsh"

  run_zsh_func "validate_system"
  [ "$status" -ne 0 ]
  [[ "$output" == *"free space required"* ]]
}

@test "validate_system fails without internet" {
  create_mock_bin "sw_vers" "echo 14.0"
  create_mock_bin "df" 'echo "Filesystem 1024-blocks Used Available Capacity Mounted"; echo "/dev/disk1s1 483041280 209715200 52428800 50% /"'
  create_mock_bin "xcode-select" "echo /Applications/Xcode.app/Contents/Developer; exit 0"
  create_mock_bin "ping" "exit 1"
  mkdir -p "$HOME/.oh-my-zsh"

  run_zsh_func "validate_system"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Internet connectivity required"* ]]
}

@test "validate_system fails without Oh My Zsh" {
  create_mock_bin "sw_vers" "echo 14.0"
  create_mock_bin "df" 'echo "Filesystem 1024-blocks Used Available Capacity Mounted"; echo "/dev/disk1s1 483041280 209715200 52428800 50% /"'
  create_mock_bin "xcode-select" "echo /Applications/Xcode.app/Contents/Developer; exit 0"
  create_mock_bin "ping" "exit 0"
  # No .oh-my-zsh directory

  run_zsh_func "validate_system"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Oh My Zsh"* ]]
}

# =============================================================================
# build_brewfile tests
# =============================================================================

@test "build_brewfile includes core packages" {
  run zsh -c "
    source '$PROJECT_ROOT/scripts/utils.sh'
    source '$PROJECT_ROOT/scripts/mac.sh'
    build_brewfile
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *'brew "bash"'* ]]
  [[ "$output" == *'brew "git"'* ]]
  [[ "$output" == *'brew "shellcheck"'* ]]
  [[ "$output" == *'brew "actionlint"'* ]]
  [[ "$output" == *'brew "jq"'* ]]
  [[ "$output" == *'brew "ripgrep"'* ]]
  [[ "$output" == *'brew "watchexec"'* ]]
  [[ "$output" == *'brew "cliclick"'* ]]
  [[ "$output" == *'cask "codex"'* ]]
  [[ "$output" == *'cask "chatgpt"'* ]]
  [[ "$output" == *'cask "codexbar"'* ]]
  [[ "$output" == *'tap "replicate/tap"'* ]]
  [[ "$output" == *'brew "replicate/tap/replicate"'* ]]
  [[ "$output" == *'tap "danger/tap", trusted: { formulae: ["danger-js", "danger-swift"] }'* ]]
  [[ "$output" == *'brew "danger/tap/danger-js"'* ]]
  [[ "$output" == *'brew "danger/tap/danger-swift"'* ]]
  [[ "$output" != *'cupertino'* ]]
  [[ "$output" != *'ollama'* ]]
  [[ "$output" != *'omlx'* ]]
  [[ "$output" == *'mas "Numbers", id: 361304891'* ]]
  [[ "$output" == *'vscode "openai.chatgpt"'* ]]
}

@test "build_brewfile does not execute commands in its comments" {
  create_mock_bin "brew" 'echo "unexpected brew invocation: $*" >&2; exit 1'

  run zsh -c "
    export PATH='$MOCK_BIN_DIR:$REAL_PATH'
    source '$PROJECT_ROOT/scripts/utils.sh'
    source '$PROJECT_ROOT/scripts/mac.sh'
    build_brewfile
  "

  [ "$status" -eq 0 ]
  [[ "$output" != *"unexpected brew invocation"* ]]
  [[ "$output" == *'# Formula only — do NOT also install `brew install --cask periphery`.'* ]]
}

@test "build_brewfile includes Codex desktop app by default" {
  run zsh -c "
    unset INSTALL_CODEX_APP
    source '$PROJECT_ROOT/scripts/utils.sh'
    source '$PROJECT_ROOT/scripts/mac.sh'
    build_brewfile
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *'cask "chatgpt"'* ]]
  [[ "$output" == *'cask "codexbar"'* ]]
}

@test "fresh setup restores Codex configuration independently" {
  run grep -F '"$UTILS_SCRIPT_DIR/restore-codex.sh" --force' "$PROJECT_ROOT/scripts/mac.sh"
  [ "$status" -eq 0 ]
}

@test "fresh setup installs OpenWiki after the managed Node.js runtime" {
  run grep -F 'setup_openwiki' "$PROJECT_ROOT/scripts/mac.sh"
  [ "$status" -eq 0 ]
}

@test "fresh setup installs Playwright CLI after the managed Node.js runtime" {
  run grep -F 'setup_playwright_cli' "$PROJECT_ROOT/scripts/mac.sh"
  [ "$status" -eq 0 ]
}

@test "fresh setup installs Playwright MCP after the managed Node.js runtime" {
  run grep -F 'setup_playwright_mcp' "$PROJECT_ROOT/scripts/mac.sh"
  [ "$status" -eq 0 ]
}

@test "fresh setup installs Obscura independently of the Claude preference" {
  run python3 - "$PROJECT_ROOT/scripts/mac.sh" <<'PYTEST'
from pathlib import Path
import sys

lines = Path(sys.argv[1]).read_text().splitlines()
obscura = lines.index("    setup_obscura")
claude_guard = lines.index("    # Install Claude Code if requested")
assert obscura < claude_guard
PYTEST
  [ "$status" -eq 0 ]
}

@test "fresh setup keeps Git and Python version checks advisory under set -e" {
  run zsh -c "
    set -e
    source '$PROJECT_ROOT/scripts/utils.sh'
    source '$PROJECT_ROOT/scripts/mac.sh'
    check_version() {
      log_with_level WARN \"\$1 version warning\"
      return 1
    }
    check_bootstrap_versions 3.14.0
    echo continued
  "

  [ "$status" -eq 0 ]
  [[ "$output" == *"git version warning"* ]]
  [[ "$output" == *"python3 version warning"* ]]
  [[ "$output" == *"continued"* ]]
}

@test "build_brewfile excludes Codex desktop app when INSTALL_CODEX_APP=n" {
  run zsh -c "
    export INSTALL_CODEX_APP=n
    source '$PROJECT_ROOT/scripts/utils.sh'
    source '$PROJECT_ROOT/scripts/mac.sh'
    build_brewfile
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *'cask "codex"'* ]]
  [[ "$output" != *'cask "chatgpt"'* ]]
  [[ "$output" != *'cask "codexbar"'* ]]
}

@test "build_brewfile includes iOS tools when INSTALL_IOS_TOOLS=Y" {
  run zsh -c "
    export INSTALL_IOS_TOOLS=Y
    source '$PROJECT_ROOT/scripts/utils.sh'
    source '$PROJECT_ROOT/scripts/mac.sh'
    build_brewfile
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *'xcodes'* ]]
  [[ "$output" == *'swiftlint'* ]]
  [[ "$output" == *'swift-format'* ]]
  [[ "$output" == *'swiftformat'* ]]
  [[ "$output" == *'ios-deploy'* ]]
  [[ "$output" == *'simslim'* ]]
  [[ "$output" == *'periphery'* ]]
  [[ "$output" == *'tap "xcodesorg/made", trusted: { formula: "xcodes" }'* ]]
  [[ "$output" == *'tap "mobai-app/tap", trusted: { formula: "simslim" }'* ]]
  [[ "$output" == *'brew "mobai-app/tap/simslim"'* ]]
  [[ "$output" != *'tap "peripheryapp/periphery"'* ]]
  [[ "$output" != *'tap "thoughtbot/formulae"'* ]]
  [[ "$output" != *'xcodebuildmcp'* ]]
  run rg -F 'setup_xcode_mcp' "$PROJECT_ROOT/scripts/mac.sh"
  [ "$status" -eq 0 ]
  run rg -F 'retire_legacy_xcode_mcps' "$PROJECT_ROOT/scripts/mac.sh"
  [ "$status" -eq 0 ]
}

@test "build_brewfile excludes iOS tools when INSTALL_IOS_TOOLS=n" {
  run zsh -c "
    export INSTALL_IOS_TOOLS=n
    source '$PROJECT_ROOT/scripts/utils.sh'
    source '$PROJECT_ROOT/scripts/mac.sh'
    build_brewfile
  "
  [ "$status" -eq 0 ]
  [[ "$output" != *'xcodes'* ]]
  [[ "$output" != *'swiftlint'* ]]
  [[ "$output" != *'simslim'* ]]
  [[ "$output" != *'periphery'* ]]
  [[ "$output" != *'xcodebuildmcp'* ]]
}

@test "build_brewfile includes dev tools when INSTALL_DEV_TOOLS=Y" {
  run zsh -c "
    export INSTALL_DEV_TOOLS=Y
    source '$PROJECT_ROOT/scripts/utils.sh'
    source '$PROJECT_ROOT/scripts/mac.sh'
    build_brewfile
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *'docker'* ]]
  [[ "$output" == *'colima'* ]]
}

@test "build_brewfile excludes dev tools when INSTALL_DEV_TOOLS=n" {
  run zsh -c "
    export INSTALL_DEV_TOOLS=n
    source '$PROJECT_ROOT/scripts/utils.sh'
    source '$PROJECT_ROOT/scripts/mac.sh'
    build_brewfile
  "
  [ "$status" -eq 0 ]
  [[ "$output" != *'"docker"'* ]]
  [[ "$output" != *'colima'* ]]
}

@test "build_brewfile includes terraform when INSTALL_CLOUD_TOOLS=Y" {
  run zsh -c "
    export INSTALL_CLOUD_TOOLS=Y
    source '$PROJECT_ROOT/scripts/utils.sh'
    source '$PROJECT_ROOT/scripts/mac.sh'
    build_brewfile
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *'tap "hashicorp/tap", trusted: { formula: "terraform" }'* ]]
  [[ "$output" == *'hashicorp/tap/terraform'* ]]
}

@test "build_brewfile excludes terraform when INSTALL_CLOUD_TOOLS=n" {
  run zsh -c "
    export INSTALL_CLOUD_TOOLS=n
    source '$PROJECT_ROOT/scripts/utils.sh'
    source '$PROJECT_ROOT/scripts/mac.sh'
    build_brewfile
  "
  [ "$status" -eq 0 ]
  [[ "$output" != *'tap "hashicorp/tap"'* ]]
  [[ "$output" != *'hashicorp/tap/terraform'* ]]
}

@test "build_brewfile always includes applications" {
  run zsh -c "
    export INSTALL_IOS_TOOLS=n
    export INSTALL_DEV_TOOLS=n
    source '$PROJECT_ROOT/scripts/utils.sh'
    source '$PROJECT_ROOT/scripts/mac.sh'
    build_brewfile
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *'spotify'* ]]
  [[ "$output" == *'visual-studio-code'* ]]
  [[ "$output" == *'raycast'* ]]
  [[ "$output" == *'mullvad-vpn'* ]]
}

@test "build_brewfile includes extra apps when INSTALL_EXTRA_APPS=Y" {
  run zsh -c "
    export INSTALL_EXTRA_APPS=Y
    source '$PROJECT_ROOT/scripts/utils.sh'
    source '$PROJECT_ROOT/scripts/mac.sh'
    build_brewfile
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *'postman'* ]]
  [[ "$output" == *'google-chrome'* ]]
}

@test "build_brewfile excludes extra apps by default" {
  run zsh -c "
    unset INSTALL_EXTRA_APPS
    source '$PROJECT_ROOT/scripts/utils.sh'
    source '$PROJECT_ROOT/scripts/mac.sh'
    build_brewfile
  "
  [ "$status" -eq 0 ]
  [[ "$output" != *'postman'* ]]
  [[ "$output" != *'google-chrome'* ]]
}

@test "build_brewfile includes network tools by default" {
  run zsh -c "
    unset INSTALL_NETWORK_TOOLS
    source '$PROJECT_ROOT/scripts/utils.sh'
    source '$PROJECT_ROOT/scripts/mac.sh'
    build_brewfile
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *'wireshark'* ]]
  [[ "$output" == *'mitmproxy'* ]]
  [[ "$output" == *'proxyman'* ]]
}

@test "build_brewfile excludes network tools when INSTALL_NETWORK_TOOLS=n" {
  run zsh -c "
    export INSTALL_NETWORK_TOOLS=n
    source '$PROJECT_ROOT/scripts/utils.sh'
    source '$PROJECT_ROOT/scripts/mac.sh'
    build_brewfile
  "
  [ "$status" -eq 0 ]
  [[ "$output" != *'wireshark'* ]]
  [[ "$output" != *'mitmproxy'* ]]
  [[ "$output" != *'proxyman'* ]]
}

# =============================================================================
# install_homebrew architecture detection tests
# =============================================================================

@test "install_homebrew sets arm64 prefix" {
  create_mock_bin "uname" "echo arm64"
  create_mock_bin "brew" "exit 0"

  run zsh -c "
    export PATH='$MOCK_BIN_DIR:$REAL_PATH'
    source '$PROJECT_ROOT/scripts/utils.sh'
    source '$PROJECT_ROOT/scripts/mac.sh'
    install_homebrew
    echo \"\$HOMEBREW_PREFIX\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"/opt/homebrew"* ]]
}

@test "install_homebrew sets x86_64 prefix" {
  create_mock_bin "uname" "echo x86_64"
  create_mock_bin "brew" "exit 0"

  run zsh -c "
    export PATH='$MOCK_BIN_DIR:$REAL_PATH'
    source '$PROJECT_ROOT/scripts/utils.sh'
    source '$PROJECT_ROOT/scripts/mac.sh'
    install_homebrew
    echo \"\$HOMEBREW_PREFIX\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"/usr/local"* ]]
}

# =============================================================================
# parse_tool_versions tests (zsh-only: uses typeset -gA)
# =============================================================================

@test "parse_tool_versions reads tools from .tool-versions" {
  tracked="$PROJECT_ROOT/dot_files/.tool-versions"

  # Read the expected pins from the file under test so a routine pin bump
  # cannot fail this test.
  for tool in python nodejs ruby; do
    pinned=$(awk -v t="$tool" '$1 == t { print $2; exit }' "$tracked")
    [ -n "$pinned" ]

    run zsh -c "
      source '$PROJECT_ROOT/scripts/utils.sh'
      parse_tool_versions '$tracked'
      echo \"$tool=\${TOOL_VERSIONS[$tool]}\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"$tool=$pinned"* ]]
  done
}

@test "parse_tool_versions skips comment lines" {
  cat > "$TEST_TEMP_DIR/.tool-versions" <<'EOF'
# This is a comment
python 3.13.0
# Another comment
nodejs 22.9.0
EOF

  run zsh -c "
    source '$PROJECT_ROOT/scripts/utils.sh'
    parse_tool_versions '$TEST_TEMP_DIR/.tool-versions'
    echo \"python=\${TOOL_VERSIONS[python]}\"
    echo \"nodejs=\${TOOL_VERSIONS[nodejs]}\"
    echo \"count=\${#TOOL_VERSIONS[@]}\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"python=3.13.0"* ]]
  [[ "$output" == *"nodejs=22.9.0"* ]]
  [[ "$output" == *"count=2"* ]]
}
