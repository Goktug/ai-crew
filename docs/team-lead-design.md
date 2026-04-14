# ai-crew — Production-Grade Team Lead Plugin

**Status:** Design (locked) • **Created:** 2026-04-14

## Problem Statement

**HMW build a thin Claude Code plugin that takes any React Native or TypeScript backend task from idea to production-grade PR with one human checkpoint — by orchestrating a verbatim copy of agent-skills' 20-skill workflow library, with an Opus team-lead that runs intake / research-dispatch / spec / plan / verify / review / ship inline, parallel Haiku web-researchers, strict 1-level Sonnet developer dispatch, reference-based prompts, and a minimal three-file disk artifact set.**

## Core Bets

1. **Plan quality is the multiplier.** Spend Opus tokens generously on research, spec, and an atomized DAG with explicit dependencies, per-task acceptance criteria, and per-task verification commands. When the plan is right, implementation becomes mechanical execution that Sonnet can do one task at a time.
2. **Reference, don't embed.** Subagent prompts carry file paths, task IDs, and skill paths — never embedded content. The subagent reads what it needs itself. Team-lead context stays small even on long runs.
3. **Heavy thinking in the Opus team-lead; everything else is parallelizable cheap work.** Opus where judgement matters; Haiku for parallel research; Sonnet for focused, deterministic execution.

## Recommended Direction

The plugin is a **vendored, verbatim copy of agent-skills** — one-time copy, no upstream sync planned. On top of that base, a small delta of new files implements:

- One `team-lead` skill (the orchestrator process)
- One `intake-with-validation` skill (inline Q&A even when the request is clear)
- One `mobile-component-testing-with-rntl` skill (RN component tests via `@testing-library/react-native`)
- One `developer` agent (Sonnet, no `Agent`/`Task` tool — strict 1-level dispatch)
- One `web-researcher` agent (Haiku, web tools only)
- One `/team-lead` slash command
- One project-type detection hook

The `team-lead` runs in the **Opus main session**. It dispatches **Haiku web-researchers in parallel** during research, and **Sonnet developers** during build (one task at a time per wave; parallel only when the plan declares independence). It does spec, plan, verify, **review**, and ship **inline** by reading agent-skills' SKILL.md content. Strict 1-level dispatch — no subagent ever spawns its own subagents.

## Model Routing

| Layer | Model | Role |
|---|---|---|
| `team-lead` (main session) | **Opus** | Orchestrator + architect + planner + verifier + **reviewer** + shipper. Heavy thinking inline. |
| `web-researcher` subagent | **Haiku** | One focused web-research question per researcher. Returns a brief; team-lead absorbs into `spec.md` as a citation. |
| `developer` subagent | **Sonnet** | One task per dispatch. Reads task ID + file paths + skill paths from the prompt; reads files itself. **No `Agent`/`Task` tool.** |

## Lifecycle

1. **Intake** — Opus team-lead reads `intake-with-validation` SKILL.md, runs Q&A one question at a time. Findings flow directly into `spec.md`. No separate intake artifact.
2. **Research** — Opus team-lead identifies open questions, dispatches N parallel **Haiku** `web-researcher` subagents. Each returns a brief in its final response; team-lead extracts citations and updates `spec.md`. No `research/` directory.
3. **Spec** — Opus team-lead reads `spec-driven-development` SKILL.md inline, finalizes `spec.md`.
4. **Plan** — Opus team-lead reads `planning-and-task-breakdown` SKILL.md inline, writes `plan.md`. Per task: ID, dependencies, file paths to touch, acceptance criteria, skill tags, verification command, **independence flag** (for parallelism).
5. **CHECKPOINT** — User approves `plan.md`. The only mandatory human touchpoint after intake.
6. **Build** — Team-lead walks the DAG. For each task (sequential by default; parallel within a wave when the plan declares independence), it dispatches a **Sonnet** `developer` with a *reference-based prompt*. Developer reads files itself, follows TDD, returns a one-line PASS/FAIL summary. Team-lead checks the box in `progress.md`.
7. **Verify** — Opus team-lead runs typecheck + lint + RNTL inline. On failure, dispatches one focused-fix developer task; **max 3 retries** before escalating to user.
8. **Review** — Opus team-lead reads `code-review-and-quality` + `security-and-hardening` + `code-simplification` + `performance-optimization` SKILL.md files inline and applies five-axis review to the diff itself. On critical findings, loops back to step 6 with a focused fix task (counts against the same max-3 budget).
9. **Ship** — Opus team-lead reads `git-workflow-and-versioning` + `shipping-and-launch` inline, commits, opens PR.

## Run State Directory (minimal)

`~/.claude/ai-crew/runs/<YYYY-MM-DD-slug>/`

```
~/.claude/ai-crew/runs/2026-04-14-push-notifications/
├── spec.md          # what we're building, constraints, success criteria, citations
├── plan.md          # task DAG — sacred artifact
└── progress.md      # current phase + per-task checkbox state
```

