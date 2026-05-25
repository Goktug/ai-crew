---
name: intake-with-validation
description: Runs structured one-question-at-a-time intake on every ai-crew run, even when the request seems clear. Each question carries a GUESS, confidence is tracked numerically, and an explicit "yes" on a restated intent is required before findings land in spec.md.
---

# Intake with Validation

## Overview

Run structured Q&A one question at a time, even when the request seems crystal clear. The most expensive bugs in a team-lead run come from assumptions the team-lead filled in silently during intake. This skill extracts what the user *actually* wants — not what they think they should want — and captures scope, success criteria, hard constraints, and non-goals directly in `spec.md`. No separate intake artifact, no batched questions, no skipping steps because "the user obviously meant X."

## When to Use

- The team-lead is starting Phase 1 (Intake) of a new run.
- The user invoked `/team-lead` with any new request — clear, vague, big, or small.
- A new requirement appeared mid-run that wasn't covered in the original `spec.md`.

**When NOT to use:**
- A pure code-review or read-only investigation that won't write code or open a PR.
- Continuation of an in-progress run where intake has already happened.

## The Process

### Step 1 — Hypothesize, with a confidence number

Before asking anything, write down your current best read of what the user actually wants in **one sentence**, plus an honest confidence number (0–100%). Below ~70%, append a `— missing: <what's still unresolved>` tail on the same line:

```
HYPOTHESIS: You want to reduce p99 latency on /pricing by caching responses.
CONFIDENCE: ~25% — missing: actual pain (latency vs. cost vs. rate limit), cache scope, invalidation triggers.
```

```
HYPOTHESIS: You want to jitter the midnight cron so it doesn't all fire at 00:00:00.
CONFIDENCE: ~90%
```

The number forces honesty. If you wrote a high number but can't predict the user's reactions to the next three questions you'd ask (see *The 95% confidence stop* below), the number is wrong. Start at the confidence level you can defend.

The `— missing:` tail tells the user exactly what intake needs to surface and prevents the number from being a vague signal.

### Step 2 — Ask one question at a time, each with a GUESS attached

Format:

```
Q:     <one focused question>
GUESS: <your hypothesis for the answer, with the reasoning that produced it>
```

Wait for the user to react before asking the next question. **Never batch.**

**Why one at a time:**
- The user can't react to your hypotheses if you bury them in a list.
- Batches encourage skim-reading and surface answers.
- The third question often depends on the answer to the first; asking them all at once locks in the wrong framing.
- The user's energy for thinking carefully is finite.

**Why attach a GUESS:**
- The user reacts faster to a wrong guess than they generate an answer from scratch.
- It commits you to a hypothesis you can be visibly wrong about, which keeps you honest.
- It surfaces *your* assumptions, which is the point of intake.

The risk is a polite user agreeing with your guess to be agreeable. Mitigate by being visibly willing to be wrong, and occasionally guessing in a direction you expect pushback on.

**Every question also follows `references/asking-clarifying-questions.md`.** The shared reference doc is the source of truth; the four rules, inlined here for convenience:

1. One question per message (no "and" joining two questions).
2. Multiple choice > open-ended when the answer space is bounded.
3. Non-trivial decisions → present 2–3 options with trade-offs, quantified when possible.
4. Lead with your recommended option and explain why.

The `GUESS:` line and the recommended option are compatible — the GUESS *is* your recommended option for open-ended questions; for multiple-choice questions, lead with the recommended option and put your reasoning in the GUESS.

### Step 3 — Cover the four required areas

Across your Q/GUESS rounds, cover these in order. Each may be one or several questions depending on the answers:

