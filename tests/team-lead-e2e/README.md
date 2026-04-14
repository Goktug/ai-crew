# tests/team-lead-e2e — End-to-end smoke tests for the team-lead orchestrator

Adapted from [`reference-projects/superpowers/tests/subagent-driven-dev/`](../../reference-projects/superpowers/tests/subagent-driven-dev/), with two ai-crew-specific changes:

1. **Pre-prepared spec.md + plan.md** — the fixture provides them so the team-lead can skip Phases 1–4 (Intake/Research/Spec/Plan) and execute Build → Verify → Review headlessly. Without this, the human checkpoint would block a `claude -p` run.
2. **Hand-off evidence checks** — after the run, the runner greps the stream-json log for `subagent_type=developer` dispatches, PASS/FAIL replies, and progress.md updates. These verify that the team-lead's strict 1-level dispatch actually happens at runtime.

## Layout

```
tests/team-lead-e2e/
├── README.md            # this file
├── run-test.sh          # main runner: scaffolds + runs claude -p + checks hand-off
├── rn-counter/          # SEQUENTIAL fixture: 3 TDD-chained tasks (T-01 → T-02 → T-03)
│   ├── design.md
│   ├── spec.md
│   ├── plan.md
│   ├── scaffold.sh
│   └── starter/         # minimal React Native + RNTL project
│       ├── package.json
│       ├── babel.config.js
│       ├── jest.config.js
│       ├── tsconfig.json
│       ├── index.js
│       ├── App.tsx
│       └── components/  # empty — team-lead adds Counter.tsx + Counter.test.tsx
└── ts-utility-pack/     # PARALLEL fixture: 3 independent tasks dispatched in one fan-out
    ├── design.md
    ├── spec.md
    ├── plan.md          # all 3 tasks marked [Independent] in Wave 1
    ├── scaffold.sh
    └── starter/         # minimal TypeScript + Jest project
        ├── package.json
        ├── tsconfig.json
        ├── jest.config.js
        └── src/         # empty — team-lead adds slugify, chunk, clamp + tests
```

## Two fixtures, two architectural checks

| Fixture | What it tests | Pass criterion |
|---|---|---|
| `rn-counter` | Sequential dispatch through a TDD chain. T-02 depends on T-01, T-03 on T-02. Verifies hand-off works at all. | ≥1 developer dispatch, progress.md updated, no nested dispatches. |
| `ts-utility-pack` | **Parallel fan-out.** 3 independent tasks at the same DAG depth. Verifies team-lead respects `[Independent]` flags and dispatches multiple developers in a single assistant turn. | All `rn-counter` checks **plus** ≥1 assistant turn must contain ≥2 `Task` tool calls (parallel fan-out detected via jq inspection of stream-json). |

## Quickstart

```bash
# Sequential dispatch fixture (RN Counter, 3 TDD-chained tasks)
./tests/team-lead-e2e/run-test.sh rn-counter

# Parallel dispatch fixture (TS utility pack, 3 [Independent] tasks)
./tests/team-lead-e2e/run-test.sh ts-utility-pack

# Use a different plugin dir
./tests/team-lead-e2e/run-test.sh ts-utility-pack --plugin-dir /path/to/ai-crew
```

The runner:

1. Scaffolds a fresh project at `/tmp/ai-crew-tests/<timestamp>/team-lead-e2e/rn-counter/project/`
2. Runs `claude -p` with the team-lead prompt, `--plugin-dir`, `--dangerously-skip-permissions`, `--output-format stream-json`, `--verbose`
3. Captures the full stream-json log to `claude-output.json`
4. Greps the log for hand-off evidence (developer subagent dispatched, PASS/FAIL replies, progress.md updated, no nested dispatches)
5. Prints token usage and a "next steps" hint for manual verification

## What "PASS" means here

The runner exits 0 if the **hand-off architecture worked**:

- ≥1 developer subagent dispatch was made by the team-lead
- ≥1 developer reply was correlated back to an Agent tool call
- progress.md was updated
- All Agent calls resolved to a known subagent type (1-level rule held)
- Parallel fan-out was detected (ts-utility-pack only)

It does NOT directly verify that the resulting code compiles or that `npm test` passes — although in practice **the team-lead often runs `npm install && npm test` itself in Phase 7 (Verify)** because its `Verify, Don't Assume` core operating behavior demands real evidence over static checks. Per-task verification commands (in plan.md) stay static for speed; the team-lead's holistic Phase 7 may run the real tests.

If the team-lead did not run npm itself, you can verify manually:

```bash
cd /tmp/ai-crew-tests/<timestamp>/team-lead-e2e/<fixture>/project
npm install     # ~1–2 minutes for RN, much faster for ts-utility-pack
npm test        # runs the developer-authored tests
```

Total runtime budget per fixture run: **~3–5 minutes** (mostly waiting for `claude -p` to finish; npm install adds ~1 min if the team-lead invokes it).

## What this test catches

| Failure mode | Caught by |
|---|---|
| Plugin manifest broken | Runner exits early; static `test-plugin-manifest.sh` also catches it. |
| `team-lead` skill not loaded | `Check 1` fails — no developer dispatches happen because team-lead never ran. |
| `developer` agent not registered as subagent_type | `Check 1` fails — Task tool calls reject `subagent_type="developer"`. |
| Reference-based prompt format wrong | Manually inspect the log; future enhancement: assert prompt length < 30 lines. |
| 1-level dispatch broken (developer spawns subagent) | `Check 4` warns. |
| Team-lead doesn't update progress.md | `Check 3` fails. |
| Developer doesn't return PASS/FAIL | `Check 2` warns. |

## Adding a new fixture

1. Make a sibling directory under `tests/team-lead-e2e/<fixture-name>/`
2. Add `design.md`, `spec.md`, `plan.md`, `scaffold.sh`, and a `starter/` subdirectory
3. Run `./run-test.sh <fixture-name>`

Keep fixtures small. Each one is a smoke test, not a real product.
