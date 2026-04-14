# rn-counter — Spec

> Pre-prepared spec for the ai-crew team-lead end-to-end test. The team-lead reads this verbatim instead of running Phase 1 (Intake) and Phase 3 (Spec).

## Objective

Implement a `Counter` component for the starter React Native project. The component must render the current count, expose `+` and `-` controls, and be covered by `@testing-library/react-native` tests written first (RED) before any implementation (GREEN).

## Scope

**In scope:**
- Create `components/Counter.tsx` with the Counter component.
- Create `components/Counter.test.tsx` with RNTL tests.
- Counter starts at 0.
- Pressing `+` increments by 1.
- Pressing `-` decrements by 1, clamped at 0.

**Out of scope:**
- Persistence (no AsyncStorage, no localStorage).
- Theming or styling beyond what RNTL needs to find buttons.
- Integration with `App.tsx` — the starter `App.tsx` stays unchanged.
- Any animation, gestures, accessibility audit beyond `accessibilityLabel` for the buttons.

## Success criteria

The team-lead's run is successful when:
1. `components/Counter.tsx` exists and exports a `Counter` React component.
2. `components/Counter.test.tsx` exists and contains at least 3 RNTL tests:
   - "renders the initial count of 0"
   - "increments when the + button is pressed"
   - "decrements when the - button is pressed, clamped at zero"
3. Each test was written **before** the corresponding implementation (RED→GREEN cycle visible in the developer's commit history or PASS reports).
4. `progress.md` shows every plan task as PASS.
5. Inline review using the four review skills is recorded in `progress.md`.

## Hard constraints

- Use `@testing-library/react-native` only — no Maestro, no Detox, no e2e tooling.
- Reference-based dispatch only — the team-lead's prompt to the developer must be under 30 lines and contain file paths, not embedded spec content.
- Strict 1-level dispatch — the developer must not dispatch any further subagents.
- Do NOT touch `App.tsx`, `package.json`, `babel.config.js`, `jest.config.js`, `tsconfig.json`, or `index.js`.
- Do NOT commit, do NOT open a PR.

### Verification policy

- **Per-task verification (developer subagents during Build):** static greps only — see the Verification command on each plan task. Developers should NOT run `npm install` or `npm test` because each task is small, isolated, and already covered by static checks.
- **Phase 7 Verify (team-lead, holistic):** the team-lead MAY run `npm install && npm test` as a cross-task verification once all developer dispatches return. This is the team-lead's call, governed by the `Verify, Don't Assume` core operating behavior.

## Non-goals

- This is a fixture, not a product. Code quality bar is "tests cover the behavior and the component is the smallest correct implementation." No premature abstractions, no helper components.

## Acceptance verification (manual, after the run)

The user will inspect:
1. `progress.md` — every task PASS.
2. `components/Counter.tsx` and `components/Counter.test.tsx` exist.
3. If the team-lead did not run `npm install && npm test` itself in Phase 7, run them manually and confirm the RNTL tests pass.
