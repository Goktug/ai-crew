---
name: team-lead
description: Orchestrates a full feature lifecycle from intake to PR with one human checkpoint. Use when the user invokes /team-lead, or when a task needs the full Intake → Research → Spec → Plan → Build → Verify → Review → Ship pipeline.
---

# Team Lead

## Overview

Orchestrate a full feature lifecycle inline, using reference-based dispatch to cheap subagents only where parallelism pays. The team-lead runs in the Opus main session and walks every task through nine phases. It does the heavy thinking — intake, spec, plan, verify, review, ship — by **invoking the relevant agent-skills via the Skill tool** at each phase. It dispatches subagents only for two narrow jobs: `web-researcher` (Haiku) for one focused web question, and `developer` (Sonnet) for one atomized build task.

Strict 1-level dispatch: subagents never spawn subagents. The `developer` and `web-researcher` agents have no `Agent` or `Task` tools by configuration.

**Skills are workflows, not reference docs.** The team-lead MUST invoke each sub-skill via the `Skill` tool — not read its SKILL.md with the `Read` tool. Reading a SKILL.md bypasses the skill-invocation ritual (announcement, checklist, running state) that turns a skill from a static doc into an enforced workflow. **Team-lead rule: never use the `Read` tool on any SKILL.md file — always use the `Skill` tool.** This applies at every phase.

**Every question to the human follows a shared protocol.** Any message in any phase that asks the human anything — intake Q&A, plan checkpoint revisions, verify/review escalations — follows `references/asking-clarifying-questions.md`: one question per message, multiple choice when bounded, non-trivial decisions surfaced as 2–3 options with trade-offs, lead with a recommendation. This protocol is a reference doc (not a skill), so the team-lead *reads* it with the `Read` tool when it needs a refresher — the "never Read on SKILL.md" rule does not apply to files under `references/`.

## Foundation: core operating behaviors

Six behaviors apply at every phase of this run:

1. **Surface assumptions.** Before any non-trivial implementation, list the assumptions you are making about requirements, architecture, and scope. Let the user correct them before you proceed.
2. **Manage confusion actively.** When you notice a conflict or an unclear requirement, STOP and ask. Never pick an interpretation and hope it is right.
3. **Push back when warranted.** If an approach has a clear problem, name it, quantify the downside where possible, and propose an alternative. Sycophancy is a failure mode.
4. **Enforce simplicity.** The boring, obvious solution beats clever abstractions. If 1000 lines would do in 100, you have failed.
5. **Maintain scope discipline.** Touch only what is in scope. No unsolicited refactors, no "while we are here" cleanup.
6. **Verify, don't assume.** No task is complete without evidence — passing tests, build output, runtime data.

**You are inside an `ai-crew:team-lead` run.** Do NOT invoke the `ai-crew:team-lead` skill again during this session — every further Skill tool call targets a different skill in the Skill Invocation Map below.

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

**Step 1a — Vagueness check.** Before any skill invocation, assess the incoming request:

- **Vague** — no clear beneficiary, no observable success criterion, or uses words like "improve," "rethink," "explore," "somehow"; request is under ~2 sentences of substance → first invoke `ai-crew:idea-refine` via the Skill tool to produce a concrete direction, **then** proceed to Step 1b.
- **Concrete** — clear beneficiary, observable success criterion, known files or surfaces in play → skip idea-refine and go straight to Step 1b.

When invoking `ai-crew:idea-refine` from inside team-lead, apply `references/asking-clarifying-questions.md` as a team-lead-level constraint: questions go one at a time, even though idea-refine's own text describes "3–5 sharpening questions." Merge idea-refine's *Recommended Direction*, *Key Assumptions*, and *Not Doing* output **directly into `spec.md`** under appropriate headings. **Do NOT let idea-refine write `docs/ideas/<name>.md`** — that is a 4th artifact file and breaks the run-directory contract (`spec.md`, `plan.md`, `progress.md`).

**Step 1b — Structured intake.** Invoke the `ai-crew:intake-with-validation` skill via the Skill tool. Run structured Q&A **one question at a time**, per `references/asking-clarifying-questions.md`, even when the request seems clear. Findings flow directly into `spec.md`. There is no separate intake artifact.

### Phase 2 — Research

Identify the open questions left after intake. For each one that requires web information (current API behavior, recent library changes, product comparisons), dispatch a `web-researcher` subagent. Multiple researchers run in parallel — each gets one focused question.

