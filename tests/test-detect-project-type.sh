#!/usr/bin/env bash
#
# test-detect-project-type.sh — wraps hooks/detect-project-type.test.sh so
# the existing fixture-based test runs as part of the main test suite.
#
# Also asserts the script is executable and exists.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

cd "$PLUGIN_ROOT"

echo "=== Test: detect-project-type.sh ==="

failed=0

if assert_file_exists "hooks/detect-project-type.sh" "script exists"; then :; else
  failed=$((failed + 1))
fi

if assert_file_executable "hooks/detect-project-type.sh" "script is executable"; then :; else
  failed=$((failed + 1))
fi

if assert_file_exists "hooks/detect-project-type.test.sh" "test harness exists"; then :; else
  failed=$((failed + 1))
fi

# Run the existing fixture harness.
echo "  --- running hooks/detect-project-type.test.sh ---"
if harness_output="$(bash hooks/detect-project-type.test.sh 2>&1)"; then
  echo "$harness_output" | sed 's/^/    /'
  echo "  [PASS] all 4 fixtures classified correctly"
else
  echo "$harness_output" | sed 's/^/    /'
  echo "  [FAIL] fixture harness exited non-zero"
  failed=$((failed + 1))
fi

if [ "$failed" -gt 0 ]; then
  echo ""
  echo "FAIL: $failed detect-project-type check(s) failed"
  exit 1
fi

echo ""
echo "PASS: detect-project-type.sh verified"
exit 0
