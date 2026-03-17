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
  if ! actual=$(jq -r "$jq_query" "$file" 2>&1); then
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
  if ! result=$(jq -r "$jq_query | select(. == \"$value\")" "$file" 2>&1); then
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
  if ! diff_output=$(diff <(jq -S . "$actual" 2>&1) <(jq -S . "$expected" 2>&1) 2>&1); then
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
  if ! exists=$(jq -r ".plugins | has(\"$plugin_key\")" "$file" 2>&1); then
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
  if ! exists=$(jq -r ".plugins | has(\"$plugin_key\")" "$file" 2>&1); then
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
  if ! exists=$(jq -r "has(\"$marketplace_key\")" "$file" 2>&1); then
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
  if ! exists=$(jq -r "has(\"$marketplace_key\")" "$file" 2>&1); then
    echo "jq query failed" >&2
    echo "$exists" >&2
    return 1
  fi

  if [ "$exists" = "true" ]; then
    echo "Marketplace should not exist: $marketplace_key" >&2
    return 1
  fi
}