Each researcher returns a brief in its final response. The team-lead extracts the citations and integrates them into `spec.md`. There is no `research/` directory.

The web-researcher uses Haiku and has only `WebFetch, WebSearch, Read, Write` tools. It cannot dispatch further subagents.

### Phase 3 — Spec

Invoke the `ai-crew:spec-driven-development` skill via the Skill tool, then invoke `ai-crew:context-engineering` to load supporting context. Finalize `spec.md`. The team-lead does this work itself — there is no spec subagent.

### Phase 4 — Plan

Invoke the `ai-crew:planning-and-task-breakdown` skill via the Skill tool. Write `plan.md` as a task DAG. Per task: ID, dependencies, file paths to touch, acceptance criteria, skill tags, verification command, **independence flag** (for parallelism). Plan quality is the multiplier — atomize aggressively so the developer can execute one task at a time without judgment calls.

### Phase 5 — CHECKPOINT (human approval)

Stop. Present `plan.md` to the user. Wait for explicit approval before any file is created. **This is the only mandatory human touchpoint after intake.** If the user requests changes, revise `plan.md` and present again.

### Phase 6 — Build

Walk the DAG in dependency order. For each task — sequential by default, parallel within a wave when the plan declares independence — dispatch a `developer` subagent with a **reference-based prompt** under ~30 lines.

The developer uses Sonnet and has only `Read, Write, Edit, Bash, Grep, Glob, Skill` tools. It cannot dispatch further subagents. It reads the spec, plan, and required skills itself. It follows TDD (write failing test → implement → green) and incremental-implementation. It returns ONLY a one-line `PASS: …` or `FAIL: …` summary.

After each developer dispatch, the team-lead checks the box for that task in `progress.md` (PASS) or marks it failed (FAIL).

#### Reference-based dispatch template

The team-lead's outgoing prompt to a `developer` looks like this — never longer than ~30 lines, never embeds spec or plan content:

```
Task: T-007 — Add push notification permission flow

Plan:  ~/.claude/ai-crew/runs/2026-04-14-push-notif/plan.md  (find task T-007)
Spec:  ~/.claude/ai-crew/runs/2026-04-14-push-notif/spec.md

Skills to read first:
  - <plugin>/skills/test-driven-development/SKILL.md
  - <plugin>/skills/incremental-implementation/SKILL.md
  - <plugin>/skills/mobile-component-testing-with-rntl/SKILL.md

Files to touch (per plan):
  - src/permissions/notifications.ts (new)
  - src/permissions/notifications.test.ts (new)
  - src/screens/Onboarding/PermissionStep.tsx (modify)

Acceptance criteria: read T-007 in plan.md
Verification command: pnpm test src/permissions/notifications

Return: PASS or FAIL with one-line summary.
```

The team-lead's context stays small even on long runs because the subagent does the reading.

### Phase 7 — Verify

The team-lead runs typecheck + lint + the project's test runner (RNTL for React Native) itself. On failure, invoke `ai-crew:debugging-and-error-recovery` via the Skill tool to localize the root cause, then dispatch ONE focused-fix `developer` task with a reference-based prompt that names the failing files and the verification command.

**Retry budget:** **max 3 fix loops** before escalating to the user. The same budget covers Verify and Review combined.

### Phase 8 — Review

Invoke these four review skills via the Skill tool, in order:

1. `ai-crew:code-review-and-quality`
2. `ai-crew:security-and-hardening`
3. `ai-crew:code-simplification`
4. `ai-crew:performance-optimization`

Apply five-axis review (correctness, readability, architecture, security, performance) to the diff. **Review is done by the team-lead itself after invoking the four review skills — there are no reviewer subagents.**

On critical findings, loop back to Phase 6 with a focused-fix developer task. This loop counts against the same **max-3** budget shared with Verify.

### Phase 9 — Ship

Invoke `ai-crew:git-workflow-and-versioning`, `ai-crew:shipping-and-launch`, and `ai-crew:documentation-and-adrs` via the Skill tool. Commit with a clean message, open the PR with a structured description.

## Skill Invocation Map

The team-lead invokes these skills via the Skill tool at each phase. Every skill in the table below is called with `Skill({ skill: "ai-crew:<name>" })` — never via the Read tool.

