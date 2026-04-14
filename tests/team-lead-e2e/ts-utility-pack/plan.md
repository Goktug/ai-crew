# ts-utility-pack — Plan

> Pre-prepared task DAG for the ai-crew team-lead end-to-end test. The team-lead reads this and skips Phase 4 (Plan), executing tasks via developer subagent dispatch.

## Wave structure

**Wave 1 contains all three tasks.** Each task is marked `[Independent]` and touches a disjoint pair of files. The team-lead must dispatch all three developers in a single fan-out — one assistant turn with three `Task` tool calls, not three sequential turns.

This is the parallelism check this fixture exists to exercise.

---

## Tasks

### T-01: `slugify(text: string): string` [Independent]

- **Dependencies:** None
- **Wave:** 1
- **Files to touch:**
  - `src/slugify.ts` (new)
  - `src/slugify.test.ts` (new)
- **TDD:** Write `slugify.test.ts` first (RED), then `slugify.ts` (GREEN).
- **Acceptance criteria:**
  - `src/slugify.ts` exports a named function `slugify(text: string): string`.
  - Lowercases input.
  - Replaces every run of non-alphanumeric ASCII characters with a single `-`.
  - Trims leading and trailing `-`.
  - `src/slugify.test.ts` contains at least these test cases:
    - `slugify('Hello World')` → `'hello-world'`
    - `slugify('  Foo!!Bar??  ')` → `'foo-bar'`
    - `slugify('A B  C   D')` → `'a-b-c-d'`
    - `slugify('---already---slugged---')` → `'already-slugged'`
    - `slugify('')` → `''`
- **Verification command** (no `npm install` in this fixture; static checks only):
  ```bash
  test -f src/slugify.ts && \
  test -f src/slugify.test.ts && \
  grep -q "export.*function slugify\|export.*const slugify\|export function slugify" src/slugify.ts && \
  grep -q "from './slugify'" src/slugify.test.ts && \
  grep -q "hello-world" src/slugify.test.ts && \
  grep -q "foo-bar" src/slugify.test.ts && \
  grep -q "already-slugged" src/slugify.test.ts
  ```

---

### T-02: `chunk<T>(arr: T[], size: number): T[][]` [Independent]

- **Dependencies:** None
- **Wave:** 1
- **Files to touch:**
  - `src/chunk.ts` (new)
  - `src/chunk.test.ts` (new)
- **TDD:** Write `chunk.test.ts` first (RED), then `chunk.ts` (GREEN).
- **Acceptance criteria:**
  - `src/chunk.ts` exports a generic named function `chunk<T>(arr: T[], size: number): T[][]`.
  - Splits `arr` into consecutive sub-arrays of length `size`.
  - The last chunk may be shorter than `size`.
  - Throws `RangeError` if `size <= 0` (zero or negative).
  - `src/chunk.test.ts` contains at least these test cases:
    - `chunk([1,2,3,4,5], 2)` → `[[1,2],[3,4],[5]]`
    - `chunk([1,2,3,4], 2)` → `[[1,2],[3,4]]`
    - `chunk([], 3)` → `[]`
    - `chunk([1,2,3], 5)` → `[[1,2,3]]`
    - Calling `chunk([1,2,3], 0)` throws `RangeError`
    - Calling `chunk([1,2,3], -1)` throws `RangeError`
- **Verification command:**
  ```bash
  test -f src/chunk.ts && \
  test -f src/chunk.test.ts && \
  grep -q "export.*function chunk\|export.*const chunk\|export function chunk" src/chunk.ts && \
  grep -q "RangeError" src/chunk.ts && \
  grep -q "from './chunk'" src/chunk.test.ts && \
  grep -q "RangeError" src/chunk.test.ts
  ```

---

### T-03: `clamp(value: number, min: number, max: number): number` [Independent]

- **Dependencies:** None
- **Wave:** 1
- **Files to touch:**
  - `src/clamp.ts` (new)
  - `src/clamp.test.ts` (new)
- **TDD:** Write `clamp.test.ts` first (RED), then `clamp.ts` (GREEN).
- **Acceptance criteria:**
  - `src/clamp.ts` exports a named function `clamp(value: number, min: number, max: number): number`.
  - Returns `min` if `value < min`.
  - Returns `max` if `value > max`.
  - Returns `value` otherwise.
  - Throws `RangeError` if `min > max`.
  - `src/clamp.test.ts` contains at least these test cases:
    - `clamp(5, 0, 10)` → `5`
    - `clamp(-3, 0, 10)` → `0`
    - `clamp(15, 0, 10)` → `10`
    - `clamp(0, 0, 10)` → `0` (boundary)
    - `clamp(10, 0, 10)` → `10` (boundary)
    - Calling `clamp(5, 10, 0)` throws `RangeError`
- **Verification command:**
  ```bash
  test -f src/clamp.ts && \
  test -f src/clamp.test.ts && \
  grep -q "export.*function clamp\|export.*const clamp\|export function clamp" src/clamp.ts && \
  grep -q "RangeError" src/clamp.ts && \
  grep -q "from './clamp'" src/clamp.test.ts && \
  grep -q "RangeError" src/clamp.test.ts
  ```

---

## Wave summary

- **Wave 1:** T-01, T-02, T-03 — **all three [Independent], dispatched in parallel.**

There is no Wave 2 in this fixture. The whole point is the single-wave fan-out.

## Verification

After all three tasks return PASS, run inline review using the four review skills (`code-review-and-quality`, `security-and-hardening`, `code-simplification`, `performance-optimization`) and record findings in `progress.md`.

Then STOP. Do NOT run `npm install`, do NOT run `npm test`, do NOT commit, do NOT open a PR. The user verifies the run end-to-end manually.
