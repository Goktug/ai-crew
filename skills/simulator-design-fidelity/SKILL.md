---
name: simulator-design-fidelity
description: Compares a running iOS app against its Figma design by capturing the runtime component tree and screenshot via Argent MCP, normalizing both the runtime and the Figma payloads into a symmetric shape, and judging the difference. Use when an ai-crew fidelity gate runs after a contiguous group of UI build tasks (those tagged with `frontend-ui-engineering` or `mobile-component-testing-with-rntl`). Emits a structured delta report with severity and node-id citations; the team-lead judges materiality.
---

# Simulator Design Fidelity

## Overview

Drive a real iOS simulator with Argent, capture what the app actually rendered, fetch the Figma design that was supposed to be rendered, normalize both sides into a symmetric structure, and judge the difference. The judgment is the deliverable — not a pass/fail. The Opus team-lead reads the deltas and decides whether to insert a fix task, accept the deviation, or flag it for human review.

This skill specializes the broader Argent skill set (`argent-simulator-interact`, `argent-test-ui-flow`, `argent-react-native-app-workflow`) for one narrow purpose: design-fidelity verification at the end of a UI epic. It does not replicate those skills — it composes them. Defer to them for low-level simulator operation; focus this skill on the normalization and judgment layer.

## When to Use

- The Build phase of an ai-crew run has just finished a contiguous group of UI tasks (skill tags include `frontend-ui-engineering` or `mobile-component-testing-with-rntl`), and the team-lead is about to dispatch the matching fidelity gate.
- The `simulator-engineer` subagent has been dispatched a fidelity-gate task whose `Skills to read first` list includes this file.
- The project type from `detect-project-type.sh` is `react-native`. The gate is RN-only — it relies on Argent's React debugger component tree, which has no equivalent for web or backend.

**When NOT to use:**
- Per-task verification during Build — fidelity gates are per-epic, not per-task. Use RNTL (`mobile-component-testing-with-rntl`) for per-task verification.
- End-to-end behavioral journeys (login, checkout, multi-screen flows) — out of scope. This skill compares single screens against their Figma source; it does not test flows.
- Performance profiling, crash repro, or log inspection — those are user-invoked, not part of the lifecycle. They live in `argent-react-native-profiler`, `argent-metro-debugger`, etc.
- Web or backend projects — there is no simulator to drive.

## Process

The fidelity gate is a single DAG node. The agent runs all member-screen comparisons inside one simulator session: boot once, navigate many, teardown once.

### 1. Pre-flight

- Read `<plugin>/skills/using-agent-skills/SKILL.md`.
- Read the cited `plan.md` task range. Confirm the gate ID matches the prompt's `Task:` line.
- Read the cited `spec.md` ranges to understand the user-facing intent of each member screen — judgment is grounded in intent, not pixel-equivalence.
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

#### 3b. Capture the App Side

```
mcp__argent__debugger-component-tree → React component tree (preferred)
mcp__argent__describe                → accessibility tree (fallback)
mcp__argent__screenshot              → rendered pixels (always)
```

Save the structural tree to disk as `app.tree.json`. Note the screenshot path Argent auto-saved. If the structural tree is empty after one 500ms retry, emit `FAIL` for this screen and continue with the rest of the epic.

#### 3c. Fetch the Figma Side

```
mcp__figma__get_metadata        → XML tree of node ids, names, parent-relative frames
mcp__figma__get_design_context  → React+Tailwind code with data-node-id back-references
mcp__figma__get_screenshot      → rendered design (always)
```

Save metadata and design context to disk as `figma.meta.xml` and `figma.ctx.code`. The metadata is the structural backbone; the design context provides text content and style tokens.

#### 3d. Normalize Both Sides

Run the projector to convert both raw payloads into the symmetric shape the judge consumes:

```bash
node <plugin>/scripts/fidelity/normalize.mjs argent  app.tree.json --viewport-pt <W>x<H>  > app.json
node <plugin>/scripts/fidelity/normalize.mjs figma   figma.meta.xml figma.ctx.code        > figma.json
```

`--viewport-pt` is the booted simulator's pt size; look it up via `list-simulators` runtime info or take it from the dispatch prompt. Without it the Argent describe path emits no frames.

Both files share `{ frame?, root: <Node> }` where each `<Node>` carries `{ id, name, text?, frame, fill?, stroke?, font?, children? }`. **`frame` is screen-absolute points on both sides** — that is the canonical comparison space. `name`, `fill`, `stroke`, and `font` are advisory metadata: the judge does not fire deltas on those alone, because designer/dev names diverge by convention and CSS-variable hex resolution drifts between rendering pipelines.

