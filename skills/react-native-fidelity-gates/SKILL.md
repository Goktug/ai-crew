---
name: react-native-fidelity-gates
description: Amends the team-lead lifecycle for React Native runs by adding design-fidelity gates that diff the running app against its Figma source. Read by team-lead only when `detect-project-type.sh` reports `react-native`. Defines gate emission rules (Phase 4), the `simulator-engineer` dispatch template and advisory action policy (Phase 6), the shared retry-budget extension (Phases 7–8), and the matching rationalizations, red flags, and verification checks.
---

# React Native Fidelity Gates

## Overview

This skill is an **amendment** to `team-lead`. It adds one extra concern: comparing what the React Native app actually rendered on a real iOS simulator against the Figma design that was supposed to drive the build.

The team-lead reads this file end-to-end at run start, **immediately after `using-agent-skills/SKILL.md`**, but only when `detect-project-type.sh` reported `projectType: react-native`. On backend, web, or unknown projects this skill is never loaded — the lifecycle runs without it and pays no token cost for it.

What this skill defines:

- **Phase 4 amendment** — when and how to emit fidelity-gate tasks into `plan.md`.
- **Phase 6 amendment** — the `simulator-engineer` dispatch template, plus the advisory action policy the team-lead applies to the structured `RESULT` it returns.
- **Phases 7–8 amendment** — gate-driven fix loops share the same max-3 retry budget that Verify and Review use; this skill extends that budget definition rather than introducing a new one.
- The matching Common Rationalizations, Red Flags, and Verification checks that apply on RN runs.

Nothing here changes Phases 1–3, 5, 7 (verification commands themselves), 8 (the five-axis review), or 9 (ship). Those are project-type-agnostic and stay in `team-lead`.

## When to Use

- The team-lead has just finished reading `<plugin>/skills/using-agent-skills/SKILL.md` at run start AND `detect-project-type.sh` (already executed by the session-start hook) reported `projectType: react-native`. Read this skill end to end and keep it in mind for the rest of the run.
- A subagent dispatch is about to invoke `simulator-engineer` — re-check the dispatch template and the action policy before sending the prompt.

**When NOT to use:**
- The project is not React Native — do not load this skill, do not emit gates, do not invent a use for the `simulator-engineer` agent.
- The plan contains zero UI tasks (no skill tag of `frontend-ui-engineering` or `mobile-component-testing-with-rntl`) — the gate-emission rule is empty for that plan; load the skill but emit nothing.
- A standalone fidelity check requested by the user outside an ai-crew run — call `simulator-design-fidelity` directly with `simulator-engineer`, no orchestration needed.

## Phase 4 amendment — gate emission

A **UI task** is any plan task whose `skill tags` include `frontend-ui-engineering` or `mobile-component-testing-with-rntl` — i.e., the task renders or modifies a user-facing screen. UI tasks should already carry a `figma_ref` because the developer needs it for `mcp__figma__get_design_context`; the `simulator-engineer` reuses the same field, so there is no new spec field to curate.

After Phase 4's existing Task Index step and before Phase 5 (CHECKPOINT), append one fidelity-gate task per **contiguous group of UI tasks** in the DAG. Each gate dispatches `simulator-engineer` (not `developer`) and depends on every UI task in its group.

The gate task is a regular `plan.md` entry — same `### T-NNN ...` heading, same `Plan task` line range, same Task Index treatment. It differs from a developer task in only three fields:

- **Agent**: `simulator-engineer`
- **Skills to read first**: `simulator-design-fidelity` (plus the Argent skills installed by `argent init` in the project — `argent-simulator-setup`, `argent-react-native-app-workflow`, `argent-test-ui-flow`; the team-lead assumes these are pre-installed and does not run `argent init` itself)
- **Inputs**: per-member-screen `nav_hint` from the UI task plus `figma_files` paths the team-lead populates during pre-flight (see Phase 6). The original `figma_ref` URL is recorded in `progress.md` for traceability but is *not* what the subagent receives.

Emission rules:

