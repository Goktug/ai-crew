#!/usr/bin/env bash
#
# test-plugin-loads.sh — FUNCTIONAL test: the plugin loads without errors.
#
# This is the most fundamental functional test. If the manifest is invalid,
# a SKILL.md has broken frontmatter, an agent file is malformed, or a hook
# is broken, claude will fail to start cleanly. We invoke claude headlessly
# with --plugin-dir and verify it exits 0.
#
# COSTS API CREDITS — runs a real claude -p call.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== Test: plugin loads without errors (FUNCTIONAL) ==="
echo "  loading plugin from: $PLUGIN_ROOT"
echo "  this calls claude -p (real API call) ..."
echo ""

failed=0

# Trivial prompt — the goal is not the answer, it's that claude can start
# with the plugin loaded and finish a turn cleanly. We use a short timeout.
if output=$(run_claude "Reply with exactly the word OK and nothing else." 60 2>&1); then
  if echo "$output" | grep -qiE '\bOK\b'; then
    echo "  [PASS] plugin loaded and claude responded cleanly"
  else
    echo "  [FAIL] claude exit 0 but response did not contain OK"
    echo "  Output:"
    echo "$output" | sed 's/^/    /'
    failed=$((failed + 1))
  fi
else
  exit_code=$?
  echo "  [FAIL] claude exited non-zero ($exit_code)"
  echo "  Output:"
  echo "$output" | sed 's/^/    /'
  failed=$((failed + 1))
fi

if [ "$failed" -gt 0 ]; then
  echo ""
  echo "FAIL: plugin failed to load — check manifest, frontmatter, hooks"
  exit 1
fi

echo ""
echo "PASS: plugin loads cleanly"
exit 0