A viewport mismatch between the design's frame size and the simulator's `--viewport-pt` produces predictable shifts in absolute coordinates — those are not bugs and the judge factors them out by reading both top-level `frame` fields.

If the projector errors, emit `FAIL` with its stderr. Do not hand-roll a partial diff to compensate — the symmetry of the two normalized files is what makes the judgment tractable.

#### 3e. Judge the Difference

You — the simulator-engineer — are the judge. Read `app.json`, `figma.json`, `app.png`, `figma.png`, and the cited `Spec refs` lines side by side. Identify differences between the design and the implementation along these dimensions:

- **identity** — the app rendered a different element than the design specified, or rendered nothing where the design specified something
- **layout** — anchor, grouping, ordering, or positioning intent of the design is not preserved
- **style** — color, typography, spacing, corner radius, or other styling token applied incorrectly
- **copy** — visible text the design specifies (titles, labels, button copy) does not match
- **ambiguous** — the mapping between Figma node and app node is unclear and cannot be resolved confidently

When classifying:
- **Name differences alone are not identity deltas.** Designer "Card" vs dev "ReviewCard" is not a bug — the tree shapes still align. Identity fires only when the element itself is structurally missing or replaced.
- **Style judgments come from the screenshots, not hex equality.** `fill` and `font` in the projector output are advisory; CSS-variable resolution drifts between rendering pipelines, so visually identical tokens may report different hex values. **But when Figma specifies a non-system `font.family` for a node, visually confirm the app rendered that font** — a missing custom font that silently falls back to the system bold is one of the most common visible style bugs and is easy to overlook because the screenshot still "looks like text".
- **Layout judgments use `frame` (screen-absolute pt) on both sides**, but factor in any difference between the design's `frame` size and the simulator's pt viewport. Predictable shifts caused by running on a wider/taller device than the design intended are not bugs.

For every candidate difference, classify whether it represents a real implementation bug or a data-driven difference:

- A real implementation bug: the developer missed or misinterpreted the design.
- A data-driven difference: content varies because the app reads real data the mock doesn't have. The user's actual name vs. "John Doe". A list of 47 real reviews vs. 4 mock cards. A chart's bars sized by real metrics. Drop these from the report — the team-lead has no fix to dispatch. If transparency matters, mention them once under `NOTES`.

Severity guidance:

- `high` — a structural element from the design is missing, in the wrong place, or rendered with the wrong identity
- `medium` — a styling or copy difference that is plainly designer intent, not a data variation
- `low` — small visual differences that may or may not be material, surfaced for the team-lead's judgment

Cite a Figma `node_id` per delta. If you cannot cite one, the difference is unanchored — the team-lead has nothing to point a fix-developer at — and it should not be reported.

### 4. Emit the Structured Block

Use the output format defined in `<plugin>/agents/simulator-engineer.md`. Hard rules:

- Max 25 deltas per gate. If you would exceed it, keep the highest-severity entries and append `... and N more`.
- Each delta is a single line: `[<severity>] <kind> @ <node_id> "<short label>" — <evidence>`.
- No raw tree dumps, no inline JSON, no normalized payloads, no screenshot bytes.
- One block per member screen; the overall `RESULT` is the worst of the per-screen results.
- Drop any delta whose evidence reduces to "the data is different".

## Patterns

### Pattern 1 — Clean judgment

```
SCREEN: Settings → Notifications
FIGMA: ABC123/45:678

DELTAS:
- [high] identity @ 45:701 "DescriptionLabel" — design specifies a description under NotificationSection; app does not render one
- [medium] copy @ 45:692 "PushToggleTitle" — design="Push notifications" app="Push Notifications"
- [medium] style @ 45:710 "PrimaryButton.fill" — design token resolves to #0A84FF; app renders #1F8AFE
```

The team-lead can route each delta to a fix-developer with the node id as the anchor.

### Pattern 2 — Data-driven differences excluded

```
SCREEN: Profile
FIGMA: ABC123/99:101

DELTAS:
- [medium] style @ 99:120 "AvatarRing" — design token resolves to #10B981; app renders #34D399

NOTES:
profile.name and profile.handle differ between design and app — excluded as data-driven; user is signed in.
```

The judge saw both differences but only emitted the one that's actually a token-resolution bug. Data-driven differences are noted in `NOTES` for transparency without being reported as deltas.

