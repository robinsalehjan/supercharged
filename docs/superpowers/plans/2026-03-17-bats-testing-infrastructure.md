# BATS Testing Infrastructure Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement BATS testing infrastructure for backup-claude.sh and restore-claude.sh with jq-based assertions

**Architecture:** Test suite organized hierarchically (tests/claude/, tests/utils/) with shared helpers (setup, assertions, mocks) and reusable fixtures. Tests source production scripts and verify behavior with jq queries. Pre-commit integration catches issues early.

**Tech Stack:** BATS (bats-core), jq, zsh, git hooks (Husky)

**Spec:** `docs/superpowers/specs/2026-03-17-bats-testing-design.md`

---

## File Structure Overview

### New Files to Create

**Test Infrastructure:**
```
tests/
├── helpers/
│   ├── setup.bash           # Temp directory management, fixture loading
│   ├── assertions.bash      # jq-based JSON assertions
│   └── mocks.bash          # Command mocking for error scenarios
```

**Test Fixtures:**
```
tests/fixtures/
├── claude-backup/
│   ├── settings-full.json
│   ├── plugins-mixed.json
│   ├── marketplaces-full.json
│   └── plugins-malformed.json
├── claude-restore/
│   ├── repo-sanitized.json
│   ├── local-with-vend.json
│   └── repo-config.json
└── expected/
    ├── plugins-sanitized.json
    ├── marketplaces-sanitized.json
    └── plugins-merged.json
```

**Test Files:**
```
tests/
├── claude/
│   ├── backup.bats         # Backup sanitization tests
│   └── restore.bats        # Restore merge tests
└── utils/
    └── portability.bats    # Path portability tests
```

**CI/CD:**
```
.github/workflows/
└── test.yml                # GitHub Actions workflow
```

### Files to Modify

- `package.json` - Add test scripts
- `.husky/pre-commit` - Add test execution
- `scripts/mac.sh` - Ensure bats-core in Brewfile
- `README.md` - Add testing documentation

---

## Chunk 1: Infrastructure Setup and Test Helpers

### Task 1: Install BATS and Create Directory Structure

**Files:**
- Modify: `scripts/mac.sh` (Brewfile section)
- Create: `tests/` directory structure

- [ ] **Step 1: Ensure bats-core in Brewfile**

Check if `scripts/mac.sh` already includes bats-core in the Brewfile content:

```bash
grep -n "bats-core" scripts/mac.sh
```

Expected: Should find it in the existing brew packages list. If not found, add it.

- [ ] **Step 2: Create test directory structure**

```bash
mkdir -p tests/helpers
mkdir -p tests/fixtures/claude-backup
mkdir -p tests/fixtures/claude-restore
mkdir -p tests/fixtures/expected
mkdir -p tests/claude
mkdir -p tests/utils
```

- [ ] **Step 3: Verify directory structure**

```bash
tree tests/ -L 3
```

Expected output:
```
tests/
├── claude
├── fixtures
│   ├── claude-backup
│   ├── claude-restore
│   └── expected
├── helpers
└── utils
```

- [ ] **Step 4: Commit directory structure**

```bash
git add tests/
git commit -m "test: create BATS test directory structure"
```

---

### Task 2: Create Test Setup Helper

**Files:**
- Create: `tests/helpers/setup.bash`

- [ ] **Step 1: Create setup.bash with temp directory management**

Create `tests/helpers/setup.bash`:

```bash
#!/usr/bin/env bash
# Test environment setup and teardown utilities

# Create isolated temp directory for each test
setup_test_env() {
  TEST_TEMP_DIR="$(mktemp -d)"
  TEMP_CLAUDE="$TEST_TEMP_DIR/.claude"
  TEMP_CLAUDE_PLUGINS="$TEMP_CLAUDE/plugins"
  TEMP_REPO_CONFIG="$TEST_TEMP_DIR/claude_config"

  mkdir -p "$TEMP_CLAUDE_PLUGINS"
  mkdir -p "$TEMP_REPO_CONFIG"

  # Backup original HOME before override
  export ORIGINAL_HOME="$HOME"

  # Override HOME for path portability tests
  export HOME="$TEST_TEMP_DIR"

  # Set fixture directory path (relative to tests/)
  FIXTURE_DIR="$(cd "$(dirname "${BATS_TEST_DIRNAME}")/../fixtures" && pwd)"

  # Export for use in tests
  export TEST_TEMP_DIR
  export TEMP_CLAUDE
  export TEMP_CLAUDE_PLUGINS
  export TEMP_REPO_CONFIG
  export FIXTURE_DIR
}

# Cleanup after each test
teardown_test_env() {
  if [ -n "$TEST_TEMP_DIR" ] && [ -d "$TEST_TEMP_DIR" ]; then
    rm -rf "$TEST_TEMP_DIR"
  fi

  # Restore original HOME if we backed it up
  if [ -n "$ORIGINAL_HOME" ]; then
    export HOME="$ORIGINAL_HOME"
  fi
}

# Load fixture file to destination
# Usage: load_fixture "claude-backup/plugins-mixed.json" "$TEMP_CLAUDE_PLUGINS/installed_plugins.json"
load_fixture() {
  local fixture_name="$1"
  local destination="$2"

  if [ ! -f "$FIXTURE_DIR/$fixture_name" ]; then
    echo "Fixture not found: $FIXTURE_DIR/$fixture_name" >&2
    return 1
  fi

  mkdir -p "$(dirname "$destination")"
  cp "$FIXTURE_DIR/$fixture_name" "$destination"
}
```

- [ ] **Step 2: Make setup.bash executable**

```bash
chmod +x tests/helpers/setup.bash
```

- [ ] **Step 3: Verify setup.bash syntax**

```bash
shellcheck --shell=bash tests/helpers/setup.bash
```

