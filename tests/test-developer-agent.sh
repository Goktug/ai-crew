#!/usr/bin/env bash
#
# test-developer-agent.sh — verify all developer subagent definitions.
#
# The plugin ships three developer agents that share an identical workflow and
# differ only in the backing model. The team-lead routes tasks by the
# `complexity` flag in plan.md (simple → sonnet, complex → opus, frontier →
# fable). All must pass the same contract checks.
#
# Asserts (for each of sonnet-developer.md, opus-developer.md, and fable-developer.md):
#   - frontmatter has the matching name and expected model
#   - disallowedTools denylist includes Agent and Task (developer needs broad
#     tool access; the denylist enforces the strict 1-level dispatch invariant
#     without enumerating every allowed tool)
#   - no stray tools: allowlist alongside disallowedTools:
#   - body explicitly forbids subagent dispatch
#   - body references test-driven-development and incremental-implementation
#   - body specifies one-line PASS/FAIL output format

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

cd "$PLUGIN_ROOT"

echo "=== Test: developer agents (sonnet + opus + fable) ==="

failed=0

check_agent() {
  local name="$1"
  local expected_model="$2"
  local path="agents/${name}.md"

  echo ""
  echo "--- ${name} (${path}) ---"

  if [ ! -f "$path" ]; then
    echo "  [FAIL] missing $path"
    failed=$((failed + 1))
    return
  fi

  if head -10 "$path" | grep -q "^name: ${name}\$"; then
    echo "  [PASS] frontmatter name == ${name}"
  else
    echo "  [FAIL] frontmatter name is not ${name}"
    failed=$((failed + 1))
  fi

  if head -10 "$path" | grep -q "^model: ${expected_model}\$"; then
    echo "  [PASS] frontmatter model == ${expected_model}"
  else
    echo "  [FAIL] frontmatter model is not ${expected_model}"
    failed=$((failed + 1))
  fi

  local disallowed_line
  disallowed_line="$(head -10 "$path" | grep '^disallowedTools:' || true)"
  if [ -z "$disallowed_line" ]; then
    echo "  [FAIL] frontmatter has no disallowedTools: line"
    failed=$((failed + 1))
  else
    local denylist_ok=true
    for forbidden in Agent Task; do
      if echo "$disallowed_line" | grep -qw "$forbidden"; then :; else
        echo "  [FAIL] disallowedTools: line missing required denial: $forbidden"
        failed=$((failed + 1))
        denylist_ok=false
      fi
    done
    if [ "$denylist_ok" = true ]; then
      echo "  [PASS] disallowedTools: line denies Agent and Task"
    fi
  fi

  if head -10 "$path" | grep -q "^tools:"; then
    echo "  [FAIL] frontmatter has stray tools: allowlist alongside disallowedTools:"
    failed=$((failed + 1))
  else
    echo "  [PASS] frontmatter has no stray tools: allowlist"
  fi

  if grep -qi "do not have access to Agent\|cannot dispatch subagents\|no Agent or Task" "$path"; then
    echo "  [PASS] body forbids subagent dispatch explicitly"
  else
    echo "  [FAIL] body does not explicitly forbid subagent dispatch"
    failed=$((failed + 1))
  fi

  if grep -q "test-driven-development" "$path"; then
    echo "  [PASS] body references test-driven-development"
  else
    echo "  [FAIL] body does not reference test-driven-development"
    failed=$((failed + 1))
  fi

  if grep -q "incremental-implementation" "$path"; then
    echo "  [PASS] body references incremental-implementation"
  else
    echo "  [FAIL] body does not reference incremental-implementation"
    failed=$((failed + 1))
  fi

  if grep -q "PASS:" "$path" && grep -q "FAIL:" "$path"; then
    echo "  [PASS] body specifies PASS/FAIL one-line output format"
  else
    echo "  [FAIL] body does not specify PASS/FAIL output format"
    failed=$((failed + 1))
  fi
}

check_agent sonnet-developer sonnet
check_agent opus-developer opus
check_agent fable-developer fable

# The team-lead skill must reference all agents and the complexity flag that
# routes between them. A regression here would break the dispatch contract.
echo ""
echo "--- team-lead skill routing references ---"
SKILL="skills/team-lead/SKILL.md"
for needle in "sonnet-developer" "opus-developer" "fable-developer" "complexity"; do
  if grep -q "$needle" "$SKILL"; then
    echo "  [PASS] $SKILL references '$needle'"
  else
    echo "  [FAIL] $SKILL is missing reference to '$needle'"
    failed=$((failed + 1))
  fi
done

# The old single agent must be gone — leaving it would create ambiguous routing.
if [ -e "agents/developer.md" ]; then
  echo "  [FAIL] legacy agents/developer.md still exists; it should be removed"
  failed=$((failed + 1))
else
  echo "  [PASS] legacy agents/developer.md is removed"
fi

if [ "$failed" -gt 0 ]; then
  echo ""
  echo "FAIL: $failed developer agent check(s) failed"
  exit 1
fi

echo ""
echo "PASS: sonnet-developer, opus-developer, and fable-developer verified"
exit 0
