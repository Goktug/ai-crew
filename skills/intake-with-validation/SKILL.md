---
name: intake-with-validation
description: Runs structured one-question-at-a-time intake on every ai-crew run, even when the request seems clear. Use at the start of every team-lead lifecycle to surface assumptions and capture scope, success criteria, and constraints directly in spec.md.
---

# Intake with Validation

## Overview

Run structured Q&A one question at a time, even when the request seems crystal clear. The most expensive bugs in a team-lead run come from assumptions the team-lead filled in silently during intake. This skill captures scope, success criteria, hard constraints, and non-goals directly in `spec.md` — no separate intake artifact, no batched questions, no skipping steps because "the user obviously meant X."

## When to Use

- The team-lead is starting Phase 1 (Intake) of a new run.
- The user invoked `/team-lead` with any new request — clear, vague, big, or small.
- A new requirement appeared mid-run that wasn't covered in the original `spec.md`.

**When NOT to use:**
- A pure code-review or read-only investigation that won't write code or open a PR.
- Continuation of an in-progress run where intake has already happened.

## Process

### Step 1 — Surface assumptions before asking anything

Before the first question, write down what you're assuming. List them explicitly:

```
ASSUMPTIONS I'M MAKING:
1. [assumption about platform]
2. [assumption about tech stack]
3. [assumption about scope]
4. [assumption about constraints]
→ I'll ask about anything I'm unsure of one question at a time.
```

This forces honesty about what you don't actually know.

### Step 2 — One question at a time

Ask ONE question. Wait for the answer. Then ask the next. **Never batch questions.** Batching surfaces fewer disagreements and signals that you don't really care about the answers.

Use the canned coverage areas below. Skip a question only if the user has already answered it explicitly in their request — and even then, paraphrase your understanding back as a confirmation question.

### Step 3 — Canned question set (coverage areas)

Cover these four areas in order. Each may be one or several questions depending on the answers:

1. **Scope boundaries** — What's in scope? What's explicitly out of scope? Which subsystems / files / surfaces will you touch, and which will you NOT touch?
2. **Success criteria** — How will we know this is done? What is the smallest verifiable thing that proves it works? What does the user need to see/click/run?
3. **Hard constraints** — Deadlines, dependencies you cannot introduce, dependencies you cannot remove, performance budgets, compliance requirements, design system you must follow.
4. **Non-goals** — What this is explicitly NOT trying to do. Common non-goals: refactoring adjacent code, adding feature flags, writing migration scripts, supporting a new platform.

### Step 4 — Write findings directly into `spec.md`

As answers come in, append them under structured headings in `spec.md`:

```
## Scope
- In: ...
- Out: ...

## Success Criteria
- ...

## Hard Constraints
- ...

## Non-Goals
- ...
```

There is **no `intake.md`**. The run-state directory holds exactly three files: `spec.md`, `plan.md`, `progress.md`.

### Step 5 — Hand off to spec-driven-development

When the four coverage areas are answered, hand off to the `spec-driven-development` skill. The team-lead reads that skill inline to finalize the rest of `spec.md` (objective, project structure, code style, testing strategy, boundaries).

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "The request is clear — I can skip intake." | This is the #1 source of wasted work. Intake is one question at a time *especially* when the request seems clear. |
| "I'll batch all the questions into one message to save time." | Batching kills accuracy. Users skim batches; one question at a time gets honest answers. |
| "I'll write an intake.md to track the answers." | No. The run directory has exactly three files. Findings go in `spec.md`. |
| "The user already gave me a doc — no need for questions." | Read the doc, then still ask the four coverage questions. Docs go stale; assumptions multiply. |

## Red Flags

- About to send a message with more than one question.
- About to skip intake because "the request is clear."
- About to create `intake.md` or any 4th file in the run directory.
- About to start spec without surfacing assumptions.
- About to start the Plan phase without a `## Non-Goals` section in `spec.md`.

## Verification

Before advancing to Phase 2 (Research) or Phase 3 (Spec):

- [ ] `spec.md` exists in the run directory
- [ ] `spec.md` contains all four sections: Scope, Success Criteria, Hard Constraints, Non-Goals
- [ ] At least one assumption was surfaced and either confirmed or corrected by the user
- [ ] No `intake.md` exists in the run directory
- [ ] The team-lead is ready to read `spec-driven-development/SKILL.md` for the rest of the spec
