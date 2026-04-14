#!/usr/bin/env bash
#
# test-developer-agent-loads.sh — FUNCTIONAL: verify claude can read the
# developer subagent definition and report its tool list. Catches schema
# regressions that file-content greps would miss (e.g., wrong frontmatter
# format that claude rejects but grep accepts).
#
# COSTS API CREDITS.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== Test: developer agent loads (FUNCTIONAL) ==="
echo ""

prompt='Read the developer agent definition at agents/developer.md inside the loaded ai-crew plugin. Report exactly: (1) the model the agent uses, (2) the full list of tools it has, (3) whether it has Agent or Task tools (yes/no for each), (4) the one-line output format it must return when finished.'

failed=0

# Run claude; capture output + exit code separately. Exit 124 means the
# outer timeout fired during SessionEnd hook cleanup (e.g. claude-mem
# session-complete) after claude had already produced its answer. Treat
# that as a soft warning and still evaluate the captured content.
set +e
output=$(run_claude "$prompt" 180 2>&1)
exit_code=$?
set -e

if [ "$exit_code" -eq 124 ]; then
  echo "  [WARN] claude exited 124 (session-end hook cancelled) — evaluating captured output anyway"
elif [ "$exit_code" -ne 0 ]; then
  echo "  [FAIL] claude exited non-zero ($exit_code)"
  echo "  Output:"
  echo "$output" | sed 's/^/    /'
  exit 1
fi

if echo "$output" | grep -qi "sonnet"; then
  echo "  [PASS] reports model = sonnet"
else
  echo "  [FAIL] does not report sonnet model"
  failed=$((failed + 1))
fi

for tool in Read Write Edit Bash Grep Glob Skill; do
  if echo "$output" | grep -qw "$tool"; then
    echo "  [PASS] reports tool: $tool"
  else
    echo "  [FAIL] does not report tool: $tool"
    failed=$((failed + 1))
  fi
done

if echo "$output" | grep -qiE "no.*Agent|Agent.*:.*no|does not.*have.*Agent|without.*Agent|cannot.*Agent"; then
  echo "  [PASS] reports NO Agent tool"
else
  echo "  [FAIL] does not clearly report absence of Agent tool"
  failed=$((failed + 1))
fi

if echo "$output" | grep -qiE "no.*Task|Task.*:.*no|does not.*have.*Task|without.*Task|cannot.*Task"; then
  echo "  [PASS] reports NO Task tool"
else
  echo "  [FAIL] does not clearly report absence of Task tool"
  failed=$((failed + 1))
fi

if echo "$output" | grep -qE "PASS|FAIL"; then
  echo "  [PASS] reports PASS/FAIL output format"
else
  echo "  [FAIL] does not report PASS/FAIL output format"
  failed=$((failed + 1))
fi

if [ "$failed" -gt 0 ]; then
  echo ""
  echo "  Full claude output:"
  echo "$output" | sed 's/^/    /'
  echo ""
  echo "FAIL: developer agent functional check failed"
  exit 1
fi

echo ""
echo "PASS: developer agent loads and reports correct configuration"
exit 0
