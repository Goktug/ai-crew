# rn-counter — Plan

> Pre-prepared task DAG for the ai-crew team-lead end-to-end test. The team-lead reads this and skips Phase 4 (Plan), executing tasks in dependency order via developer subagent dispatch.

## Tasks

Three atomized tasks. Each is dispatched as one developer subagent call.

---

### T-01: RNTL test for initial render

- **Dependencies:** None
- **Files to touch:**
  - `components/Counter.test.tsx` (new)
- **Acceptance criteria:**
  - File exists and imports `render`, `screen` from `@testing-library/react-native`
  - Has a test `it('renders the initial count of 0', ...)` that:
    - Imports `{ Counter }` from `./Counter`
    - Renders `<Counter />`
    - Asserts `screen.getByText('0')` is on the screen
  - Test was committed RED first (the `Counter` component does not yet exist, so the test fails on import). The implementation in T-02 makes it pass.
- **Verification command:** Skip running tests (no `npm install` in this fixture). Verify the file exists and the import + assertion strings are present:
  ```bash
  test -f components/Counter.test.tsx && \
  grep -q "@testing-library/react-native" components/Counter.test.tsx && \
  grep -q "renders the initial count of 0" components/Counter.test.tsx && \
  grep -q "screen.getByText('0')" components/Counter.test.tsx
  ```

---

### T-02: Counter component skeleton (initial render only)

- **Dependencies:** T-01
- **Files to touch:**
  - `components/Counter.tsx` (new)
- **Acceptance criteria:**
  - File exists and exports a named `Counter` React function component
  - Renders the current count as text using `<Text>` from `react-native`
  - Initial count is `0`
  - Stores the count in component state (`useState`)
  - Does NOT yet add the `+` or `-` buttons (those come in T-03)
- **Verification command:**
  ```bash
  test -f components/Counter.tsx && \
  grep -q "export.*function.*Counter\|export.*const.*Counter" components/Counter.tsx && \
  grep -q "useState" components/Counter.tsx && \
  grep -q "from 'react-native'" components/Counter.tsx
  ```

---

### T-03: Add increment + decrement (with RED RNTL tests first)

- **Dependencies:** T-02
- **Files to touch:**
  - `components/Counter.test.tsx` (modify — add 2 tests)
  - `components/Counter.tsx` (modify — add 2 buttons)
- **Acceptance criteria:**
  - Two new tests in `Counter.test.tsx`, both written RED first:
    - `it('increments when the + button is pressed', ...)` — uses `fireEvent.press(screen.getByRole('button', { name: '+' }))` and asserts the displayed count became `1`
    - `it('decrements when the - button is pressed, clamped at zero', ...)` — presses `-` from initial 0, asserts the count is still `0`; then presses `+` then `-` and asserts it's back to `0`
  - `Counter.tsx` now renders two `Pressable` (or `Button`) elements with `accessibilityLabel="+"` and `accessibilityLabel="-"` (or `accessibilityRole="button"` with the matching name)
  - Increment handler: `setCount(c => c + 1)`
  - Decrement handler: `setCount(c => Math.max(0, c - 1))`
- **Verification command:**
  ```bash
  grep -q "increments when the + button is pressed" components/Counter.test.tsx && \
  grep -q "decrements when the - button is pressed" components/Counter.test.tsx && \
  grep -q "fireEvent.press" components/Counter.test.tsx && \
  grep -q "Math.max(0, c - 1)\|Math.max(0, count - 1)" components/Counter.tsx
  ```

---

## Wave summary

- Wave 1: T-01 (independent)
- Wave 2: T-02 (depends on T-01)
- Wave 3: T-03 (depends on T-02)

All three are sequential — no parallel execution opportunity in this fixture. Each is a separate developer subagent dispatch.

## Verification

After all three tasks are PASS, run inline review using the four review skills (`code-review-and-quality`, `security-and-hardening`, `code-simplification`, `performance-optimization`) and record findings in `progress.md`.

Then STOP. Do NOT run `npm install`, do NOT run `npm test`, do NOT commit, do NOT open a PR. The user verifies the run end-to-end manually.