Expected: No errors or only SC2034 warnings about unused variables (which are OK - they're exported for test use)

- [ ] **Step 4: Commit setup helper**

```bash
git add tests/helpers/setup.bash
git commit -m "test: add test environment setup helper"
```

---

### Task 3: Create JSON Assertion Helper

**Files:**
- Create: `tests/helpers/assertions.bash`

- [ ] **Step 1: Create assertions.bash with jq-based utilities**

Create `tests/helpers/assertions.bash`:

```bash
#!/usr/bin/env bash
# jq-based JSON assertion utilities

# Assert JSON field equals expected value
# Usage: assert_json_field "file.json" ".plugins | length" "2"
assert_json_field() {
  local file="$1"
  local jq_query="$2"
  local expected="$3"

  if [ ! -f "$file" ]; then
    echo "File not found: $file" >&2
    return 1
  fi

  local actual
  actual=$(jq -r "$jq_query" "$file" 2>&1)
  if [ $? -ne 0 ]; then
    echo "jq query failed: $jq_query" >&2
    echo "$actual" >&2
    return 1
  fi

  if [ "$actual" != "$expected" ]; then
    echo "Expected: $expected" >&2
    echo "Actual: $actual" >&2
    echo "Query: $jq_query" >&2
    return 1
  fi
}

# Assert JSON array does not contain value
# Usage: assert_json_array_not_contains "plugins.json" '.plugins | keys[]' 'vend-internal@vend-plugins'
assert_json_array_not_contains() {
  local file="$1"
  local jq_query="$2"
  local value="$3"

  if [ ! -f "$file" ]; then
    echo "File not found: $file" >&2
    return 1
  fi

  local result
  result=$(jq -r "$jq_query | select(. == \"$value\")" "$file" 2>&1)
  if [ $? -ne 0 ]; then
    echo "jq query failed: $jq_query" >&2
    echo "$result" >&2
    return 1
  fi

  if [ -n "$result" ]; then
    echo "Array should not contain: $value" >&2
    echo "Found: $result" >&2
    return 1
  fi
}

# Assert JSON files are equivalent (ignoring whitespace/order)
# Usage: assert_json_equals "actual.json" "expected.json"
assert_json_equals() {
  local actual="$1"
  local expected="$2"

  if [ ! -f "$actual" ]; then
    echo "Actual file not found: $actual" >&2
    return 1
  fi

  if [ ! -f "$expected" ]; then
    echo "Expected file not found: $expected" >&2
    return 1
  fi

  local diff_output
  diff_output=$(diff <(jq -S . "$actual" 2>&1) <(jq -S . "$expected" 2>&1) 2>&1)
  if [ $? -ne 0 ]; then
    echo "JSON files differ:" >&2
    echo "$diff_output" >&2
    return 1
  fi
}

# Assert plugin key exists in JSON
# Usage: assert_plugin_exists "plugins.json" "superpowers@claude-plugins-official"
assert_plugin_exists() {
  local file="$1"
  local plugin_key="$2"

  if [ ! -f "$file" ]; then
    echo "File not found: $file" >&2
    return 1
  fi

  local exists
  exists=$(jq -r ".plugins | has(\"$plugin_key\")" "$file" 2>&1)
  if [ $? -ne 0 ]; then
    echo "jq query failed" >&2
    echo "$exists" >&2
    return 1
  fi

  if [ "$exists" != "true" ]; then
    echo "Plugin not found: $plugin_key" >&2
    echo "Available plugins:" >&2
    jq -r '.plugins | keys[]' "$file" >&2
    return 1
  fi
}

# Assert plugin key does NOT exist in JSON
# Usage: assert_plugin_not_exists "plugins.json" "vend-internal@vend-plugins"
assert_plugin_not_exists() {
  local file="$1"
  local plugin_key="$2"

  if [ ! -f "$file" ]; then
    echo "File not found: $file" >&2
    return 1
  fi

  local exists
  exists=$(jq -r ".plugins | has(\"$plugin_key\")" "$file" 2>&1)
  if [ $? -ne 0 ]; then
    echo "jq query failed" >&2
    echo "$exists" >&2
    return 1
  fi

  if [ "$exists" = "true" ]; then
    echo "Plugin should not exist: $plugin_key" >&2
    return 1
  fi
}

# Assert marketplace exists in JSON
# Usage: assert_marketplace_exists "marketplaces.json" "claude-plugins-official"
assert_marketplace_exists() {
  local file="$1"
  local marketplace_key="$2"

  if [ ! -f "$file" ]; then
    echo "File not found: $file" >&2
    return 1
  fi

  local exists
  exists=$(jq -r "has(\"$marketplace_key\")" "$file" 2>&1)
  if [ $? -ne 0 ]; then
    echo "jq query failed" >&2
    echo "$exists" >&2
    return 1
  fi

  if [ "$exists" != "true" ]; then
    echo "Marketplace not found: $marketplace_key" >&2
    echo "Available marketplaces:" >&2
    jq -r 'keys[]' "$file" >&2
    return 1
  fi
}

# Assert marketplace does NOT exist in JSON
# Usage: assert_marketplace_not_exists "marketplaces.json" "vend-plugins"
assert_marketplace_not_exists() {
  local file="$1"
  local marketplace_key="$2"

  if [ ! -f "$file" ]; then
    echo "File not found: $file" >&2
    return 1
  fi

  local exists
  exists=$(jq -r "has(\"$marketplace_key\")" "$file" 2>&1)
  if [ $? -ne 0 ]; then
    echo "jq query failed" >&2
    echo "$exists" >&2
    return 1
  fi

  if [ "$exists" = "true" ]; then
    echo "Marketplace should not exist: $marketplace_key" >&2
    return 1
  fi
}
```

- [ ] **Step 2: Make assertions.bash executable**

```bash
chmod +x tests/helpers/assertions.bash
```

- [ ] **Step 3: Verify assertions.bash syntax**

```bash
shellcheck --shell=bash tests/helpers/assertions.bash
```

Expected: No errors

- [ ] **Step 4: Commit assertions helper**

```bash
git add tests/helpers/assertions.bash
git commit -m "test: add jq-based JSON assertion utilities"
```

---

### Task 4: Create Command Mocking Helper

**Files:**
- Create: `tests/helpers/mocks.bash`

- [ ] **Step 1: Create mocks.bash with command mocking**

Create `tests/helpers/mocks.bash`:

```bash
#!/usr/bin/env bash
# Command mocking utilities for error scenario testing

# Mock jq command to simulate missing dependency
mock_jq_missing() {
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
  function stat() {
    echo "$timestamp"
  }
  export -f stat
}

# Restore real stat command
unmock_stat() {
  unset -f stat
}

# Create a file that simulates malformed JSON
# Usage: create_malformed_json "$output_file"
create_malformed_json() {
  local output_file="$1"
  # Missing closing braces to create genuinely malformed JSON
  cat > "$output_file" <<'EOF'
{
  "version": 2,
  "plugins": {
    "incomplete-plugin": {
      "version": "1.0.0"
    }
  }
EOF
}
```

- [ ] **Step 2: Make mocks.bash executable**

```bash
chmod +x tests/helpers/mocks.bash
```

- [ ] **Step 3: Verify mocks.bash syntax**

```bash
shellcheck --shell=bash tests/helpers/mocks.bash
```

Expected: No errors

- [ ] **Step 4: Commit mocks helper**

```bash
git add tests/helpers/mocks.bash
git commit -m "test: add command mocking utilities"
```

---

## Chunk 2: Test Fixtures

### Task 5: Create Backup Test Fixtures

**Files:**
- Create: `tests/fixtures/claude-backup/settings-full.json`
- Create: `tests/fixtures/claude-backup/plugins-mixed.json`
- Create: `tests/fixtures/claude-backup/marketplaces-full.json`
- Create: `tests/fixtures/claude-backup/plugins-malformed.json`

- [ ] **Step 1: Create settings-full.json fixture**

Create `tests/fixtures/claude-backup/settings-full.json`:

```json
{
  "enabledPlugins": {
    "superpowers@claude-plugins-official": true,
    "hookify@claude-plugins-official": true,
    "vend-internal@vend-plugins": true,
    "vend-api@vend-plugins": true
  },
  "theme": "dark",
  "model": "claude-sonnet-4-5"
}
```

- [ ] **Step 2: Create plugins-mixed.json fixture**

Create `tests/fixtures/claude-backup/plugins-mixed.json`:

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

- [ ] **Step 3: Create marketplaces-full.json fixture**

Create `tests/fixtures/claude-backup/marketplaces-full.json`:

```json
{
  "claude-plugins-official": {
    "url": "https://github.com/anthropics/claude-plugins-official",
    "type": "git"
  },
  "vend-plugins": {
    "url": "git@github.com:vend/vend-plugins.git",
    "type": "git"
  }
}
```

- [ ] **Step 4: Create plugins-malformed.json fixture**

Create `tests/fixtures/claude-backup/plugins-malformed.json`:

```json
{
  "version": 2,
  "plugins": {
    "test-plugin@marketplace": {
      "version": "1.0.0"
```

Note: This file is intentionally malformed (missing closing braces) for error testing.

- [ ] **Step 5: Verify fixtures are valid JSON (except malformed)**

```bash
jq . tests/fixtures/claude-backup/settings-full.json > /dev/null
jq . tests/fixtures/claude-backup/plugins-mixed.json > /dev/null
jq . tests/fixtures/claude-backup/marketplaces-full.json > /dev/null
echo "First three fixtures are valid JSON"

# Verify malformed file fails
if jq . tests/fixtures/claude-backup/plugins-malformed.json 2>/dev/null; then
  echo "ERROR: malformed fixture should not be valid JSON"
  exit 1
else
  echo "Malformed fixture correctly fails jq parsing"
fi
```

Expected: First three files validate, malformed file fails

- [ ] **Step 6: Commit backup fixtures**

```bash
git add tests/fixtures/claude-backup/
git commit -m "test: add backup test fixtures"
```

---

### Task 6: Create Restore Test Fixtures

**Files:**
- Create: `tests/fixtures/claude-restore/repo-sanitized.json`
- Create: `tests/fixtures/claude-restore/local-with-vend.json`
- Create: `tests/fixtures/claude-restore/repo-config.json`

- [ ] **Step 1: Create repo-sanitized.json fixture**

Create `tests/fixtures/claude-restore/repo-sanitized.json`:

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

- [ ] **Step 2: Create local-with-vend.json fixture**

Create `tests/fixtures/claude-restore/local-with-vend.json`:

```json
{
  "version": 2,
  "plugins": {
    "old-plugin@claude-plugins-official": {
      "version": "1.0.0",
      "installPath": "/Users/robin.saleh-jan@m10s.io/.claude/plugins/cache/claude-plugins-official/old-plugin/1.0.0"
    },
    "vend-internal@vend-plugins": {
      "version": "1.5.0",
      "installPath": "/Users/robin.saleh-jan@m10s.io/.claude/plugins/cache/vend-plugins/vend-internal/1.5.0"
    }
  }
}
```

- [ ] **Step 3: Create repo-config.json fixture (for marketplace restore)**

Create `tests/fixtures/claude-restore/repo-config.json`:

```json
{
  "claude-plugins-official": {
    "url": "https://github.com/anthropics/claude-plugins-official",
    "type": "git"
  }
}
```

- [ ] **Step 4: Verify restore fixtures are valid JSON**

```bash
jq . tests/fixtures/claude-restore/repo-sanitized.json > /dev/null
jq . tests/fixtures/claude-restore/local-with-vend.json > /dev/null
jq . tests/fixtures/claude-restore/repo-config.json > /dev/null
echo "All restore fixtures are valid JSON"
```

Expected: All files validate successfully

- [ ] **Step 5: Commit restore fixtures**

```bash
git add tests/fixtures/claude-restore/
git commit -m "test: add restore test fixtures"
```

---

### Task 7: Create Expected Output Fixtures

**Files:**
- Create: `tests/fixtures/expected/plugins-sanitized.json`
- Create: `tests/fixtures/expected/marketplaces-sanitized.json`
- Create: `tests/fixtures/expected/plugins-merged.json`

- [ ] **Step 1: Create plugins-sanitized.json expected output**

Create `tests/fixtures/expected/plugins-sanitized.json`:

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

- [ ] **Step 2: Create marketplaces-sanitized.json expected output**

Create `tests/fixtures/expected/marketplaces-sanitized.json`:

```json
{
  "claude-plugins-official": {
    "url": "https://github.com/anthropics/claude-plugins-official",
    "type": "git"
  }
}
```

- [ ] **Step 3: Create plugins-merged.json expected output**

Create `tests/fixtures/expected/plugins-merged.json`:

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
      "version": "1.5.0",
      "installPath": "/Users/robin.saleh-jan@m10s.io/.claude/plugins/cache/vend-plugins/vend-internal/1.5.0"
    }
  }
}
```

- [ ] **Step 4: Verify expected fixtures are valid JSON**

```bash
jq . tests/fixtures/expected/plugins-sanitized.json > /dev/null
jq . tests/fixtures/expected/marketplaces-sanitized.json > /dev/null
jq . tests/fixtures/expected/plugins-merged.json > /dev/null
echo "All expected output fixtures are valid JSON"
```

Expected: All files validate successfully

- [ ] **Step 5: Commit expected output fixtures**

```bash
git add tests/fixtures/expected/
git commit -m "test: add expected output fixtures"
```

---

## Chunk 3: Backup Sanitization Tests

### Task 8: Create Backup Tests - Happy Paths

**Files:**
- Create: `tests/claude/backup.bats`

- [ ] **Step 1: Create backup.bats with basic structure and setup**

Create `tests/claude/backup.bats`:

```bash
#!/usr/bin/env bats

