# tests/team-lead-e2e — End-to-end smoke tests for the team-lead orchestrator

Adapted from [`reference-projects/superpowers/tests/subagent-driven-dev/`](../../reference-projects/superpowers/tests/subagent-driven-dev/), with two ai-crew-specific changes:

1. **Pre-prepared spec.md + plan.md** — the fixture provides them so the team-lead can skip Phases 1–4 (Intake/Research/Spec/Plan) and execute Build → Verify → Review headlessly. Without this, the human checkpoint would block a `claude -p` run.
2. **Hand-off evidence checks** — after the run, the runner greps the stream-json log for `subagent_type=developer` dispatches, PASS/FAIL replies, and progress.md updates. These verify that the team-lead's strict 1-level dispatch actually happens at runtime.

## Layout

```
tests/team-lead-e2e/
├── README.md            # this file
├── run-test.sh          # main runner: scaffolds + runs claude -p + checks hand-off
└── rn-counter/          # the demo fixture
    ├── design.md        # high-level requirement
    ├── spec.md          # detailed spec (pre-filled, lets team-lead skip Phase 3)
    ├── plan.md          # task DAG (pre-filled, lets team-lead skip Phase 4)
    ├── scaffold.sh      # creates /tmp project, copies starter + artifacts, git init
    └── starter/         # minimal React Native + RNTL project files
        ├── package.json
        ├── babel.config.js
        ├── jest.config.js
        ├── tsconfig.json
        ├── index.js
        ├── App.tsx
        └── components/  # empty — team-lead adds Counter.tsx + Counter.test.tsx here
```

## Quickstart

```bash
# Run the rn-counter end-to-end test
./tests/team-lead-e2e/run-test.sh rn-counter

# Use a different plugin dir
./tests/team-lead-e2e/run-test.sh rn-counter --plugin-dir /path/to/ai-crew
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
- progress.md was updated
- No nested subagent dispatches (1-level rule held)

It does NOT verify that the resulting code compiles or that `npm test` passes. That's a manual step:

```bash
cd /tmp/ai-crew-tests/<timestamp>/team-lead-e2e/rn-counter/project
npm install     # ~1–2 minutes for RN + RNTL
npm test        # runs Counter.test.tsx
```

If the team-lead's developer dispatches did the right thing, all 3 tests in `components/Counter.test.tsx` will pass.

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
