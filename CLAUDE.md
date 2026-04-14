# ai-crew

Production-grade Claude Code plugin: takes any React Native or TypeScript backend task from idea to PR with one human checkpoint.

## Design (locked)

See [docs/team-lead-design.md](docs/team-lead-design.md) — all eight architectural decisions are locked. Read this first before proposing changes to any of: model routing, dispatch tiers, artifact set, vendor strategy, or lifecycle phases.

## Source of truth

`reference-projects/agent-skills/` — base. Will be **vendored verbatim** (one-time copy) into `skills/`, `agents/`, `references/`, `hooks/`, and `.claude/commands/` at the plugin root. **Never edit vendored files.**

## Model routing

| Layer | Model | Role |
|---|---|---|
| `team-lead` (main session) | **Opus** | Orchestrator + architect + planner + verifier + **reviewer** + shipper. Heavy thinking inline. |
| `developer` subagent | **Sonnet** | One task per dispatch. **No `Agent`/`Task` tool.** |
| `web-researcher` subagent | **Haiku** | One focused web-research question per dispatch. **No `Agent`/`Task` tool.** |

## Architectural laws (non-negotiable)

1. **Strict 1-level dispatch.** Subagents never spawn subagents.
2. **Reference-based dispatch.** Subagent prompts contain file paths, task IDs, and skill paths — never embedded content.
3. **Three-file disk artifacts per run:** `spec.md`, `plan.md`, `progress.md`. Nothing else unless materially needed.
4. **Run state at** `~/.claude/ai-crew/runs/<YYYY-MM-DD-slug>/`.
5. **Vendored agent-skills SKILL.md content is never edited.** One-time copy, no upstream sync.
6. **Plan quality > parallelism.** Atomized DAG with per-task acceptance criteria + verification commands. Sonnet executes mechanically when the plan is right.
7. **No reviewer subagents.** Opus team-lead does five-axis review inline using agent-skills' four review skills (`code-review-and-quality`, `security-and-hardening`, `code-simplification`, `performance-optimization`).
8. **Verify/review retry policy: max 3 fix loops** before escalating to user.
9. **Skills and reference docs are user-facing.** Anything under `skills/`, `references/`, `agents/`, `hooks/`, or `.claude/commands/` ships inside the installed plugin. End users see it without any of this CLAUDE.md, the git history, the `reference-projects/` source material, or the architectural laws above. Never include content that only makes sense to the plugin maintainer:
   - No "vendored" / "upstream" / "one-time copy" / "reference-projects" language.
   - No "inspired by" / "ported from" / "adapted from" attribution.
   - No references to this repo's branches, PRs, or commit workflow.
   - No mentions of these architectural laws or locked-design rationale.
   - No meta-commentary like "this plugin," "for v1 scope," or "the maintainer."
   - No paper-trail reminders like "surgical edits require a commit-message note" — that's maintainer-facing.

   Rule of thumb: read every line in `skills/*/SKILL.md` or `references/*.md` pretending you installed ai-crew from a marketplace five minutes ago. If a line requires prior knowledge of how the plugin was built, rewrite it. When maintainer rules exist (like Law 5 above), they live in this CLAUDE.md only — never in the shipped files.

## v1 scope (what we are NOT doing)

- No autonomous mode (plan checkpoint stays)
- No mid-run `resume <run-id>` command
- No Maestro / Detox / e2e (RNTL only)
- No multi-repo dashboard or daemon
- No `claude-mem` integration
- No reviewer subagents
- No dynamic skill picker
- No custom plan DAG format reinvention

See "Not Doing" in `docs/team-lead-design.md` for full list.

## Reference projects (read-only)

- `reference-projects/agent-skills/` — **base**, will be vendored verbatim
- `reference-projects/claude-code-setup/` — old ai-crew, conceptually replaced by this rebuild
- `reference-projects/superpowers/` — Q&A and inline subagent patterns to mirror

## Plugin file layout (target)

```
ai-crew/
├── .claude-plugin/                                       # plugin manifest                    (new)
├── skills/
│   ├── (20 verbatim copies from agent-skills/skills/)    # base, one-time copy
│   ├── team-lead/SKILL.md                                # NEW — orchestrator
│   ├── intake-with-validation/SKILL.md                   # NEW — Q&A even when clear
│   └── mobile-component-testing-with-rntl/SKILL.md       # NEW — RNTL skill
├── agents/
│   ├── code-reviewer.md                                  # verbatim from agent-skills
│   ├── test-engineer.md                                  # verbatim
│   ├── security-auditor.md                               # verbatim
│   ├── developer.md                                      # NEW — Sonnet, NO Agent/Task tool
│   └── web-researcher.md                                 # NEW — Haiku, web tools only
├── references/                                           # all verbatim from agent-skills
├── hooks/
│   ├── (verbatim from agent-skills)
│   └── detect-project-type.sh                            # NEW — runs once on session start
└── .claude/commands/
    ├── (existing /spec /plan /build /test /review /ship verbatim)
    └── team-lead.md                                      # NEW — single entry point
```