| Phase | Skills invoked via Skill tool |
|---|---|
| Intake | `idea-refine` **(conditional — vague requests only)**, then `intake-with-validation` |
| Research | (no skill — dispatches `web-researcher` subagents) |
| Spec | `spec-driven-development`, `context-engineering` |
| Plan | `planning-and-task-breakdown` |
| Build | (developer subagent invokes `test-driven-development`, `incremental-implementation`, plus mobile/UI/API skills as the task tags require) |
| Verify | `debugging-and-error-recovery` (on failure) |
| Review | `code-review-and-quality`, `security-and-hardening`, `code-simplification`, `performance-optimization` |
| Ship | `git-workflow-and-versioning`, `shipping-and-launch`, `documentation-and-adrs` |

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I can skip intake — the request is clear." | Intake is one-question-at-a-time even when the request seems clear. The most expensive bugs come from assumptions you didn't surface. |
| "Let me embed the plan content in the developer prompt so the subagent doesn't have to read." | This blows up team-lead context on long runs. Use reference-based dispatch — give file paths, not content. |
| "I'll spawn a reviewer subagent to do the review in parallel." | No. Review is done by the team-lead itself after invoking the four review skills. |
| "I'll just `Read` the spec-driven-development SKILL.md quickly — same text ends up in context either way." | No. Reading a SKILL.md skips the skill-invocation ritual (announcement, TodoWrite checklist, running state) that turns the skill from a static doc into an enforced workflow. The session-level rule is "Never use the Read tool on skill files." Use the Skill tool. |
| "I'll let the developer subagent dispatch its own helper subagents." | Strict 1-level dispatch. The `developer` and `web-researcher` agents do not have `Agent` or `Task` tools by configuration. |
| "This fix loop is the 4th retry — one more attempt should do it." | No. Max 3 fix loops total (Verify + Review combined). Escalate to the user. |
| "I'll keep iterating on the plan without showing it to the user." | No. The plan checkpoint is the only mandatory human touchpoint. Show the plan, wait for approval, then move. |
| "I'll call `/spec` (the slash command) from inside team-lead to do Phase 3." | Slash commands are user-facing entry points expanded by the Claude Code REPL when a human types them. From inside a running skill, use the Skill tool directly: `Skill({ skill: "ai-crew:spec-driven-development" })`. The slash command is just a thin wrapper around that skill anyway. |

## Red Flags

Stop and reconsider if you notice any of these:

- About to open a SKILL.md with the `Read` tool instead of invoking it via the `Skill` tool.
- About to dispatch a developer with > 50 lines of embedded context.
- About to skip the plan checkpoint because "the user clearly wants me to just run it."
- About to enter a 4th fix-loop retry on the same task.
- About to spawn a subagent from inside a subagent.
- About to skip Phase 1 (Intake) because the request seems clear.
- About to skip the Phase 1 vagueness check and jump straight to `intake-with-validation` on a request that has no observable success criterion.
- About to let `idea-refine` write to `docs/ideas/<name>.md` when invoked from Phase 1 (output must be merged into `spec.md` instead).
- About to send a message with two questions joined by "and" instead of following `references/asking-clarifying-questions.md`.
- About to put the spec or plan anywhere other than `~/.claude/ai-crew/runs/<run-id>/`.
- About to create a 4th file in the run directory (anything beyond `spec.md`, `plan.md`, `progress.md`) without a clear reason.
- About to invoke a reviewer subagent.

## Verification

Before declaring a run complete:

- [ ] `ai-crew:team-lead` was invoked exactly once at the start of the run — not re-invoked at any later point
- [ ] Each phase's skill(s) were invoked via the Skill tool (not read with the Read tool)
- [ ] `~/.claude/ai-crew/runs/<run-id>/` contains exactly `spec.md`, `plan.md`, `progress.md`
- [ ] `progress.md` shows every plan task as PASS or explicit FAIL with reason
- [ ] All Verify commands return success (or escalation to user happened within the 3-loop budget)
- [ ] Review across all 4 review skills is documented in `progress.md` with the Skill tool invocation recorded per skill
- [ ] Commit message follows `git-workflow-and-versioning`
- [ ] PR is open with a structured description per `shipping-and-launch`
- [ ] No subagent dispatched another subagent
- [ ] No subagent prompt exceeded ~30 lines
- [ ] No reviewer subagent was used
- [ ] No SKILL.md was opened with the Read tool at any point
