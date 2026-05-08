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
- **Inputs**: per-member-screen `(figma_ref, nav_hint)` pairs, taken from each member UI task's existing `figma_ref` field

Emission rules:

- **One gate per contiguous UI epic.** Do not emit one gate per task. Per-task gates serialize the simulator unnecessarily and shred parallelism within the epic; RNTL already covers per-task structural correctness.
- **Gates are mutually exclusive by construction.** Each is a single DAG node, the simulator is a singleton, and the team-lead never spawns two `simulator-engineer` dispatches concurrently. Serialization is structural, not enforced at runtime.
- **No UI tasks → emit nothing.** A plan with zero UI tasks proceeds to Phase 5 with no gates appended. Do not invent gates "to be safe."
- Gates land in `plan.md` **before** Phase 5. Once the user approves the plan at the checkpoint, the DAG (gates included) is frozen — Verify/Review fix loops never add or renumber entries, including gate entries.

## Phase 6 amendment — `simulator-engineer` dispatch

Fidelity-gate tasks dispatch `simulator-engineer` instead of `developer`. The `simulator-engineer` uses Sonnet and has only `Read, Bash, Grep, Glob, Skill, mcp__figma, mcp__argent` tools. It cannot dispatch further subagents. It is read-only on the codebase. It returns a structured `RESULT:` block per member screen, not a one-line PASS/FAIL summary.

### Dispatch template

The dispatch prompt is ≤30 lines, like a developer dispatch, and cites line ranges from the Task Index and Section Index — never embeds spec/plan content, never points at whole files. Every dispatch MUST include a `Plan task` range and at least one `Spec refs` range. The shape is the same as a developer dispatch but carries `Member screens` instead of `Files to touch`:

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

Simulator: first booted iPhone
App: { "bundleId": "com.example.MyApp" }

Member screens (one per UI task in this epic):
  - figma_ref: https://figma.com/design/<fileKey>/<name>?node-id=<nodeId>
    nav_hint: "settings → notifications"
  - figma_ref: https://figma.com/design/<fileKey>/<name>?node-id=<nodeId2>
    nav_hint: "profile → edit"

Return: RESULT: MATCH | DELTA | FAIL with structured deltas per member screen.
```

### Action policy — advisory, not blocking

After the gate returns, the team-lead reads the structured block inline and picks one of four actions. **Gates never auto-block the lifecycle.** The orchestrator decides; the gate produces evidence.

| Result | Action | DAG effect |
|---|---|---|
| `MATCH` | Annotate `progress.md`. Continue. | None |
| `DELTA` (material — missing component, wrong copy, structural mismatch) | Insert a focused-fix developer task with the deltas as context, then re-dispatch the `simulator-engineer` for re-verification. | One cycle, counts toward the **shared 3-loop budget** (see below). |
| `DELTA` (intentional deviation, designer changed mind, ambiguous mapping) | Annotate `progress.md` and flag in PR description for human review. Continue. | None |
| `FAIL` (simulator unbootable, app crashed, navigation lost) | Surface to user; do not auto-loop more than once on infrastructure failures. | Counts as one loop. |

## Phases 7–8 amendment — shared retry budget

The team-lead's base retry budget is **max 3 fix loops** for Verify + Review combined. On RN runs this skill extends that definition: gate-driven focused-fix dispatches share the same budget. The total across all three sources (Verify, Review, fidelity-gate fixes) must not exceed three before escalating to the user. There is no per-source quota.

Concretely: if Verify already burned two loops on a typecheck regression, a single material `DELTA` is the third and final loop; subsequent material deltas escalate.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll add a fidelity gate even though the project is a backend service." | This skill is not loaded on backend services. If you find yourself reading it, the project is RN. If you're reasoning about backend work, exit this skill and rely on `team-lead` alone. |
| "Fidelity gates should fail the run on any delta." | Gates are advisory. Material deltas trigger one focused-fix developer dispatch (counted against the shared 3-loop budget); ambiguous deltas annotate and continue. The gate produces evidence; the team-lead decides. |
| "I'll dispatch a fidelity gate per UI task to catch regressions sooner." | One gate per contiguous UI epic. Per-task gates serialize the simulator and shred parallelism within the epic for marginal benefit — RNTL already covers per-task structural correctness. |
| "I'll let two `simulator-engineer`s run in parallel — they're cheap subagents." | The simulator is a singleton. The DAG never schedules two `simulator-engineer` dispatches concurrently because the team-lead never spawns two at once. If a future plan accidentally asks for it, the second dispatch must `FAIL` rather than race. |
| "The fidelity-gate retries should have their own budget separate from Verify and Review." | They share. The 3-loop cap is total across Verify, Review, and gate-driven fixes. A run with no Verify/Review failures has up to three gate loops; a run that already burned two on Verify has only one left for gates. |

## Red Flags

Stop and reconsider if you notice any of these — they are the moves this skill is designed to prevent:

- About to spawn two `simulator-engineer` dispatches in the same wave.
- About to emit a fidelity gate for a plan with no UI tasks (no `frontend-ui-engineering` or `mobile-component-testing-with-rntl` skill tags).
- About to treat a fidelity-gate `DELTA` as a hard fail.
- About to keep looping past the shared 3-loop budget on gate-driven fixes.
- About to add a fidelity-gate entry to `plan.md` after Phase 5 (the plan is frozen at the checkpoint, gates included).
- About to embed raw component-tree dumps or screenshot bytes from a `simulator-engineer` reply into team-lead context — read the structured `RESULT` block only; the full evidence already lives in Argent's auto-screenshot dir.

## Verification

Before declaring an RN run complete, in addition to the base team-lead verification:

- [ ] If the plan had at least one UI task (`frontend-ui-engineering` or `mobile-component-testing-with-rntl` skill tag), exactly one fidelity gate was emitted per contiguous UI epic; gates were dispatched sequentially, never two in the same wave.
- [ ] Every `simulator-engineer` dispatch cited `Plan task` + `Spec refs` line ranges from the Task Index / Section Index — no whole-file pointers.
- [ ] Any gate-driven focused-fix developer dispatch was counted against the shared 3-loop budget alongside Verify and Review (total ≤ 3).
- [ ] No `MATCH` was claimed for a gate where one or more member screens returned a navigation `FAIL`. Partial coverage is not coverage.
- [ ] No raw component trees, raw Figma JSON, or screenshot bytes were inlined into `progress.md` — only the structured `RESULT` block and any classified deltas.
