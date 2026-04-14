#!/usr/bin/env bash
#
# tests/team-lead-e2e/run-test.sh — end-to-end smoke test of the team-lead
# orchestrator with subagent hand-off.
#
# Adapted from reference-projects/superpowers/tests/subagent-driven-dev/run-test.sh
# with these ai-crew-specific changes:
#
# 1. The fixture provides PRE-PREPARED spec.md + plan.md so the team-lead
#    can skip Intake/Research/Spec/Plan and execute the Build phase. This
#    avoids the human checkpoint stalling a headless run.
# 2. The prompt explicitly tells team-lead to dispatch developer subagents
#    for each task and stop before Ship (no commit, no PR).
# 3. After the run, we grep the stream-json log for hand-off evidence:
#    - Task tool calls with subagent_type=developer
#    - Each subagent returning PASS/FAIL
#    - progress.md updated
#
# Usage:
#   ./run-test.sh <fixture-name> [--plugin-dir <path>]
# Example:
#   ./run-test.sh rn-counter

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_NAME="${1:?Usage: $0 <fixture-name> [--plugin-dir <path>]}"
shift || true

PLUGIN_DIR=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --plugin-dir)
      PLUGIN_DIR="$2"; shift 2 ;;
    *)
      echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$PLUGIN_DIR" ]]; then
  PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

TEST_DIR="$SCRIPT_DIR/$TEST_NAME"
if [[ ! -d "$TEST_DIR" ]]; then
  echo "Error: fixture '$TEST_NAME' not found at $TEST_DIR" >&2
  echo "Available fixtures:" >&2
  find "$SCRIPT_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; >&2
  exit 1
fi

if [[ ! -x "$TEST_DIR/scaffold.sh" ]]; then
  echo "Error: $TEST_DIR/scaffold.sh missing or not executable" >&2
  exit 1
fi

TIMESTAMP=$(date +%s)
OUTPUT_BASE="/tmp/ai-crew-tests/$TIMESTAMP/team-lead-e2e"
OUTPUT_DIR="$OUTPUT_BASE/$TEST_NAME"
mkdir -p "$OUTPUT_DIR"

echo "========================================"
echo " ai-crew Team-Lead End-to-End Test"
echo "========================================"
echo "Fixture:     $TEST_NAME"
echo "Plugin dir:  $PLUGIN_DIR"
echo "Output dir:  $OUTPUT_DIR"
echo "Timestamp:   $(date)"
echo ""

echo ">>> Scaffolding fixture project ..."
"$TEST_DIR/scaffold.sh" "$OUTPUT_DIR/project"
echo ""

PROJECT_DIR="$OUTPUT_DIR/project"
SPEC_PATH="$PROJECT_DIR/spec.md"
PLAN_PATH="$PROJECT_DIR/plan.md"
PROGRESS_PATH="$PROJECT_DIR/progress.md"

# The prompt: load team-lead, skip Intake/Spec/Plan (pre-provided), run Build,
# Verify, Review, then STOP before Ship. Each Build task is dispatched as a
# Task tool call to the developer subagent.
PROMPT=$(cat <<EOF
You are an ai-crew Opus team-lead session. The plugin is loaded from $PLUGIN_DIR.

This run has pre-prepared artifacts in the current working directory:
  - design.md   (high-level requirement)
  - spec.md     (detailed spec, ready)
  - plan.md     (task DAG, ready — every task has acceptance criteria + verification)
  - progress.md (empty checklist for you to update)

Please:
1. Load the ai-crew:team-lead skill (skills/team-lead/SKILL.md inside the plugin) and read it end to end.
2. Read using-agent-skills/SKILL.md — the team-lead's foundation.
3. Read spec.md and plan.md.
4. Skip Phase 1 (Intake), Phase 2 (Research), Phase 3 (Spec), and Phase 4 (Plan). They are already complete.
5. There is no human checkpoint in this run — proceed directly into Phase 6 (Build).
6. Walk plan.md in dependency order. For each task T-N, dispatch the developer subagent (subagent_type="developer", model="sonnet") with a reference-based prompt under ~30 lines following the template in the team-lead skill. The developer must read spec.md and plan.md itself.
7. After each developer dispatch, mark the task's checkbox in progress.md as PASS or FAIL.
8. Run Phase 7 (Verify): execute the verification commands listed in plan.md.
9. Run Phase 8 (Review) inline using the four review skills, and document findings in progress.md.
10. STOP before Phase 9 (Ship). Do NOT commit. Do NOT open a PR. Do NOT push.

Constraints:
- The developer subagent has NO Agent or Task tools — it cannot dispatch further subagents.
- Reference-based dispatch only — no embedded plan/spec content in the developer prompt.
- Max 3 fix loops total (Verify + Review combined) before reporting failure to me.
EOF
)

