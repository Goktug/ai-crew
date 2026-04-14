#!/usr/bin/env bash
#
# test-team-lead-skill-loads.sh — FUNCTIONAL: ask claude to describe the
# team-lead skill, verify the response includes the 9 lifecycle phases,
# the 4 inline review skills, and the using-agent-skills foundation.
#
# This is the strongest functional check that the team-lead skill is
# loaded, parseable, and that its content describes the architecture
# correctly when read by claude.
#
# COSTS API CREDITS.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== Test: team-lead skill loads and describes the lifecycle (FUNCTIONAL) ==="
echo ""

prompt='Read the ai-crew team-lead skill (skills/team-lead/SKILL.md inside the loaded plugin). Then describe its 9 lifecycle phases in order, the 4 review skills it loads inline during the Review phase, and which foundation skill it loads first before any phase. Be specific — name each item.'

failed=0

if output=$(run_claude "$prompt" 120 2>&1); then
  for phase in Intake Research Spec Plan CHECKPOINT Build Verify Review Ship; do
    if echo "$output" | grep -qi "$phase"; then
      echo "  [PASS] phase mentioned: $phase"
    else
      echo "  [FAIL] phase missing: $phase"
      failed=$((failed + 1))
    fi
  done

  for review_skill in code-review-and-quality security-and-hardening code-simplification performance-optimization; do
    if echo "$output" | grep -q "$review_skill"; then
      echo "  [PASS] review skill named: $review_skill"
    else
      echo "  [FAIL] review skill missing: $review_skill"
      failed=$((failed + 1))
    fi
  done

  if echo "$output" | grep -q "using-agent-skills"; then
    echo "  [PASS] foundation skill named: using-agent-skills"
  else
    echo "  [FAIL] foundation skill (using-agent-skills) not mentioned"
    failed=$((failed + 1))
  fi

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
  echo "FAIL: team-lead skill description was incomplete or skill failed to load"
  exit 1
fi

echo ""
echo "PASS: team-lead skill loaded and described correctly"
exit 0
