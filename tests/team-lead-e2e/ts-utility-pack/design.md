# ts-utility-pack — Design

## Overview

A trio of pure TypeScript utility functions (`slugify`, `chunk`, `clamp`), each with its own Jest tests. Used as an end-to-end smoke test of **parallel developer dispatch**: the three tasks are independent (no shared files, no dependencies) so the team-lead should fan out three `developer` subagents concurrently inside a single Build wave.

## Functions

| Function | Signature | Behavior |
|---|---|---|
| `slugify` | `(text: string) => string` | Lowercase, ASCII-only, non-alphanumerics replaced with `-`, leading/trailing `-` trimmed, runs of `-` collapsed |
| `chunk` | `<T>(arr: T[], size: number) => T[][]` | Splits an array into fixed-size chunks; the last chunk may be smaller; throws `RangeError` if `size <= 0` |
| `clamp` | `(value: number, min: number, max: number) => number` | Returns `value` constrained to `[min, max]`; throws `RangeError` if `min > max` |

## Why this fixture exists

This fixture is **not** about the utilities themselves — they are intentionally trivial. It exists to verify two things the rn-counter fixture does not exercise:

1. **Parallel dispatch.** With three independent tasks at the same DAG depth, the team-lead must dispatch three `developer` subagents in a single fan-out (one assistant turn containing three `Task` tool calls), not three sequential turns.
2. **Plan-driven independence flags.** The plan declares each task `[Independent]`. The team-lead skill must respect that flag and parallelize accordingly.

If either is broken, the run will still produce three correct files — but it will produce them sequentially. The hand-off checks in `run-test.sh` distinguish the two cases by inspecting the stream-json log.
