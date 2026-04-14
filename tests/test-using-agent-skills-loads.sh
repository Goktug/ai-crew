#!/usr/bin/env bash
#
# test-using-agent-skills-loads.sh — FUNCTIONAL: verify the meta-skill
# `using-agent-skills` is loaded and discoverable. The team-lead depends on it
# as the foundation skill loaded before Phase 1.
#
# COSTS API CREDITS.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== Test: using-agent-skills meta-skill loads (FUNCTIONAL) ==="
echo ""

prompt='Read the using-agent-skills skill (skills/using-agent-skills/SKILL.md inside the loaded ai-crew plugin). Summarize: (1) what it is in one sentence, (2) name the six Core Operating Behaviors it defines, (3) the Lifecycle Sequence step count.'

failed=0

if output=$(run_claude "$prompt" 90 2>&1); then
  if echo "$output" | grep -qi "meta-skill\|skill.*discover\|discovers.*skill"; then
    echo "  [PASS] response identifies it as a meta/discovery skill"
  else
    echo "  [FAIL] response does not identify it as a meta/discovery skill"
    failed=$((failed + 1))
  fi

  for behavior in "Surface Assumptions" "Manage Confusion" "Push Back" "Enforce Simplicity" "Scope Discipline" "Verify"; do
    if echo "$output" | grep -qi "$behavior"; then
      echo "  [PASS] core behavior named: $behavior"
    else
      echo "  [FAIL] core behavior missing: $behavior"
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
  echo "FAIL: using-agent-skills was not described correctly"
  exit 1
fi

echo ""
echo "PASS: using-agent-skills loaded and described correctly"
exit 0
