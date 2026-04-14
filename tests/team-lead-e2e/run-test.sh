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
#
# Claude Code 2.1.107 facts that drive the patterns below:
#   - The subagent dispatch tool is named `Agent` (NOT `Task`).
#   - subagent_type values are namespaced by plugin: `ai-crew:developer`,
#     not bare `developer`.
#   - A single logical assistant message can be streamed as multiple rows
#     sharing one `message.id`. Tool_use counts MUST be aggregated by id.
#
# All checks require jq. macOS doesn't ship `timeout` either — the runner's
# top-level `claude -p` invocation doesn't get killed if it hangs, but every
# check below operates on the captured log file and is fast.

hand_off_failed=0

if ! command -v jq > /dev/null 2>&1; then
  echo "ERROR: jq is required for hand-off checks." >&2
  echo "Install with: brew install jq" >&2
  exit 1
fi

# Pre-compute the metrics we need with one jq pass each. All counts are
# integers — never strings with embedded newlines.
agent_dispatches=$(jq -s '
  [.[] | select(.type == "assistant") | .message.content[]?
   | select(.type == "tool_use" and .name == "Agent")] | length
' "$LOG_FILE")

developer_dispatches=$(jq -s '
  [.[] | select(.type == "assistant") | .message.content[]?
   | select(.type == "tool_use" and .name == "Agent")
   | .input.subagent_type
   | select(. == "developer" or . == "ai-crew:developer")] | length
' "$LOG_FILE")

webresearcher_dispatches=$(jq -s '
  [.[] | select(.type == "assistant") | .message.content[]?
   | select(.type == "tool_use" and .name == "Agent")
   | .input.subagent_type
   | select(. == "web-researcher" or . == "ai-crew:web-researcher")] | length
' "$LOG_FILE")

# Group all assistant rows by message.id, then for each group count Agent
# tool_use blocks across the rows. A group whose count is ≥2 is a parallel
# fan-out (multiple tool calls in one logical assistant message).
parallel_turns=$(jq -s '
  [.[] | select(.type == "assistant")]
  | group_by(.message.id)
  | map([.[].message.content[]? | select(.type == "tool_use" and .name == "Agent")] | length)
  | map(select(. >= 2))
  | length
' "$LOG_FILE")

largest_fanout=$(jq -s '
  [.[] | select(.type == "assistant")]
  | group_by(.message.id)
  | map([.[].message.content[]? | select(.type == "tool_use" and .name == "Agent")] | length)
  | max // 0
' "$LOG_FILE")

# Count completed developer replies by correlating Agent tool_use_ids to
# tool_result events. This is robust to whatever wording the developer used
# (the previous `^PASS:` regex only matched two of three replies because the
# third said "All 6 tests pass and the verification command succeeds.").
#
# total_replies = number of tool_results whose tool_use_id matches an Agent
#                 dispatch — i.e., subagents that actually completed.
# explicit_fails = subset whose text contains "FAIL:" or "FAIL " at start.
# implicit_passes = total_replies - explicit_fails (any non-FAIL reply is
#                   treated as success, since FAIL is the only deliberate
#                   non-success signal in the developer's contract).
total_replies=$(jq -s '
  ([.[] | select(.type == "assistant") | .message.content[]?
    | select(.type == "tool_use" and .name == "Agent") | .id]) as $ids
  | [.[] | select(.type == "user") | .message.content[]?
     | select(.type == "tool_result")
     | select(.tool_use_id as $tid | $ids | index($tid) != null)]
  | length
' "$LOG_FILE")

explicit_fails=$(jq -s '
  ([.[] | select(.type == "assistant") | .message.content[]?
    | select(.type == "tool_use" and .name == "Agent") | .id]) as $ids
  | [.[] | select(.type == "user") | .message.content[]?
     | select(.type == "tool_result")
     | select(.tool_use_id as $tid | $ids | index($tid) != null)
     | (.content // [])
     | (if type == "string" then [{type: "text", text: .}] else . end)
     | .[]?
     | select(.type == "text")
     | .text
     | select(test("^FAIL[: ]"))]
  | length
' "$LOG_FILE")

implicit_passes=$((total_replies - explicit_fails))

echo "--- Check 1: developer subagent dispatched at least once ---"
if [ "$developer_dispatches" -ge 1 ]; then
  echo "  [PASS] developer subagent dispatched $developer_dispatches time(s) (web-researcher: $webresearcher_dispatches, total Agent calls: $agent_dispatches)"
else
  echo "  [FAIL] no developer subagent dispatch found (total Agent calls: $agent_dispatches, web-researcher: $webresearcher_dispatches)"
  hand_off_failed=$((hand_off_failed + 1))
fi

echo ""
echo "--- Check 2: developer subagents returned a result ---"
if [ "$total_replies" -ge 1 ]; then
  echo "  [PASS] $total_replies developer reply/replies received (implicit_pass=$implicit_passes, explicit_fail=$explicit_fails)"
else
  echo "  [FAIL] no completed developer replies correlated to Agent tool calls"
  hand_off_failed=$((hand_off_failed + 1))
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
echo "--- Check 4: 1-level dispatch (no nested subagent calls) ---"
# Strict 1-level dispatch means: every Agent tool call must come from the
# top-level team-lead session, not from inside another subagent. Inside a
# subagent the Agent tool isn't even available (developer/web-researcher
# don't have it in their tools list), so any nested call would surface as
# an error in the stream. We approximate the check by asserting that every
# Agent tool call resolves to a known subagent_type (developer or
# web-researcher). An unknown value would indicate a wrong-tool dispatch.
unknown_dispatches=$((agent_dispatches - developer_dispatches - webresearcher_dispatches))
if [ "$unknown_dispatches" -eq 0 ]; then
  echo "  [PASS] all $agent_dispatches Agent calls resolved to a known subagent type"
else
  echo "  [WARN] $unknown_dispatches Agent call(s) used an unknown subagent_type — investigate manually"
fi

echo ""
echo "--- Check 5: parallel fan-out (≥2 Agent calls in one assistant message) ---"
echo "  parallel_turns=$parallel_turns largest_fanout=$largest_fanout"

# ts-utility-pack: 3 independent tasks → at least one message must have ≥2 Agent calls.
# rn-counter: sequential by design → no parallel fan-out expected.
if [[ "$TEST_NAME" == "ts-utility-pack" ]]; then
  if [ "$parallel_turns" -ge 1 ] && [ "$largest_fanout" -ge 2 ]; then
    echo "  [PASS] parallel fan-out detected ($parallel_turns turn(s) with ≥2 Agent calls, largest=$largest_fanout)"
  else
    echo "  [FAIL] no parallel fan-out — three independent tasks ran sequentially"
    hand_off_failed=$((hand_off_failed + 1))
  fi
else
  if [ "$parallel_turns" -ge 1 ]; then
    echo "  [INFO] parallel fan-out detected (largest=$largest_fanout) — not required for this fixture"
  else
    echo "  [INFO] no parallel fan-out (sequential dispatch — expected for this fixture)"
  fi
fi

echo ""
echo "--- Check 6: token usage ---"
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