1. **Scope boundaries** — What's in scope? What's explicitly out of scope? Which subsystems / files / surfaces you'll touch, and which you won't.
2. **Success criteria** — How will we know this is done? The smallest verifiable thing that proves it works. What the user needs to see/click/run.
3. **Hard constraints** — Deadlines, dependencies you cannot introduce, dependencies you cannot remove, performance budgets, compliance, design system you must follow.
4. **Non-goals** — What this is explicitly NOT trying to do. Common non-goals: refactoring adjacent code, adding feature flags, writing migration scripts, supporting a new platform.

Skip an area only if the user explicitly answered it in the original request — and even then, paraphrase your understanding back as a confirmation Q/GUESS.

### Step 4 — Listen for "want vs. should-want"

The most dangerous answers are the ones where the user says what a thoughtful answer *sounds like* rather than what they actually want. Watch for:

- Best-practice talk without specifics ("scalable", "clean architecture", "robust", "modern").
- Convention deferral ("the way most apps do it", "the standard approach").
- "I should probably…", "I think I'm supposed to…", "good engineering practice says…".
- Buzzwords as goals — when the *answer* is "modern" or "robust" instead of a specific outcome.

When you hear these, the question to ask is:

> *"If you didn't have to justify this to anyone, what would you actually want?"*

That single question often does more work than the previous five.

### The 95% confidence stop

"95% confidence" isn't a vibe — it's operationalized as a checkable test. You're done interviewing when you can answer yes to:

> *Can I predict the user's reaction to the next three questions I would ask?*

If yes, stop and produce the restate (Step 5). If no, ask the next question.

Floor: if you've gone three or more rounds and still can't predict, something foundational is missing — stop and say so: *"I've asked X questions and I still can't predict your reactions. Want to step back?"*

### Step 5 — Restate intent and require an explicit yes

Once the 95% confidence stop fires (you can predict the next three reactions), write back what you now think the user wants. Keep it tight (5–8 lines), use the user's own language where possible, and structure it so they can confirm or correct line by line:

```
Here's what I now think you want:

- Outcome:      <one line>
- User:         <one line — who benefits>
- Why now:      <one line — what changed>
- Success:      <one line — how we know it worked>
- Constraint:   <one line — the binding limit>
- Out of scope: <one line — what we're explicitly not doing>

Yes / no / refine?
```

The `Out of scope` line is non-negotiable. Half of misalignment is silent disagreement about what is *not* being built.

The gate is an explicit **yes**. The following are **not** yes:

- *"Whatever you think is best."* → Delegation, which means the user doesn't have 95% confidence either. Re-ask with two concrete options framed as a choice.
- *"Sounds good."* → Ambiguous. Ask: *"Anything you'd refine?"* Silence isn't confirmation.
- *"Sure, let's go."* → Often a polite exit, not an endorsement. Same follow-up.
- Silence followed by "okay let's start." → The user has given up on the interview, not converged. Stop and ask whether you've missed something.

If they correct you, fold the correction in and restate. Loop until you get an explicit yes.

### Step 6 — Write findings into `spec.md`

Only after the explicit yes, append under structured headings in `spec.md`:

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

### Step 7 — Hand off to spec-driven-development

The team-lead reads `spec-driven-development/SKILL.md` inline to finalize the rest of `spec.md` (objective, project structure, code style, testing strategy, boundaries), framed against the confirmed intent from Step 5.

## Example

**Without `intake-with-validation`:**

```
User:  add caching to our /pricing endpoint
Agent: <starts proposing Redis vs. in-memory, TTL values, cache-aside layout>
```

The agent has assumed: what's actually slow or broken, what "caching" means here, the invalidation model, the constraint. Each assumption is a place the user can later say "that's not what I meant."

**With `intake-with-validation`:**

