# BATS Testing Infrastructure Design

**Date:** 2026-03-17
**Status:** Approved
**Scope:** Minimal proof-of-concept testing for backup/restore sanitization and merge logic

## Overview

This design establishes a BATS-based testing infrastructure for the supercharged repository's shell scripts, focusing initially on the critical backup/restore functionality in `backup-claude.sh` and `restore-claude.sh`. The approach prioritizes rapid implementation with jq-heavy testing that mirrors production code patterns.

## Goals

1. **Verify critical sanitization logic** - Ensure work-related plugins/marketplaces are removed during backup
2. **Verify merge preservation logic** - Ensure local work plugins are preserved during restore
3. **Catch real-world failures** - Test error scenarios (missing jq, malformed JSON, missing files)
4. **Enable confident refactoring** - Provide safety net for future script changes
5. **Establish foundation** - Create extensible test infrastructure for future script coverage

## Non-Goals (For This Phase)

- Full test coverage of all shell scripts (mac.sh, update.sh, etc.)
- Integration tests that run actual installations
- Performance/benchmark testing
- Cross-platform testing (Linux, other shells)

## Architecture

### Directory Structure

```
tests/
├── helpers/
│   ├── setup.bash           # Common setup/teardown, temp directory management
│   ├── assertions.bash      # jq-based JSON assertions and comparisons
│   └── mocks.bash          # Mock command failures (jq, missing files)
├── fixtures/
│   ├── claude-backup/      # Input fixtures for backup tests
│   │   ├── settings-full.json
│   │   ├── plugins-mixed.json
│   │   ├── marketplaces-full.json
│   │   └── plugins-malformed.json
│   ├── claude-restore/     # Input fixtures for restore tests
│   │   ├── repo-sanitized.json
│   │   ├── local-with-vend.json
│   │   └── repo-config.json
│   └── expected/           # Expected output JSON files
│       ├── plugins-sanitized.json
│       ├── marketplaces-sanitized.json
│       └── plugins-merged.json
├── claude/
│   ├── backup.bats         # Tests for backup-claude.sh sanitization
│   └── restore.bats        # Tests for restore-claude.sh merge logic
└── utils/
    └── portability.bats    # Tests for make_path_portable/expand_portable_path

package.json                # Updated with test scripts
.husky/pre-commit          # Updated to run tests
.github/workflows/test.yml  # CI configuration (optional)
```

### Key Architectural Principles

1. **Isolation** - Each test runs in its own temporary directory with `$HOME` override
2. **Fixtures** - Real JSON files represent test scenarios (version-controlled, human-readable)
3. **jq-first** - All JSON operations use jq for reliability (mirrors production)
4. **Source scripts** - Tests import actual production scripts and test functions directly
5. **Automatic cleanup** - Teardown removes temp files after each test
6. **Parallel-safe** - Tests can run concurrently without interference

## Testing Approach

### Test Philosophy

- **Happy paths first** - Verify core functionality works as expected
- **Critical errors second** - Test realistic failure modes (missing dependencies, bad input)
- **Edge cases later** - Can be added incrementally as needed
- **Readable assertions** - Use jq queries that clearly express intent
- **Fast execution** - Target < 5 seconds for full suite

### Test Categories

#### 1. Backup Sanitization Tests (`tests/claude/backup.bats`)

Tests for `backup-claude.sh` focusing on removing work-related data:

**Happy Paths:**
- `removes vend-plugins from settings.json enabledPlugins` - Verifies work plugins excluded from settings
- `removes vend-plugins entries from installed_plugins.json` - Verifies work plugins removed from plugin list
- `removes vend-plugins marketplace from known_marketplaces.json` - Verifies work marketplace excluded
- `preserves personal plugins in installed_plugins.json` - Verifies non-work plugins remain intact
- `preserves personal marketplaces in known_marketplaces.json` - Verifies non-work marketplaces remain
- `makes paths portable by replacing HOME directory` - Verifies `/Users/username/` → `$HOME/`

**Error Scenarios:**
- `exits with error when jq is missing` - Validates dependency check works
- `logs warning and continues when source file missing` - Graceful degradation
- `logs error when JSON is malformed` - Handles invalid input

#### 2. Restore Merge Tests (`tests/claude/restore.bats`)

Tests for `restore-claude.sh` focusing on preserving local work data:

**Happy Paths:**
- `merges repo config with preserved local vend-plugins` - Core merge functionality
- `creates new config when no local config exists` - Fresh install scenario
- `skips restore when local config is newer` - Timestamp comparison logic
- `force restore overwrites regardless of timestamps` - `--force` flag behavior
- `expands $HOME placeholder to actual home directory` - Verifies `$HOME/` → `/Users/username/`
- `preserves multiple vend-plugins during merge` - Handles multiple work plugins

