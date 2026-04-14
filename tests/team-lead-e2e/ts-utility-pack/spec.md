# ts-utility-pack — Spec

> Pre-prepared spec for the ai-crew team-lead end-to-end test. The team-lead reads this verbatim instead of running Phase 1 (Intake) and Phase 3 (Spec).

## Objective

Implement three pure TypeScript utility functions — `slugify`, `chunk`, and `clamp` — each in its own source file, each with a Jest test file written **first** (RED) before any implementation (GREEN). The three functions are independent and have no shared types, no shared helpers, and no execution-order dependencies. The team-lead is expected to dispatch them in parallel.

## Scope

**In scope:**
- Create `src/slugify.ts` and `src/slugify.test.ts`.
- Create `src/chunk.ts` and `src/chunk.test.ts`.
- Create `src/clamp.ts` and `src/clamp.test.ts`.
- Each function is a named export; each test file imports from its sibling module.
- Each test file covers at least the cases listed in the plan task's acceptance criteria.

**Out of scope:**
- Wiring an `index.ts` barrel export. The functions stay independent.
- Any shared types, helpers, or test utilities.
- Performance optimization beyond the obvious implementation.

## Success criteria

The team-lead's run is successful when:
1. All three source files (`slugify.ts`, `chunk.ts`, `clamp.ts`) and three test files exist under `src/`.
2. Each test file contains at least the assertions listed in the plan.
3. The three tasks were dispatched **in parallel** within a single team-lead turn (verified via the stream-json log inspection in `run-test.sh`).
4. `progress.md` shows every plan task as PASS.
5. Inline review using the four review skills is recorded in `progress.md`.

## Hard constraints

- Reference-based dispatch only — the team-lead's prompt to each developer must be under 30 lines and contain file paths, not embedded spec content.
- Strict 1-level dispatch — no developer dispatches further subagents.
- Each task touches only the two files for its own function — no cross-file edits.
- Do NOT touch `package.json`, `tsconfig.json`, `jest.config.js`, or any configuration file.
- Do NOT commit, do NOT open a PR.

### Verification policy

- **Per-task verification (developer subagents during Build):** static greps only — see the Verification command on each plan task. Developers should NOT run `npm install` or `npm test` because each task is small, isolated, and already covered by static checks.
- **Phase 7 Verify (team-lead, holistic):** the team-lead MAY run `npm install && npm test` as a cross-task verification once all developer dispatches return. This is the team-lead's call, governed by the `Verify, Don't Assume` core operating behavior.

## Non-goals

- This is a fixture, not a published utility library. No README, no exports map, no version bump, no publish flow.

## Acceptance verification (manual, after the run)

The user will inspect:
1. `progress.md` — every task PASS.
2. The six expected files under `src/`.
3. The stream-json log: three `Agent` tool calls dispatched in a single assistant turn (parallel fan-out).
4. If the team-lead did not run `npm install && npm test` itself in Phase 7, run them manually and confirm all six Jest tests pass.