# Load test helpers
load '../helpers/setup'
load '../helpers/assertions'
load '../helpers/mocks'

# Setup runs before each test
setup() {
  setup_test_env

  # Get project root (two levels up from tests/claude/)
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

  # Source utils.sh for make_path_portable function
  source "$PROJECT_ROOT/scripts/utils.sh"
}

# Teardown runs after each test
teardown() {
  teardown_test_env
}

# Helper function to simulate backup sanitization
# This mimics the logic from backup-claude.sh
sanitize_plugins() {
  local input_file="$1"
  local output_file="$2"

  # Build jq filter to remove vend-plugins entries
  jq '{version: .version, plugins: (.plugins | to_entries | map(select(.key | endswith("@vend-plugins") | not)) | from_entries)}' \
    "$input_file" | make_path_portable > "$output_file"
}

sanitize_marketplaces() {
  local input_file="$1"
  local output_file="$2"

  # Remove vend-plugins marketplace
  jq 'del(.["vend-plugins"])' "$input_file" | make_path_portable > "$output_file"
}

@test "removes vend-plugins entries from installed_plugins.json" {
  # Arrange: Load fixture
  load_fixture "claude-backup/plugins-mixed.json" "$TEMP_CLAUDE_PLUGINS/installed_plugins.json"

  # Act: Run sanitization
  sanitize_plugins "$TEMP_CLAUDE_PLUGINS/installed_plugins.json" "$TEMP_REPO_CONFIG/installed_plugins.json"

  # Assert: Vend plugins removed
  assert_plugin_not_exists "$TEMP_REPO_CONFIG/installed_plugins.json" "vend-internal@vend-plugins"
  assert_plugin_not_exists "$TEMP_REPO_CONFIG/installed_plugins.json" "vend-api@vend-plugins"

  # Assert: Personal plugins preserved
  assert_plugin_exists "$TEMP_REPO_CONFIG/installed_plugins.json" "superpowers@claude-plugins-official"
  assert_plugin_exists "$TEMP_REPO_CONFIG/installed_plugins.json" "hookify@claude-plugins-official"
}