**Error Scenarios:**
- `warns and overwrites when jq missing during merge` - Fallback behavior documented
- `handles missing repo config gracefully` - Early exit when nothing to restore
- `handles malformed local JSON during merge` - Error handling for bad local state

#### 3. Path Portability Tests (`tests/utils/portability.bats`)

Tests for utility functions in `utils.sh`:

**Happy Paths:**
- `make_path_portable replaces /Users/username with $HOME` - Forward transformation
- `expand_portable_path replaces $HOME with actual path` - Reverse transformation
- `round-trip preserves JSON structure and data` - Verify lossless transformation
- `handles nested paths in JSON objects` - Deep object support
- `handles paths in JSON arrays` - Array element support

**Edge Cases:**
- `handles multiple paths in same JSON file` - Multiple replacements
- `preserves paths that don't contain HOME` - Only modify relevant paths
- `handles empty JSON objects` - Graceful handling of edge input

## Implementation Details

### Helper Functions

#### `tests/helpers/setup.bash`

Provides test environment setup and teardown:

```bash
# Create isolated temp directory for each test
setup_test_env() {
  TEST_TEMP_DIR="$(mktemp -d)"
  TEMP_CLAUDE="$TEST_TEMP_DIR/.claude"
  TEMP_CLAUDE_PLUGINS="$TEMP_CLAUDE/plugins"
  TEMP_REPO_CONFIG="$TEST_TEMP_DIR/claude_config"

  mkdir -p "$TEMP_CLAUDE_PLUGINS"
  mkdir -p "$TEMP_REPO_CONFIG"

  export HOME="$TEST_TEMP_DIR"  # Override HOME for path portability tests
  export FIXTURE_DIR="$(cd "$(dirname "${BATS_TEST_DIRNAME}")/../fixtures" && pwd)"
}

# Cleanup after each test
teardown_test_env() {
  [ -n "$TEST_TEMP_DIR" ] && rm -rf "$TEST_TEMP_DIR"
}
```

**Usage in tests:**
```bash
setup() {
  load '../helpers/setup'
  setup_test_env
}

teardown() {
  teardown_test_env
}
```

#### `tests/helpers/assertions.bash`

Provides jq-based JSON assertion utilities:

```bash
# Assert JSON field equals expected value
# Usage: assert_json_field "file.json" ".plugins | length" "2"
assert_json_field() {
  local file="$1"
  local jq_query="$2"
  local expected="$3"

  local actual=$(jq -r "$jq_query" "$file")
  [ "$actual" = "$expected" ] || {
    echo "Expected: $expected"
    echo "Actual: $actual"
    return 1
  }
}

# Assert JSON array does not contain value
# Usage: assert_json_array_not_contains "plugins.json" '.plugins | keys[]' 'vend-internal@vend-plugins'
assert_json_array_not_contains() {
  local file="$1"
  local jq_query="$2"
  local value="$3"

  local result=$(jq -r "$jq_query | select(. == \"$value\")" "$file")
  [ -z "$result" ] || {
    echo "Array should not contain: $value"
    return 1
  }
}

# Assert JSON files are equivalent (ignoring whitespace/order)
# Usage: assert_json_equals "actual.json" "expected.json"
assert_json_equals() {
  local actual="$1"
  local expected="$2"

  diff <(jq -S . "$actual") <(jq -S . "$expected") || {
    echo "JSON files differ"
    return 1
  }
}

# Assert plugin key exists in JSON
# Usage: assert_plugin_exists "plugins.json" "superpowers@claude-plugins-official"
assert_plugin_exists() {
  local file="$1"
  local plugin_key="$2"

  local exists=$(jq -r ".plugins | has(\"$plugin_key\")" "$file")
  [ "$exists" = "true" ] || {
    echo "Plugin not found: $plugin_key"
    return 1
  }
}

# Assert plugin key does NOT exist in JSON
# Usage: assert_plugin_not_exists "plugins.json" "vend-internal@vend-plugins"
assert_plugin_not_exists() {
  local file="$1"
  local plugin_key="$2"

  local exists=$(jq -r ".plugins | has(\"$plugin_key\")" "$file")
  [ "$exists" = "false" ] || {
    echo "Plugin should not exist: $plugin_key"
    return 1
  }
}
```

#### `tests/helpers/mocks.bash`

Provides command mocking for error scenarios:

```bash
# Mock jq command to simulate missing dependency
mock_jq_missing() {
  function jq() {
    echo "jq: command not found" >&2
    return 127
  }
  export -f jq
}

# Restore real jq
unmock_jq() {
  unset -f jq
}

# Mock stat command for timestamp tests
mock_stat_older() {
  local older_time="$1"
  function stat() {
    echo "$older_time"
  }
  export -f stat
}

unmock_stat() {
  unset -f stat
}
```

