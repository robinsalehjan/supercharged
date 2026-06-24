#!/usr/bin/env bash
# Command mocking utilities for error scenario testing

# Restore real jq command
unmock_jq() {
  unset -f jq
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

# Mock rtk for RTK setup testing
mock_rtk() {
    _ensure_mock_bin_dir
    if [ -n "${MOCK_BIN_DIR:-}" ]; then
        cat > "$MOCK_BIN_DIR/rtk" << 'RTKEOF'
#!/bin/sh
case "$1" in
    init) exit 0 ;;
    --version) echo "rtk 0.5.0" ;;
    *) exit 0 ;;
esac
RTKEOF
        chmod +x "$MOCK_BIN_DIR/rtk"
    fi
}

unmock_rtk() {
    [ -n "${MOCK_BIN_DIR:-}" ] && rm -f "$MOCK_BIN_DIR/rtk"
}

# Mock pipx for code-review-graph testing
mock_pipx() {
    _ensure_mock_bin_dir
    if [ -n "${MOCK_BIN_DIR:-}" ]; then
        printf '#!/bin/sh\nexit 0\n' > "$MOCK_BIN_DIR/pipx"
        chmod +x "$MOCK_BIN_DIR/pipx"
    fi
}

unmock_pipx() {
    [ -n "${MOCK_BIN_DIR:-}" ] && rm -f "$MOCK_BIN_DIR/pipx"
}

# Mock code-review-graph
mock_code_review_graph() {
    _ensure_mock_bin_dir
    if [ -n "${MOCK_BIN_DIR:-}" ]; then
        printf '#!/bin/sh\nexit 0\n' > "$MOCK_BIN_DIR/code-review-graph"
        chmod +x "$MOCK_BIN_DIR/code-review-graph"
    fi
}

unmock_code_review_graph() {
    [ -n "${MOCK_BIN_DIR:-}" ] && rm -f "$MOCK_BIN_DIR/code-review-graph"
}

# Mock wt (Worktrunk) for setup testing
mock_wt() {
    _ensure_mock_bin_dir
    if [ -n "${MOCK_BIN_DIR:-}" ]; then
        cat > "$MOCK_BIN_DIR/wt" << 'WTEOF'
#!/bin/sh
case "$1 $2 $3" in
    "config shell install") exit 0 ;;
    *) exit 0 ;;
esac
WTEOF
        chmod +x "$MOCK_BIN_DIR/wt"
    fi
}

unmock_wt() {
    [ -n "${MOCK_BIN_DIR:-}" ] && rm -f "$MOCK_BIN_DIR/wt"
}

# Mock gh CLI for Obscura release-download tests.
# Intercepts `gh release download --pattern <name> --dir <dir>` and writes a
# fake tarball at <dir>/<name> containing two stub binaries (obscura,
# obscura-worker). Binaries are placed at archive root only — the
# subdir-nesting fallback in setup_obscura's `find` call is NOT exercised
# by this mock. Any other gh subcommand is a silent success.
mock_gh_release_obscura() {
    _ensure_mock_bin_dir
    if [ -n "${MOCK_BIN_DIR:-}" ]; then
        cat > "$MOCK_BIN_DIR/gh" << 'GHEOF'
#!/bin/sh
if [ "$1" = "release" ] && [ "$2" = "download" ]; then
    # Parse --pattern and --dir
    pattern=""
    dir=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --pattern) pattern="$2"; shift 2 ;;
            --dir) dir="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    [ -n "$pattern" ] && [ -n "$dir" ] || exit 1
    mkdir -p "$dir"
    staging=$(mktemp -d)
    printf '#!/bin/sh\necho obscura-stub\n' > "$staging/obscura"
    printf '#!/bin/sh\necho obscura-worker-stub\n' > "$staging/obscura-worker"
    chmod +x "$staging/obscura" "$staging/obscura-worker"
    tar -czf "$dir/$pattern" -C "$staging" obscura obscura-worker
    rm -rf "$staging"
    exit 0
fi
exit 0
GHEOF
        chmod +x "$MOCK_BIN_DIR/gh"
    fi
}

unmock_gh_release_obscura() {
    [ -n "${MOCK_BIN_DIR:-}" ] && rm -f "$MOCK_BIN_DIR/gh"
}

# Mock claude CLI — records every invocation to $MOCK_BIN_DIR/claude.calls
# so smoke tests can assert what install-plugins.sh / restore-claude.sh would run.
#
# NOTE: the heredoc is UNQUOTED so MOCK_BIN_DIR expands at stub-write time and
# the absolute path bakes into the generated shim. $* is escaped so it expands
# at invocation time. Required because the stub runs as its own sh process and
# wouldn't see MOCK_BIN_DIR from the test environment otherwise.
mock_claude() {
    _ensure_mock_bin_dir
    if [ -n "${MOCK_BIN_DIR:-}" ]; then
        : > "$MOCK_BIN_DIR/claude.calls"
        cat > "$MOCK_BIN_DIR/claude" << CLAUDEEOF
#!/bin/sh
printf '%s\n' "\$*" >> "$MOCK_BIN_DIR/claude.calls"
exit 0
CLAUDEEOF
        chmod +x "$MOCK_BIN_DIR/claude"
    fi
}

unmock_claude() {
    [ -n "${MOCK_BIN_DIR:-}" ] && rm -f "$MOCK_BIN_DIR/claude" "$MOCK_BIN_DIR/claude.calls"
}

# Unmock all system command mocks — call in teardown to prevent leaks
unmock_all() {
  unset -f brew ping asdf 2>/dev/null || true
  [ -n "${MOCK_BIN_DIR:-}" ] && rm -f "$MOCK_BIN_DIR/rtk" "$MOCK_BIN_DIR/pipx" "$MOCK_BIN_DIR/code-review-graph" "$MOCK_BIN_DIR/wt" "$MOCK_BIN_DIR/gh" "$MOCK_BIN_DIR/obscura" "$MOCK_BIN_DIR/obscura-worker" "$MOCK_BIN_DIR/ping" "$MOCK_BIN_DIR/brew" "$MOCK_BIN_DIR/claude" "$MOCK_BIN_DIR/claude.calls" 2>/dev/null || true
}