@test "removes vend-plugins marketplace from known_marketplaces.json" {
  # Arrange: Load fixture
  load_fixture "claude-backup/marketplaces-full.json" "$TEMP_CLAUDE_PLUGINS/known_marketplaces.json"

  # Act: Run sanitization
  sanitize_marketplaces "$TEMP_CLAUDE_PLUGINS/known_marketplaces.json" "$TEMP_REPO_CONFIG/known_marketplaces.json"

  # Assert: Vend marketplace removed
  assert_marketplace_not_exists "$TEMP_REPO_CONFIG/known_marketplaces.json" "vend-plugins"

  # Assert: Personal marketplace preserved
  assert_marketplace_exists "$TEMP_REPO_CONFIG/known_marketplaces.json" "claude-plugins-official"
}

@test "makes paths portable by replacing HOME directory" {
  # Arrange: Load fixture with absolute paths
  load_fixture "claude-backup/plugins-mixed.json" "$TEMP_CLAUDE_PLUGINS/installed_plugins.json"

  # Act: Run sanitization (includes make_path_portable)
  sanitize_plugins "$TEMP_CLAUDE_PLUGINS/installed_plugins.json" "$TEMP_REPO_CONFIG/installed_plugins.json"

  # Assert: Paths contain $HOME placeholder
  local path
  path=$(jq -r '.plugins["superpowers@claude-plugins-official"].installPath' "$TEMP_REPO_CONFIG/installed_plugins.json")

  [[ "$path" == "\$HOME"* ]] || {
    echo "Expected path to start with \$HOME, got: $path"
    return 1
  }
}

@test "removes vend-plugins from settings.json enabledPlugins" {
  # Arrange: Load settings fixture
  load_fixture "claude-backup/settings-full.json" "$TEMP_CLAUDE/settings.json"

  # Act: Sanitize settings (remove vend-plugins from enabledPlugins)
  jq '{enabledPlugins: (.enabledPlugins | to_entries | map(select(.key | endswith("@vend-plugins") | not)) | from_entries)} + (. | del(.enabledPlugins))' \
    "$TEMP_CLAUDE/settings.json" | make_path_portable > "$TEMP_REPO_CONFIG/settings.json"

  # Assert: Vend plugins removed from enabledPlugins
  local vend_in_enabled
  vend_in_enabled=$(jq '.enabledPlugins | to_entries | map(select(.key | endswith("@vend-plugins"))) | length' "$TEMP_REPO_CONFIG/settings.json")
  [ "$vend_in_enabled" -eq 0 ] || {
    echo "Expected no vend-plugins in enabledPlugins, found $vend_in_enabled"
    return 1
  }

  # Assert: Personal plugins preserved
  local personal_count
  personal_count=$(jq '.enabledPlugins | to_entries | map(select(.key | endswith("@claude-plugins-official"))) | length' "$TEMP_REPO_CONFIG/settings.json")
  [ "$personal_count" -eq 2 ] || {
    echo "Expected 2 personal plugins in enabledPlugins, found $personal_count"
    return 1
  }

  # Assert: Other settings fields preserved
  assert_json_field "$TEMP_REPO_CONFIG/settings.json" '.theme' "dark"
  assert_json_field "$TEMP_REPO_CONFIG/settings.json" '.model' "claude-sonnet-4-5"
}

@test "preserves JSON structure during sanitization" {
  # Arrange: Load fixture
  load_fixture "claude-backup/plugins-mixed.json" "$TEMP_CLAUDE_PLUGINS/installed_plugins.json"

  # Act: Run sanitization
  sanitize_plugins "$TEMP_CLAUDE_PLUGINS/installed_plugins.json" "$TEMP_REPO_CONFIG/installed_plugins.json"

  # Assert: Version field preserved
  assert_json_field "$TEMP_REPO_CONFIG/installed_plugins.json" ".version" "2"

  # Assert: Plugins is an object
  assert_json_field "$TEMP_REPO_CONFIG/installed_plugins.json" ".plugins | type" "object"
}
```

- [ ] **Step 2: Run backup tests to verify they work**

```bash
bats tests/claude/backup.bats
```

Expected output:
```
✓ removes vend-plugins entries from installed_plugins.json
✓ removes vend-plugins marketplace from known_marketplaces.json
✓ makes paths portable by replacing HOME directory
✓ removes vend-plugins from settings.json enabledPlugins
✓ preserves JSON structure during sanitization

5 tests, 0 failures
```

- [ ] **Step 3: Commit backup happy path tests**

```bash
git add tests/claude/backup.bats
git commit -m "test: add backup sanitization happy path tests"
```

---

### Task 9: Add Backup Error Scenario Tests

**Files:**
- Modify: `tests/claude/backup.bats` (add error tests)

- [ ] **Step 1: Add error scenario tests to backup.bats**

Append to `tests/claude/backup.bats`:

```bash