### Fixture Design

#### Sample Fixture: `tests/fixtures/claude-backup/plugins-mixed.json`

Represents realistic scenario with both personal and work plugins:

```json
{
  "version": 2,
  "plugins": {
    "superpowers@claude-plugins-official": {
      "version": "5.0.2",
      "installPath": "/Users/robin.saleh-jan@m10s.io/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.2"
    },
    "hookify@claude-plugins-official": {
      "version": "2.1.0",
      "installPath": "/Users/robin.saleh-jan@m10s.io/.claude/plugins/cache/claude-plugins-official/hookify/2.1.0"
    },
    "vend-internal@vend-plugins": {
      "version": "1.0.0",
      "installPath": "/Users/robin.saleh-jan@m10s.io/.claude/plugins/cache/vend-plugins/vend-internal/1.0.0"
    },
    "vend-api@vend-plugins": {
      "version": "2.3.0",
      "installPath": "/Users/robin.saleh-jan@m10s.io/.claude/plugins/cache/vend-plugins/vend-api/2.3.0"
    }
  }
}
```

#### Expected Output: `tests/fixtures/expected/plugins-sanitized.json`

After sanitization (work plugins removed, paths made portable):

```json
{
  "version": 2,
  "plugins": {
    "superpowers@claude-plugins-official": {
      "version": "5.0.2",
      "installPath": "$HOME/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.2"
    },
    "hookify@claude-plugins-official": {
      "version": "2.1.0",
      "installPath": "$HOME/.claude/plugins/cache/claude-plugins-official/hookify/2.1.0"
    }
  }
}
```

### Test Execution Flow

1. BATS loads test file (e.g., `tests/claude/backup.bats`)
2. `setup()` hook runs before each test:
   - Calls `setup_test_env()` - creates temp directories
   - Sets `$HOME` to temp directory
   - Loads fixtures directory path
3. Test function executes:
   - Copies fixtures to temp locations
   - Sources production script: `source ./scripts/backup-claude.sh`
   - Calls production functions with temp paths
   - Uses jq-based assertions to verify output
4. `teardown()` hook runs after each test:
   - Calls `teardown_test_env()` - removes temp directories
   - Restores environment

### Example Test Implementation

```bash
# tests/claude/backup.bats

setup() {
  load '../helpers/setup'
  load '../helpers/assertions'
  setup_test_env

  # Source the production script
  source "$BATS_TEST_DIRNAME/../../scripts/backup-claude.sh"
}

teardown() {
  teardown_test_env
}

@test "removes vend-plugins entries from installed_plugins.json" {
  # Arrange: Copy fixture to temp Claude directory
  cp "$FIXTURE_DIR/claude-backup/plugins-mixed.json" \
     "$TEMP_CLAUDE_PLUGINS/installed_plugins.json"

  # Act: Run backup sanitization (would need to extract this logic)
  # This is conceptual - actual implementation may differ
  export CLAUDE_HOME="$TEMP_CLAUDE"
  export CLAUDE_CONFIG_DIR="$TEMP_REPO_CONFIG"

  # Manually call the sanitization logic
  # (In practice, we'd extract this to a testable function)
  jq '{version: .version, plugins: (.plugins | to_entries | map(select(.key | endswith("@vend-plugins") | not)) | from_entries)}' \
     "$TEMP_CLAUDE_PLUGINS/installed_plugins.json" > "$TEMP_REPO_CONFIG/installed_plugins.json"

  # Assert: Verify vend-plugins removed
  assert_plugin_not_exists "$TEMP_REPO_CONFIG/installed_plugins.json" "vend-internal@vend-plugins"
  assert_plugin_not_exists "$TEMP_REPO_CONFIG/installed_plugins.json" "vend-api@vend-plugins"

  # Assert: Verify personal plugins preserved
  assert_plugin_exists "$TEMP_REPO_CONFIG/installed_plugins.json" "superpowers@claude-plugins-official"
  assert_plugin_exists "$TEMP_REPO_CONFIG/installed_plugins.json" "hookify@claude-plugins-official"
}
```

## Integration with Workflow

### NPM Scripts

Add to `package.json`:

```json
{
  "scripts": {
    "test": "bats tests/**/*.bats",
    "test:watch": "watch 'npm test' tests scripts",
    "test:claude": "bats tests/claude/*.bats",
    "test:utils": "bats tests/utils/*.bats",
    "pretest": "command -v bats >/dev/null || (echo '❌ bats not found. Install with: brew install bats-core' && exit 1)"
  }
}
```

### Pre-commit Hook Integration

Update `.husky/pre-commit` to run tests before commit:

