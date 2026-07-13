# ai-crew

**A battle-tested, production-grade engineering orchestrator for Claude Code.**

**Describe the job. Approve the plan. Get the PR.**

ai-crew encodes the workflows, quality gates, and best practices senior engineers run on every change — intake, spec, plan, build, verify, review, ship — and packages them as a Claude Code orchestrator for TypeScript, Node, backend, and React Native. A Fable 5 team-lead reasons through every phase; scoped Sonnet and Opus developers handle implementation in sequence or in parallel; one human checkpoint sits between Plan and Build.

Built on top of [Addy Osmani's `agent-skills`](https://github.com/addyosmani/agent-skills) (vendored, MIT). See [§ Why this is different](#why-this-is-different) for what ai-crew adds on top.

---

## Backstory

> I love Superpowers and Addy Osmani's `agent-skills`, but I kept finding myself too much in the loop. All I wanted was to define the spec, approve the plan, and get a tested, working PR — not narrate the next step or remember which skill to invoke.
>
> So I started with the obvious AI-team setup: architect, business analyst, QA lead, researcher, designer, developer, each as its own subagent. Burned tokens. Quality barely changed. So I cut them.
>
> The unlock: main context stays lean. The orchestrator does analysis, spec, plan, and review inline. Only coding tasks and one-shot web research get delegated — the parts that benefit from a fresh, narrow context. Developers run in parallel when tasks are independent, in sequence when they're not.
>
> That's ai-crew's team-lead. One brain at the wheel, scoping every task and delegating only what needs a fresh, narrow context. Guided Q&A for spec, and one human checkpoint for plan approval.

---

## Demo

```
$ claude
> /team-lead Wire RevenueCat into our paywall, gate the premium tab, and track
              checkout events with our analytics SDK

ai-crew  [Intake — Q1 of 3]   one question at a time, A/B/C with tradeoffs
         How should the premium gate behave when a user without entitlement
         taps the tab?

         A. Hard gate — replace the tab entirely with the paywall
            (recommended: cleanest mental model, zero leakage of premium UI)
         B. Modal paywall over the existing tab; dismiss returns to free content
            (best if you have free content worth keeping inside the tab)
         C. Soft gate — inline teaser with a Subscribe CTA
            (highest conversion in some apps, mixed UX consistency)

You      B

ai-crew  [Q2 — RevenueCat SDK version?]  A: 4.x   B: 5.0   C: other
You      A

ai-crew  [Q3 — Analytics destination?]   A: Segment   B: Amplitude   C: custom
You      C — Mixpanel via our own wrapper

ai-crew  [Intake complete. Writing spec...]
         [spec.md written]
         [plan.md written — 6 tasks, 2 parallel waves]

         ✋  CHECKPOINT — review plan.md before I write a single file.
            Approve, or tell me what to change.

You      Looks good, go.

ai-crew  [Wave 1 — dispatching 3 parallel Sonnet developers...]
         [Wave 2 — dispatching 2 parallel Sonnet developers...]
         [Verify — all tests green]
         [Review — inline five-axis review, no critical findings]
         [Ship — PR opened]

         PR: https://github.com/your-org/your-app/pull/47
             "feat: RevenueCat paywall, premium gate, checkout analytics"
```

---

## What you actually get

- A PR opened on a feature branch, with tests, ready to review.
- A written `spec.md` and `plan.md` before any code is touched — edit them if you want.
- One clear checkpoint: you approve the plan, then ai-crew runs without interruption.
- Tasks that can run in parallel are dispatched as concurrent Sonnet developers — no serial bottleneck on independent work.
- A five-axis review (correctness, readability, architecture, security, performance) done inline by the Fable 5 team-lead before the PR opens.
- Max 3 fix loops on failures before the problem escalates back to you, never silently broken.

---

## Quick Start

Click any tool to expand. Claude Code is the primary platform; the skills run anywhere agent-skills do.

<details open>
<summary><b>Claude Code (recommended)</b></summary>

**Marketplace install:**

```
/plugin marketplace add goktug/ai-crew
/plugin install ai-crew@ai-crew
```

> **SSH errors?** The marketplace clones repos via SSH. If you don't have SSH keys set up on GitHub, either [add an SSH key](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account) or switch to HTTPS for fetches:
>
>     git config --global url."https://github.com/".insteadOf "git@github.com:"

**Local / development:**

```bash
git clone https://github.com/goktug/ai-crew.git
claude --plugin-dir /path/to/ai-crew
```

**Try it:**

```
> /team-lead Migrate our Express auth middleware to JWT rotation, with tests and a rollback plan.
```

</details>

<details>
<summary><b>Cursor</b></summary>

Copy any `SKILL.md` into `.cursor/rules/`, or reference the full `skills/` directory. See [agent-skills/docs/cursor-setup.md](https://github.com/addyosmani/agent-skills/blob/main/docs/cursor-setup.md).

</details>

<details>
<summary><b>Gemini CLI</b></summary>

Install as native skills for auto-discovery, or add to `GEMINI.md` for persistent context.

**From the repo:**

```bash
gemini skills install https://github.com/goktug/ai-crew.git --path skills
```

**From a local clone:**

```bash
gemini skills install ./ai-crew/skills/
```

See [agent-skills/docs/gemini-cli-setup.md](https://github.com/addyosmani/agent-skills/blob/main/docs/gemini-cli-setup.md).

</details>

<details>
<summary><b>Windsurf</b></summary>

Add skill contents to your Windsurf rules configuration. See [agent-skills/docs/windsurf-setup.md](https://github.com/addyosmani/agent-skills/blob/main/docs/windsurf-setup.md).

</details>

<details>
<summary><b>OpenCode</b></summary>

Uses agent-driven skill execution via `AGENTS.md` and the `skill` tool. See [agent-skills/docs/opencode-setup.md](https://github.com/addyosmani/agent-skills/blob/main/docs/opencode-setup.md).

</details>

<details>
<summary><b>GitHub Copilot</b></summary>

Use agent definitions from `agents/` as Copilot personas, and skill content in `.github/copilot-instructions.md`. See [agent-skills/docs/copilot-setup.md](https://github.com/addyosmani/agent-skills/blob/main/docs/copilot-setup.md).

</details>

<details>
<summary><b>Codex / Other agents</b></summary>

Skills are plain Markdown — they work with any agent that accepts system prompts or instruction files. The `/team-lead` orchestrator depends on Claude Code's subagent dispatch, but the underlying skills run wherever [`agent-skills`](https://github.com/addyosmani/agent-skills) do.

</details>

---

## The example, walked through

Starting command:

```
> /team-lead Wire RevenueCat into our paywall, gate the premium tab, and track
              checkout events with our analytics SDK
```

**Intake phase** — one question at a time, **multiple choice with tradeoffs**. Every question leads with a recommendation:

```
Q1: How should the premium gate behave on the tab?
    A. Hard gate — replace the tab with the paywall
       (recommended — cleanest mental model, zero premium-UI leakage)
    B. Modal paywall over the tab; dismiss returns to free content
       (best when you have free content worth keeping inside the tab)
    C. Soft gate — inline teaser with a Subscribe CTA
       (highest conversion in some apps, but mixed UX consistency)

Q2: RevenueCat SDK version?
    A. 4.x       B. 5.0       C. Older — add a migration step

Q3: Analytics destination for checkout events?
    A. Segment   B. Amplitude   C. Custom wrapper (paste the event contract)
```

**plan.md excerpt** (what you approve at the checkpoint):

```
T-01  Add RevenueCat SDK init + entitlement check  [files: src/iap/rc.ts]
T-02  Paywall modal component + dismiss logic       [files: src/screens/Paywall.tsx]
T-03  Premium tab gate (depends on T-01, T-02)     [files: src/navigation/TabNav.tsx]
T-04  Analytics: track checkout events             [files: src/analytics/iap.ts]
```

**Post-build summary line:**

```
PASS: 4 tasks complete, 12 tests green, PR #47 opened on feat/revenuecat-paywall
```

---

## More examples

ai-crew is general-purpose. React Native is one use case, not the only one.

```
> /team-lead Migrate our Express auth middleware from session cookies to JWT
              rotation, with tests and a rollback plan.
```

```
> /team-lead Add a Stripe webhook handler for invoice.payment_failed that retries
              dunning notifications and logs to Sentry.
```

```
> /team-lead Extract our user-profile API into a standalone NestJS microservice,
              update the monolith to call it over HTTP, write contract tests.
```

---

## How it works

### 9-phase lifecycle

```
Intake ─► Research ─► Spec ─► Plan ─► ✋ CHECKPOINT ─► Build ─► Verify ─► Review ─► Ship
```

Each phase has a defined skill and a defined output. The Fable 5 team-lead runs every phase inline — it dispatches subagents only for Build tasks and web research questions.

### Model routing

| Layer | Model | Role |
|---|---|---|
| `team-lead` (main session) | **Fable 5** | Coordinator — plans big, executes small. Orchestrator + architect + planner + verifier + reviewer + shipper. Heavy thinking inline; never reads token-heavy raw material a dispatch can read. |
| `sonnet-developer` / `opus-developer` / `fable-developer` subagents | **Sonnet / Opus / Fable 5** | One task per dispatch, routed by the plan's `complexity` flag (`simple` / `complex` / `frontier`). `fable-developer` is rare by design — no rate arbitrage, only context isolation and depth. No `Agent`/`Task` tool. |
| `web-researcher` subagent | **Haiku** | One focused web-research question per dispatch. No `Agent`/`Task` tool. |

### Reference-based dispatch

When the team-lead dispatches a developer, the outgoing prompt is under 30 lines. It contains file paths and line ranges into `spec.md` and `plan.md` — never embedded content, never whole-file pointers. The `md-index.sh` script generates a Section Index for `spec.md` and a Task Index for `plan.md` at the end of Phase 3 and Phase 4 respectively, so every dispatch cites exactly the slices the developer must read. Team-lead context stays tight on long runs; the developer's input tokens drop because it never reads files it doesn't need.

### Parallel waves

Tasks marked independent in `plan.md` are dispatched as concurrent Sonnet developers in the same wave — no artificial serial bottleneck on work that can run side by side. Beyond a single run, you can fan out multiple `/team-lead` runs across git worktrees or separate sessions. ai-crew pulls you back into the loop only at each run's plan checkpoint. Independent work scales horizontally; your attention stays at the decision boundary.

---

## The team-lead is smart

The orchestrator does the heavy thinking once and then hands off the smallest possible unit of work to a Sonnet developer. That keeps token usage low and turn count low without giving up code quality.

- **Scoped tasks.** Each developer dispatch is one task: a specific ID from `plan.md`, the exact files to touch, the acceptance criteria, and the verification command. No broad "implement the feature" prompts that produce broad, generic code.
- **Pre-named skills per task.** The plan tags every task with the skills it requires — for example `test-driven-development`, `incremental-implementation`, `api-and-interface-design`, `mobile-component-testing-with-rntl`. The developer reads exactly those skills before writing code, nothing more.
- **Reference, not embedding.** Every dispatch prompt stays under 30 lines and cites `spec.md` / `plan.md` line ranges via `md-index.sh`. The developer reads only the slices it needs, not the whole files. The team-lead's own context stays compact even across long runs.
- **Sequential when work depends on work.** Tasks with declared dependencies execute in order, so each developer sees a coherent codebase state.
- **Parallel when work is independent.** Tasks the plan marks independent dispatch as a concurrent wave of Sonnet developers. Complexity decides shape: a feature with one critical path runs sequentially, a feature with three orthogonal slices runs as a 3-wide wave.
- **Three-file context budget.** `spec.md`, `plan.md`, and `progress.md` are the entire run state. Anything else is created only when the run materially needs it.

The result: fewer turns, smaller per-turn prompts, and developers that read the right skill at the right time without you babysitting.

---

## Why this is different

### Built on agent-skills (vendored)

ai-crew vendors 21 skills from [Addy Osmani's `agent-skills`](https://github.com/addyosmani/agent-skills) (MIT) as a one-time verbatim copy. Those skills cover test-driven development, incremental implementation, code review, security hardening, performance optimization, API design, and more. ai-crew adds three skills on top: `team-lead` (the orchestrator lifecycle), `intake-with-validation` (one-question-at-a-time structured Q&A), and `mobile-component-testing-with-rntl` (React Native Testing Library slot). The vendored skills are never edited — they stay aligned with upstream by design.

### Inspired by Superpowers' intake pattern

The one-question-at-a-time intake pattern was popularized by the Superpowers project. ai-crew makes it the default for every run — even when the request looks complete, the intake phase surfaces assumptions before a single line of code is written. The most expensive bugs come from context you didn't ask for.

### Comparison

| Feature | agent-skills | Superpowers | ai-crew |
|---|---|---|---|
| Structured intake (one Q at a time) | No | Yes | Yes — every run |
| Full lifecycle orchestrator (Intake → PR) | No | Partial | Yes — 9 phases |
| Written plan with human checkpoint | No | No | Yes — mandatory |
| Parallel agent dispatch within a run | No | No | Yes — independent tasks fan out |
| Inline five-axis review by orchestrator | No | No | Yes — Fable 5, 4 review skills |
| Max fix-loop budget before escalation | No | No | Yes — 3 loops |
| Reference-based dispatch (line-range slicing) | No | No | Yes — md-index.sh |
| Subagent spawning subagents | N/A | Varies | Never — strict 1-level |

---

## The trust contract

Guarantees pulled directly from the locked architectural laws:

- **Strict 1-level dispatch.** `developer` and `web-researcher` subagents have no `Agent` or `Task` tools by configuration. They cannot spawn further subagents.
- **Reference-based dispatch.** Every developer prompt is under 30 lines and cites spec/plan line ranges — never embedded context, never whole-file pointers.
- **Three-file run state.** Each run writes exactly `spec.md`, `plan.md`, `progress.md` under `~/.claude/ai-crew/runs/<YYYY-MM-DD-slug>/`. Nothing else unless the run materially needs it.
- **One mandatory human checkpoint.** Plan approval is the only point where ai-crew stops and waits. Everything before and after is autonomous.
- **Max 3 fix loops before escalation.** Verify and Review share a combined budget of 3 fix-loop retries. On the 4th failure, ai-crew escalates to you instead of silently spinning.
- **Inline review by the Fable 5 team-lead.** Review is done inline across 4 review skills (`code-review-and-quality`, `security-and-hardening`, `code-simplification`, `performance-optimization`). There are no reviewer subagents.
- **Vendored skills are never edited.** The 21 agent-skills are a one-time copy. Editing them would silently diverge from upstream.

---

## FAQ

<details>
<summary><b>What happens when something goes wrong mid-run?</b></summary>

The team-lead dispatches a focused-fix developer task and retries. Verify and Review share a combined budget of max 3 fix loops. If the third attempt still fails, ai-crew stops and explains the failure — it does not silently loop forever or paper over broken tests.

</details>

<details>
<summary><b>Is this React Native only?</b></summary>

No. ai-crew is general-purpose for TypeScript, Node, backend, and fullstack work. React Native is one example use case, and the `mobile-component-testing-with-rntl` skill is bundled but only used when the plan tags a task for it. The three non-RN examples in this README are there specifically to make that point.

</details>

<details>
<summary><b>How do you avoid runaway token costs?</b></summary>

Reference-based dispatch with line-range slicing. The developer subagent reads only the ~30-line prompt it receives plus the specific slices of `spec.md` and `plan.md` it is told to fetch — not the whole files. The `md-index.sh` script generates the Section Index and Task Index that make those citations possible. The architecture is the control, not a percentage claim.

</details>

<details>
<summary><b>Can I use this with Codex or other frontier model CLIs?</b></summary>

Yes. See the Quick Start above. The `skills/` directory is plain Markdown and works with any CLI or SDK that supports SKILL.md-style skill loading — copy the `skills/` directory into your tool's plugin layout and point it at `skills/team-lead/SKILL.md`.

</details>

<details>
<summary><b>Why one human checkpoint and not zero or three?</b></summary>

Plan approval is the only step where human course-correction has outsized leverage. Before the plan, requirements are still ambiguous. After the plan, the code is already written. Catching a wrong direction at plan review costs a 30-second read and a one-sentence redirect; catching it after Build costs a full re-run.

</details>

<details open>
<summary><b>Can I run multiple ai-crew jobs in parallel?</b></summary>

Yes. Fan out across git worktrees or separate terminal sessions — each `/team-lead` invocation is independent. ai-crew pulls you back only at each run's plan checkpoint. Within a single run, independent tasks are dispatched as parallel waves of Sonnet developers automatically — you don't have to do anything to enable it.

</details>

<details>
<summary><b>Does ai-crew work on existing codebases or only greenfield?</b></summary>

Both. The intake phase asks about existing patterns, conventions, and constraints before writing the spec. The developer subagents read the files they are told to touch before editing them. The plan lists the exact files that will change — you see that at the checkpoint before anything is modified.

</details>

<details>
<summary><b>What models does ai-crew use and can I change them?</b></summary>

The orchestrator (team-lead) runs on Fable 5 as a plan-big-execute-small coordinator — it does the heavy reasoning (spec writing, plan quality, inline review) and never reads token-heavy raw material a worker can read, so the heavy tokens bill at worker rates. Developer subagents run on Sonnet (simple tasks), Opus (complex tasks), or Fable 5 (rare frontier tasks that resist atomization): one atomized task per dispatch, no spawning of further agents. Web-researcher subagents run on Haiku: one focused question each. The model routing is a locked architectural decision because the cost-to-capability fit at each layer is deliberate.

</details>

---

## Run state layout

```
~/.claude/ai-crew/runs/2026-04-25-revenuecat-paywall/
├── spec.md       # what we're building, constraints, success criteria
├── plan.md       # task DAG with Task Index — the sacred artifact
└── progress.md   # per-task checkbox state, review notes
```

Three files. That's it.

---

## Credits and links

- **[agent-skills](https://github.com/addyosmani/agent-skills)** by Addy Osmani — 21 skills vendored verbatim, MIT-licensed. The foundation this plugin is built on.
- **Superpowers** — inspiration for the one-question-at-a-time intake pattern.
- **[Anthropic Claude Code](https://docs.anthropic.com/claude-code)** — the runtime this plugin targets.
- **Repository:** [github.com/Goktug/ai-crew](https://github.com/Goktug/ai-crew)
- **License:** MIT — see [LICENSE](LICENSE).
