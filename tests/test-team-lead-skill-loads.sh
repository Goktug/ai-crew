#!/usr/bin/env bash
#
# test-team-lead-skill-loads.sh — STATIC: verify the team-lead SKILL.md
# file defines the 9 lifecycle phases in order, names the 4 review skills
# invoked during Phase 8, and references the `using-agent-skills` foundation
# skill.
#
# This test used to invoke claude and ask it to describe the skill. That
# was brittle because once the team-lead skill is loaded into a session,
# asking claude to "describe" it tends to trigger the orchestration
# workflow (Phase 1 intake questions) rather than a summary of the phases.
# The contract we actually care about is the SKILL.md file content, so
# this test asserts on the file directly.
#
# Functional plugin-loading coverage lives in:
#   - test-plugin-loads.sh
#   - test-using-agent-skills-loads.sh
#   - team-lead-e2e/ (end-to-end dispatch flow)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

SKILL_FILE="$PLUGIN_ROOT/skills/team-lead/SKILL.md"

echo "=== Test: team-lead SKILL.md defines the lifecycle (STATIC) ==="
echo ""

failed=0

if [ ! -f "$SKILL_FILE" ]; then
  echo "  [FAIL] SKILL.md not found at $SKILL_FILE"
  exit 1
fi

echo "  --- phase headings ---"
for phase in Intake Research Spec Plan CHECKPOINT Build Verify Review Ship; do
  if grep -q "### Phase [0-9] — $phase" "$SKILL_FILE" || grep -q "### Phase [0-9] —.*$phase" "$SKILL_FILE"; then
    echo "  [PASS] phase heading present: $phase"
  else
    echo "  [FAIL] phase heading missing: $phase"
    failed=$((failed + 1))
  fi
done

echo "  --- review skills (Phase 8) ---"
for review_skill in code-review-and-quality security-and-hardening code-simplification performance-optimization; do
  if grep -q "ai-crew:$review_skill" "$SKILL_FILE"; then
    echo "  [PASS] review skill invoked: ai-crew:$review_skill"
  else
    echo "  [FAIL] review skill missing: ai-crew:$review_skill"
    failed=$((failed + 1))
  fi
done

echo "  --- foundation (inlined core operating behaviors) ---"
for behavior in "Surface assumptions" "Manage confusion" "Push back" "Enforce simplicity" "Scope discipline" "Verify, don't assume"; do
  if grep -qi "$behavior" "$SKILL_FILE"; then
    echo "  [PASS] core behavior present: $behavior"
  else
    echo "  [FAIL] core behavior missing: $behavior"
    failed=$((failed + 1))
  fi
done

echo "  --- re-entry guard ---"
if grep -q "Do NOT invoke the .ai-crew:team-lead. skill again" "$SKILL_FILE"; then
  echo "  [PASS] re-entry guard present"
else
  echo "  [FAIL] re-entry guard missing — team-lead can be re-invoked mid-run"
  failed=$((failed + 1))
fi

echo "  --- skill-invocation contract ---"
if grep -q "Invoke the \`ai-crew:" "$SKILL_FILE"; then
  echo "  [PASS] uses 'Invoke the ai-crew:...' verbiage"
else
  echo "  [FAIL] no 'Invoke the ai-crew:...' invocations found — skill may still be using Read-inline wording"
  failed=$((failed + 1))
fi

if grep -q "SKILL.md inline" "$SKILL_FILE"; then
  echo "  [FAIL] still contains legacy 'SKILL.md inline' wording — should use Skill tool invocation"
  failed=$((failed + 1))
else
  echo "  [PASS] no legacy 'SKILL.md inline' wording"
fi

echo "  --- foundation skill no longer auto-invoked ---"
if grep -q "invoke the .ai-crew:using-agent-skills. skill" "$SKILL_FILE"; then
  echo "  [FAIL] team-lead still invokes ai-crew:using-agent-skills as a foundation skill — should be inlined"
  failed=$((failed + 1))
else
  echo "  [PASS] team-lead does not re-invoke ai-crew:using-agent-skills"
fi

if [ "$failed" -gt 0 ]; then
  echo ""
  echo "FAIL: team-lead SKILL.md structure check failed ($failed issue(s))"
  exit 1
fi

echo ""
echo "PASS: team-lead SKILL.md defines the lifecycle correctly"
exit 0