```bash
#!/bin/zsh

echo "🔒 Running security checks..."
# ... existing security checks ...

# Run BATS tests if test files exist
if [ -d "tests" ] && command -v bats >/dev/null 2>&1; then
  echo "🧪 Running tests..."
  npm test || {
    echo "❌ Tests failed. Fix issues before committing."
    exit 1
  }
fi

echo "✅ All checks passed!"
```

**Optional bypass:** Allow `--no-test` in commit message to skip tests during rapid iteration:

```bash
# Check for --no-test flag in commit message
if git log -1 --pretty=%B 2>/dev/null | grep -q '\-\-no-test'; then
  echo "⏭️  Skipping tests (--no-test flag detected)"
else
  npm test || {
    echo "❌ Tests failed. Fix issues or use --no-test in commit message."
    exit 1
  }
fi
```

### CI/CD Structure

Create `.github/workflows/test.yml` for GitHub Actions:

```yaml
name: Tests

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]

jobs:
  test:
    runs-on: macos-latest

    steps:
    - uses: actions/checkout@v3

    - name: Install dependencies
      run: |
        brew install bats-core jq shellcheck
        npm install

    - name: Run shellcheck
      run: npm run lint

    - name: Run BATS tests
      run: npm test

    - name: Upload test results
      if: failure()
      uses: actions/upload-artifact@v3
      with:
        name: test-logs
        path: |
          tests/**/*.log
          *.log
```

### Installation Requirements

Ensure BATS is installed during setup. Update `scripts/mac.sh` to include:

```bash
# Testing tools (already has jq and shellcheck)
brew "bats-core"
```

**Note:** jq and shellcheck are already installed as core dependencies.

### Documentation Updates

Add to `README.md`:

```markdown
## 🧪 Testing

### Run Tests

```bash
npm test              # Run all tests
npm run test:claude   # Run Claude backup/restore tests only
npm run test:utils    # Run utility function tests only
```

### Test Requirements

- bats-core (installed via setup)
- jq (installed via setup)
- shellcheck (installed via setup)

Tests run automatically in:
- Pre-commit hook (can bypass with `--no-test` in commit message)
- GitHub Actions on push/PR

### Writing Tests

See `tests/claude/backup.bats` for examples. Key patterns:

- Use `setup_test_env()` for isolated temp directories
- Use jq-based assertions from `tests/helpers/assertions.bash`
- Copy fixtures from `tests/fixtures/` for test data
- Source production scripts and test functions directly
```

## Success Criteria

A successful implementation will:

1. ✅ **Verify sanitization** - Confirm vend-plugins removed during backup
2. ✅ **Verify preservation** - Confirm vend-plugins preserved during restore
3. ✅ **Catch errors** - Tests fail when jq missing or JSON malformed
4. ✅ **Run fast** - Full test suite completes in < 5 seconds
5. ✅ **Integrate smoothly** - Pre-commit hook runs tests without friction
6. ✅ **CI-ready** - GitHub Actions configuration works (optional for PoC)

## Future Enhancements

After proving the concept, consider:

1. **Expand coverage** - Add tests for `setup-profile.sh`, `update.sh`
2. **Edge case testing** - Empty configs, all-work-plugins, no-local-plugins
3. **Performance tests** - Verify operations complete within time budgets
4. **Integration tests** - End-to-end workflows with real temp installations
5. **Test coverage reporting** - Track which script functions have tests
6. **Parallel execution** - Run tests concurrently for faster feedback

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| BATS not installed on dev machines | Pre-commit checks for BATS, `npm test` has helpful error |
| Tests too slow, block commits | Target < 5s total, can bypass with `--no-test` flag |
| Fixtures drift from production format | Use real production JSON as basis for fixtures |
| Tests become brittle with script changes | Test behavior not implementation, use jq queries |
| Hard to test scripts with side effects | Extract testable functions, mock external commands |

## Implementation Plan (Outline)

This design document will be followed by a detailed implementation plan that breaks down:

1. Setup BATS infrastructure (install, configuration)
2. Create helper libraries (setup.bash, assertions.bash, mocks.bash)
3. Build fixture files (backup scenarios, restore scenarios, expected outputs)
4. Implement backup sanitization tests
5. Implement restore merge tests
6. Implement path portability tests
7. Update pre-commit hook
8. Update package.json with test scripts
9. Create GitHub Actions workflow (optional)
10. Update documentation

## Conclusion

This BATS testing infrastructure provides a minimal, pragmatic approach to testing the critical backup/restore functionality. By leveraging jq-heavy assertions that mirror production code, tests are fast to write, easy to understand, and provide confidence in refactoring. The hierarchical test organization and shared fixtures create a foundation that scales as more scripts are added to test coverage.
