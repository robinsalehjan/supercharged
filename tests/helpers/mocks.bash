#!/usr/bin/env bash
# Command mocking utilities for error scenario testing

# Mock jq command to simulate missing dependency
mock_jq_missing() {
  # shellcheck disable=SC2329
  function jq() {
    echo "jq: command not found" >&2
    return 127
  }
  export -f jq
}

# Restore real jq command
unmock_jq() {
  unset -f jq
}

# Mock stat command to return specific timestamp
# Usage: mock_stat_time "1234567890"
mock_stat_time() {
  local timestamp="$1"
  # shellcheck disable=SC2329
  function stat() {
    echo "$timestamp"
  }
  export -f stat
}

# Restore real stat command
unmock_stat() {
  unset -f stat
}

# Ensure a mock bin dir exists on PATH for path-based mocking (works in zsh subprocesses)
_ensure_mock_bin_dir() {
  if [ -n "${TEST_TEMP_DIR:-}" ]; then
    MOCK_BIN_DIR="$TEST_TEMP_DIR/bin"
    mkdir -p "$MOCK_BIN_DIR"
    export MOCK_BIN_DIR
    case ":$PATH:" in
      *":$MOCK_BIN_DIR:"*) ;;
      *) export PATH="$MOCK_BIN_DIR:$PATH" ;;
    esac
  fi
}

# Mock brew to prevent real package operations
mock_brew() {
  function brew() {
    case "$1" in
      update|upgrade|cleanup|bundle) return 0 ;;
      list)
        case "$2" in
          --cask) echo "spotify visual-studio-code" ;;
          *) echo "git jq shellcheck coreutils" ;;
        esac
        ;;
      outdated) echo "" ;;
      *) return 0 ;;
    esac
  }
  export -f brew

  # Also create a path-based mock for zsh subprocess invocations
  _ensure_mock_bin_dir
  if [ -n "${MOCK_BIN_DIR:-}" ]; then
    cat > "$MOCK_BIN_DIR/brew" << 'BREWEOF'
#!/bin/sh
case "$1" in
  update|upgrade|cleanup|bundle) exit 0 ;;
  list)
    case "$2" in
      --cask) echo "spotify visual-studio-code" ;;
      *) echo "git jq shellcheck coreutils" ;;
    esac
    ;;
  outdated) echo "" ;;
  *) exit 0 ;;
esac
BREWEOF
    chmod +x "$MOCK_BIN_DIR/brew"
  fi
}

unmock_brew() {
  unset -f brew
  [ -n "${MOCK_BIN_DIR:-}" ] && rm -f "$MOCK_BIN_DIR/brew"
}

# Mock sw_vers for macOS version testing
# Usage: mock_sw_vers "14.5.1" (will be piped through cut -d. -f1-2 by validate_system)
mock_sw_vers() {
  local version="$1"
  function sw_vers() { echo "$version"; }
  export -f sw_vers
}

unmock_sw_vers() {
  unset -f sw_vers
}

# Mock df for disk space testing
# Usage: mock_df "50Gi" — the Gi suffix is stripped by sed in validate_system
mock_df() {
  local space="$1"
  function df() {
    echo "Filesystem Size Used Avail Use% Mounted"
    echo "/dev/disk1s1 460Gi 200Gi $space 50% /"
  }
  export -f df
}

unmock_df() {
  unset -f df
}

# Mock xcode-select
mock_xcode_select_installed() {
  function xcode-select() { echo "/Applications/Xcode.app/Contents/Developer"; return 0; }
  export -f xcode-select
}

mock_xcode_select_missing() {
  function xcode-select() {
    if [ "$1" = "-p" ]; then return 1; fi
    return 0
  }
  export -f xcode-select
}

unmock_xcode_select() {
  unset -f xcode-select
}

# Mock ping for internet connectivity
mock_ping_success() {
  function ping() { return 0; }
  export -f ping

  # Also create a path-based mock for zsh subprocess invocations
  _ensure_mock_bin_dir
  if [ -n "${MOCK_BIN_DIR:-}" ]; then
    printf '#!/bin/sh\nexit 0\n' > "$MOCK_BIN_DIR/ping"
    chmod +x "$MOCK_BIN_DIR/ping"
  fi
}

mock_ping_failure() {
  function ping() { return 1; }
  export -f ping

  _ensure_mock_bin_dir
  if [ -n "${MOCK_BIN_DIR:-}" ]; then
    printf '#!/bin/sh\nexit 1\n' > "$MOCK_BIN_DIR/ping"
    chmod +x "$MOCK_BIN_DIR/ping"
  fi
}

unmock_ping() {
  unset -f ping
  [ -n "${MOCK_BIN_DIR:-}" ] && rm -f "$MOCK_BIN_DIR/ping"
}

# Mock asdf to prevent real plugin installs
mock_asdf() {
  function asdf() {
    case "$1" in
      plugin)
        case "$2" in
          list) printf '%s\n' python ruby nodejs gcloud firebase java kotlin ;;
          add|update) return 0 ;;
        esac
        ;;
      current) echo "$2 3.13.0  $HOME/.tool-versions" ;;
      install|reshim|set) return 0 ;;
      list) echo "  3.13.0" ;;
      *) return 0 ;;
    esac
  }
  export -f asdf
}

unmock_asdf() {
  unset -f asdf
}

# Mock uname for architecture detection
# Usage: mock_uname "arm64" or mock_uname "x86_64"
mock_uname() {
  local arch="$1"
  function uname() { echo "$arch"; }
  export -f uname
}

unmock_uname() {
  unset -f uname
}

# Mock curl to prevent real downloads
mock_curl() {
  function curl() { echo "mocked-download-content"; return 0; }
  export -f curl
}

unmock_curl() {
  unset -f curl
}

# Unmock all system command mocks — call in teardown to prevent leaks
unmock_all() {
  unset -f brew sw_vers df xcode-select ping asdf uname curl 2>/dev/null || true
}
