# Asking Clarifying Questions

The protocol for clarifying questions across ai-crew. Applies any time a skill, the team-lead, or a subagent needs information from the human and is about to send a question.

## When this protocol applies

- `skills/intake-with-validation/SKILL.md` — every question in Phase 1 intake
- `skills/idea-refine/SKILL.md` — divergent questions (the skill's own text describes "3–5 questions," but this protocol enforces one-per-message when invoked inside an ai-crew run)
- Any future skill or subagent that asks the user anything

## The four rules

### 1. One question per message

Never batch questions. Each message contains exactly one question that requires an answer.

- **Why.** Batched questions hide disagreements. Users skim batches and answer the easy ones; the hard ones get skipped or half-answered. One at a time forces honest, deliberate answers.
- **No exceptions.** Not "except when the questions are related." Not "except when the user seems to be in a hurry." Always one.

### 2. Multiple choice > open-ended

When the decision space is bounded, present it as labeled options (A/B/C) rather than asking the user to generate the answer from scratch.

- **Why.** Multiple choice is faster to answer, surfaces the full option space, and forces you to think through the alternatives before asking.
- **Open-ended is fine** when the answer space is genuinely unbounded ("What's the observable success criterion?").

### 3. Non-trivial decisions → 2–3 options with trade-offs

If the answer involves a genuine trade-off (performance vs. simplicity, flexibility vs. safety, speed vs. thoroughness), present the options explicitly and quantify the trade-offs where possible.

- **Why.** The user's best answer depends on seeing the alternatives. "What's your preference?" puts all the work on them. "A is faster but loses X, B keeps X but adds Y latency, C splits the difference" lets them engage with the real decision.
- **Quantify when possible.** "adds ~200ms latency" beats "might be slower."

### 4. Lead with your recommendation

When presenting 2–3 options, label one as your recommendation and explain the reasoning. Never present options neutrally — that is sycophancy dressed as choice.

- **Why.** Neutral presentation signals "I haven't thought about this." A recommendation signals "I have a view and I am inviting you to override it."
- **Still accept the override.** If the user picks a different option, implement that option without pushback. The recommendation is a starting point, not a demand.

## Good vs bad examples

### Example 1 — One at a time vs. batched

**Bad (batched):**

> I need to understand the scope. What's in scope, what's out of scope, what's the deadline, and who's the target user?

**Good (one at a time):**

> What's in scope for this change? List the files or surfaces you expect to touch.

*[wait for answer]*

> What's explicitly out of scope — the things you do NOT want me to touch?

*[wait for answer]*

> Is there a deadline or release constraint I should know about?

### Example 2 — Multiple choice with trade-offs and recommendation

**Bad (open-ended, no trade-offs):**

> How do you want to store the session state?

**Good (multiple choice + trade-offs + recommendation):**

> I need to pick a session store. Three options:
>
> **A. Redis (recommended)** — fast reads (~1 ms), survives app restarts, adds an infra dependency.
> **B. In-memory** — zero infra, but sessions die on deploy and can't scale horizontally.
> **C. Database** — no new infra, but writes hit the main DB (~5–15 ms each) and compete with user traffic.
>
> I recommend A because you already have Redis for the rate limiter, so it's free, and the ~1 ms read matters on the hot path. Override if you want something different.

## Enforcement checklist

Before sending any message that asks the user anything, verify:

- [ ] The message contains exactly one question the user needs to answer.
- [ ] If the answer is a choice between bounded options, the options are labeled A/B/C.
- [ ] If the answer involves a trade-off, the trade-off is explicit and quantified where possible.
- [ ] One option is labeled as the recommendation, with a one-line reason.

If any checkbox is unchecked, rewrite the message before sending.

## Red flags

- About to send a message with "and" joining two questions.
- About to present options without a recommendation because "the user should decide."
- About to use open-ended phrasing when a multiple-choice version exists.
- About to ask a question you already have the answer to from earlier in the conversation.