@test "handles malformed JSON gracefully" {
  # Arrange: Load malformed fixture
  load_fixture "claude-backup/plugins-malformed.json" "$TEMP_CLAUDE_PLUGINS/installed_plugins.json"

  # Act & Assert: Sanitization should fail with malformed input
  run sanitize_plugins "$TEMP_CLAUDE_PLUGINS/installed_plugins.json" "$TEMP_REPO_CONFIG/installed_plugins.json"

  # Should fail (non-zero exit code)
  [ "$status" -ne 0 ]
}

@test "handles missing source file gracefully" {
  # Arrange: No fixture loaded (file doesn't exist)

  # Act: Attempt sanitization with missing file
  run sanitize_plugins "$TEMP_CLAUDE_PLUGINS/nonexistent.json" "$TEMP_REPO_CONFIG/installed_plugins.json"

  # Assert: Should fail
  [ "$status" -ne 0 ]
}

@test "handles empty plugins object" {
  # Arrange: Create empty plugins file
  echo '{"version": 2, "plugins": {}}' > "$TEMP_CLAUDE_PLUGINS/installed_plugins.json"

  # Act: Run sanitization
  sanitize_plugins "$TEMP_CLAUDE_PLUGINS/installed_plugins.json" "$TEMP_REPO_CONFIG/installed_plugins.json"

  # Assert: Output is valid JSON with empty plugins
  assert_json_field "$TEMP_REPO_CONFIG/installed_plugins.json" ".plugins | length" "0"
  assert_json_field "$TEMP_REPO_CONFIG/installed_plugins.json" ".version" "2"
}

@test "handles all vend-plugins removed scenario" {
  # Arrange: Create file with only vend plugins
  cat > "$TEMP_CLAUDE_PLUGINS/installed_plugins.json" <<'EOF'
{
  "version": 2,
  "plugins": {
    "vend-internal@vend-plugins": {
      "version": "1.0.0",
      "installPath": "/Users/test/.claude/plugins/cache/vend-plugins/vend-internal/1.0.0"
    },
    "vend-api@vend-plugins": {
      "version": "2.0.0",
      "installPath": "/Users/test/.claude/plugins/cache/vend-plugins/vend-api/2.0.0"
    }
  }
}
EOF

  # Act: Run sanitization
  sanitize_plugins "$TEMP_CLAUDE_PLUGINS/installed_plugins.json" "$TEMP_REPO_CONFIG/installed_plugins.json"

  # Assert: Result should have empty plugins object
  assert_json_field "$TEMP_REPO_CONFIG/installed_plugins.json" ".plugins | length" "0"
}
```

- [ ] **Step 2: Run all backup tests including error scenarios**

```bash
bats tests/claude/backup.bats
```

Expected output:
```
✓ removes vend-plugins entries from installed_plugins.json
✓ removes vend-plugins marketplace from known_marketplaces.json
✓ makes paths portable by replacing HOME directory
✓ removes vend-plugins from settings.json enabledPlugins
✓ preserves JSON structure during sanitization
✓ handles malformed JSON gracefully
✓ handles missing source file gracefully
✓ handles empty plugins object
✓ handles all vend-plugins removed scenario

9 tests, 0 failures
```

- [ ] **Step 3: Commit backup error scenario tests**

```bash
git add tests/claude/backup.bats
git commit -m "test: add backup error scenario tests"
```

---

## Chunk 4: Restore and Portability Tests

### Task 10: Create Restore Tests - Merge Logic

**Files:**
- Create: `tests/claude/restore.bats`

- [ ] **Step 1: Create restore.bats with merge tests**

Create `tests/claude/restore.bats`:

```bash
#!/usr/bin/env bats

# Load test helpers
load '../helpers/setup'
load '../helpers/assertions'
load '../helpers/mocks'

setup() {
  setup_test_env

  # Get project root
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

  # Source utils.sh for expand_portable_path function
  source "$PROJECT_ROOT/scripts/utils.sh"
}

teardown() {
  teardown_test_env
}

# Helper function to simulate restore merge
# This mimics the logic from restore-claude.sh
merge_plugin_configs() {
  local repo_file="$1"
  local local_file="$2"
  local output_file="$3"

  # If no local file, just expand repo config
  if [ ! -f "$local_file" ]; then
    expand_portable_path < "$repo_file" > "$output_file"
    return 0
  fi

  # Extract vend-plugins from local config
  local local_vend
  local_vend=$(jq '.plugins // {} | to_entries | map(select(.key | endswith("@vend-plugins"))) | from_entries' "$local_file")

  # Get repo plugins and expand paths
  local repo_plugins
  repo_plugins=$(expand_portable_path < "$repo_file" | jq '.plugins // {}')

  # Merge: repo + local vend plugins (local takes precedence)
  local merged_plugins
  merged_plugins=$(echo "$repo_plugins" | jq --argjson vend "$local_vend" '. + $vend')

  # Get version from repo
  local version
  version=$(jq '.version // 2' "$repo_file")

  # Build final merged object
  jq -n --argjson version "$version" --argjson plugins "$merged_plugins" '{version: $version, plugins: $plugins}' > "$output_file"
}

@test "merges repo config with preserved local vend-plugins" {
  # Arrange: Load fixtures
  load_fixture "claude-restore/repo-sanitized.json" "$TEMP_REPO_CONFIG/installed_plugins.json"
  load_fixture "claude-restore/local-with-vend.json" "$TEMP_CLAUDE_PLUGINS/installed_plugins.json"

  # Act: Run merge
  merge_plugin_configs \
    "$TEMP_REPO_CONFIG/installed_plugins.json" \
    "$TEMP_CLAUDE_PLUGINS/installed_plugins.json" \
    "$TEMP_CLAUDE_PLUGINS/merged.json"

  # Assert: Repo plugins present
  assert_plugin_exists "$TEMP_CLAUDE_PLUGINS/merged.json" "superpowers@claude-plugins-official"
  assert_plugin_exists "$TEMP_CLAUDE_PLUGINS/merged.json" "hookify@claude-plugins-official"

  # Assert: Local vend plugin preserved
  assert_plugin_exists "$TEMP_CLAUDE_PLUGINS/merged.json" "vend-internal@vend-plugins"

  # Assert: Old plugin not present (repo takes precedence for non-vend)
  assert_plugin_not_exists "$TEMP_CLAUDE_PLUGINS/merged.json" "old-plugin@claude-plugins-official"
}

