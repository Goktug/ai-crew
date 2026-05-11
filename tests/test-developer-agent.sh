#!/usr/bin/env bash
#
# test-developer-agent.sh — verify the developer subagent definition.
#
# Asserts:
#   - frontmatter has name=developer, model=sonnet
#   - disallowedTools denylist includes Agent and Task (developer needs broad
#     tool access; the denylist enforces the strict 1-level dispatch invariant
#     without enumerating every allowed tool)
#   - body explicitly forbids subagent dispatch
#   - body references test-driven-development and incremental-implementation
#   - body specifies one-line PASS/FAIL output format

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

cd "$PLUGIN_ROOT"

echo "=== Test: developer agent ==="

DEV="agents/developer.md"
failed=0

if [ ! -f "$DEV" ]; then
  echo "  [FAIL] missing $DEV"
  exit 1
fi

# Frontmatter checks (limited to first 10 lines so a body mention of "Agent"
# does not produce a false positive on the disallowedTools: line).
if head -10 "$DEV" | grep -q "^name: developer\$"; then
  echo "  [PASS] frontmatter name == developer"
else
  echo "  [FAIL] frontmatter name is not developer"
  failed=$((failed + 1))
fi

if head -10 "$DEV" | grep -q "^model: sonnet\$"; then
  echo "  [PASS] frontmatter model == sonnet"
else
  echo "  [FAIL] frontmatter model is not sonnet"
  failed=$((failed + 1))
fi

# disallowedTools line: must deny both Agent and Task (denylist pattern that
# enforces strict 1-level dispatch without enumerating every allowed tool).
# Also guard against a leftover `tools:` allowlist sneaking back in alongside
# disallowedTools, which would silently override the denylist intent.
disallowed_line="$(head -10 "$DEV" | grep '^disallowedTools:' || true)"
if [ -z "$disallowed_line" ]; then
  echo "  [FAIL] frontmatter has no disallowedTools: line"
  failed=$((failed + 1))
else
  for forbidden in Agent Task; do
    if echo "$disallowed_line" | grep -qw "$forbidden"; then :; else
      echo "  [FAIL] disallowedTools: line missing required denial: $forbidden"
      failed=$((failed + 1))
    fi
  done
  echo "  [PASS] disallowedTools: line denies Agent and Task"
fi

if head -10 "$DEV" | grep -q "^tools:"; then
  echo "  [FAIL] frontmatter has stray tools: allowlist alongside disallowedTools:"
  failed=$((failed + 1))
else
  echo "  [PASS] frontmatter has no stray tools: allowlist"
fi

# Body content checks.
if grep -qi "do not have access to Agent\|cannot dispatch subagents\|no Agent or Task" "$DEV"; then
  echo "  [PASS] body forbids subagent dispatch explicitly"
else
  echo "  [FAIL] body does not explicitly forbid subagent dispatch"
  failed=$((failed + 1))
fi

if grep -q "test-driven-development" "$DEV"; then
  echo "  [PASS] body references test-driven-development"
else
  echo "  [FAIL] body does not reference test-driven-development"
  failed=$((failed + 1))
fi

if grep -q "incremental-implementation" "$DEV"; then
  echo "  [PASS] body references incremental-implementation"
else
  echo "  [FAIL] body does not reference incremental-implementation"
  failed=$((failed + 1))
fi

if grep -q "PASS:" "$DEV" && grep -q "FAIL:" "$DEV"; then
  echo "  [PASS] body specifies PASS/FAIL one-line output format"
else
  echo "  [FAIL] body does not specify PASS/FAIL output format"
  failed=$((failed + 1))
fi

if [ "$failed" -gt 0 ]; then
  echo ""
  echo "FAIL: $failed developer agent check(s) failed"
  exit 1
fi

echo ""
echo "PASS: developer agent verified"
exit 0
