# ai-crew tests

Local test suite for the ai-crew plugin. Two key properties:

1. **Hermetic via `--plugin-dir`** — every functional test loads the plugin from this repo via `claude --plugin-dir $PLUGIN_ROOT -p ...`. No global install required, no pollution of the user's installed plugins.
2. **Two test classes, both run by default.** Static checks catch broken manifests and vendored-content drift; functional tests actually load the plugin into a real `claude -p` session and verify behavior.

## Quickstart

```bash
# Default: run static + functional tests (slow, costs a few API credits)
./tests/run-tests.sh

# Fast iteration: skip API calls
./tests/run-tests.sh --no-api

# Only the functional tests
./tests/run-tests.sh --only-functional

# Just one test
./tests/run-tests.sh --test test-team-lead-skill-loads.sh

# Verbose (show per-test output on PASS too)
./tests/run-tests.sh --verbose
```

Requirements:
- `claude` CLI in `$PATH` (`claude --version` should work)
- `jq`
- `bash`, `diff`, `grep`, `sed`, `awk` (all standard on macOS / Linux)

## Test classes

### Static tests (~1s each, no API cost)

| File | What it verifies |
|---|---|
| `test-vendor-integrity.sh` | Vendored `skills/`, `agents/`, `references/`, `hooks/` are byte-identical to `reference-projects/agent-skills/`. `.claude/commands/` permitted to differ from T-06 prefix rewrite, but no source file may be missing. |
| `test-plugin-manifest.sh` | `plugin.json` and `marketplace.json` parse as JSON, have expected fields, and `claude plugin validate` exits 0. |
| `test-namespace-rewrite.sh` | T-06 rewrite is intact: zero `agent-skills:` in `.claude/commands/`, every command file has at least one `ai-crew:` reference, no NEW file references `reference-projects/agent-skills/`. |
| `test-skill-anatomy.sh` | Each NEW skill has YAML frontmatter (correct `name`) and the six standard sections. `team-lead/SKILL.md` references all 4 review skills + 8 lifecycle phases + `using-agent-skills` + dispatch template. |
| `test-developer-agent.sh` | `agents/developer.md` frontmatter has `model: sonnet`, `tools` includes `Read, Write, Edit, Bash, Grep, Glob, Skill`, excludes `Agent` and `Task`, body mentions TDD + incremental-implementation + PASS/FAIL output. |
| `test-web-researcher-agent.sh` | `agents/web-researcher.md` has `model: haiku`, tools `WebFetch, WebSearch, Read, Write`, no `Agent`/`Task`, body specifies brief + citations format. |
| `test-detect-project-type.sh` | Wraps `hooks/detect-project-type.test.sh` to exercise the script against the four fixture directories (rn, nextjs, node-ts, none). |

### Functional tests (10–60s each, COSTS API CREDITS)

These actually start `claude -p` with `--plugin-dir $PLUGIN_ROOT` and verify behavior. They are the strongest signal that the plugin works.

| File | What it verifies |
|---|---|
| `test-plugin-loads.sh` | Smoke test: `claude -p` starts cleanly with the plugin loaded. Catches broken manifests, frontmatter, hooks. |
| `test-slash-commands-registered.sh` | `/team-lead`, `/build`, `/plan`, `/spec`, `/test`, `/review`, `/ship`, `/code-simplify` are all visible to claude inside a session loaded with the plugin. |
| `test-team-lead-skill-loads.sh` | Asks claude to describe the team-lead skill and verifies the response names all 9 lifecycle phases (Intake → Ship), all 4 inline review skills, and the `using-agent-skills` foundation. |
| `test-using-agent-skills-loads.sh` | Asks claude to summarize the meta-skill and verifies it names the six Core Operating Behaviors. |
| `test-developer-agent-loads.sh` | Asks claude to read `agents/developer.md` and report its model, tool list, and the absence of `Agent`/`Task` tools. Catches schema regressions that grep would miss. |

Approximate cost per full run: a handful of cents at Opus rates. Cheap enough to run before every commit; expensive enough that you don't want it firing in a tight edit loop. Use `--no-api` for the loop, full run before committing.

## Adding a new test

1. Drop a `test-*.sh` file in `tests/`.
2. Source `test-helpers.sh`:
   ```bash
   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   source "$SCRIPT_DIR/test-helpers.sh"
   ```
3. Use the helpers (`run_claude`, `assert_contains`, `assert_not_contains`, `assert_count`, `assert_order`, `assert_file_exists`, `assert_file_executable`).
4. Add the filename to either `static_tests` or `functional_tests` in `run-tests.sh`.
5. Exit non-zero on failure, zero on pass. The runner aggregates results.

## Layout

```
tests/
├── README.md                              # this file
├── run-tests.sh                           # main runner
├── test-helpers.sh                        # assertion + run_claude library
│
├── test-vendor-integrity.sh               # static
├── test-plugin-manifest.sh                # static
├── test-namespace-rewrite.sh              # static
├── test-skill-anatomy.sh                  # static
├── test-developer-agent.sh                # static
├── test-web-researcher-agent.sh           # static
├── test-detect-project-type.sh            # static (wraps fixture harness)
│
├── test-plugin-loads.sh                   # functional
├── test-slash-commands-registered.sh      # functional
├── test-team-lead-skill-loads.sh          # functional
├── test-using-agent-skills-loads.sh       # functional
└── test-developer-agent-loads.sh          # functional
```
