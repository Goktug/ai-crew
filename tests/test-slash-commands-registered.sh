#!/usr/bin/env bash
#
# test-slash-commands-registered.sh — FUNCTIONAL: ai-crew slash commands are
# registered and discoverable from inside a claude session that has the plugin
# loaded via --plugin-dir.
#
# Verifies the /team-lead command (the single entry point) is visible to claude.
# Also verifies the inherited slash commands (/build, /plan, /spec, /test, /review,
# /ship, /code-simplify) are present.
#
# COSTS API CREDITS.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== Test: slash commands registered (FUNCTIONAL) ==="
echo "  asking claude to list ai-crew slash commands ..."
echo ""

prompt='List every slash command the ai-crew plugin exposes. Output one command per line, exactly in the form /command-name with no other text. Include team-lead, build, plan, spec, test, review, ship, code-simplify if they exist.'

failed=0

if output=$(run_claude "$prompt" 90 2>&1); then
  for cmd in /team-lead /build /plan /spec /test /review /ship /code-simplify; do
    if echo "$output" | grep -qE "(^|[^a-z-])$cmd([^a-z-]|$)"; then
      echo "  [PASS] $cmd is registered"
    else
      echo "  [FAIL] $cmd not in claude's response"
      failed=$((failed + 1))
    fi
  done
  if [ "$failed" -gt 0 ]; then
    echo ""
    echo "  Full claude output:"
    echo "$output" | sed 's/^/    /'
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
  echo "FAIL: $failed slash command(s) not detected"
  exit 1
fi

echo ""
echo "PASS: all 8 slash commands registered"
exit 0
