#!/usr/bin/env bash
#
# test-developer-agent-loads.sh — FUNCTIONAL: verify claude can read both
# developer subagent definitions and report their configuration. Catches
# schema regressions that file-content greps would miss (e.g., wrong
# frontmatter format that claude rejects but grep accepts).
#
# Runs the same probe against both sonnet-developer and opus-developer,
# asserting each reports the expected model plus the same tool surface
# and PASS/FAIL output contract.
#
# COSTS API CREDITS (two claude invocations).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== Test: developer agents load (FUNCTIONAL) ==="
echo ""

failed=0

probe_agent() {
  local name="$1"
  local expected_model="$2"
  local agent_path="agents/${name}.md"

  echo "--- ${name} ---"

  local prompt
  prompt="Read the ${name} agent definition at ${agent_path} inside the loaded ai-crew plugin. Report exactly: (1) the model the agent uses, (2) the full list of tools it has, (3) whether it has Agent or Task tools (yes/no for each), (4) the one-line output format it must return when finished."

  local output
  if output=$(run_claude "$prompt" 90 2>&1); then
    if echo "$output" | grep -qi "$expected_model"; then
      echo "  [PASS] reports model = ${expected_model}"
    else
      echo "  [FAIL] does not report ${expected_model} model"
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
      echo "  Full claude output for ${name}:"
      echo "$output" | sed 's/^/    /'
    fi
  else
    local exit_code=$?
    echo "  [FAIL] claude exited non-zero ($exit_code) for ${name}"
    echo "  Output:"
    echo "$output" | sed 's/^/    /'
    failed=$((failed + 1))
  fi

  echo ""
}

probe_agent sonnet-developer sonnet
probe_agent opus-developer opus

if [ "$failed" -gt 0 ]; then
  echo "FAIL: developer agent functional check failed"
  exit 1
fi

echo "PASS: sonnet-developer and opus-developer load and report correct configuration"
exit 0