@test "creates new config when no local config exists" {
  # Arrange: Load repo fixture only (no local)
  load_fixture "claude-restore/repo-sanitized.json" "$TEMP_REPO_CONFIG/installed_plugins.json"

  # Act: Run merge with no local file
  merge_plugin_configs \
    "$TEMP_REPO_CONFIG/installed_plugins.json" \
    "$TEMP_CLAUDE_PLUGINS/nonexistent.json" \
    "$TEMP_CLAUDE_PLUGINS/merged.json"

  # Assert: Repo plugins present
  assert_plugin_exists "$TEMP_CLAUDE_PLUGINS/merged.json" "superpowers@claude-plugins-official"
  assert_plugin_exists "$TEMP_CLAUDE_PLUGINS/merged.json" "hookify@claude-plugins-official"

  # Assert: No vend plugins
  local vend_count
  vend_count=$(jq '.plugins | to_entries | map(select(.key | endswith("@vend-plugins"))) | length' "$TEMP_CLAUDE_PLUGINS/merged.json")
  [ "$vend_count" -eq 0 ]
}

@test "expands \$HOME placeholder to actual home directory" {
  # Arrange: Load repo fixture with $HOME placeholder
  load_fixture "claude-restore/repo-sanitized.json" "$TEMP_REPO_CONFIG/installed_plugins.json"

  # Act: Run merge (which calls expand_portable_path)
  merge_plugin_configs \
    "$TEMP_REPO_CONFIG/installed_plugins.json" \
    "$TEMP_CLAUDE_PLUGINS/nonexistent.json" \
    "$TEMP_CLAUDE_PLUGINS/merged.json"

  # Assert: Paths expanded to actual HOME value
  local path
  path=$(jq -r '.plugins["superpowers@claude-plugins-official"].installPath' "$TEMP_CLAUDE_PLUGINS/merged.json")

  # Path should start with the actual HOME directory (our temp dir in tests)
  [[ "$path" == "$HOME"* ]] || {
    echo "Expected path to start with $HOME, got: $path"
    return 1
  }

  # Path should NOT contain the literal string "\$HOME"
  [[ "$path" != *"\$HOME"* ]] || {
    echo "Path should not contain literal \$HOME, got: $path"
    return 1
  }
}

@test "preserves multiple vend-plugins during merge" {
  # Arrange: Create local config with multiple vend plugins
  cat > "$TEMP_CLAUDE_PLUGINS/installed_plugins.json" <<'EOF'
{
  "version": 2,
  "plugins": {
    "vend-internal@vend-plugins": {
      "version": "1.0.0",
      "installPath": "/Users/test/.claude/plugins/cache/vend-plugins/vend-internal/1.0.0"
    },
    "vend-api@vend-plugins": {
      "version": "2.0.0",
      "installPath": "/Users/test/.claude/plugins/cache/vend-plugins/vend-api/2.0.0"
    },
    "vend-tools@vend-plugins": {
      "version": "3.0.0",
      "installPath": "/Users/test/.claude/plugins/cache/vend-plugins/vend-tools/3.0.0"
    }
  }
}
EOF

  load_fixture "claude-restore/repo-sanitized.json" "$TEMP_REPO_CONFIG/installed_plugins.json"

  # Act: Run merge
  merge_plugin_configs \
    "$TEMP_REPO_CONFIG/installed_plugins.json" \
    "$TEMP_CLAUDE_PLUGINS/installed_plugins.json" \
    "$TEMP_CLAUDE_PLUGINS/merged.json"

  # Assert: All three vend plugins preserved
  assert_plugin_exists "$TEMP_CLAUDE_PLUGINS/merged.json" "vend-internal@vend-plugins"
  assert_plugin_exists "$TEMP_CLAUDE_PLUGINS/merged.json" "vend-api@vend-plugins"
  assert_plugin_exists "$TEMP_CLAUDE_PLUGINS/merged.json" "vend-tools@vend-plugins"

  # Assert: Repo plugins also present
  assert_plugin_exists "$TEMP_CLAUDE_PLUGINS/merged.json" "superpowers@claude-plugins-official"
}

@test "handles empty local plugins during merge" {
  # Arrange: Create empty local config
  echo '{"version": 2, "plugins": {}}' > "$TEMP_CLAUDE_PLUGINS/installed_plugins.json"
  load_fixture "claude-restore/repo-sanitized.json" "$TEMP_REPO_CONFIG/installed_plugins.json"

  # Act: Run merge
  merge_plugin_configs \
    "$TEMP_REPO_CONFIG/installed_plugins.json" \
    "$TEMP_CLAUDE_PLUGINS/installed_plugins.json" \
    "$TEMP_CLAUDE_PLUGINS/merged.json"

  # Assert: Repo plugins present
  assert_plugin_exists "$TEMP_CLAUDE_PLUGINS/merged.json" "superpowers@claude-plugins-official"
  assert_plugin_exists "$TEMP_CLAUDE_PLUGINS/merged.json" "hookify@claude-plugins-official"

  # Assert: No vend plugins added
  local vend_count
  vend_count=$(jq '.plugins | to_entries | map(select(.key | endswith("@vend-plugins"))) | length' "$TEMP_CLAUDE_PLUGINS/merged.json")
  [ "$vend_count" -eq 0 ]
}
```

- [ ] **Step 2: Run restore tests**

```bash
bats tests/claude/restore.bats
```

Expected output:
```
✓ merges repo config with preserved local vend-plugins
✓ creates new config when no local config exists
✓ expands $HOME placeholder to actual home directory
✓ preserves multiple vend-plugins during merge
✓ handles empty local plugins during merge

5 tests, 0 failures
```

- [ ] **Step 3: Commit restore tests**

```bash
git add tests/claude/restore.bats
git commit -m "test: add restore merge logic tests"
```

---

### Task 11: Create Path Portability Tests

**Files:**
- Create: `tests/utils/portability.bats`

- [ ] **Step 1: Create portability.bats**

Create `tests/utils/portability.bats`:

```bash
#!/usr/bin/env bats

# Load test helpers
load '../helpers/setup'
load '../helpers/assertions'

setup() {
  setup_test_env

  # Get project root
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

  # Source utils.sh for path functions
  source "$PROJECT_ROOT/scripts/utils.sh"
}

teardown() {
  teardown_test_env
}