### Pattern 3 — Ambiguous mapping

```
SCREEN: Profile → Edit
FIGMA: ABC123/99:200

DELTAS:
- [low] ambiguous @ 99:215 "PrimaryAction" — design has a node named "ContinueButton" with similar bounds; app rendered "PrimaryButton" — could be a rename or a missed migration
```

The judge cannot decide between rename and bug. The team-lead arbitrates.

### Pattern 4 — Member-screen failure inside a multi-screen gate

```
RESULT: FAIL

SCREEN: Onboarding → Welcome
FIGMA: ABC123/12:34
DELTAS: (none — match)

SCREEN: Onboarding → Permissions
FIGMA: ABC123/13:35
DELTAS: (none captured — navigation lost after 2 failed taps on "Continue" button)

NOTES:
permissions screen unreachable from welcome; manual investigation needed
```

The first screen matched; the second was unreachable. Overall verdict is `FAIL` because at least one screen could not be judged. Do not mark the gate `MATCH` — partial coverage is not full coverage.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll dump the full normalized JSON so the team-lead can judge it themselves." | No. You are the judge. The team-lead reads classified deltas with severity and node ids. Raw dumps blow up the orchestrator's context. |
| "The user's display name differs — that's a copy delta." | No, that's data. Real users have real names. Drop it from the report; mention it under `NOTES` if context matters. |
| "The reviews list shows 47 items vs. 4 in the mock — that's a layout delta." | No, that's data. The container exists where the design said it should; its contents are real data the mock could not anticipate. |
| "I noticed something looks off but I can't find a node id for it." | Then it doesn't get reported. Unanchored deltas cannot be routed to a fix-developer; they erode the team-lead's trust. Spend the time finding the id, or omit. |
| "I'll do a quick login journey while I'm here." | Out of scope. Fidelity gates compare single screens, not flows. |
| "The component tree was empty so I'll judge from the screenshot alone." | If the tree is empty after one retry, emit `FAIL` for that screen. Screenshot-only judgment loses node ids and the team-lead loses fix-routing anchors. |
| "I'll skip running normalize.mjs and judge from the raw outputs directly." | The projector is the symmetric layer. Without it the judge sees a Figma React string on one side and an Argent JSON on the other, which produces inconsistent reasoning. Run the projector. |
| "The screen renders fine but the structure is slightly off — probably fine." | If the design specifies a structural element and the app does not render it, that's a `high`-severity identity delta regardless of how it looks at first glance. Materiality is the team-lead's call. |

## Red Flags

Stop and reconsider if you notice any of these — they are the moves this skill is designed to prevent:

- About to dump a full component tree, full Figma JSON, or normalized JSON in the response.
- About to use `screenshot` as the primary discovery tool when `describe` or `debugger-component-tree` is available.
- About to navigate by tapping a home-screen icon instead of using `launch-app`.
- About to start a second fidelity gate against the same simulator while the first is still running.
- About to write or edit project files. (You don't have `Write`/`Edit` — but you do have `Bash`. Don't shell-out to `sed` or `cat >` either.)
- About to emit a delta without a Figma node id — find the id or omit the delta.
- About to flag a difference that is plainly real-data variation.
- About to skip the projector step and judge raw payloads directly.
- About to mark a gate `MATCH` when one of its member screens failed navigation.
- About to recurse into the next gate after the current one returns. The team-lead picks the next gate.
- About to read all of `spec.md` or `plan.md` instead of the cited slices.
- About to keep retrying a failed nav step beyond two attempts.

## Verification

Before reporting `RESULT`:

- [ ] Component tree, screenshot, Figma metadata, Figma design context, and Figma screenshot captured for every member screen — or `FAIL`-ed with a reason
- [ ] `normalize.mjs argent` and `normalize.mjs figma` ran successfully for every member screen
- [ ] Every emitted delta carries a `[<severity>]`, a `<kind>`, a Figma `node_id`, a short label, and an evidence clause
- [ ] Differences caused by real runtime data are excluded from the report (or noted under `NOTES` for transparency, not as deltas)
- [ ] Total deltas across the gate ≤ 25; truncation message present if higher
- [ ] One block per member screen; overall `RESULT` is the worst per-screen verdict
- [ ] First token of the response is `RESULT:`
- [ ] Latest auto-screenshot path noted under `NOTES` if visual context might help the team-lead's judgment
- [ ] Simulator left in a usable state for the next gate (no hung modals, no foreground crash)