```
User: add caching to our /pricing endpoint

Agent:
HYPOTHESIS: You want to reduce p99 latency on /pricing by caching responses.
CONFIDENCE: ~25% — missing: actual pain (latency vs. cost vs. upstream rate limit), cache scope, invalidation triggers.

Q:     Is the trigger that /pricing is slow, expensive, or hitting an upstream rate limit?
GUESS: slow — that's the most common reason engineers reach for "add caching" without naming the metric.

User: It's the upstream rate limit. We get 429s from Stripe at midnight when every tenant reloads pricing.

Agent:
Updated read: not a caching problem — a midnight thundering-herd problem. Confidence: ~55% — still missing: whether the midnight reload is a job you control, and whether stale-while-revalidate is acceptable.

Q:     Is the midnight reload a cron you control (we can stagger it) or a client-side trigger you can't move?
GUESS: a cron you control — if it were client-side you'd have raised that as the harder constraint.

User: it's our cron — we just never bothered to jitter it.
```

Two rounds in, the agent has discovered the actual ask isn't "add caching." It's "jitter the cron." Different artifact, different scope, different work. Adding a cache without fixing the cron would have left the 429s in place at a higher infra cost.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "The request is clear — I can skip intake." | This is the #1 source of wasted work. Intake runs *especially* when the request seems clear. |
| "I'll batch all the questions into one message to save time." | Batching kills accuracy. Users skim batches; one question at a time gets honest answers. |
| "If I attach my guess, I'm leading them." | Leading is the point. Reacting is faster than generating from scratch. The risk is sycophancy, not leading; mitigate by being visibly willing to be wrong. |
| "I'll give several options instead of guessing." | Options work when the user knows what they want and is choosing between trade-offs. Pre-intake, they don't. Listing options widens the search; a GUESS narrows it. |
| "The user already gave me a doc — no need for questions." | Read the doc, then still run Steps 1–5. Docs go stale; assumptions multiply. |
| "We've talked enough, I get it." | Test it: can you predict the user's reactions to the next three questions? If not, you don't get it yet. |
| "The user said yes, we're done." | If the yes followed a vague restate or an open-ended "sounds good," the yes is hollow. Restate concretely and re-confirm. |
| "Whatever you think is best — so I'll just decide." | Delegation is not decision. Re-ask with two concrete options framed as a choice. |
| "I'll write an intake.md to track the answers." | No. The run directory has exactly three files. Findings go in `spec.md`, only after the explicit yes. |

## Red Flags

- More than one question in a single message.
- A question without a GUESS attached — that's surveying, not committing.
- A confidence number below ~70% with no reason attached on the same line.
- Three or more rounds without confidence visibly rising — you're asking the wrong questions; step back and reframe.
- Accepting *"whatever you think is best"* as a terminal answer.
- Skipping the `Out of scope` line in the restate.
- The user gives a sophistication-signaling answer ("scalable", "clean", "modern") and you accept it without running the *"what would you actually want if you didn't have to justify it?"* probe.
- Writing to `spec.md` before the user has explicitly confirmed the restate.
- About to create `intake.md` or any 4th file in the run directory.
- About to start the Plan phase without a `## Non-Goals` section in `spec.md`.

## Verification

Before advancing to Phase 2 (Research) or Phase 3 (Spec):

- [ ] An explicit hypothesis with a confidence number was stated in the first turn.
- [ ] Every confidence number below ~70% was accompanied by a one-line reason.
- [ ] Every question carried a GUESS in the `Q: / GUESS:` format.
- [ ] At least one "what would you actually want if you didn't have to justify it?" probe ran when the user gave a sophistication-signaling or convention-signaling answer (when applicable).
- [ ] At the stop point, the team-lead could predict reactions to the next three questions it would ask.
- [ ] A concrete restate (Outcome / User / Why now / Success / Constraint / Out of scope) was written back to the user.
- [ ] The user confirmed the restate with an explicit yes (not "whatever you think," not "sounds good," not silence).
- [ ] `spec.md` exists in the run directory and contains all four sections: Scope, Success Criteria, Hard Constraints, Non-Goals.
- [ ] No `intake.md` exists in the run directory.
- [ ] The team-lead is ready to read `spec-driven-development/SKILL.md` for the rest of the spec.
