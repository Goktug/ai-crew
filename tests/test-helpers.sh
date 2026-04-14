#!/usr/bin/env bash
#
# test-helpers.sh — assertion + claude-cli helpers for ai-crew tests.
#
# Adapted from reference-projects/superpowers/tests/claude-code/test-helpers.sh
# with two ai-crew-specific changes:
#   1. run_claude automatically passes --plugin-dir <repo-root> so tests are
#      hermetic and do not require the plugin to be installed globally.
#   2. The repo root is resolved via PLUGIN_ROOT, exported by run-tests.sh.
#
# Source this file from individual test scripts:
#   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
#   source "$SCRIPT_DIR/test-helpers.sh"

# PLUGIN_ROOT must be exported by the caller (run-tests.sh sets it). When a
# test script is run standalone, fall back to the directory containing this
# helpers file's parent.
if [ -z "${PLUGIN_ROOT:-}" ]; then
  PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  export PLUGIN_ROOT
fi

# run_claude — invoke claude in headless mode with the ai-crew plugin loaded.
#
# Usage: run_claude "prompt" [timeout_seconds] [allowed_tools_csv]
# Returns: claude's stdout/stderr (combined). Returns claude's exit code.
run_claude() {
  local prompt="$1"
  local timeout_secs="${2:-60}"
  local allowed_tools="${3:-}"
  local output_file
  output_file="$(mktemp)"

  # Use --plugin-dir to load the ai-crew plugin for this single session.
  # No global state mutation; test isolation is preserved.
  local cmd="claude --plugin-dir \"$PLUGIN_ROOT\" -p \"$prompt\""
  if [ -n "$allowed_tools" ]; then
    cmd="$cmd --allowed-tools=$allowed_tools"
  fi

  # macOS doesn't ship `timeout` by default. Detect it; if missing, fall back
  # to running without a timeout wrapper.
  local timeout_bin=""
  if command -v timeout > /dev/null 2>&1; then
    timeout_bin="timeout"
  elif command -v gtimeout > /dev/null 2>&1; then
    timeout_bin="gtimeout"
  fi

  local exit_code=0
  if [ -n "$timeout_bin" ]; then
    "$timeout_bin" "$timeout_secs" bash -c "$cmd" > "$output_file" 2>&1 || exit_code=$?
  else
    bash -c "$cmd" > "$output_file" 2>&1 || exit_code=$?
  fi

  if [ "$exit_code" -eq 0 ]; then
    cat "$output_file"
    rm -f "$output_file"
    return 0
  else
    cat "$output_file" >&2
    rm -f "$output_file"
    return "$exit_code"
  fi
}

# assert_contains — fail if pattern is not found in output.
assert_contains() {
  local output="$1"
  local pattern="$2"
  local test_name="${3:-test}"

  if echo "$output" | grep -q -- "$pattern"; then
    echo "  [PASS] $test_name"
    return 0
  else
    echo "  [FAIL] $test_name"
    echo "  Expected to find: $pattern"
    echo "  In output:"
    echo "$output" | sed 's/^/    /'
    return 1
  fi
}

# assert_not_contains — fail if pattern IS found in output.
assert_not_contains() {
  local output="$1"
  local pattern="$2"
  local test_name="${3:-test}"

  if echo "$output" | grep -q -- "$pattern"; then
    echo "  [FAIL] $test_name"
    echo "  Did not expect to find: $pattern"
    echo "  In output:"
    echo "$output" | sed 's/^/    /'
    return 1
  else
    echo "  [PASS] $test_name"
    return 0
  fi
}

# assert_count — fail if exact match count is wrong.
assert_count() {
  local output="$1"
  local pattern="$2"
  local expected="$3"
  local test_name="${4:-test}"
  local actual
  actual="$(echo "$output" | grep -c -- "$pattern" || echo "0")"

  if [ "$actual" -eq "$expected" ]; then
    echo "  [PASS] $test_name (found $actual instances)"
    return 0
  else
    echo "  [FAIL] $test_name"
    echo "  Expected $expected instances of: $pattern"
    echo "  Found $actual instances"
    return 1
  fi
}

# assert_order — fail if pattern_a does not appear before pattern_b.
assert_order() {
  local output="$1"
  local pattern_a="$2"
  local pattern_b="$3"
  local test_name="${4:-test}"
  local line_a
  line_a="$(echo "$output" | grep -n -- "$pattern_a" | head -1 | cut -d: -f1)"
  local line_b
  line_b="$(echo "$output" | grep -n -- "$pattern_b" | head -1 | cut -d: -f1)"

  if [ -z "$line_a" ]; then
    echo "  [FAIL] $test_name: pattern A not found: $pattern_a"
    return 1
  fi
  if [ -z "$line_b" ]; then
    echo "  [FAIL] $test_name: pattern B not found: $pattern_b"
    return 1
  fi
  if [ "$line_a" -lt "$line_b" ]; then
    echo "  [PASS] $test_name (A at line $line_a, B at line $line_b)"
    return 0
  else
    echo "  [FAIL] $test_name (A at $line_a, B at $line_b — wrong order)"
    return 1
  fi
}

# assert_file_exists — fail if file does not exist.
assert_file_exists() {
  local path="$1"
  local test_name="${2:-file exists}"
  if [ -f "$path" ]; then
    echo "  [PASS] $test_name ($path)"
    return 0
  else
    echo "  [FAIL] $test_name: $path"
    return 1
  fi
}

# assert_file_executable — fail if file is not executable.
assert_file_executable() {
  local path="$1"
  local test_name="${2:-file executable}"
  if [ -x "$path" ]; then
    echo "  [PASS] $test_name ($path)"
    return 0
  else
    echo "  [FAIL] $test_name: $path"
    return 1
  fi
}

# create_test_project — make a temp dir and echo its path.
create_test_project() {
  mktemp -d
}

# cleanup_test_project — remove a temp dir created above.
cleanup_test_project() {
  local test_dir="$1"
  if [ -d "$test_dir" ]; then
    rm -rf "$test_dir"
  fi
}
