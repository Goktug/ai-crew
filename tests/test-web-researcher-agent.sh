#!/usr/bin/env bash
#
# test-web-researcher-agent.sh — verify the web-researcher subagent definition.
#
# Asserts:
#   - frontmatter has name=web-researcher, model=haiku
#   - tools list = WebFetch, WebSearch, Read, Write (NO Agent, NO Task)
#   - body forbids subagent dispatch
#   - body specifies brief + citations output format

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

cd "$PLUGIN_ROOT"

echo "=== Test: web-researcher agent ==="

WR="agents/web-researcher.md"
failed=0

if [ ! -f "$WR" ]; then
  echo "  [FAIL] missing $WR"
  exit 1
fi

if head -10 "$WR" | grep -q "^name: web-researcher\$"; then
  echo "  [PASS] frontmatter name == web-researcher"
else
  echo "  [FAIL] frontmatter name is not web-researcher"
  failed=$((failed + 1))
fi

if head -10 "$WR" | grep -q "^model: haiku\$"; then
  echo "  [PASS] frontmatter model == haiku"
else
  echo "  [FAIL] frontmatter model is not haiku"
  failed=$((failed + 1))
fi

tools_line="$(head -10 "$WR" | grep '^tools:' || true)"
if [ -z "$tools_line" ]; then
  echo "  [FAIL] frontmatter has no tools: line"
  failed=$((failed + 1))
else
  for tool in WebFetch WebSearch Read Write; do
    if echo "$tools_line" | grep -qw "$tool"; then :; else
      echo "  [FAIL] tools: line missing tool: $tool"
      failed=$((failed + 1))
    fi
  done
  for forbidden in Agent Task; do
    if echo "$tools_line" | grep -qw "$forbidden"; then
      echo "  [FAIL] tools: line contains forbidden tool: $forbidden"
      failed=$((failed + 1))
    fi
  done
  echo "  [PASS] tools: line has 4 allowed tools and no Agent/Task"
fi

if grep -qi "no Agent\|cannot dispatch\|no.*Task\|forbid.*subagent\|Forbids subagent" "$WR"; then
  echo "  [PASS] body forbids subagent dispatch"
else
  echo "  [FAIL] body does not forbid subagent dispatch"
  failed=$((failed + 1))
fi

if grep -qi "brief" "$WR" && grep -qi "citation\|CITATIONS" "$WR"; then
  echo "  [PASS] body specifies brief + citations output format"
else
  echo "  [FAIL] body does not specify brief + citations output"
  failed=$((failed + 1))
fi

if [ "$failed" -gt 0 ]; then
  echo ""
  echo "FAIL: $failed web-researcher check(s) failed"
  exit 1
fi

echo ""
echo "PASS: web-researcher agent verified"
exit 0
