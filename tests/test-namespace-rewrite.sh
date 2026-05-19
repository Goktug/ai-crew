#!/usr/bin/env bash
#
# test-namespace-rewrite.sh — verify the T-06 namespace rewrite.
#
# Asserts:
#   - No `agent-skills:` prefix remains anywhere under .claude/commands/
#   - At least one `ai-crew:` reference exists in each of the 7 vendored
#     command files (sanity check that the rewrite actually happened)
#   - No NEW file (skills/team-lead, skills/intake-with-validation, etc.)
#     references `reference-projects/agent-skills/` anywhere — vendored
#     content should be referenced by plugin-relative paths.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

cd "$PLUGIN_ROOT"

echo "=== Test: T-06 namespace rewrite ==="

failed=0

# 1. No agent-skills: prefix in .claude/commands/
if grep -rn "agent-skills:" .claude/commands/ > /dev/null 2>&1; then
  echo "  [FAIL] .claude/commands/ still contains agent-skills: prefix:"
  grep -rn "agent-skills:" .claude/commands/ | sed 's/^/    /'
  failed=$((failed + 1))
else
  echo "  [PASS] no agent-skills: prefix in .claude/commands/"
fi

# 2. Each command file has at least one ai-crew: reference.
for f in .claude/commands/build.md \
         .claude/commands/code-simplify.md \
         .claude/commands/plan.md \
         .claude/commands/review.md \
         .claude/commands/ship.md \
         .claude/commands/spec.md \
         .claude/commands/test.md; do
  if [ ! -f "$f" ]; then
    echo "  [FAIL] missing vendored command: $f"
    failed=$((failed + 1))
    continue
  fi
  if grep -q "ai-crew:" "$f"; then
    echo "  [PASS] $f references ai-crew:"
  else
    echo "  [FAIL] $f has no ai-crew: reference (rewrite did not run on this file)"
    failed=$((failed + 1))
  fi
done

# 3. No NEW file references reference-projects/agent-skills/
new_files=(
  "skills/team-lead/SKILL.md"
  "skills/intake-with-validation/SKILL.md"
  "skills/mobile-component-testing-with-rntl/SKILL.md"
  "agents/sonnet-developer.md"
  "agents/opus-developer.md"
  "agents/web-researcher.md"
  ".claude/commands/team-lead.md"
  ".claude-plugin/plugin.json"
  ".claude-plugin/marketplace.json"
)
for f in "${new_files[@]}"; do
  if [ ! -f "$f" ]; then
    echo "  [FAIL] missing NEW file: $f"
    failed=$((failed + 1))
    continue
  fi
  if grep -q "reference-projects/agent-skills" "$f"; then
    echo "  [FAIL] $f contains stale reference-projects/agent-skills path"
    failed=$((failed + 1))
  else
    echo "  [PASS] $f has no stale reference-projects/agent-skills path"
  fi
done

if [ "$failed" -gt 0 ]; then
  echo ""
  echo "FAIL: $failed namespace check(s) failed"
  exit 1
fi

echo ""
echo "PASS: namespace rewrite + new-file path hygiene verified"
exit 0