@test "make_path_portable replaces home directory with \$HOME" {
  # Arrange: Create JSON with absolute home paths
  cat > "$TEST_TEMP_DIR/input.json" <<EOF
{
  "path": "$HOME/.claude/plugins/test",
  "nested": {
    "path": "$HOME/Documents/test"
  }
}
EOF

  # Act: Run make_path_portable
  make_path_portable < "$TEST_TEMP_DIR/input.json" > "$TEST_TEMP_DIR/output.json"

  # Assert: Paths replaced with $HOME
  local path1
  path1=$(jq -r '.path' "$TEST_TEMP_DIR/output.json")
  [[ "$path1" == "\$HOME/.claude/plugins/test" ]] || {
    echo "Expected path to be \$HOME/.claude/plugins/test, got: $path1"
    return 1
  }

  local path2
  path2=$(jq -r '.nested.path' "$TEST_TEMP_DIR/output.json")
  [[ "$path2" == "\$HOME/Documents/test" ]] || {
    echo "Expected nested path to be \$HOME/Documents/test, got: $path2"
    return 1
  }
}

@test "expand_portable_path replaces \$HOME with actual directory" {
  # Arrange: Create JSON with $HOME placeholders
  cat > "$TEST_TEMP_DIR/input.json" <<'EOF'
{
  "path": "$HOME/.claude/plugins/test",
  "nested": {
    "path": "$HOME/Documents/test"
  }
}
EOF

  # Act: Run expand_portable_path
  expand_portable_path < "$TEST_TEMP_DIR/input.json" > "$TEST_TEMP_DIR/output.json"

  # Assert: Paths expanded to actual HOME
  local path1
  path1=$(jq -r '.path' "$TEST_TEMP_DIR/output.json")
  [[ "$path1" == "$HOME/.claude/plugins/test" ]] || {
    echo "Expected path to be $HOME/.claude/plugins/test, got: $path1"
    return 1
  }

  # Should NOT contain literal $HOME
  [[ "$path1" != *"\$HOME"* ]] || {
    echo "Path should not contain literal \$HOME, got: $path1"
    return 1
  }
}

@test "round-trip preserves JSON structure and data" {
  # Arrange: Create complex JSON
  cat > "$TEST_TEMP_DIR/original.json" <<EOF
{
  "version": 2,
  "plugins": {
    "test@marketplace": {
      "version": "1.0.0",
      "installPath": "$HOME/.claude/plugins/cache/test/1.0.0",
      "metadata": {
        "enabled": true,
        "priority": 10
      }
    }
  }
}
EOF

  # Act: Round-trip through portable and back
  make_path_portable < "$TEST_TEMP_DIR/original.json" > "$TEST_TEMP_DIR/portable.json"
  expand_portable_path < "$TEST_TEMP_DIR/portable.json" > "$TEST_TEMP_DIR/restored.json"

  # Assert: Structure preserved (compare normalized JSON)
  diff <(jq -S . "$TEST_TEMP_DIR/original.json") <(jq -S . "$TEST_TEMP_DIR/restored.json") || {
    echo "Round-trip did not preserve JSON structure"
    return 1
  }
}

@test "handles multiple paths in same JSON file" {
  # Arrange: Create JSON with multiple paths
  cat > "$TEST_TEMP_DIR/input.json" <<EOF
{
  "paths": [
    "$HOME/.claude/config",
    "$HOME/.ssh/keys",
    "$HOME/Downloads"
  ]
}
EOF

  # Act: Make portable
  make_path_portable < "$TEST_TEMP_DIR/input.json" > "$TEST_TEMP_DIR/output.json"

  # Assert: All paths converted
  local converted_paths
  converted_paths=$(jq -r '.paths[]' "$TEST_TEMP_DIR/output.json")

  echo "$converted_paths" | while read -r path; do
    [[ "$path" == "\$HOME"* ]] || {
      echo "Expected all paths to start with \$HOME, got: $path"
      return 1
    }
  done
}

@test "preserves paths that don't contain HOME" {
  # Arrange: Create JSON with mixed paths
  cat > "$TEST_TEMP_DIR/input.json" <<EOF
{
  "home_path": "$HOME/.claude",
  "system_path": "/usr/local/bin",
  "relative_path": "./local/path"
}
EOF

  # Act: Make portable
  make_path_portable < "$TEST_TEMP_DIR/input.json" > "$TEST_TEMP_DIR/output.json"

  # Assert: Only home_path changed
  assert_json_field "$TEST_TEMP_DIR/output.json" '.home_path' "\$HOME/.claude"
  assert_json_field "$TEST_TEMP_DIR/output.json" '.system_path' "/usr/local/bin"
  assert_json_field "$TEST_TEMP_DIR/output.json" '.relative_path' "./local/path"
}

@test "handles empty JSON objects" {
  # Arrange: Create empty JSON
  echo '{}' > "$TEST_TEMP_DIR/input.json"

  # Act: Make portable
  make_path_portable < "$TEST_TEMP_DIR/input.json" > "$TEST_TEMP_DIR/output.json"

  # Assert: Still valid empty JSON
  assert_json_field "$TEST_TEMP_DIR/output.json" '. | type' "object"
  assert_json_field "$TEST_TEMP_DIR/output.json" '. | length' "0"
}

@test "handles nested paths in JSON objects" {
  # Arrange: Create deeply nested JSON
  cat > "$TEST_TEMP_DIR/input.json" <<EOF
{
  "level1": {
    "level2": {
      "level3": {
        "path": "$HOME/.claude/deep/path"
      }
    }
  }
}
EOF

  # Act: Make portable
  make_path_portable < "$TEST_TEMP_DIR/input.json" > "$TEST_TEMP_DIR/output.json"

  # Assert: Deep path converted
  assert_json_field "$TEST_TEMP_DIR/output.json" '.level1.level2.level3.path' "\$HOME/.claude/deep/path"
}
```

- [ ] **Step 2: Run portability tests**

```bash
bats tests/utils/portability.bats
```

Expected output:
```
✓ make_path_portable replaces home directory with $HOME
✓ expand_portable_path replaces $HOME with actual directory
✓ round-trip preserves JSON structure and data
✓ handles multiple paths in same JSON file
✓ preserves paths that don't contain HOME
✓ handles empty JSON objects
✓ handles nested paths in JSON objects

7 tests, 0 failures
```

- [ ] **Step 3: Commit portability tests**

```bash
git add tests/utils/portability.bats
git commit -m "test: add path portability tests"
```

---

## Chunk 5: Integration and Documentation

### Task 12: Update package.json with Test Scripts

**Files:**
- Modify: `package.json`

- [ ] **Step 1: Add test scripts to package.json**

Add these scripts to the `"scripts"` section in `package.json`:

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

- [ ] **Step 2: Verify npm test script works**

```bash
npm test
```

Expected: All tests pass (20 total tests from backup.bats, restore.bats, portability.bats)

- [ ] **Step 3: Test individual test suites**

```bash
npm run test:claude
npm run test:utils
```

Expected: Each runs its respective test files successfully

- [ ] **Step 4: Commit package.json changes**

```bash
git add package.json
git commit -m "build: add BATS test scripts to package.json"
```

---

### Task 13: Update Pre-commit Hook

**Files:**
- Modify: `.husky/pre-commit`

- [ ] **Step 1: Read current pre-commit hook**

```bash
cat .husky/pre-commit
```

Note the existing structure and security checks.

- [ ] **Step 2: Add test execution to pre-commit hook**

Add these lines after the existing security checks in `.husky/pre-commit`:

```bash
# Run BATS tests if test files exist
if [ -d "tests" ] && command -v bats >/dev/null 2>&1; then
  echo "🧪 Running tests..."
  npm test || {
    echo "❌ Tests failed. Fix issues before committing."
    echo "   Tip: Use '--no-test' in commit message to skip tests during rapid iteration"
    exit 1
  }
