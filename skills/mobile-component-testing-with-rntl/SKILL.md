---
name: mobile-component-testing-with-rntl
description: Writes React Native component tests with @testing-library/react-native that slot into the test-driven-development RED→GREEN cycle. Use when implementing or modifying any RN component, screen, or hook.
---

# Mobile Component Testing with RNTL

## Overview

Test React Native components with `@testing-library/react-native`: write a failing test first (RED), make it pass with the minimum implementation (GREEN), then refactor. Query the rendered tree the way a user or an accessibility tool would — by visible text, accessible role, rendered output — never by inspecting component internals. RNTL renders components in a JS-only environment, so tests are fast and do not require a simulator or device.

## When to Use

- The Build phase of an ai-crew run is implementing or modifying a React Native component, screen, or custom hook.
- The `developer` subagent has been dispatched a task whose `Skills to read first` list includes this file.
- A test for a React Native component is missing or broken.
- The `test-driven-development` skill is in play and the surface under test is a React Native component (not a Node-side function).

**When NOT to use:**
- Pure JS/TS utility functions with no React surface — use plain Jest, no RNTL.
- Backend or Next.js work — use the appropriate web testing skill.
- End-to-end flows (multi-screen navigation, real device, real network) — RNTL renders in isolation and does not exercise navigation or networking; use a dedicated end-to-end testing approach for those.

## Process

This skill is a specialization of `test-driven-development`. The RED→GREEN cycle is:

1. **RED** — Write a failing RNTL test that describes what the component should render or do, from a user's perspective. Run it. Confirm it fails for the *right* reason (component doesn't exist yet, or doesn't render the expected text, or doesn't fire the expected callback).
2. **GREEN** — Write the minimum component code needed to make the test pass. Run the test. Confirm it passes.
3. **REFACTOR** — Clean up the component. Run the test again. It should still pass.

Repeat for each acceptance criterion. One assertion per test is the default; group only when you're testing the same render output from multiple angles.

### Required imports

```ts
import { render, fireEvent, screen } from '@testing-library/react-native'
```

Use `screen` queries (`screen.getByText`, `screen.getByRole`) rather than the destructured form returned by `render()` — it keeps test bodies short and makes refactors easier.

### Presence assertions

The examples below use `.toBeTruthy()` as the presence assertion. `getByText` and friends return a truthy React element when they find a match and throw when they don't, so `.toBeTruthy()` reads as "the element exists" and works with a vanilla Jest install.

RNTL also ships a richer matcher `.toBeOnTheScreen()` (and relatives like `.toHaveTextContent`, `.toBeVisible`) in `@testing-library/react-native/extend-expect`. Those require wiring up a Jest setup file:

```js
// jest.setup.ts
import '@testing-library/react-native/extend-expect'
```

and in `jest.config.js`:

```js
module.exports = {
  preset: 'react-native',
  setupFilesAfterEach: ['<rootDir>/jest.setup.ts'],
}
```

Use `.toBeOnTheScreen()` only when the project's Jest config is already set up for the extended matchers. Default to `.toBeTruthy()` for portability.

### Pattern 1 — Render and query by accessible text

For a component that displays a label:

```tsx
import { render, screen } from '@testing-library/react-native'
import { WelcomeBanner } from './WelcomeBanner'

describe('WelcomeBanner', () => {
  it('shows the user name when provided', () => {
    render(<WelcomeBanner name="Goktug" />)
    expect(screen.getByText('Welcome, Goktug')).toBeTruthy()
  })

  it('falls back to a generic greeting when name is empty', () => {
    render(<WelcomeBanner name="" />)
    expect(screen.getByText('Welcome')).toBeTruthy()
  })
})
```

### Pattern 2 — Fire a press event and assert the callback

For an interactive button:

```tsx
import { render, fireEvent, screen } from '@testing-library/react-native'
import { PrimaryButton } from './PrimaryButton'

it('calls onPress when the button is pressed', () => {
  const onPress = jest.fn()
  render(<PrimaryButton label="Continue" onPress={onPress} />)
  fireEvent.press(screen.getByRole('button', { name: 'Continue' }))
  expect(onPress).toHaveBeenCalledTimes(1)
})
```

Prefer `getByRole` with a `name` over `getByText` for interactive elements — it doubles as an accessibility check.

### Pattern 3 — Wait for async state with `findBy*`

For a component that loads data:

```tsx
import { render, screen } from '@testing-library/react-native'
import { ProfileScreen } from './ProfileScreen'

it('renders the profile name once loaded', async () => {
  render(<ProfileScreen userId="42" />)
  expect(await screen.findByText('Goktug Aral')).toBeTruthy()
})
```

`findBy*` returns a promise that retries the query until it succeeds or times out — use it whenever the assertion depends on state that resolves after render. Do NOT wrap synchronous queries in `waitFor` unless there's a real async dependency.

### Query selection priority

Prefer queries in this order (most accessible first):

1. `getByRole` — checks the accessibility tree
2. `getByLabelText` — for form fields
3. `getByPlaceholderText` — for text inputs
4. `getByText` — for visible text
5. `getByTestId` — last resort, only when no semantic query works

Avoid `getByTestId` unless you have to. A test that needs a testID is often a hint that the component is missing accessible markup.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll write an end-to-end test for this — it's more realistic." | This skill is for component-level behavior. Component-level RNTL tests are faster, more focused, and run without a device. Use end-to-end tooling only for cross-screen flows that component tests cannot cover. |
| "I'll snapshot-test the whole tree to save time." | Snapshots rot quickly and hide intent. Write explicit assertions for visible text and behavior. |
| "I'll skip RNTL for the loading state — too async." | `findBy*` exists exactly for this. Use it. |
| "I'll use `getByTestId` everywhere — it's simpler." | `getByTestId` bypasses the accessibility tree. Use it only when nothing semantic works. |
| "I'll mock the entire React Native module." | Almost never necessary. RNTL renders real components in a JSDOM-like environment. Mock only what you must (network, native modules). |

## Red Flags

- About to import from `@testing-library/react` (web) instead of `@testing-library/react-native`.
- About to write a snapshot test instead of explicit `screen.getByText` assertions.
- About to add an end-to-end test file when a component-level RNTL test would catch the same regression.
- About to use `getByTestId` when `getByRole`/`getByText` would work.
- About to wrap a synchronous query in `waitFor` instead of using `findBy*`.
- About to skip the failing-test (RED) step because "it's just a small component."
- About to mock the entire `react-native` module.
- About to use `.toBeOnTheScreen()` or another RNTL-extended matcher without first checking that `@testing-library/react-native/extend-expect` is imported in a Jest setup file. Default to `.toBeTruthy()` unless the project is already wired up for the extended matchers.

## Verification

Before reporting `PASS` on a Build task that uses this skill:

- [ ] Each new acceptance criterion has at least one RNTL test
- [ ] Tests use `@testing-library/react-native` (NOT `@testing-library/react`)
- [ ] Tests use `screen.getBy*` / `findBy*` queries, not snapshot assertions
- [ ] No `getByTestId` introduced unless no semantic query works
- [ ] No end-to-end test file added — this skill is for component-level RNTL only
- [ ] `npm test` (or the project's test command) reports green
- [ ] The RED→GREEN cycle is observable in the developer's commit history (failing test committed first, then implementation)