Three files. That's it. Anything else is created only when a specific run materially needs it.

## Reference-Based Dispatch (the prompting principle)

When the team-lead dispatches a subagent, it sends a prompt like:

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

The team-lead's outgoing prompt stays under ~30 lines no matter how big the spec or plan grows. The subagent does the actual reading.

## File Layout

```
ai-crew/
├── .claude-plugin/                                       # plugin manifest                    (new)
├── skills/
│   ├── (20 verbatim copies from agent-skills/skills/)    # base, one-time copy
│   ├── team-lead/SKILL.md                                # NEW — orchestrator
│   ├── intake-with-validation/SKILL.md                   # NEW — Q&A even when clear
│   └── mobile-component-testing-with-rntl/SKILL.md       # NEW — RNTL skill
├── agents/
│   ├── code-reviewer.md                                  # verbatim from agent-skills
│   ├── test-engineer.md                                  # verbatim
│   ├── security-auditor.md                               # verbatim
│   ├── developer.md                                      # NEW — Sonnet, NO Agent/Task tool
│   └── web-researcher.md                                 # NEW — Haiku, web tools only
├── references/                                           # all verbatim from agent-skills
├── hooks/
│   ├── (verbatim from agent-skills)
│   └── detect-project-type.sh                            # NEW — runs once on session start
└── .claude/commands/
    ├── (existing /spec /plan /build /test /review /ship verbatim)
    └── team-lead.md                                      # NEW — single entry point
```

## Locked Decisions

1. **Vendor strategy:** Copy agent-skills files verbatim into `ai-crew/`. **One-time copy. No upstream sync.**
2. **State directory:** `~/.claude/ai-crew/runs/<run-id>/` (cross-repo, single source).
3. **Project-type detection:** Hook script (`hooks/detect-project-type.sh`), runs once on session start, writes `project-type.json` to the run directory.
4. **`developer` tool list:** Read, Write, Edit, Bash, Grep, Glob, Skill. Explicitly **NO** `Agent`/`Task`.
5. **`web-researcher` tool list:** WebFetch, WebSearch, Read, Write. Explicitly **NO** `Agent`/`Task`.
6. **Wave parallelism:** Plan-driven. Team-lead parallelizes only tasks whose plan entries declare independence. agent-skills' `planning-and-task-breakdown` approach drives the breakdown. No hardcoded cap.
7. **Code review:** Done by **Opus team-lead inline**, applying agent-skills' five-axis approach across the four review skills (`code-review-and-quality`, `security-and-hardening`, `code-simplification`, `performance-optimization`). **No reviewer subagents.**
8. **Verify/review retry policy:** **Max 3** fix loops total before escalating to user.

## Key Assumptions to Validate

- [ ] **A well-atomized DAG is enough to make Sonnet deterministic** — the planning-quality bet. Validate on a real ticket.
- [ ] **Reference-based dispatch keeps team-lead context small enough on long runs** — measure on a multi-task feature.
- [ ] **Opus team-lead can do five-axis review inline without missing things** — validate against a real diff.
- [ ] **A Sonnet `developer` without `Agent`/`Task` can complete a typical RN/TS task** — test on a representative real ticket.
- [ ] **RNTL slots cleanly into `test-driven-development`'s RED→GREEN cycle** — verify on a real component.
- [ ] **Project-type detection from `package.json` + `app.json` + `next.config.{js,ts}` covers all your real repos.**
- [ ] **agent-skills' `planning-and-task-breakdown` produces tasks atomic enough that Sonnet won't get lost** — if not, extend the skill (carefully) with explicit file-paths-to-touch + per-task verification commands fields.

## Not Doing (and Why)

- **No autonomous mode in v1** — Plan checkpoint stays. v1.5 adds `--autonomous` once the pipeline is proven on real tickets.
- **No mid-run `resume <run-id>` command in v1** — Disk state is minimal; resume isn't a primary use case.
- **No Maestro / Detox / e2e** — RNTL only. v2 adds an e2e skill.
- **No multi-repo dashboard or daemon** — v3 territory.
- **No editing of agent-skills SKILL.md content** — Vendored verbatim, copy-once-and-forget.
- **No new orchestrator state machine** — Three files (`spec.md`, `plan.md`, `progress.md`) + the agent-skills lifecycle.
- **No reviewer subagents** — Opus team-lead reviews inline.
- **No dynamic skill picker** — Lifecycle skills always run; conditional skills via project-type heuristic.
- **No claude-mem / instinct extraction in v1** — Defer.
- **No custom plan DAG format reinvention** — Use what `planning-and-task-breakdown` produces; extend minimally only if a gap shows up.
- **No parallel waves as a forcing function** — Plan-driven; sequential is default.
- **No per-wave files, no per-reviewer files, no `intake.md`, no `research/` directory** — minimal artifact set.
- **No embedded context in subagent prompts** — references only.
