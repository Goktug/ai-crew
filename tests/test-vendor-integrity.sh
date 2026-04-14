#!/usr/bin/env bash
#
# test-vendor-integrity.sh — verify that vendored agent-skills content is
# byte-identical to the source mirror, EXCEPT for the seven slash-command
# files that T-06 deliberately rewrote (`agent-skills:` → `ai-crew:`).
#
# This catches accidental edits to vendored SKILL.md content, which is forbidden
# by CLAUDE.md non-negotiable #5.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

cd "$PLUGIN_ROOT"

SOURCE="reference-projects/agent-skills"

echo "=== Test: vendored content is byte-identical to source ==="

if [ ! -d "$SOURCE" ]; then
  echo "  [SKIP] source mirror not found: $SOURCE"
  echo "  (this test only runs when the agent-skills reference project is checked out)"
  exit 0
fi

failed=0

# For each vendored directory, diff against source and filter "Only in <dest>"
# lines (those are NEW files, allowed). Any "Files X and Y differ" or
# "Only in <source>" line is a real failure.
for sub in skills agents references hooks; do
  diff_output="$(diff -rq "$SOURCE/$sub/" "$sub/" 2>&1 || true)"
  bad="$(echo "$diff_output" | grep -v "^Only in $sub" || true)"
  if [ -n "$bad" ]; then
    echo "  [FAIL] $sub/ has unexpected differences against $SOURCE/$sub/:"
    echo "$bad" | sed 's/^/    /'
    failed=$((failed + 1))
  else
    echo "  [PASS] $sub/ is byte-identical to source (extras allowed)"
  fi
done

# .claude/commands/ is special: T-06 deliberately edited the 7 vendored files
# to rewrite agent-skills: → ai-crew:. We expect the 7 commands to differ from
# source — but no NEW source file should be missing.
echo "  --- .claude/commands/ (T-06 prefix rewrite) ---"
diff_output="$(diff -rq "$SOURCE/.claude/commands/" ".claude/commands/" 2>&1 || true)"
# Anything that says "Only in <source>" is missing — bad.
missing="$(echo "$diff_output" | grep "^Only in $SOURCE" || true)"
if [ -n "$missing" ]; then
  echo "  [FAIL] .claude/commands/ is missing source files:"
  echo "$missing" | sed 's/^/    /'
  failed=$((failed + 1))
else
  echo "  [PASS] .claude/commands/ has all source files (some intentionally rewritten)"
fi

if [ "$failed" -gt 0 ]; then
  echo ""
  echo "FAIL: $failed vendored directory check(s) failed"
  exit 1
fi

echo ""
echo "PASS: vendored content integrity verified"
exit 0
