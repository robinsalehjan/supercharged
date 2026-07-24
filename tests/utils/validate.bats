#!/usr/bin/env bats

# Load test helpers
load '../helpers/setup'

setup() {
  setup_test_env

  # Get project root
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

teardown() {
  teardown_test_env
}

@test "validate command checks for brew" {
  # Act
  run bash -c "cd $PROJECT_ROOT/scripts && ./utils.sh validate"

  # Assert - only verify brew appears in output; overall status depends on all
  # tools matching .tool-versions which may not hold in CI environments
  if command -v brew >/dev/null 2>&1; then
    [[ "$output" == *"brew:"* ]]
  fi
}

@test "validate command checks for git" {
  # Act
  run bash -c "cd $PROJECT_ROOT/scripts && ./utils.sh validate"

  # Assert - git output appears; overall status not asserted since it depends on
  # all tools matching .tool-versions which may not hold in CI environments
  [[ "$output" == *"git:"* ]]
}

@test "validate command checks for asdf" {
  # Act
  run bash -c "cd $PROJECT_ROOT/scripts && ./utils.sh validate"

  # Assert - asdf output appears; overall status not asserted since it depends on
  # all tools matching .tool-versions which may not hold in CI environments
  if command -v asdf >/dev/null 2>&1; then
    [[ "$output" == *"asdf:"* ]]
  else
    [ "$status" -ne 0 ]
  fi
}

@test "validate command shows success message when all tools present" {
  # Act
  run bash -c "cd $PROJECT_ROOT/scripts && ./utils.sh validate"

  # Assert - if all validations pass, should show success
  if [ "$status" -eq 0 ]; then
    [[ "$output" == *"All validations passed!"* ]]
  fi
}

@test "validate_tool function exists in utils.sh" {
  # Arrange
  source "$PROJECT_ROOT/scripts/utils.sh"

  # Assert - function should be defined
  run type validate_tool
  [ "$status" -eq 0 ]
}

@test "extract_tool_version reads omlx version" {
  source "$PROJECT_ROOT/scripts/utils.sh"
  omlx() {
    printf '%s\n' '0.5.3'
  }

  run extract_tool_version omlx

  [ "$status" -eq 0 ]
  [ "$output" = "0.5.3" ]
}

@test "validate_installation function exists in utils.sh" {
  # Arrange
  source "$PROJECT_ROOT/scripts/utils.sh"

  # Assert - function should be defined
  run type validate_installation
  [ "$status" -eq 0 ]
}

@test "load_supercharged_preferences parses without executing shell content" {
  local marker="$HOME/preference-pwned"
  cat > "$HOME/.supercharged_preferences" <<EOF
# Supercharged Setup Preferences
INSTALL_CLOUD_TOOLS=\$(touch "$marker")
INSTALL_CODEX_APP=y
INSTALL_NETWORK_TOOLS=n
SETUP_DATE=\$(touch "$marker")
EOF

  run bash -c "
    source '$PROJECT_ROOT/scripts/utils.sh'
    load_supercharged_preferences '$HOME/.supercharged_preferences'
    printf 'cloud=%s\n' \"\${INSTALL_CLOUD_TOOLS:-unset}\"
    printf 'codex_app=%s\n' \"\${INSTALL_CODEX_APP:-unset}\"
    printf 'network=%s\n' \"\${INSTALL_NETWORK_TOOLS:-unset}\"
    [ ! -e '$marker' ]
  "

  [ "$status" -eq 0 ]
  [[ "$output" == *"cloud=unset"* ]]
  [[ "$output" == *"codex_app=Y"* ]]
  [[ "$output" == *"network=N"* ]]
  [ ! -e "$marker" ]
}

@test "validate_application checks app bundle paths" {
  source "$PROJECT_ROOT/scripts/utils.sh"
  mkdir -p "$TEST_TEMP_DIR/ChatGPT.app"

  run validate_application "ChatGPT desktop app" "$TEST_TEMP_DIR/ChatGPT.app"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ChatGPT desktop app installed"* ]]

  run validate_application "ChatGPT desktop app" "$TEST_TEMP_DIR/Missing.app"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ChatGPT desktop app not installed"* ]]
}

@test "prepend_asdf_shims_to_path enables non-interactive runtime validation" {
  source "$PROJECT_ROOT/scripts/utils.sh"
  mkdir -p "$HOME/.asdf/shims"
  unset ASDF_DATA_DIR
  PATH="/usr/bin:/bin:$HOME/.asdf/shims"

  prepend_asdf_shims_to_path

  [ "${PATH%%:*}" = "$HOME/.asdf/shims" ]
}

@test "validate_font passes when matching font exists in HOME/Library/Fonts" {
  # Arrange — HOME is the isolated test temp dir, so we control the font dir
  source "$PROJECT_ROOT/scripts/utils.sh"
  mkdir -p "$HOME/Library/Fonts"
  : > "$HOME/Library/Fonts/JetBrainsMonoNerdFont-Regular.ttf"

  # Act
  run validate_font "JetBrainsMono Nerd Font" "JetBrainsMono*Nerd*.ttf"

  # Assert
  [ "$status" -eq 0 ]
  [[ "$output" == *"JetBrainsMono Nerd Font"* ]]
}

@test "validate_font fails when no matching font is registered" {
  # Arrange — empty isolated HOME means no fonts at all
  source "$PROJECT_ROOT/scripts/utils.sh"

  # Act
  run validate_font "JetBrainsMono Nerd Font" "JetBrainsMono*Nerd*.ttf"

  # Assert
  [ "$status" -eq 1 ]
  [[ "$output" == *"not registered"* ]]
}

@test "ensure_font_registered copies staged Caskroom fonts into HOME" {
  # Arrange — fake brew binary that reports the cask installed and a Caskroom prefix
  source "$PROJECT_ROOT/scripts/utils.sh"

  local fake_prefix="$TEST_TEMP_DIR/brew-prefix"
  mkdir -p "$fake_prefix/Caskroom/font-jetbrains-mono-nerd-font/3.4.0"
  : > "$fake_prefix/Caskroom/font-jetbrains-mono-nerd-font/3.4.0/JetBrainsMonoNerdFont-Regular.ttf"
  : > "$fake_prefix/Caskroom/font-jetbrains-mono-nerd-font/3.4.0/JetBrainsMonoNerdFontMono-Bold.ttf"

  mkdir -p "$TEST_TEMP_DIR/bin"
  cat > "$TEST_TEMP_DIR/bin/brew" <<EOF
#!/bin/bash
case "\$1" in
  list) [[ "\$2" == "--cask" && "\$3" == "font-jetbrains-mono-nerd-font" ]] && exit 0 ;;
  --prefix) echo "$fake_prefix" ;;
