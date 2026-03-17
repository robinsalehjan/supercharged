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
