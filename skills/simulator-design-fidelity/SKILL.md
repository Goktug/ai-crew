---
name: simulator-design-fidelity
description: Compares a running iOS app against its Figma design by capturing the runtime component tree via Argent MCP and diffing it against the Figma node. Use when an ai-crew fidelity gate runs after a contiguous group of UI build tasks (those tagged with `frontend-ui-engineering` or `mobile-component-testing-with-rntl`). Emits a structured delta report; the team-lead judges materiality.
---

# Simulator Design Fidelity

## Overview

Drive a real iOS simulator with Argent, capture what the app actually rendered, fetch the Figma design that was supposed to be rendered, and emit a structured diff between the two. The diff is the deliverable — not a pass/fail. The Opus team-lead reads the diff and decides whether to insert a fix task or accept the deviation.

This skill specializes the broader Argent skill set (`argent-simulator-interact`, `argent-test-ui-flow`, `argent-react-native-app-workflow`) for one narrow purpose: structural design-fidelity verification at the end of a UI epic. It does not replicate those skills — it composes them. Defer to them for low-level simulator operation; focus this skill on the diff layer.

## When to Use

- The Build phase of an ai-crew run has just finished a contiguous group of UI tasks (skill tags include `frontend-ui-engineering` or `mobile-component-testing-with-rntl`), and the team-lead is about to dispatch the matching fidelity gate.
- The `simulator-engineer` subagent has been dispatched a fidelity-gate task whose `Skills to read first` list includes this file.
- The project type from `detect-project-type.sh` is `react-native` (the gate is RN-only in v1).

**When NOT to use:**
- Per-task verification during Build — fidelity gates are per-epic, not per-task. Use RNTL (`mobile-component-testing-with-rntl`) for per-task verification.
- End-to-end behavioral journeys (login, checkout, multi-screen flows) — that's a future skill (deferred to v2). This skill is structural only.
- Performance profiling, crash repro, or log inspection — those are user-invoked, not part of the lifecycle. They live in `argent-react-native-profiler`, `argent-metro-debugger`, etc.
- Web or backend projects — there is no simulator to drive.

## Process

The fidelity gate is a single DAG node. The agent runs all member-screen comparisons inside one simulator session: boot once, navigate many, teardown once.

### 1. Pre-flight

- Read `<plugin>/skills/using-agent-skills/SKILL.md`.
- Read the cited `plan.md` task range. Confirm the gate ID matches the prompt's `Task:` line.
- Read the cited `spec.md` ranges to understand the user-facing intent of each member screen — diff materiality is judged against intent, not pixel-equivalence.
- List the `(figma_ref, nav_hint)` pairs from the prompt's `Figma refs` and `Nav hint` sections. There is one pair per member task.

### 2. Simulator Setup

Defer to `argent-simulator-setup`:

```
list-simulators           → pick first booted iPhone, or `boot-simulator` if none
launch-app { bundleId }   → cold-start the app
```

Never tap home-screen icons. Capture the simulator UDID once and reuse it for every Argent call in the gate.

### 3. Per-Screen Loop

For each `(figma_ref, nav_hint)` pair:

#### 3a. Navigate

Use `argent-test-ui-flow` patterns. Argent's autonomous discovery does the heavy lifting; your `nav_hint` is a guide, not a script:

```
describe                                  → find current screen and tap targets
gesture-tap / gesture-swipe / paste       → walk toward target, ≤2 retries per missed tap
debugger-component-tree (when on target)  → confirm arrival
```

After two consecutive failed taps at the same coordinates, abort this screen with a navigation `FAIL` and continue with the rest of the epic — do not blow the entire gate over one unreachable screen.

#### 3b. Capture

Preferred for React Native:

```
mcp__argent__debugger-component-tree → React component tree with names, visible text, testIDs
```

Fallback when the debugger tree is unavailable (release builds, native screens):

```
mcp__argent__describe → accessibility tree with role, label, frame coordinates
```

The capture is the *app side* of the diff. Save the latest screenshot path from Argent's auto-screenshot for `NOTES`.

#### 3c. Fetch the Figma Design

```
mcp__figma__get_design_context { fileKey, nodeId } → component tree + tokens + code reference
```

The response is the *design side* of the diff. If it is structurally loose, call `mcp__figma__get_screenshot` for a visual tiebreaker — but the diff itself is structural, not pixel-based.

#### 3d. Diff Along Four Axes Only

| Axis | What you compare | What counts as a delta |
|---|---|---|
| **Identity** | RN component name vs. Figma layer name | No case- or hyphen-insensitive substring match exists. Report axis `name`. |
| **Copy** | Visible text in tree vs. Figma text layer | Any verbatim string difference, including capitalization and trailing whitespace. Report axis `copy`. |
| **Presence** | Nodes in tree vs. nodes in Figma | App has a node Figma doesn't (`extra-node`) or vice versa (`missing-node`). |
| **Order** | Sibling sequence of identifiable nodes | The same set of nodes is present in both, but in a different order. Report axis `order`. |

Do **not** diff bounds, colors, spacing, or typography in v1. Tolerance for those axes is uncalibrated; emitting them generates noise that erodes the gate's signal-to-noise ratio.

