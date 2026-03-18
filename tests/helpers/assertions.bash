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

# Assert JSON files are equivalent (normalizing whitespace and sorting object keys, but not array order)
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

# Internal helper: Assert a JSON key exists or not in a file
# Usage: _assert_json_key "file.json" ".plugins" "key-name" "true|false" "Plugin|Marketplace"
_assert_json_key() {
  local file="$1"
  local jq_scope="$2"
  local key="$3"
  local should_exist="$4"
  local label="$5"

  if [ ! -f "$file" ]; then
    echo "File not found: $file" >&2
    return 1
  fi

  local exists
  if ! exists=$(jq -r "$jq_scope | has(\"$key\")" "$file" 2>&1); then
    echo "jq query failed" >&2
    echo "$exists" >&2
    return 1
  fi

  if [ "$should_exist" = "true" ] && [ "$exists" != "true" ]; then
    echo "$label not found: $key" >&2
    echo "Available keys:" >&2
    jq -r "$jq_scope | keys[]" "$file" >&2
    return 1
  fi

  if [ "$should_exist" = "false" ] && [ "$exists" = "true" ]; then
    echo "$label should not exist: $key" >&2
    return 1
  fi
}

# Assert plugin key exists in JSON
# Usage: assert_plugin_exists "plugins.json" "superpowers@claude-plugins-official"
assert_plugin_exists() {
  _assert_json_key "$1" ".plugins" "$2" "true" "Plugin"
}

# Assert plugin key does NOT exist in JSON
# Usage: assert_plugin_not_exists "plugins.json" "vend-internal@vend-plugins"
assert_plugin_not_exists() {
  _assert_json_key "$1" ".plugins" "$2" "false" "Plugin"
}

# Assert marketplace exists in JSON
# Usage: assert_marketplace_exists "marketplaces.json" "claude-plugins-official"
assert_marketplace_exists() {
  _assert_json_key "$1" "." "$2" "true" "Marketplace"
}

# Assert marketplace does NOT exist in JSON
# Usage: assert_marketplace_not_exists "marketplaces.json" "vend-plugins"
assert_marketplace_not_exists() {
  _assert_json_key "$1" "." "$2" "false" "Marketplace"
}