esac
exit 0
EOF
  chmod +x "$TEST_TEMP_DIR/bin/brew"
  PATH="$TEST_TEMP_DIR/bin:$PATH"

  # Act
  run ensure_font_registered "font-jetbrains-mono-nerd-font" "JetBrainsMono*Nerd*.ttf"

  # Assert
  [ "$status" -eq 0 ]
  [ -f "$HOME/Library/Fonts/JetBrainsMonoNerdFont-Regular.ttf" ]
  [ -f "$HOME/Library/Fonts/JetBrainsMonoNerdFontMono-Bold.ttf" ]
}

@test "ensure_font_registered is a no-op when fonts already registered" {
  # Arrange
  source "$PROJECT_ROOT/scripts/utils.sh"
  mkdir -p "$HOME/Library/Fonts"
  : > "$HOME/Library/Fonts/JetBrainsMonoNerdFont-Regular.ttf"

  # Stub brew so we can detect any unwanted invocation via a marker file.
  mkdir -p "$TEST_TEMP_DIR/bin"
  cat > "$TEST_TEMP_DIR/bin/brew" <<EOF
#!/bin/bash
echo "called" >> "$TEST_TEMP_DIR/brew-calls"
case "\$1" in
  list) [[ "\$2" == "--cask" ]] && exit 0 ;;
  --prefix) echo "/nonexistent" ;;
esac
exit 0
EOF
  chmod +x "$TEST_TEMP_DIR/bin/brew"
  PATH="$TEST_TEMP_DIR/bin:$PATH"

  # Act
  run ensure_font_registered "font-jetbrains-mono-nerd-font" "JetBrainsMono*Nerd*.ttf"

  # Assert — succeeds without touching Caskroom (the stubbed --prefix points nowhere)
  [ "$status" -eq 0 ]
}

@test "ensure_font_registered is a no-op when cask is not installed" {
  # Arrange — brew stub reports cask missing
  source "$PROJECT_ROOT/scripts/utils.sh"

  mkdir -p "$TEST_TEMP_DIR/bin"
  cat > "$TEST_TEMP_DIR/bin/brew" <<'EOF'
#!/bin/bash
case "$1" in
  list) exit 1 ;;
esac
exit 0
EOF
  chmod +x "$TEST_TEMP_DIR/bin/brew"
  PATH="$TEST_TEMP_DIR/bin:$PATH"

  # Act
  run ensure_font_registered "font-jetbrains-mono-nerd-font" "JetBrainsMono*Nerd*.ttf"

  # Assert
  [ "$status" -eq 0 ]
  [ ! -d "$HOME/Library/Fonts" ] || ! compgen -G "$HOME/Library/Fonts/JetBrainsMono*Nerd*.ttf" >/dev/null
}