### 4. Classify Materiality

For each delta candidate, decide whether it goes into the report:

- **Always include**: missing-node, extra-node, copy difference (including punctuation), order difference, ambiguous identity mapping.
- **Drop**: differences in elements explicitly marked as variant or experimental in the Figma layer name (e.g. layers prefixed `[exp]` or `[variant]`).
- **Drop**: differences inside layers the spec already documents as intentional deviations from the design.

If you drop a delta because of an intentional deviation, do not mention it in the output — the team-lead does not need a "drops" log.

### 5. Emit the Structured Block

Use the output format defined in `<plugin>/agents/simulator-engineer.md`. Hard rules:

- Max 25 deltas per gate. Truncate with `... and N more`.
- Each delta is a single line: `<axis>: <path-or-name> — figma="<value>" app="<value>"`.
- No raw tree dumps, no inline JSON, no screenshot bytes.
- One block per member screen; the overall `RESULT` is the worst of the per-screen results.

## Patterns

### Pattern 1 — Clean comparison

```
SCREEN: Settings → Notifications
FIGMA: ABC123/45:678

DELTAS:
- copy: "Push Notifications" — figma="Push notifications" app="Push Notifications"
- missing-node: "DescriptionLabel" under "NotificationSection" — figma="Receive alerts" app=(absent)
```

The team-lead can pinpoint exactly what to fix without re-running the gate.

### Pattern 2 — Ambiguous Figma mapping

```
SCREEN: Profile → Edit
FIGMA: ABC123/99:101

DELTAS:
- ambiguous: "PrimaryAction" — figma="ContinueButton" app="PrimaryButton (no name match found in Figma layer 99:101)"
```

Surface the ambiguity. The team-lead may decide the Figma layer was simply renamed, or that the developer chose a generic name when a specific one existed.

### Pattern 3 — Member-screen failure inside a multi-screen gate

```
RESULT: FAIL

SCREEN: Onboarding → Welcome
FIGMA: ABC123/12:34
DELTAS:
- (none — match)

SCREEN: Onboarding → Permissions
FIGMA: ABC123/13:35
DELTAS:
- (none captured — navigation lost after 2 failed taps on "Continue" button)

NOTES:
permissions screen unreachable from welcome; manual investigation needed
```

The first screen is fine; the second is unreachable. Overall verdict is `FAIL` because at least one screen could not be diffed. Do not mark the first screen `MATCH` and the gate `MATCH` — the gate is one node, and partial coverage is not full coverage.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll dump the full component tree and the full Figma JSON so the team-lead can diff them." | No. You do the diff. The team-lead reads classified deltas. Raw dumps blow up the orchestrator's context. |
| "The bounds are off by 4px — that's a delta." | v1 does not diff bounds. Tolerance is uncalibrated and 4px is well within rounding. Suppress. |
| "The screen renders the same content but the structure is slightly different." | If the difference is observable (sibling order, missing/extra nodes, copy difference), it's a delta. Don't suppress structural deltas because "the user wouldn't notice." Materiality is the team-lead's call, not yours. |
| "I'll do a quick login journey while I'm here." | Out of scope. Fidelity gates are structural only. Journeys are deferred to v2. |
| "I'll use a screenshot diff because the component tree was empty." | If the tree is empty after one retry, emit `FAIL` for that screen. Screenshot diffs are not the v1 path — they have no calibrated tolerance. |
| "Bounds, colors, and typography are easy to diff and obviously valuable — I'll add them." | Easy != calibrated. Adding axes without tolerance rules makes the gate noisy and erodes trust. Defer to v2. |

## Red Flags

- About to dump a full component tree or full Figma JSON in the response.
- About to use `screenshot` as the primary discovery tool when `describe` or `debugger-component-tree` is available.
- About to navigate by tapping a home-screen icon instead of using `launch-app`.
- About to start a second fidelity gate against the same simulator while the first is still running.
- About to write or edit project files. (You don't have `Write`/`Edit` — but you do have `Bash`. Don't shell-out to `sed` or `cat >` either.)
- About to diff bounds, colors, or typography in v1.
- About to mark a gate `MATCH` when one of its member screens failed navigation.
- About to recurse into the next gate after the current one returns. The team-lead picks the next gate.
- About to read all of `spec.md` or `plan.md` instead of the cited slices.
- About to keep retrying a failed nav step beyond two attempts.

## Verification

Before reporting `RESULT`:

- [ ] Component tree captured (or `FAIL`-ed with a reason) for every member screen
- [ ] Figma node fetched for every `figma_ref`
- [ ] Diff limited to identity, copy, presence, order — no bounds, colors, typography
- [ ] Deltas classified, not raw-dumped; total ≤ 25 per gate (truncated otherwise)
- [ ] One block per member screen; overall `RESULT` is the worst per-screen verdict
- [ ] First token of the response is `RESULT:`
- [ ] Latest auto-screenshot path noted under `NOTES` if visual context might help the team-lead's judgment
- [ ] Simulator left in a usable state for the next gate (no hung modals, no foreground crash)
