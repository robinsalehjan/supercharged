#!/usr/bin/env bats

load '../helpers/setup'

setup() {
  setup_test_env
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

teardown() {
  teardown_test_env
}

# Sourcing utils.sh writes to a log inside the repository, so point the log at
# the test's temporary HOME by running from a throwaway copy of the loader.
run_with_log() {
  local log="$1"
  shift
  zsh -c "
    source '$PROJECT_ROOT/scripts/utils.sh'
    UTILS_LOG_FILE='$log'
    UTILS_LOG_MAX_BYTES='${UTILS_LOG_MAX_BYTES:-1048576}'
    source '$PROJECT_ROOT/scripts/utils/logging.sh'
    $*
  "
}

@test "log rotation leaves a small log untouched" {
  log="$TEST_TEMP_DIR/install.log"
  printf 'small\n' > "$log"

  run_with_log "$log" 'true'

  [ -f "$log" ]
  [ ! -e "$log.1" ]
  grep -Fq small "$log"
}

@test "log rotation moves an oversized log to a single previous generation" {
  log="$TEST_TEMP_DIR/install.log"
  # Comfortably past the 1 MiB default cap.
  head -c 1200000 /dev/zero | tr '\0' 'x' > "$log"
  original_size=$(wc -c < "$log" | tr -d ' ')

  run_with_log "$log" 'log_with_level INFO "after rotation"'

  [ -f "$log.1" ]
  [ "$(wc -c < "$log.1" | tr -d ' ')" -eq "$original_size" ]
  [ "$(wc -c < "$log" | tr -d ' ')" -lt "$original_size" ]
  grep -Fq "after rotation" "$log"
}

@test "log rotation honors a custom size cap" {
  log="$TEST_TEMP_DIR/install.log"
  printf '%s\n' "0123456789" > "$log"

  UTILS_LOG_MAX_BYTES=5 run_with_log "$log" 'true'

  [ -f "$log.1" ]
}
