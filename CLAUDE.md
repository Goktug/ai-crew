# ai-crew

Production-grade Claude Code plugin: takes any React Native or TypeScript backend task from idea to PR with one human checkpoint.

## Design (locked)

All eight architectural decisions are locked. Do not propose changes to any of: model routing, dispatch tiers, artifact set, vendor strategy, or lifecycle phases without explicit approval.

## Source of truth

`reference-projects/agent-skills/` — base. Will be **vendored verbatim** (one-time copy) into `skills/`, `agents/`, `references/`, `hooks/`, and `.claude/commands/` at the plugin root. **Never edit vendored files.**

## Model routing

| Layer | Model | Role |
|---|---|---|
| `team-lead` (main session) | **Opus** | Orchestrator + architect + planner + verifier + **reviewer** + shipper. Heavy thinking inline. |
| `developer` subagent | **Sonnet** | One task per dispatch. **No `Agent`/`Task` tool.** |
| `web-researcher` subagent | **Haiku** | One focused web-research question per dispatch. **No `Agent`/`Task` tool.** |
| `simulator-engineer` subagent (RN only) | **Opus** | One fidelity gate per dispatch. Judgment-heavy: classifies confident vs ambiguous deltas, compares typography and color visually. **No `Agent`/`Task` tool.** |

## Architectural laws (non-negotiable)

1. **Strict 1-level dispatch.** Subagents never spawn subagents.
2. **Reference-based dispatch with line-range citations.** Subagent prompts contain task IDs, skill paths, and **line-range citations** into `spec.md` and `plan.md` — never embedded content and never whole-file pointers. `spec.md` carries a Section Index and `plan.md` carries a Task Index; every developer dispatch includes a `Plan task` range and at least one `Spec refs` range so the subagent reads only the slices it needs.
3. **Three-file disk artifacts per run:** `spec.md`, `plan.md`, `progress.md`. Nothing else unless materially needed.
4. **Run state at** `~/.claude/ai-crew/runs/<YYYY-MM-DD-slug>/`.
5. **Vendored agent-skills SKILL.md content is never edited, with one exception:** `using-agent-skills/SKILL.md` is editable to register project-specific skills (and project-type addenda) in its Skill Discovery flowchart, Quick Reference, and addenda map — because it is the meta-skill the team-lead loads to discover every other skill, and ai-crew custom skills must be discoverable through it. The other 19 vendored skills remain frozen — one-time copy, no upstream sync.
6. **Plan quality > parallelism.** Atomized DAG with per-task acceptance criteria + verification commands. Sonnet executes mechanically when the plan is right.
7. **No reviewer subagents.** Opus team-lead does five-axis review inline using agent-skills' four review skills (`code-review-and-quality`, `security-and-hardening`, `code-simplification`, `performance-optimization`).
8. **Verify/review retry policy: max 3 fix loops** before escalating to user.

## v1 scope (what we are NOT doing)

- No autonomous mode (plan checkpoint stays)
- No mid-run `resume <run-id>` command
- No Maestro / Detox / e2e (RNTL only)
- No multi-repo dashboard or daemon
- No `claude-mem` integration
- No reviewer subagents
- No dynamic skill picker
- No custom plan DAG format reinvention

## Reference projects (read-only)

- `reference-projects/agent-skills/` — **base**, will be vendored verbatim
- `reference-projects/claude-code-setup/` — old ai-crew, conceptually replaced by this rebuild

## Plugin file layout (target)

```
ai-crew/
├── .claude-plugin/                                       # plugin manifest                    (new)
├── skills/
│   ├── (20 verbatim copies from agent-skills/skills/)    # base, one-time copy
│   ├── team-lead/SKILL.md                                # NEW — orchestrator (project-type-agnostic)
│   ├── intake-with-validation/SKILL.md                   # NEW — Q&A even when clear
│   ├── mobile-component-testing-with-rntl/SKILL.md       # NEW — RNTL skill (developer-side)
│   ├── react-native-fidelity-gates/SKILL.md              # NEW — RN-only team-lead addendum (Phase 4/6 amendments)
│   └── simulator-design-fidelity/SKILL.md                # NEW — simulator-engineer-side fidelity diff process
├── agents/
│   ├── code-reviewer.md                                  # verbatim from agent-skills
│   ├── test-engineer.md                                  # verbatim
│   ├── security-auditor.md                               # verbatim
│   ├── developer.md                                      # NEW — Sonnet, NO Agent/Task tool
│   ├── web-researcher.md                                 # NEW — Haiku, web tools only
│   └── simulator-engineer.md                             # NEW — Opus, RN-only, Argent MCP, read-only (Figma artifacts pre-fetched by team-lead)
├── references/                                           # all verbatim from agent-skills
├── hooks/
│   ├── (verbatim from agent-skills)
│   └── detect-project-type.sh                            # NEW — runs once on session start
└── .claude/commands/
    ├── (existing /spec /plan /build /test /review /ship verbatim)
    └── team-lead.md                                      # NEW — single entry point
```
