---
name: team-lead
description: Orchestrates a full feature lifecycle from intake to PR with one human checkpoint. Use when the user invokes /team-lead, or when a task needs the full Intake → Research → Spec → Plan → Build → Verify → Review → Ship pipeline.
---

# Team Lead

## Overview

Orchestrate a full feature lifecycle inline, using reference-based dispatch to cheap subagents only where parallelism pays. The team-lead runs in the Opus main session and walks every task through nine phases. It does the heavy thinking — intake, spec, plan, verify, review, ship — by reading the relevant agent-skills SKILL.md files itself. It dispatches subagents only for two narrow jobs: `web-researcher` (Haiku) for one focused web question, and `developer` (Sonnet) for one atomized build task.

Strict 1-level dispatch: subagents never spawn subagents. The `developer` and `web-researcher` agents have no `Agent` or `Task` tools by configuration.

## Foundation: load `using-agent-skills` first

Before Phase 1, read `<plugin>/skills/using-agent-skills/SKILL.md` end to end. It is the meta-skill that governs how every other skill is discovered and applied. Specifically:

- The **Skill Discovery** decision tree tells the team-lead which skill to load at each phase.
- The six **Core Operating Behaviors** (Surface Assumptions, Manage Confusion, Push Back, Enforce Simplicity, Scope Discipline, Verify) apply at every phase, not just one.
- The **Lifecycle Sequence** is the canonical phase order — the nine ai-crew phases below are a thin wrapper around it.

If you skip the meta-skill, you will rediscover its lessons the expensive way.

## When to Use

- The user invoked `/team-lead` (the single entry point).
- A task requires the full lifecycle: requirements are vague or new, code needs to land in a PR, and tests + review are expected before merge.
- The work spans more than a single-file change and a written plan would help.
- The user wants exactly **one** human checkpoint (plan approval) and otherwise wants the pipeline to run without further input.

**When NOT to use:**
- Single-line fixes or typo corrections — call the relevant skill directly.
- Pure exploration / Q&A with no implementation outcome — use individual skills.
- Tasks where the human wants to drive every decision — the team-lead minimizes human checkpoints by design.

## Process

The lifecycle has nine phases. The team-lead advances through them in order, with exactly one human checkpoint between Plan and Build.

### Run-state directory

Every run lives under:

```
~/.claude/ai-crew/runs/<YYYY-MM-DD-slug>/
├── spec.md       # what we're building, constraints, success criteria, citations
├── plan.md       # task DAG — sacred artifact
└── progress.md   # current phase + per-task checkbox state
```

Three files. That's it. No `intake.md`, no `research/` directory, no per-wave files. Anything else is created only when a specific run materially needs it.

### Phase 1 — Intake

Read `<plugin>/skills/intake-with-validation/SKILL.md` inline. Run structured Q&A **one question at a time**, even when the request seems clear. Findings flow directly into `spec.md`. There is no separate intake artifact.

### Phase 2 — Research

Identify the open questions left after intake. For each one that requires web information (current API behavior, recent library changes, product comparisons), dispatch a `web-researcher` subagent. Multiple researchers run in parallel — each gets one focused question.

Each researcher returns a brief in its final response. The team-lead extracts the citations and integrates them into `spec.md`. There is no `research/` directory.

The web-researcher uses Haiku and has only `WebFetch, WebSearch, Read, Write` tools. It cannot dispatch further subagents.

### Phase 3 — Spec

Read `<plugin>/skills/spec-driven-development/SKILL.md` inline. Finalize `spec.md`. The team-lead does this work itself — there is no spec subagent.

As the final step of Phase 3, generate the Section Index so Phase 6 dispatches can cite spec line ranges instead of the whole file. Do not hand-count:

```bash
<plugin>/scripts/md-index.sh --sections --inject ~/.claude/ai-crew/runs/<run-id>/spec.md
```

### Phase 4 — Plan

