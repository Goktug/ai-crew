#!/usr/bin/env bash
# Test harness for detect-project-type.sh
# Validates that the script correctly classifies sample package.json fixtures
# as react-native, nextjs, node-typescript, or unknown.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DETECT="$SCRIPT_DIR/detect-project-type.sh"
FIXTURES="$SCRIPT_DIR/fixtures"

if [ ! -x "$DETECT" ]; then
  echo "FAIL: $DETECT is not executable (or does not exist)"
  exit 1
fi

pass=0
fail=0

assert_type() {
  local fixture_name="$1"
  local expected="$2"
  local fixture_dir="$FIXTURES/$fixture_name"
  local output
  output="$("$DETECT" "$fixture_dir")"
  local got
  got="$(printf '%s' "$output" | sed -n 's/.*"projectType"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"

  if [ "$got" = "$expected" ]; then
    echo "  PASS: fixture=$fixture_name expected=$expected got=$got"
    pass=$((pass + 1))
  else
    echo "  FAIL: fixture=$fixture_name expected=$expected got=$got (raw=$output)"
    fail=$((fail + 1))
  fi
}

echo "Running detect-project-type.sh tests..."
assert_type "rn"      "react-native"
assert_type "nextjs"  "nextjs"
assert_type "node-ts" "node-typescript"
assert_type "none"    "unknown"

echo
echo "Passed: $pass"
echo "Failed: $fail"

if [ "$fail" -gt 0 ]; then
  echo "ALL TESTS FAILED — see output above"
  exit 1
fi

echo "ALL TESTS PASSED"
exit 0