- **One gate per contiguous UI epic.** Do not emit one gate per task. Per-task gates serialize the simulator unnecessarily and shred parallelism within the epic; RNTL already covers per-task structural correctness.
- **Gates are mutually exclusive by construction.** Each is a single DAG node, the simulator is a singleton, and the team-lead never spawns two `simulator-engineer` dispatches concurrently. Serialization is structural, not enforced at runtime.
- **No UI tasks → emit nothing.** A plan with zero UI tasks proceeds to Phase 5 with no gates appended. Do not invent gates "to be safe."
- Gates land in `plan.md` **before** Phase 5. Once the user approves the plan at the checkpoint, the DAG (gates included) is frozen — Verify/Review fix loops never add or renumber entries, including gate entries.

## Phase 6 amendment — `simulator-engineer` dispatch

Fidelity-gate tasks dispatch `simulator-engineer` instead of `developer`. The `simulator-engineer` uses Sonnet and has only `Read, Bash, Grep, Glob, Skill, mcp__argent` tools. **It does not have `mcp__figma`** — Claude Code's MCP propagation does not reliably pass main-session MCP servers into subagent dispatches, so the team-lead pre-fetches all Figma artifacts on its side before dispatching. The subagent reads them from disk. This makes the gate robust to the propagation gap and keeps the artifacts inspectable for the user.

The simulator-engineer cannot dispatch further subagents. It is read-only on the codebase. It returns a structured `RESULT:` block per member screen, not a one-line PASS/FAIL summary.

### Pre-flight — team-lead fetches Figma artifacts

Before writing the dispatch prompt, the team-lead fetches the design side for every member screen and writes three files per screen to a per-gate directory under the run state.