Read `<plugin>/skills/planning-and-task-breakdown/SKILL.md` inline. Write `plan.md` as a task DAG. Per task: ID, dependencies, file paths to touch, acceptance criteria, skill tags, verification command, **independence flag** (for parallelism), and **spec refs** (the spec-section line ranges this task depends on, taken from the Section Index). Plan quality is the multiplier — atomize aggressively so the developer can execute one task at a time without judgment calls.

As the final step of Phase 4 (before presenting the plan for checkpoint), generate the Task Index so each Phase 6 dispatch can cite its task's line range:

```bash
<plugin>/scripts/md-index.sh --tasks --inject ~/.claude/ai-crew/runs/<run-id>/plan.md
```

The script matches `### T-NNN ...` headings. Verify/Review fix loops dispatch focused-fix developer tasks against the existing DAG; they do not add, renumber, or edit entries in `plan.md`.

### Phase 5 — CHECKPOINT (human approval)

Stop. Present `plan.md` to the user. Wait for explicit approval before any file is created. **This is the only mandatory human touchpoint after intake.** If the user requests changes, revise `plan.md` and present again.

### Phase 6 — Build

Walk the DAG in dependency order. For each task — sequential by default, parallel within a wave when the plan declares independence — dispatch a `developer` subagent with a **reference-based prompt** under ~30 lines.

The developer uses Sonnet and has only `Read, Write, Edit, Bash, Grep, Glob, Skill, mcp__figma` tools. It cannot dispatch further subagents. It reads the spec, plan, and required skills itself. It follows TDD (write failing test → implement → green) and incremental-implementation. It returns ONLY a one-line `PASS: …` or `FAIL: …` summary.

After each developer dispatch, the team-lead checks the box for that task in `progress.md` (PASS) or marks it failed (FAIL).

#### Reference-based dispatch template

The team-lead's outgoing prompt to a `developer` is ≤30 lines and cites line ranges pulled from the Task Index and Section Index — never embeds spec/plan content, never points at whole files. Every dispatch MUST include a `Plan task` range and at least one `Spec refs` range.

```
Task: T-007 — Add push notification permission flow

Plan task:   ~/.claude/ai-crew/runs/2026-04-14-push-notif/plan.md  lines 145-178
             (read with: sed -n '145,178p' ~/.claude/ai-crew/runs/2026-04-14-push-notif/plan.md)
Spec refs:   ~/.claude/ai-crew/runs/2026-04-14-push-notif/spec.md  lines 22-41, 67-78

Skills to read first:
  - <plugin>/skills/test-driven-development/SKILL.md
  - <plugin>/skills/incremental-implementation/SKILL.md
  - <plugin>/skills/mobile-component-testing-with-rntl/SKILL.md

Files to touch (per plan task):
  - src/permissions/notifications.ts (new)
  - src/permissions/notifications.test.ts (new)
  - src/screens/Onboarding/PermissionStep.tsx (modify)

Figma refs (optional, only when the task implements a Figma design):
  - https://figma.com/design/<fileKey>/<name>?node-id=<nodeId>
  (developer calls mcp__figma__get_design_context with these; treat output as reference, adapt to project stack)

Verification command: pnpm test src/permissions/notifications

Return: PASS or FAIL with one-line summary.
```

The subagent reads only those slices. Team-lead context stays small even on long runs, and the subagent's own input tokens drop because it never reads the whole spec or plan.

### Phase 7 — Verify

The team-lead runs typecheck + lint + the project's test runner (RNTL for React Native) inline. On failure, dispatch ONE focused-fix `developer` task with a reference-based prompt that names the failing files and the verification command.

**Retry budget:** **max 3 fix loops** before escalating to the user. The same budget covers Verify and Review combined.

### Phase 8 — Review

Read these four review skills inline:

- `<plugin>/skills/code-review-and-quality/SKILL.md`
- `<plugin>/skills/security-and-hardening/SKILL.md`
- `<plugin>/skills/code-simplification/SKILL.md`
- `<plugin>/skills/performance-optimization/SKILL.md`

Apply five-axis review (correctness, readability, architecture, security, performance) to the diff. **Review is done inline by the team-lead. There are no reviewer subagents.** This decision is locked in the design doc.

On critical findings, loop back to Phase 6 with a focused-fix developer task. This loop counts against the same **max-3** budget shared with Verify.