LOG_FILE="$OUTPUT_DIR/claude-output.json"
echo ">>> Running team-lead end-to-end ..."
echo "Project: $PROJECT_DIR"
echo "Log:     $LOG_FILE"
echo "(this calls claude -p with --plugin-dir and --dangerously-skip-permissions)"
echo ""

cd "$PROJECT_DIR"
claude -p "$PROMPT" \
  --plugin-dir "$PLUGIN_DIR" \
  --dangerously-skip-permissions \
  --output-format stream-json \
  --verbose \
  > "$LOG_FILE" 2>&1 || true

echo ""
echo ">>> Run complete. Inspecting results ..."
echo ""

# --- Hand-off evidence checks ---
hand_off_failed=0

echo "--- Check 1: developer subagent dispatched at least once ---"
if grep -q '"subagent_type"[[:space:]]*:[[:space:]]*"developer"' "$LOG_FILE" 2>/dev/null; then
  dispatch_count=$(grep -c '"subagent_type"[[:space:]]*:[[:space:]]*"developer"' "$LOG_FILE" || echo "0")
  echo "  [PASS] developer subagent dispatched $dispatch_count time(s)"
else
  echo "  [FAIL] no developer subagent dispatch found in stream-json log"
  hand_off_failed=$((hand_off_failed + 1))
fi

echo ""
echo "--- Check 2: developer subagent returned PASS/FAIL ---"
if grep -qE '"text"[[:space:]]*:[[:space:]]*"(PASS|FAIL):' "$LOG_FILE" 2>/dev/null; then
  pass_count=$(grep -cE '"text"[[:space:]]*:[[:space:]]*"PASS:' "$LOG_FILE" || echo "0")
  fail_count=$(grep -cE '"text"[[:space:]]*:[[:space:]]*"FAIL:' "$LOG_FILE" || echo "0")
  echo "  [PASS] developer reported PASS=$pass_count FAIL=$fail_count"
else
  echo "  [WARN] no PASS:/FAIL: lines in subagent text — pattern may differ"
fi

echo ""
echo "--- Check 3: progress.md was updated ---"
if [ -f "$PROGRESS_PATH" ] && [ -s "$PROGRESS_PATH" ]; then
  echo "  [PASS] $PROGRESS_PATH exists and is non-empty"
  echo "  --- progress.md contents ---"
  sed 's/^/      /' "$PROGRESS_PATH" | head -40
else
  echo "  [FAIL] progress.md was not updated"
  hand_off_failed=$((hand_off_failed + 1))
fi

echo ""
echo "--- Check 4: developer did NOT spawn its own subagent (1-level dispatch) ---"
# Count Task tool calls inside subagent contexts. If any subagent_id has nested
# subagent dispatches, the 1-level rule is broken.
nested=$(grep -c '"name"[[:space:]]*:[[:space:]]*"Task"' "$LOG_FILE" 2>/dev/null || echo "0")
top_level=$(grep -c '"subagent_type"[[:space:]]*:[[:space:]]*"developer"' "$LOG_FILE" 2>/dev/null || echo "0")
if [ "$nested" -le "$top_level" ]; then
  echo "  [PASS] no nested subagent dispatches detected ($nested Task calls, $top_level developer dispatches)"
else
  echo "  [WARN] $nested Task calls vs $top_level developer dispatches — investigate manually"
fi

echo ""
echo "--- Check 5: token usage ---"
if command -v jq > /dev/null 2>&1; then
  jq -s '[.[] | select(.type == "result")] | last | .usage' "$LOG_FILE" 2>/dev/null || echo "(could not parse usage)"
else
  echo "(install jq for token usage breakdown)"
fi

echo ""
echo "========================================"
if [ "$hand_off_failed" -gt 0 ]; then
  echo "STATUS: HAND-OFF CHECKS FAILED ($hand_off_failed)"
else
  echo "STATUS: HAND-OFF CHECKS PASSED"
fi
echo "========================================"
echo ""
echo ">>> Next steps:"
echo "1. Inspect the project: cd $PROJECT_DIR"
echo "2. Read claude's full log: less $LOG_FILE"
echo "3. Run the project's own tests: cd $PROJECT_DIR && npm install && npm test"
echo ""

exit "$hand_off_failed"