For each `figma_ref` (extracted from the matching UI task's plan entry):

```
1. mcp__figma__get_metadata { fileKey, nodeId }
   → response is XML text
   → write the response body to <gate-dir>/<n>.meta.xml using the Write tool

2. mcp__figma__get_design_context { fileKey, nodeId, excludeScreenshot: true }
   → response is React+Tailwind code text (with trailing prose that's harmless to keep)
   → write the response body to <gate-dir>/<n>.ctx.code using the Write tool

3. mcp__figma__get_screenshot { fileKey, nodeId }
   → response is JSON { image_url, width, height, format } — NOT the PNG itself
   → run Bash:  curl -s -o <gate-dir>/<n>.figma.png "<image_url>"
   → the URL is short-lived; download immediately, do not cache
```

Where `<gate-dir>` is `~/.claude/ai-crew/runs/<run-id>/gates/<gate-id>/` and `<n>` is the member-screen index (1-based) or a slug derived from `nav_hint`.

**Important:** the screenshot path is a two-step MCP-then-Bash dance. The MCP call returns a URL; the team-lead must `curl` that URL into the file. Skipping the curl leaves no PNG on disk and the subagent will `FAIL` reading it. After all three writes, verify with `ls -la <gate-dir>` that exactly three files per screen exist with non-zero size before dispatching the gate.

If any Figma fetch fails, do not dispatch the gate — surface the fetch error to the user. The simulator-engineer cannot recover from a missing artifact (it has no `mcp__figma`); a missing file is a dispatch bug.

**Why pre-flight, not in-subagent fetch:** the team-lead has Figma MCP reliably (it's the main session). Subagents do not. Pre-fetching once on the team-lead side is cheaper, more robust to MCP propagation gaps, and produces inspectable on-disk artifacts the user can review.

### Dispatch template

The dispatch prompt is ≤30 lines, cites line ranges from the Task Index and Section Index, and references the pre-fetched Figma files by absolute path. Every dispatch MUST include a `Plan task` range and at least one `Spec refs` range.

```
Task: T-007-fidelity — Design fidelity gate for Settings epic

Plan task:   ~/.claude/ai-crew/runs/2026-04-14-push-notif/plan.md  lines 312-348
             (read with: sed -n '312,348p' ~/.claude/ai-crew/runs/2026-04-14-push-notif/plan.md)
Spec refs:   ~/.claude/ai-crew/runs/2026-04-14-push-notif/spec.md  lines 22-41, 67-78

Skills to read first:
  - <plugin>/skills/simulator-design-fidelity/SKILL.md
  - argent-simulator-setup
  - argent-react-native-app-workflow
  - argent-test-ui-flow

Simulator:   first booted iPhone
Viewport-pt: 393x852    (look up from list-simulators if uncertain)
App:         { "bundleId": "com.example.MyApp" }

Member screens (one per UI task in this epic):
  - nav_hint: "settings → notifications"
    figma_files:
      meta:       ~/.claude/ai-crew/runs/2026-04-14-push-notif/gates/T-007/1.meta.xml
      ctx:        ~/.claude/ai-crew/runs/2026-04-14-push-notif/gates/T-007/1.ctx.code
      screenshot: ~/.claude/ai-crew/runs/2026-04-14-push-notif/gates/T-007/1.figma.png
  - nav_hint: "profile → edit"
    figma_files:
      meta:       ~/.claude/ai-crew/runs/2026-04-14-push-notif/gates/T-007/2.meta.xml
      ctx:        ~/.claude/ai-crew/runs/2026-04-14-push-notif/gates/T-007/2.ctx.code
      screenshot: ~/.claude/ai-crew/runs/2026-04-14-push-notif/gates/T-007/2.figma.png

Return: RESULT: MATCH | DELTA | FAIL with structured deltas per member screen.
```

The subagent reads the three files via the `Read` tool — no Figma MCP call required. The team-lead retains the original `figma_ref` (URL or `fileKey/nodeId`) in `progress.md` for traceability.

### Action policy — fix every confirmed discrepancy

After the gate returns, the team-lead reads the structured block inline and routes by the judge's confidence, not by severity. The judge's classification is binary at delta time:

- **Confident** — the delta is tagged `[high]`, `[medium]`, or `[low]`. Severity describes magnitude; all three signal "this is a real implementation discrepancy." Auto-fix.
- **Uncertain** — the delta is tagged `[ambiguous]`. The judge cannot decide whether the difference is a bug or an intentional designer/product change. Surface to a human; do not auto-fix.

| Result | Action | DAG effect |
|---|---|---|
| `MATCH` | Annotate `progress.md`. Continue. | None |
| `DELTA` with at least one confident item (`high`/`medium`/`low`) | Dispatch a focused-fix developer task carrying every confident delta. Re-dispatch the `simulator-engineer` to verify the fix. Repeat until convergence. | One cycle per pass, counts against the **gate's own loop budget** (see below). |
| `DELTA` with only ambiguous items | Annotate `progress.md` and **append a "Fidelity findings" section to the PR body** with each ambiguous delta's node id, evidence, and the judge's reasoning. No fix dispatch. | None |
| `DELTA` mixed (confident + ambiguous) | Auto-fix the confident batch as above. The ambiguous items always go into the PR's "Fidelity findings" section, even after the gate converges to MATCH on the confident set. | One cycle, counts as above. |
| `FAIL` (simulator unbootable, app crashed, navigation lost) | Surface to user; one infrastructure retry max before escalating. | Counts against the gate's budget. |

The principle: if the judge confirmed a discrepancy, fix it — small bugs are still bugs. Severity exists only to help the fix-developer prioritize within a batch and to summarize the gate's findings in the PR description.

## Phases 7–8 amendment — convergence-based gate budget

Verify and Review keep their existing **3 shared fix loops**. The fidelity gate is **independent** from that budget — gate-driven fix dispatches do not consume Verify/Review's loops, and Verify/Review failures do not eat into the gate's capacity.

The gate's own budget is **convergence-based, not count-based**:

```
loop:
  N      = count of confident deltas in latest gate run
  if N == 0:                       MATCH — done
  dispatch fix-developer with the confident batch
  re-run simulator-engineer
  N'     = count of confident deltas in the new run
  if N' == 0:                      MATCH — done
  if N' >= N:                      not converging — escalate to user
  cycle_count += 1
  if cycle_count >= 10:            runaway brake — escalate to user
  goto loop
```

Why this shape:
- **No arbitrary count cap on quality.** The gate keeps fixing as long as each pass reduces confident deltas. A 7-bug screen converges in 1–2 cycles when the developer can see all the bugs at once.
- **Regression detection built in.** If a fix attempt makes things worse or stays flat, that's the signal that the developer can't fix it (missing asset, framework limitation, design ambiguity not caught at judge time). Escalate immediately.
- **Hard ceiling at 10 is a runaway brake, not a target.** A real run converges in ≤3 cycles. Hitting 10 means something is fundamentally broken; the user must see it.
- **Independent from Verify/Review.** A flaky test burning Verify's loops doesn't starve the gate, and the gate dispatching fixes doesn't keep Verify from converging on a real regression.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll add a fidelity gate even though the project is a backend service." | This skill is not loaded on backend services. If you find yourself reading it, the project is RN. If you're reasoning about backend work, exit this skill and rely on `team-lead` alone. |
| "Fidelity gates should fail the run on any delta." | Gates do not block the lifecycle. Confident deltas (`high`/`medium`/`low`) trigger a focused-fix developer dispatch and a re-run; ambiguous deltas surface to the PR for human review. The gate produces evidence and converges; the team-lead orchestrates. |
| "Low-severity deltas aren't worth fixing — annotate and move on." | If the judge tagged it with a severity, the judge is *confident* it's a real discrepancy. Severity is magnitude, not certainty. A 4px shadow mismatch is still a token mismatch — fix it. Use `[ambiguous]` when the judge actually can't decide; that's the only tag that bypasses auto-fix. |
| "I'll dispatch a fidelity gate per UI task to catch regressions sooner." | One gate per contiguous UI epic. Per-task gates serialize the simulator and shred parallelism within the epic for marginal benefit — RNTL already covers per-task structural correctness. |
| "I'll let two `simulator-engineer`s run in parallel — they're cheap subagents." | The simulator is a singleton. The DAG never schedules two `simulator-engineer` dispatches concurrently because the team-lead never spawns two at once. If a future plan accidentally asks for it, the second dispatch must `FAIL` rather than race. |
| "The fidelity gate's fix loops should share Verify and Review's budget." | They are independent. Verify+Review keep their 3 shared loops; the gate has its own convergence-based budget. A flaky test burning Verify's budget does not starve the gate, and the gate's auto-fix loops do not block Verify from converging. |
| "I'll keep looping the gate as long as it finds anything." | Loop only while confident-delta count is *decreasing*. Same-or-worse counts mean the developer can't fix the underlying issue (missing asset, framework limitation) — escalate. Hard cap at 10 is a runaway brake, never expected to hit. |

## Red Flags

Stop and reconsider if you notice any of these — they are the moves this skill is designed to prevent:

- About to spawn two `simulator-engineer` dispatches in the same wave.
- About to emit a fidelity gate for a plan with no UI tasks (no `frontend-ui-engineering` or `mobile-component-testing-with-rntl` skill tags).
- About to treat a fidelity-gate `DELTA` as a hard fail.
- About to skip auto-fix on a `[low]`-severity confident delta because "it's not worth fixing." All confident deltas get fixed; only `[ambiguous]` items bypass auto-fix.
- About to charge gate-driven fix loops against Verify/Review's 3-loop budget (or vice versa). Those budgets are independent.
- About to keep looping the gate after a pass that did not reduce the confident-delta count. That's the escalation signal.
- About to add a fidelity-gate entry to `plan.md` after Phase 5 (the plan is frozen at the checkpoint, gates included).
- About to embed raw component-tree dumps or screenshot bytes from a `simulator-engineer` reply into team-lead context — read the structured `RESULT` block only; the full evidence already lives in Argent's auto-screenshot dir.

## Verification

Before declaring an RN run complete, in addition to the base team-lead verification:

- [ ] If the plan had at least one UI task (`frontend-ui-engineering` or `mobile-component-testing-with-rntl` skill tag), exactly one fidelity gate was emitted per contiguous UI epic; gates were dispatched sequentially, never two in the same wave.
- [ ] Every `simulator-engineer` dispatch cited `Plan task` + `Spec refs` line ranges from the Task Index / Section Index — no whole-file pointers.
- [ ] Every confident delta (`high`/`medium`/`low`) the gate reported was either fixed (gate converged to MATCH on the confident set) or surfaced to the user via escalation. No confident delta was silently dropped.
- [ ] Every ambiguous delta the gate reported was annotated in `progress.md` and appended to the PR's "Fidelity findings" section for human review.
- [ ] Gate-driven fix loops were counted against the gate's own convergence budget, NOT against Verify/Review's 3-loop budget. The two budgets stayed independent.
- [ ] The gate did not loop past a pass that failed to reduce the confident-delta count; non-converging passes escalated to the user.
- [ ] No `MATCH` was claimed for a gate where one or more member screens returned a navigation `FAIL`. Partial coverage is not coverage.
- [ ] No raw component trees, raw Figma JSON, or screenshot bytes were inlined into `progress.md` — only the structured `RESULT` block and any classified deltas.