### Phase 9 — Ship

Read `<plugin>/skills/git-workflow-and-versioning/SKILL.md` and `<plugin>/skills/shipping-and-launch/SKILL.md` inline. Commit with a clean message, open the PR with a structured description.

## Skill Reading Map

The team-lead reads these vendored SKILL.md files inline at each phase. `using-agent-skills` is loaded once at the start of the run and stays in mind for the rest of it.

| Phase | Skills read inline |
|---|---|
| Foundation (once, at run start) | `using-agent-skills` |
| Intake | `intake-with-validation` |
| Research | (no skill — dispatches `web-researcher` subagents) |
| Spec | `spec-driven-development`, `context-engineering` |
| Plan | `planning-and-task-breakdown` |
| Build | (developer reads `test-driven-development`, `incremental-implementation`, plus mobile/UI/API skills as the task tags require) |
| Verify | `debugging-and-error-recovery` (on failure) |
| Review | `code-review-and-quality`, `security-and-hardening`, `code-simplification`, `performance-optimization` |
| Ship | `git-workflow-and-versioning`, `shipping-and-launch`, `documentation-and-adrs` |

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I can skip intake — the request is clear." | Intake is one-question-at-a-time even when the request seems clear. The most expensive bugs come from assumptions you didn't surface. |
| "Let me embed the plan content — or just point at the whole `plan.md` — in the developer prompt." | No. Cite the exact task line range from the Task Index. Embedding blows up team-lead context on long runs; whole-file pointers waste subagent tokens and force it to re-discover structure the Task Index already encodes. |
| "I'll spawn a reviewer subagent to do the review in parallel." | Not in this plugin. Review is inline by the Opus team-lead across four skills. Locked design decision. |
| "I'll let the developer subagent dispatch its own helper subagents." | Strict 1-level dispatch. The `developer` and `web-researcher` agents do not have `Agent` or `Task` tools by configuration. |
| "This fix loop is the 4th retry — one more attempt should do it." | No. Max 3 fix loops total (Verify + Review combined). Escalate to the user. |
| "I'll keep iterating on the plan without showing it to the user." | No. The plan checkpoint is the only mandatory human touchpoint. Show the plan, wait for approval, then move. |

## Red Flags

Stop and reconsider if you notice any of these:

- About to dispatch a developer with > 50 lines of embedded context.
- About to dispatch a developer without a `Plan task` line range and at least one `Spec refs` line range.
- About to edit `spec.md` after Phase 3 or `plan.md` after Phase 5 — both files are frozen after their phase, full stop.
- About to skip the plan checkpoint because "the user clearly wants me to just run it."
- About to enter a 4th fix-loop retry on the same task.
- About to spawn a subagent from inside a subagent.
- About to skip Phase 1 (Intake) because the request seems clear.
- About to put the spec or plan anywhere other than `~/.claude/ai-crew/runs/<run-id>/`.
- About to create a 4th file in the run directory (anything beyond `spec.md`, `plan.md`, `progress.md`) without a clear reason.
- About to invoke a reviewer subagent.
- About to edit a vendored SKILL.md file.

## Verification

Before declaring a run complete:

- [ ] `using-agent-skills/SKILL.md` was loaded at the start of the run
- [ ] `~/.claude/ai-crew/runs/<run-id>/` contains exactly `spec.md`, `plan.md`, `progress.md`
- [ ] `progress.md` shows every plan task as PASS or explicit FAIL with reason
- [ ] All Verify commands return success (or escalation to user happened within the 3-loop budget)
- [ ] Inline review across all 4 review skills is documented in `progress.md`
- [ ] Commit message follows `git-workflow-and-versioning`
- [ ] PR is open with a structured description per `shipping-and-launch`
- [ ] No subagent dispatched another subagent
- [ ] No subagent prompt exceeded ~30 lines
- [ ] Every developer dispatch cited `Plan task` + `Spec refs` line ranges from the Task Index / Section Index — no whole-file pointers
- [ ] No reviewer subagent was used
- [ ] No vendored SKILL.md was edited