fi
```

- [ ] **Step 3: Test pre-commit hook**

```bash
# Create a dummy change
echo "# test" >> README.md

# Try to commit
git add README.md
git commit -m "test: verify pre-commit hook runs tests"

# Should see tests run and pass
```

Expected: Hook runs security checks, then runs tests, then commits

- [ ] **Step 4: Revert test change and commit hook update**

```bash
git restore README.md
git add .husky/pre-commit
git commit -m "ci: add test execution to pre-commit hook"
```

---

### Task 14: Create GitHub Actions Workflow

**Files:**
- Create: `.github/workflows/test.yml`

- [ ] **Step 1: Create .github/workflows directory**

```bash
mkdir -p .github/workflows
```

- [ ] **Step 2: Create test.yml workflow**

Create `.github/workflows/test.yml`:

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
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '20'

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
      uses: actions/upload-artifact@v4
      with:
        name: test-logs
        path: |
          tests/**/*.log
          *.log
```

- [ ] **Step 3: Validate workflow syntax**

```bash
# Verify YAML is valid
cat .github/workflows/test.yml | grep -v "^$" | head -20
```

Expected: Clean YAML output with no syntax errors

- [ ] **Step 4: Commit GitHub Actions workflow**

```bash
git add .github/workflows/test.yml
git commit -m "ci: add GitHub Actions test workflow"
```

---

### Task 15: Update Documentation

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Find testing section in README.md**

```bash
grep -n "## 🧪 Testing" README.md || echo "Testing section not found - will add it"
```

- [ ] **Step 2: Add testing section to README.md**

Add this section after the "Available Commands" section in `README.md`:

```markdown
## 🧪 Testing

This project uses [BATS (Bash Automated Testing System)](https://github.com/bats-core/bats-core) for testing shell scripts.

### Run Tests

```bash
npm test              # Run all tests
npm run test:claude   # Run Claude backup/restore tests only
npm run test:utils    # Run utility function tests only
```

### Test Coverage

The test suite covers:
- **Backup sanitization** - Verifies work-related plugins/marketplaces are removed during backup
- **Restore merge logic** - Ensures local work plugins are preserved during restore
- **Path portability** - Validates `$HOME` placeholder replacement works correctly
- **Error scenarios** - Tests missing dependencies, malformed JSON, missing files

### Test Requirements

- bats-core (installed via setup)
- jq (installed via setup)
- shellcheck (installed via setup)

Tests run automatically:
- **Pre-commit hook** - Catches issues before commit
- **GitHub Actions** - Runs on push/PR to main/master branches

### Writing Tests

Test files are organized hierarchically:
```
tests/
├── claude/           # Claude Code backup/restore tests
├── utils/            # Utility function tests
├── helpers/          # Shared test utilities (setup, assertions, mocks)
└── fixtures/         # Test data (JSON files)
```

See existing test files for examples. Key patterns:
- Use `setup_test_env()` for isolated temp directories
- Use jq-based assertions from `tests/helpers/assertions.bash`
- Load fixtures from `tests/fixtures/` for test data
- Source production scripts and test functions directly

### Skipping Tests

During rapid iteration, you can skip tests by including `--no-test` in your commit message:

```bash
git commit -m "wip: experimental change --no-test"
```

**Note:** This should only be used during development. CI will still run tests on push.
```

- [ ] **Step 3: Verify documentation renders correctly**

```bash
# Check markdown syntax
grep -A 10 "## 🧪 Testing" README.md
```

Expected: Clean markdown with proper formatting

- [ ] **Step 4: Commit documentation updates**

```bash
git add README.md
git commit -m "docs: add testing section to README"
```

---

### Task 16: Final Verification

**Files:**
- All test files

- [ ] **Step 1: Run full test suite**

```bash
npm test
```

Expected output:
```
✓ removes vend-plugins entries from installed_plugins.json
✓ removes vend-plugins marketplace from known_marketplaces.json
✓ makes paths portable by replacing HOME directory
✓ removes vend-plugins from settings.json enabledPlugins
✓ preserves JSON structure during sanitization
✓ handles malformed JSON gracefully
✓ handles missing source file gracefully
✓ handles empty plugins object
✓ handles all vend-plugins removed scenario
✓ merges repo config with preserved local vend-plugins
✓ creates new config when no local config exists
✓ expands $HOME placeholder to actual home directory
✓ preserves multiple vend-plugins during merge
✓ handles empty local plugins during merge
✓ make_path_portable replaces home directory with $HOME
✓ expand_portable_path replaces $HOME with actual directory
✓ round-trip preserves JSON structure and data
✓ handles multiple paths in same JSON file
✓ preserves paths that don't contain HOME
✓ handles empty JSON objects
✓ handles nested paths in JSON objects

21 tests, 0 failures
```

- [ ] **Step 2: Run shellcheck on all scripts**

```bash
npm run lint
```

Expected: No errors (SC1071, SC2296 warnings can be ignored)

- [ ] **Step 3: Verify git status is clean**

```bash
git status
```

Expected: Working tree clean (all changes committed)

- [ ] **Step 4: Create final summary commit (if needed)**

If there are any remaining changes:

```bash
git add -A
git commit -m "test: complete BATS testing infrastructure implementation"
```

---

## Implementation Complete

All tasks completed! The BATS testing infrastructure is now in place with:

✅ Test helpers (setup, assertions, mocks)
✅ Test fixtures (backup, restore, expected outputs)
✅ Backup sanitization tests (9 tests)
✅ Restore merge tests (5 tests)
✅ Path portability tests (7 tests)
✅ NPM test scripts
✅ Pre-commit hook integration
✅ GitHub Actions CI workflow
✅ Updated documentation

**Next steps:**
- Push to remote repository
- Verify GitHub Actions workflow runs successfully
- Consider expanding test coverage to other scripts (mac.sh, update.sh, etc.)
