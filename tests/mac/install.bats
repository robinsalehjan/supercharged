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
# validate_system tests
# =============================================================================

@test "validate_system passes with valid system" {
  create_mock_bin "sw_vers" "echo 14.0"
  create_mock_bin "df" 'echo "Filesystem Size Used Avail Use% Mounted"; echo "/dev/disk1s1 460Gi 200Gi 50Gi 50% /"'
  create_mock_bin "xcode-select" "echo /Applications/Xcode.app/Contents/Developer; exit 0"
  create_mock_bin "ping" "exit 0"
  mkdir -p "$HOME/.oh-my-zsh"

  run_zsh_func "validate_system"
  [ "$status" -eq 0 ]
  [[ "$output" == *"System validation passed"* ]]
}

@test "validate_system rejects old macOS version" {
  create_mock_bin "sw_vers" "echo 11.0"
  create_mock_bin "df" 'echo "Filesystem Size Used Avail Use% Mounted"; echo "/dev/disk1s1 460Gi 200Gi 50Gi 50% /"'
  create_mock_bin "xcode-select" "echo /Applications/Xcode.app/Contents/Developer; exit 0"
  create_mock_bin "ping" "exit 0"
  mkdir -p "$HOME/.oh-my-zsh"

  run_zsh_func "validate_system"
  [ "$status" -ne 0 ]
  [[ "$output" == *"macOS"*"required"* ]]
}

@test "validate_system rejects insufficient disk space" {
  create_mock_bin "sw_vers" "echo 14.0"
  create_mock_bin "df" 'echo "Filesystem Size Used Avail Use% Mounted"; echo "/dev/disk1s1 460Gi 400Gi 5Gi 90% /"'
  create_mock_bin "xcode-select" "echo /Applications/Xcode.app/Contents/Developer; exit 0"
  create_mock_bin "ping" "exit 0"
  mkdir -p "$HOME/.oh-my-zsh"

  run_zsh_func "validate_system"
  [ "$status" -ne 0 ]
  [[ "$output" == *"free space required"* ]]
}

@test "validate_system fails without internet" {
  create_mock_bin "sw_vers" "echo 14.0"
  create_mock_bin "df" 'echo "Filesystem Size Used Avail Use% Mounted"; echo "/dev/disk1s1 460Gi 200Gi 50Gi 50% /"'
  create_mock_bin "xcode-select" "echo /Applications/Xcode.app/Contents/Developer; exit 0"
  create_mock_bin "ping" "exit 1"
  mkdir -p "$HOME/.oh-my-zsh"

  run_zsh_func "validate_system"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Internet connectivity required"* ]]
}

@test "validate_system fails without Oh My Zsh" {
  create_mock_bin "sw_vers" "echo 14.0"
  create_mock_bin "df" 'echo "Filesystem Size Used Avail Use% Mounted"; echo "/dev/disk1s1 460Gi 200Gi 50Gi 50% /"'
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
  [[ "$output" == *'brew "git"'* ]]
  [[ "$output" == *'brew "shellcheck"'* ]]
  [[ "$output" == *'brew "jq"'* ]]
  [[ "$output" == *'brew "ripgrep"'* ]]
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
  [[ "$output" == *'ios-deploy'* ]]
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
  run zsh -c "
    source '$PROJECT_ROOT/scripts/utils.sh'
    parse_tool_versions '$PROJECT_ROOT/dot_files/.tool-versions'
    echo \"python=\${TOOL_VERSIONS[python]}\"
    echo \"nodejs=\${TOOL_VERSIONS[nodejs]}\"
    echo \"ruby=\${TOOL_VERSIONS[ruby]}\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"python=3.13.0"* ]]
  [[ "$output" == *"nodejs=22.9.0"* ]]
  [[ "$output" == *"ruby=2.7.7"* ]]
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
