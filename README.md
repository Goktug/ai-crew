# g-plugins-marketplace

Goktug's plugins marketplace for [Claude Code](https://code.claude.com). Currently distributes the **ai-crew** plugin — a production-grade Opus team-lead orchestrator that takes any React Native or TypeScript backend task from idea to PR with one human checkpoint.

## What's in the marketplace

| Plugin | Description |
|---|---|
| **ai-crew** | Opus team-lead with strict 1-level dispatch to Sonnet developers and Haiku web-researchers. Reference-based prompts, three-file run state (`spec.md`, `plan.md`, `progress.md`), inline five-axis review across four review skills, max 3 fix loops. Vendored on top of the [`agent-skills`](https://github.com/addyosmani/agent-skills) workflow library. |

## Install

```bash
# 1. Add this marketplace
claude plugin marketplace add Goktug/g-plugins-marketplace

# 2. Install the ai-crew plugin from it
claude plugin install ai-crew@g-plugins-marketplace

# 3. Use it
claude
> /team-lead Build a push-notification permission flow for our React Native onboarding screen.
```

For local development without publishing:

```bash
# Load the plugin for one session, no install
claude --plugin-dir /path/to/g-plugins-marketplace
```

## ai-crew quick architecture

- **Opus team-lead** runs the full lifecycle: Intake → Research → Spec → Plan → CHECKPOINT → Build → Verify → Review → Ship.
- **One human checkpoint:** plan approval. Everything else is autonomous.
- **Strict 1-level dispatch:** the `developer` (Sonnet) and `web-researcher` (Haiku) subagents have no `Agent`/`Task` tools by configuration — they cannot spawn further subagents.
- **Reference-based prompts:** team-lead's outgoing dispatch is ≤30 lines and contains *paths*, never embedded spec/plan content. Subagent context stays tight on long runs.
- **Inline review:** team-lead applies five-axis review across `code-review-and-quality`, `security-and-hardening`, `code-simplification`, and `performance-optimization`. No reviewer subagents.
- **Run state:** three files at `~/.claude/ai-crew/runs/<YYYY-MM-DD-slug>/`: `spec.md`, `plan.md`, `progress.md`. That's it.

Full design: [`docs/team-lead-design.md`](docs/team-lead-design.md). Implementation plan: [`docs/implementation-plan.md`](docs/implementation-plan.md).

## Layout

```
g-plugins-marketplace/
├── .claude-plugin/
│   ├── plugin.json              # ai-crew plugin manifest
│   └── marketplace.json         # marketplace manifest (this repo)
├── skills/                      # 24 skills (21 vendored from agent-skills + 3 new)
│   ├── team-lead/               # NEW — orchestrator
│   ├── intake-with-validation/  # NEW — one-question-at-a-time
│   ├── mobile-component-testing-with-rntl/  # NEW — RNTL slots into TDD
│   └── (21 vendored skills)
├── agents/                      # 5 agents (3 vendored + 2 new)
│   ├── developer.md             # NEW — Sonnet, no Agent/Task tool
│   ├── web-researcher.md        # NEW — Haiku, web tools only
│   └── (3 vendored agents)
├── references/                  # 4 vendored checklists
├── hooks/                       # vendored hooks + detect-project-type.sh
├── .claude/commands/            # 8 slash commands (7 vendored + /team-lead)
├── docs/                        # design + implementation plan
└── tests/                       # static + functional + team-lead-e2e/
```

## Tests

```bash
# Static checks (fast, no API cost) — runs in seconds
./tests/run-tests.sh --no-api

# Full suite incl. functional tests that load the plugin via claude -p
./tests/run-tests.sh

# End-to-end smoke test of the team-lead → developer hand-off (~2–5 min)
./tests/team-lead-e2e/run-test.sh rn-counter
```

See [`tests/README.md`](tests/README.md) and [`tests/team-lead-e2e/README.md`](tests/team-lead-e2e/README.md).

## Credits

- Vendored skills, agents, references, hooks, and base slash commands are a one-time copy of [`agent-skills`](https://github.com/addyosmani/agent-skills) by Addy Osmani, MIT-licensed.
- End-to-end test pattern adapted from [`superpowers/tests/subagent-driven-dev`](https://github.com/jessevincent/superpowers) by Jesse Vincent.

## License

MIT — see [LICENSE](LICENSE) when added.
