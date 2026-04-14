#!/usr/bin/env bash
#
# run-tests.sh — main test runner for the ai-crew plugin.
#
# Two test classes:
#   - static     : file-based, fast, no API calls. Catch broken manifests,
#                  vendored-content edits, missing fields. ~1s per test.
#   - functional : invoke `claude -p --plugin-dir <repo>`. Actually load the
#                  plugin and verify behavior. SLOW (10–60s each) and costs
#                  API credits. This is what tells you the plugin really works.
#
# DEFAULT: both classes run. Use --no-api to skip functional tests for fast
# iteration without burning credits. Use --only-functional to skip the static
# checks if you only care about behavior.
#
# Usage:
#   ./run-tests.sh                    # default: static + functional
#   ./run-tests.sh --no-api           # static only (fast, no API cost)
#   ./run-tests.sh --only-functional  # functional only (skip static checks)
#   ./run-tests.sh --test test-x.sh   # one specific test
#   ./run-tests.sh --verbose          # show full per-test output even on PASS
#   ./run-tests.sh --timeout 180      # per-test timeout (default 120s)
#   ./run-tests.sh --help             # this message

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
export PLUGIN_ROOT

VERBOSE=false
SPECIFIC_TEST=""
TIMEOUT=120
RUN_STATIC=true
RUN_FUNCTIONAL=true

while [[ $# -gt 0 ]]; do
  case $1 in
    --verbose|-v)        VERBOSE=true; shift ;;
    --test|-t)           SPECIFIC_TEST="$2"; shift 2 ;;
    --timeout)           TIMEOUT="$2"; shift 2 ;;
    --no-api)            RUN_FUNCTIONAL=false; shift ;;
    --only-functional)   RUN_STATIC=false; shift ;;
    --help|-h)
      sed -n '2,/^$/p' "$0" | sed 's/^# //;s/^#//'
      exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Use --help for usage information" >&2
      exit 1 ;;
  esac
done

echo "========================================"
echo " ai-crew Test Suite"
echo "========================================"
echo "Plugin root:    $PLUGIN_ROOT"
echo "Test directory: $SCRIPT_DIR"
echo "Test time:      $(date)"
echo "Claude version: $(claude --version 2>/dev/null || echo 'not found')"
echo "Mode:           static=$RUN_STATIC functional=$RUN_FUNCTIONAL timeout=${TIMEOUT}s"
echo ""

if ! command -v claude > /dev/null 2>&1; then
  echo "ERROR: claude CLI not found in PATH" >&2
  echo "Install Claude Code first: https://code.claude.com" >&2
  exit 1
fi

# Detect a timeout binary. macOS doesn't ship `timeout` by default; coreutils
# provides `gtimeout`. If neither exists, fall back to no-timeout mode (tests
# can hang on a broken claude CLI but at least the suite runs).
TIMEOUT_BIN=""
if command -v timeout > /dev/null 2>&1; then
  TIMEOUT_BIN="timeout"
elif command -v gtimeout > /dev/null 2>&1; then
  TIMEOUT_BIN="gtimeout"
else
  echo "Note: no timeout binary found. Tests will run without a timeout wrapper."
  echo "      Install coreutils (\`brew install coreutils\`) to enable timeouts."
  echo ""
fi

run_with_timeout() {
  if [ -n "$TIMEOUT_BIN" ]; then
    "$TIMEOUT_BIN" "$1" bash "$2"
  else
    bash "$2"
  fi
}

# Static tests — fast, file-based, no API calls.
static_tests=(
  "test-vendor-integrity.sh"
  "test-plugin-manifest.sh"
  "test-namespace-rewrite.sh"
  "test-skill-anatomy.sh"
  "test-developer-agent.sh"
  "test-web-researcher-agent.sh"
  "test-detect-project-type.sh"
)

# Functional tests — load the plugin via --plugin-dir and verify behavior.
# Each one calls claude -p, which is a real API call.
functional_tests=(
  "test-plugin-loads.sh"
  "test-slash-commands-registered.sh"
  "test-team-lead-skill-loads.sh"
  "test-using-agent-skills-loads.sh"
  "test-developer-agent-loads.sh"
)

tests=()
if [ "$RUN_STATIC" = true ]; then
  tests+=("${static_tests[@]}")
fi
if [ "$RUN_FUNCTIONAL" = true ]; then
  tests+=("${functional_tests[@]}")
fi

if [ -n "$SPECIFIC_TEST" ]; then
  tests=("$SPECIFIC_TEST")
fi

passed=0
failed=0
skipped=0
failed_names=()

for test in "${tests[@]}"; do
  echo "----------------------------------------"
  echo "Running: $test"
  echo "----------------------------------------"
  test_path="$SCRIPT_DIR/$test"

  if [ ! -f "$test_path" ]; then
    echo "  [SKIP] not found: $test"
    skipped=$((skipped + 1))
    echo ""
    continue
  fi

  start_time=$(date +%s)
  if [ "$VERBOSE" = true ]; then
    if run_with_timeout "$TIMEOUT" "$test_path"; then
      end_time=$(date +%s)
      echo "  [PASS] ($((end_time - start_time))s)"
      passed=$((passed + 1))
    else
      exit_code=$?
      end_time=$(date +%s)
      duration=$((end_time - start_time))
      if [ "$exit_code" -eq 124 ]; then
        echo "  [FAIL] $test (timeout after ${TIMEOUT}s)"
      else
        echo "  [FAIL] $test (${duration}s)"
      fi
      failed=$((failed + 1))
      failed_names+=("$test")
    fi
  else
    if output=$(run_with_timeout "$TIMEOUT" "$test_path" 2>&1); then
      end_time=$(date +%s)
      echo "  [PASS] ($((end_time - start_time))s)"
      passed=$((passed + 1))
    else
      exit_code=$?
      end_time=$(date +%s)
      duration=$((end_time - start_time))
      if [ "$exit_code" -eq 124 ]; then
        echo "  [FAIL] (timeout after ${TIMEOUT}s)"
      else
        echo "  [FAIL] (${duration}s)"
      fi
      echo ""
      echo "  Output:"
      echo "$output" | sed 's/^/    /'
      failed=$((failed + 1))
      failed_names+=("$test")
    fi
  fi
  echo ""
done

echo "========================================"
echo " Test Results Summary"
echo "========================================"
echo "  Passed:  $passed"
echo "  Failed:  $failed"
echo "  Skipped: $skipped"
if [ "$failed" -gt 0 ]; then
  echo ""
  echo "  Failed tests:"
  for n in "${failed_names[@]}"; do echo "    - $n"; done
fi
echo ""

if [ "$RUN_FUNCTIONAL" = false ]; then
  echo "Note: functional tests were SKIPPED (--no-api). Static checks only."
  echo "      Run without --no-api to actually exercise plugin loading."
  echo ""
fi

if [ "$failed" -gt 0 ]; then
  echo "STATUS: FAILED"
  exit 1
else
  echo "STATUS: PASSED"
  exit 0
fi
