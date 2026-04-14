# Implementation Plan: ai-crew Plugin

**Status:** PLAN — awaiting human approval (only mandatory checkpoint)
**Created:** 2026-04-14 • **Revised:** 2026-04-14 (Q1/Q2/Q3 resolved)
**Source design:** [`docs/team-lead-design.md`](team-lead-design.md)
**Source skill (read-only):** `reference-projects/agent-skills/skills/planning-and-task-breakdown/SKILL.md`

## Overview

Implement the ai-crew Claude Code plugin in three waves:

1. **Wave 1 — Vendor + namespace rewrite** (6 tasks). Byte-identical copy of 5 directories from `reference-projects/agent-skills/`, then a single deliberate edit pass that rewrites `agent-skills:` → `ai-crew:` inside `.claude/commands/*.md` (the only permitted edit, per Q1 resolution).
2. **Wave 2 — Author 9 NEW files** (9 tasks). The delta on top of the vendored base.
3. **Wave 3 — Validate** (7 tasks). Statically + runtime checks against the 7 assumptions in the locked design.

No file in `reference-projects/agent-skills/` is touched. Vendored SKILL.md content is never edited (per CLAUDE.md non-negotiable #5). The single namespace rewrite applies only to `.claude/commands/*.md` — see Resolved Decisions § R1.

## Architecture Anchors (from locked design)

- 1-level dispatch only. Subagents (`developer`, `web-researcher`) MUST NOT have `Agent` or `Task` tools.
- Reference-based prompts under ~30 lines. No embedded spec/plan content.
- 3 disk artifacts per run: `spec.md`, `plan.md`, `progress.md` at `~/.claude/ai-crew/runs/<run-id>/`.
- Inline review by Opus team-lead using 4 review skills (no reviewer subagent).
- Max 3 fix loops (verify or review combined) before escalating to user.

## Resolved Decisions (from prior checkpoint)

### R1 — Namespace rewrite in vendored slash commands ✅
All 7 vendored command files contain `agent-skills:` namespace prefixes (verified). **Decision:** rewrite `agent-skills:` → `ai-crew:` inside `.claude/commands/*.md` only. This is the **single permitted edit** to vendored content. CLAUDE.md non-negotiable #5 forbids editing SKILL.md specifically — command files are exempt under the literal reading the user has confirmed. Captured as **T-06**.

### R2 — `marketplace.json` is in scope ✅
Author `.claude-plugin/marketplace.json` alongside `plugin.json`. Distribution metadata matters. Captured as new **T-08**, separate from the plugin manifest task.

### R3 — Plugin namespace in `.claude/commands/team-lead.md` ✅
Use `ai-crew:team-lead` (matching the plugin name). Aligned with R1.

## Vendor Source Inventory (verified)

| Source path | Count | Notes |
|---|---|---|
| `skills/` | **21 dirs** | Includes `using-agent-skills`. Design says 20 — descriptive; vendor all 21. |
| `agents/` | **3 files** | `code-reviewer.md`, `security-auditor.md`, `test-engineer.md` |
| `references/` | **4 files** | `accessibility-checklist.md`, `performance-checklist.md`, `security-checklist.md`, `testing-patterns.md` |
| `hooks/` | **5 files** | `hooks.json`, `session-start.sh`, `simplify-ignore-test.sh`, `simplify-ignore.sh`, `SIMPLIFY-IGNORE.md` |
| `.claude/commands/` | **7 files** | `build.md`, `code-simplify.md`, `plan.md`, `review.md`, `ship.md`, `spec.md`, `test.md`. Design listed 6 — descriptive; vendor all 7. **Subject to R1 rewrite.** |

## NEW-File Inventory (Wave 2 deliverables)

| # | Path | Purpose |
|---|---|---|
| 1 | `.claude-plugin/plugin.json` | Plugin manifest (`name: ai-crew`) |
| 2 | `.claude-plugin/marketplace.json` | Marketplace metadata (`name: ai-crew`) — per R2 |
| 3 | `skills/team-lead/SKILL.md` | Orchestrator process — encodes 9-step lifecycle |
| 4 | `skills/intake-with-validation/SKILL.md` | One-question-at-a-time Q&A |
| 5 | `skills/mobile-component-testing-with-rntl/SKILL.md` | RNTL pattern; slots into TDD |
| 6 | `agents/developer.md` | Sonnet, no `Agent`/`Task`, one task per dispatch |
| 7 | `agents/web-researcher.md` | Haiku, web tools only |
| 8 | `hooks/detect-project-type.sh` | Classifies repo as RN/Next/Node-TS/unknown |
| 9 | `.claude/commands/team-lead.md` | Single entry-point slash command |

---

## Task DAG

Legend: `[Independent]` = can run in parallel with sibling tasks once listed dependencies are satisfied.
**Total tasks: 22** (6 vendor+rewrite + 9 author + 7 validation)

---

### Wave 1 — Vendor + namespace rewrite

T-01..T-05 are mutually independent and have no dependencies. T-06 depends on T-05 only.

---

#### T-01: Vendor `skills/`

- **Dependencies:** None
- **Independence:** [Independent] of T-02..T-05
- **Files touched:** `skills/` (creates 21 subdirectories with full contents)
- **Acceptance criteria:**
  - [ ] `skills/` exists at the plugin root
  - [ ] All 21 subdirectories from `reference-projects/agent-skills/skills/` exist under `skills/`
  - [ ] Every destination file is byte-identical to its source counterpart
  - [ ] No extra files added; no source files missing
- **Verification:**
  ```bash
  diff -rq reference-projects/agent-skills/skills/ skills/
  # Expected: no output (zero differences)
  ```
- **Implementation hint:** `cp -Rp reference-projects/agent-skills/skills/. skills/`

---

#### T-02: Vendor `agents/`

- **Dependencies:** None
- **Independence:** [Independent] of T-01, T-03..T-05
- **Files touched:**
  - `agents/code-reviewer.md`
  - `agents/security-auditor.md`
  - `agents/test-engineer.md`
- **Acceptance criteria:**
  - [ ] All 3 source files exist at destination
  - [ ] Each destination file is byte-identical to its source
- **Verification:**
  ```bash
  diff -rq reference-projects/agent-skills/agents/ agents/
  ```

---

#### T-03: Vendor `references/`

- **Dependencies:** None
- **Independence:** [Independent] of T-01, T-02, T-04, T-05
- **Files touched:**
  - `references/accessibility-checklist.md`
  - `references/performance-checklist.md`
  - `references/security-checklist.md`
  - `references/testing-patterns.md`
- **Acceptance criteria:**
  - [ ] All 4 source files exist at destination
  - [ ] Each destination file is byte-identical to its source
- **Verification:**
  ```bash
  diff -rq reference-projects/agent-skills/references/ references/
  ```

---

#### T-04: Vendor `hooks/`

- **Dependencies:** None
- **Independence:** [Independent] of T-01..T-03, T-05
- **Files touched:**
  - `hooks/hooks.json`
  - `hooks/session-start.sh`
  - `hooks/simplify-ignore-test.sh`
  - `hooks/simplify-ignore.sh`
  - `hooks/SIMPLIFY-IGNORE.md`
- **Acceptance criteria:**
  - [ ] All 5 source files exist at destination
  - [ ] Each destination file is byte-identical to its source
  - [ ] Executable bits preserved on `.sh` files (use `cp -p`)
- **Verification:**
  ```bash
  diff -rq reference-projects/agent-skills/hooks/ hooks/
  test -x hooks/session-start.sh && test -x hooks/simplify-ignore.sh && echo "exec bits OK"
  ```

---

#### T-05: Vendor `.claude/commands/`

- **Dependencies:** None
- **Independence:** [Independent] of T-01..T-04
- **Files touched:**
  - `.claude/commands/build.md`
  - `.claude/commands/code-simplify.md`
  - `.claude/commands/plan.md`
  - `.claude/commands/review.md`
  - `.claude/commands/ship.md`
  - `.claude/commands/spec.md`
  - `.claude/commands/test.md`
- **Acceptance criteria:**
  - [ ] `.claude/commands/` exists
  - [ ] All 7 source files exist at destination
  - [ ] Each destination file is byte-identical to its source (rewrite happens in T-06, NOT here)
- **Verification:**
  ```bash
  diff -rq reference-projects/agent-skills/.claude/commands/ .claude/commands/
  # Expected: no output. Any difference here is a bug.
  ```

---

#### T-06: Rewrite `agent-skills:` → `ai-crew:` in `.claude/commands/*.md` (R1)

- **Dependencies:** T-05 (commands must exist verbatim before edit)
- **Independence:** Sequential after T-05; [Independent] of T-01..T-04 once T-05 is done
- **Files touched:**
  - `.claude/commands/build.md`
  - `.claude/commands/code-simplify.md`
  - `.claude/commands/plan.md`
  - `.claude/commands/review.md`
  - `.claude/commands/ship.md`
  - `.claude/commands/spec.md`
  - `.claude/commands/test.md`
- **Acceptance criteria:**
  - [ ] Every literal occurrence of `agent-skills:` inside `.claude/commands/*.md` is replaced with `ai-crew:` — and ONLY there
  - [ ] **No other vendored file is touched** (skills, agents, references, hooks remain byte-identical to source)
  - [ ] Pre-rewrite count of `agent-skills:` matches post-rewrite count of `ai-crew:` (no occurrences lost or duplicated)
  - [ ] Each rewritten file remains valid Markdown with intact YAML frontmatter
- **Verification:**
  ```bash
  # Step 1: zero remaining 'agent-skills:' occurrences inside .claude/commands/
  ! grep -rn "agent-skills:" .claude/commands/

  # Step 2: at least one 'ai-crew:' occurrence in each command file (sanity — every original file had at least one)
  for f in .claude/commands/build.md .claude/commands/code-simplify.md .claude/commands/plan.md .claude/commands/review.md .claude/commands/ship.md .claude/commands/spec.md .claude/commands/test.md; do
    grep -q "ai-crew:" "$f" || { echo "no rewrite happened in $f"; exit 1; }
  done

  # Step 3: substitution counts match between source and destination
  src_count=$(grep -ro "agent-skills:" reference-projects/agent-skills/.claude/commands/ | wc -l | tr -d ' ')
  dst_count=$(grep -ro "ai-crew:" .claude/commands/ | wc -l | tr -d ' ')
  test "$src_count" = "$dst_count" || { echo "count mismatch: src=$src_count dst=$dst_count"; exit 1; }

  # Step 4: every other vendored directory is still byte-identical to source
  diff -rq reference-projects/agent-skills/skills/ skills/
  diff -rq reference-projects/agent-skills/agents/ agents/
  diff -rq reference-projects/agent-skills/references/ references/
  diff -rq reference-projects/agent-skills/hooks/ hooks/
  ```
- **Implementation hint:** `find .claude/commands -name '*.md' -exec sed -i.bak 's/agent-skills:/ai-crew:/g' {} \;` then remove `*.bak` files. On macOS BSD sed: `sed -i ''` instead of `sed -i.bak`.
- **Critical:** This task is the ONLY permitted edit to vendored content. It is gated by the user's explicit Q1 resolution.

---

### Checkpoint W1 — Vendor + permitted rewrite complete

- [ ] `diff -rq` returns zero differences for `skills/`, `agents/`, `references/`, `hooks/`
- [ ] `.claude/commands/*.md` contains zero `agent-skills:` occurrences and N `ai-crew:` occurrences (where N == source count of `agent-skills:`)
- [ ] No file outside the design's file layout was added
- [ ] No file in `reference-projects/agent-skills/` was modified

---

### Wave 2 — Author 9 NEW files

All 9 tasks depend ONLY on Wave 1 completion. Within Wave 2, every task is independent of every other Wave 2 task — full parallelism opportunity.

---

#### T-07: Author `.claude-plugin/plugin.json`

- **Dependencies:** Wave 1 complete (T-01..T-06)
- **Independence:** [Independent] of T-08..T-15
- **Files touched:** `.claude-plugin/plugin.json`
- **Acceptance criteria:**
  - [ ] Valid JSON (parseable by `jq .`)
  - [ ] Required fields: `name` = `"ai-crew"`, `description`, `version` = `"0.1.0"`, `author`, `commands` = `"./.claude/commands"`
  - [ ] Description references "team-lead" orchestration and "one human checkpoint"
  - [ ] Does NOT copy upstream license/homepage/repository (author chooses)
- **Verification:**
  ```bash
  jq -e '.name == "ai-crew" and .commands == "./.claude/commands" and .version == "0.1.0"' .claude-plugin/plugin.json
  ```
- **Notes:** Use `reference-projects/agent-skills/.claude-plugin/plugin.json` as a *structural template only*. Do not copy verbatim.

---

#### T-08: Author `.claude-plugin/marketplace.json` (R2)

- **Dependencies:** Wave 1 complete
- **Independence:** [Independent] of T-07, T-09..T-15
- **Files touched:** `.claude-plugin/marketplace.json`
- **Acceptance criteria:**
  - [ ] Valid JSON (parseable by `jq .`)
  - [ ] Top-level `name` field = `"ai-crew"` (or marketplace owner name; use `"ai-crew"` for v1)
  - [ ] `metadata.description` present and non-empty
  - [ ] `plugins` array contains exactly one entry with `name == "ai-crew"`
  - [ ] Plugin entry has a `source` block (use `{"source":"local"}` for v1 since the plugin lives next to the marketplace; can be revised when published)
  - [ ] Description references the team-lead orchestrator and one human checkpoint
- **Verification:**
  ```bash
  jq -e '.name and .metadata.description and (.plugins | length == 1) and (.plugins[0].name == "ai-crew") and .plugins[0].source' .claude-plugin/marketplace.json
  ```
- **Notes:** Structural template is `reference-projects/agent-skills/.claude-plugin/marketplace.json`. Replace owner/repo references with ai-crew specifics. Do NOT copy GitHub repo references unless the user has actually published the plugin.

---

#### T-09: Author `skills/team-lead/SKILL.md`

- **Dependencies:** Wave 1 complete
- **Independence:** [Independent] of T-07, T-08, T-10..T-15
- **Files touched:** `skills/team-lead/SKILL.md`
- **Acceptance criteria:**
  - [ ] Valid YAML frontmatter: `name: team-lead`, `description: ...` (third-person, then "Use when...")
  - [ ] Six standard sections present: Overview, When to Use, Process, Common Rationalizations, Red Flags, Verification
  - [ ] Process section encodes the full 9-step lifecycle from `docs/team-lead-design.md` § Lifecycle: Intake → Research → Spec → Plan → CHECKPOINT → Build → Verify → Review → Ship
  - [ ] Includes the reference-based dispatch template (~30 lines) verbatim from design doc § "Reference-Based Dispatch"
  - [ ] States the run-state directory: `~/.claude/ai-crew/runs/<YYYY-MM-DD-slug>/` containing `spec.md`, `plan.md`, `progress.md`
  - [ ] States max 3 fix loops policy
  - [ ] Names all 4 review skills used inline: `code-review-and-quality`, `security-and-hardening`, `code-simplification`, `performance-optimization`
  - [ ] Lists which vendored skills the team-lead reads at each phase (Intake → `intake-with-validation`; Spec → `spec-driven-development`; Plan → `planning-and-task-breakdown`; Build → `incremental-implementation` + `test-driven-development`; Ship → `git-workflow-and-versioning` + `shipping-and-launch`)
  - [ ] States: subagents are dispatched via reference-based prompts only; no embedded spec/plan content
  - [ ] No content fabricated beyond what `docs/team-lead-design.md` establishes
- **Verification:**
  ```bash
  head -5 skills/team-lead/SKILL.md | grep -E '^name: team-lead'
  for s in "Overview" "When to Use" "Process" "Common Rationalizations" "Red Flags" "Verification"; do
    grep -q "^## $s" skills/team-lead/SKILL.md || { echo "MISSING: $s"; exit 1; }
  done
  for phase in "Intake" "Research" "Spec" "Plan" "Build" "Verify" "Review" "Ship"; do
    grep -qi "$phase" skills/team-lead/SKILL.md || { echo "MISSING phase: $phase"; exit 1; }
  done
  for s in code-review-and-quality security-and-hardening code-simplification performance-optimization; do
    grep -q "$s" skills/team-lead/SKILL.md || { echo "MISSING review skill: $s"; exit 1; }
  done
  ```

---

#### T-10: Author `skills/intake-with-validation/SKILL.md`

- **Dependencies:** Wave 1 complete
- **Independence:** [Independent] of T-07..T-09, T-11..T-15
- **Files touched:** `skills/intake-with-validation/SKILL.md`
- **Acceptance criteria:**
  - [ ] Valid YAML frontmatter: `name: intake-with-validation`, descriptive `description`
  - [ ] Six standard sections present
  - [ ] Process enforces: ask one question at a time, EVEN when request seems clear
  - [ ] States: intake findings flow directly into `spec.md` (no separate intake artifact)
  - [ ] Provides a small canned question set covering: scope boundaries, success criteria, hard constraints, non-goals
  - [ ] References `spec-driven-development` skill as the next phase
- **Verification:**
  ```bash
  head -5 skills/intake-with-validation/SKILL.md | grep -E '^name: intake-with-validation'
  for s in "Overview" "When to Use" "Process" "Verification"; do
    grep -q "^## $s" skills/intake-with-validation/SKILL.md || { echo "MISSING: $s"; exit 1; }
  done
  grep -q "spec.md" skills/intake-with-validation/SKILL.md
  grep -q "spec-driven-development" skills/intake-with-validation/SKILL.md
  ```

---

#### T-11: Author `skills/mobile-component-testing-with-rntl/SKILL.md`

- **Dependencies:** Wave 1 complete
- **Independence:** [Independent] of T-07..T-10, T-12..T-15
- **Files touched:** `skills/mobile-component-testing-with-rntl/SKILL.md`
- **Acceptance criteria:**
  - [ ] Valid YAML frontmatter: `name: mobile-component-testing-with-rntl`, descriptive `description`
  - [ ] Six standard sections present
  - [ ] References `@testing-library/react-native` as the test library
  - [ ] References `test-driven-development` skill by name; explains how RNTL fits into RED→GREEN
  - [ ] States: RNTL only — no Maestro, no Detox, no e2e (per design doc § Not Doing)
  - [ ] Provides ≥2 concrete RNTL patterns (e.g., `getByRole`/`getByText`, `fireEvent.press`, async with `findBy*`, accessibility queries)
- **Verification:**
  ```bash
  head -5 skills/mobile-component-testing-with-rntl/SKILL.md | grep -E '^name: mobile-component-testing-with-rntl'
  grep -q "@testing-library/react-native" skills/mobile-component-testing-with-rntl/SKILL.md
  grep -q "test-driven-development" skills/mobile-component-testing-with-rntl/SKILL.md
  grep -qi "RED\|GREEN\|failing test" skills/mobile-component-testing-with-rntl/SKILL.md
  ! grep -i "maestro\|detox" skills/mobile-component-testing-with-rntl/SKILL.md
  ```

---

#### T-12: Author `agents/developer.md`

- **Dependencies:** Wave 1 complete
- **Independence:** [Independent] of T-07..T-11, T-13..T-15
- **Files touched:** `agents/developer.md`
- **Acceptance criteria:**
  - [ ] Valid YAML frontmatter with: `name: developer`, `description: ...`, `model: sonnet`, `tools: Read, Write, Edit, Bash, Grep, Glob, Skill`
  - [ ] `tools:` line MUST NOT contain `Agent` or `Task`
  - [ ] System prompt body explicitly states: "You receive ONE task at a time. You read files yourself. You DO NOT have access to Agent or Task tools — you cannot dispatch subagents."
  - [ ] System prompt explains the reference-based prompt format the developer will receive: task ID, plan path, spec path, skills to read, files to touch, acceptance criteria, verification command
  - [ ] Instructs developer to follow `test-driven-development` and `incremental-implementation` skills
  - [ ] Instructs developer to return ONLY a one-line `PASS: …` or `FAIL: …` summary
- **Verification:**
  ```bash
  head -10 agents/developer.md | grep -E '^name: developer'
  head -10 agents/developer.md | grep -E '^model: sonnet'
  head -10 agents/developer.md | grep -E '^tools:.*Read.*Write.*Edit.*Bash.*Grep.*Glob.*Skill'
  ! head -10 agents/developer.md | grep -E '^tools:.*Agent'
  ! head -10 agents/developer.md | grep -E '^tools:.*Task'
  grep -q "test-driven-development" agents/developer.md
  grep -q "incremental-implementation" agents/developer.md
  ```

---

#### T-13: Author `agents/web-researcher.md`

- **Dependencies:** Wave 1 complete
- **Independence:** [Independent] of T-07..T-12, T-14, T-15
- **Files touched:** `agents/web-researcher.md`
- **Acceptance criteria:**
  - [ ] Valid YAML frontmatter with: `name: web-researcher`, `description: ...`, `model: haiku`, `tools: WebFetch, WebSearch, Read, Write`
  - [ ] `tools:` line MUST NOT contain `Agent` or `Task`
  - [ ] System prompt: "You receive ONE focused research question. Return a brief with citations in your final response."
  - [ ] Forbids subagent dispatch explicitly
  - [ ] Output format specified: brief paragraph + bullet list of cited URLs
- **Verification:**
  ```bash
  head -10 agents/web-researcher.md | grep -E '^name: web-researcher'
  head -10 agents/web-researcher.md | grep -E '^model: haiku'
  head -10 agents/web-researcher.md | grep -E '^tools:.*WebFetch.*WebSearch.*Read.*Write'
  ! head -10 agents/web-researcher.md | grep -E '^tools:.*Agent'
  ! head -10 agents/web-researcher.md | grep -E '^tools:.*Task'
  ```

---

#### T-14: Author `hooks/detect-project-type.sh` — **TDD**

- **Dependencies:** Wave 1 complete (T-04 ensures `hooks/` exists)
- **Independence:** [Independent] of T-07..T-13, T-15
- **Files touched:**
  - `hooks/detect-project-type.sh`
  - `hooks/detect-project-type.test.sh` (test harness; kept in repo)
  - `hooks/fixtures/rn/package.json` (test fixture)
  - `hooks/fixtures/nextjs/package.json` (test fixture)
  - `hooks/fixtures/node-ts/package.json` (test fixture)
  - `hooks/fixtures/none/.gitkeep` (empty dir for "no package.json" case)
- **Acceptance criteria:**
  - [ ] **TDD discipline:** Test fixtures + harness written FIRST. Run harness, see RED. Then implement script until GREEN.
  - [ ] Fixture (a) RN: `{"dependencies":{"react-native":"0.74.0"}}`
  - [ ] Fixture (b) Next.js: `{"dependencies":{"next":"14.0.0","react":"18.0.0"}}`
  - [ ] Fixture (c) Node-TS: `{"dependencies":{"typescript":"5.0.0"}}` (no `react-native`, no `next`)
  - [ ] Fixture (d) none: directory with no `package.json`
  - [ ] Test harness asserts the script outputs JSON with `projectType` ∈ {`react-native`, `nextjs`, `node-typescript`, `unknown`}
  - [ ] Script accepts a target directory arg (defaults to `pwd`)
  - [ ] Script handles missing `package.json` → outputs `{"projectType":"unknown"}`
  - [ ] Script is executable (`chmod +x`)
  - [ ] Detection precedence: `react-native` > `next` > `typescript` > `unknown` (RN wins because Expo apps depend on `react`)
  - [ ] Pure POSIX shell preferred; `jq` allowed if needed — document the dependency at the top of the script
- **Verification:**
  ```bash
  test -x hooks/detect-project-type.sh
  bash hooks/detect-project-type.test.sh
  echo $?  # Expected: 0
  ```
- **Notes:** Run-state integration (writing `project-type.json` to the run directory) is OUT of scope for this task — the script just emits to stdout. Wiring it into a session-start hook is a follow-up.

---

#### T-15: Author `.claude/commands/team-lead.md`

- **Dependencies:** Wave 1 complete (T-05 ensures `.claude/commands/` exists)
- **Independence:** [Independent] of T-07..T-14. References the `team-lead` skill by name only — no hard dep on T-09.
- **Files touched:** `.claude/commands/team-lead.md`
- **Acceptance criteria:**
  - [ ] Valid YAML frontmatter with `description: ...`
  - [ ] Body invokes `ai-crew:team-lead` skill (per R3)
  - [ ] Mentions the single human checkpoint (plan approval)
  - [ ] No embedded prompt content — only references the skill
  - [ ] Body length ≤ 30 lines
- **Verification:**
  ```bash
  head -5 .claude/commands/team-lead.md | grep -E '^description: '
  grep -q "ai-crew:team-lead" .claude/commands/team-lead.md
  test "$(wc -l < .claude/commands/team-lead.md)" -le 40  # frontmatter + body
  ```

---

### Checkpoint W2 — Authoring complete

- [ ] All 9 NEW files exist at the paths in the design's file layout (plus marketplace.json per R2)
- [ ] Every NEW skill SKILL.md has valid frontmatter and 6 standard sections
- [ ] Both subagent files declare model + restricted tool list (no `Agent`, no `Task`)
- [ ] No vendored file (Wave 1 outputs, including the T-06 rewrite) was modified during Wave 2

---

### Wave 3 — Validate against design assumptions

Goal: Pre-validate the 7 assumptions in `docs/team-lead-design.md` § "Key Assumptions to Validate". Real-ticket validation (the full form of assumptions 1, 2, 3, 4, 5) is deferred to the first ai-crew run.

---

#### T-16: Validate atomized DAG (assumption 1 + 7 — self-validation of this plan)

- **Dependencies:** Wave 2 complete (so the plan is final)
- **Independence:** [Independent] of T-17..T-22
- **Files touched:** Read-only — `docs/implementation-plan.md`
- **Acceptance criteria:**
  - [ ] Every task has all 6 fields: ID, Dependencies, Independence, Files touched, Acceptance criteria, Verification command
  - [ ] No task touches more than ~6 distinct files (T-14 with fixtures is the largest at 6)
  - [ ] Every task has at least one verification command
  - [ ] No task description contains "and then" / "after that" smell of two tasks fused
  - [ ] Total task count is exactly 22
- **Verification:**
  ```bash
  test "$(grep -c '^#### T-' docs/implementation-plan.md)" -eq 22
  test "$(grep -c '^- \*\*Verification:\*\*' docs/implementation-plan.md)" -eq 22
  test "$(grep -c '^- \*\*Dependencies:\*\*' docs/implementation-plan.md)" -eq 22
  test "$(grep -c '^- \*\*Independence:\*\*' docs/implementation-plan.md)" -eq 22
  ```

---

#### T-17: Validate reference-based dispatch (assumption 2)

- **Dependencies:** T-09, T-12, T-15
- **Independence:** [Independent] of T-16, T-18..T-22
- **Files touched:** Read-only — `skills/team-lead/SKILL.md`, `agents/developer.md`, `.claude/commands/team-lead.md`
- **Acceptance criteria:**
  - [ ] `skills/team-lead/SKILL.md` includes the dispatch template literally
  - [ ] `agents/developer.md` instructs the developer to read files itself, not expect embedded content
  - [ ] No NEW file embeds a > 50-line code/prose block from another file (keeps prompts lean)
- **Verification:**
  ```bash
  grep -A 25 "Skills to read first" skills/team-lead/SKILL.md
  grep -i "read.*yourself\|read the files\|reference.*based" agents/developer.md
  for f in skills/team-lead/SKILL.md agents/developer.md agents/web-researcher.md .claude/commands/team-lead.md; do
    awk '/^```/{flag=!flag; if(flag){n=0} else {if(n>50){print FILENAME": fence > 50 lines"; exit 1}}} flag{n++}' "$f"
  done
  ```

---

#### T-18: Validate inline review coverage (assumption 3)

- **Dependencies:** T-09
- **Independence:** [Independent] of T-16, T-17, T-19..T-22
- **Files touched:** Read-only — `skills/team-lead/SKILL.md`
- **Acceptance criteria:**
  - [ ] All 4 review skills are named in `skills/team-lead/SKILL.md`: `code-review-and-quality`, `security-and-hardening`, `code-simplification`, `performance-optimization`
  - [ ] Each of those 4 skills exists as a vendored directory under `skills/`
  - [ ] team-lead/SKILL.md states: review is inline, no reviewer subagent
- **Verification:**
  ```bash
  for s in code-review-and-quality security-and-hardening code-simplification performance-optimization; do
    grep -q "$s" skills/team-lead/SKILL.md || { echo "missing ref: $s"; exit 1; }
    test -f "skills/$s/SKILL.md" || { echo "vendored skill missing: $s"; exit 1; }
  done
  grep -qi "no reviewer subagent\|reviewer.*inline\|inline.*review" skills/team-lead/SKILL.md
  ```

---

#### T-19: Validate Sonnet developer tool list (assumption 4)

- **Dependencies:** T-12
- **Independence:** [Independent] of T-16..T-18, T-20..T-22
- **Files touched:** Read-only — `agents/developer.md`
- **Acceptance criteria:**
  - [ ] `tools:` frontmatter line lists exactly: `Read, Write, Edit, Bash, Grep, Glob, Skill` (in any order)
  - [ ] `tools:` does NOT contain `Agent` or `Task`
  - [ ] `model: sonnet` is declared
- **Verification:**
  ```bash
  awk '/^tools:/' agents/developer.md
  awk '/^tools:/' agents/developer.md | grep -v Agent | grep -v Task | grep -E "Read.*Write.*Edit.*Bash.*Grep.*Glob.*Skill"
  awk '/^model:/' agents/developer.md | grep -q sonnet
  ```

---

#### T-20: Runtime test of `detect-project-type.sh` (assumption 6)

- **Dependencies:** T-14
- **Independence:** [Independent] of T-16..T-19, T-21, T-22
- **Files touched:** Read-only — runs the test harness from T-14
- **Acceptance criteria:**
  - [ ] All 4 fixture scenarios pass (RN, Next.js, Node-TS, unknown)
  - [ ] Output JSON parseable by `jq`
  - [ ] Exit code is 0 for all valid inputs
- **Verification:**
  ```bash
  bash hooks/detect-project-type.test.sh
  echo $?  # Expected: 0
  ```

---

#### T-21: Validate RNTL slots into TDD (assumption 5)

- **Dependencies:** T-11
- **Independence:** [Independent] of T-16..T-20, T-22
- **Files touched:** Read-only — `skills/mobile-component-testing-with-rntl/SKILL.md`, `skills/test-driven-development/SKILL.md`
- **Acceptance criteria:**
  - [ ] `skills/mobile-component-testing-with-rntl/SKILL.md` references `test-driven-development` by name
  - [ ] Skill body explains RED→GREEN with an RNTL example
  - [ ] No mention of Maestro or Detox as required tooling
  - [ ] Vendored `skills/test-driven-development/SKILL.md` exists
- **Verification:**
  ```bash
  grep -q "test-driven-development" skills/mobile-component-testing-with-rntl/SKILL.md
  grep -qi "RED\|GREEN\|failing test" skills/mobile-component-testing-with-rntl/SKILL.md
  ! grep -i "maestro\|detox" skills/mobile-component-testing-with-rntl/SKILL.md
  test -f skills/test-driven-development/SKILL.md
  ```

---

#### T-22: Cross-reference path resolution + namespace sanity

- **Dependencies:** Wave 2 complete
- **Independence:** [Independent] of T-16..T-21
- **Files touched:** Read-only — every file authored in Wave 2 + the T-06 rewrite output
- **Acceptance criteria:**
  - [ ] Every relative `skills/.../SKILL.md` path mentioned in NEW files resolves to a real file
  - [ ] No NEW file references `reference-projects/agent-skills/` (vendored copies should reference plugin-relative paths)
  - [ ] No `.claude/commands/*.md` file contains `agent-skills:` (T-06 sanity recheck)
  - [ ] Both manifest files (`plugin.json`, `marketplace.json`) load as valid JSON
- **Verification:**
  ```bash
  grep -hoE 'skills/[a-z-]+/SKILL\.md' \
    skills/team-lead/SKILL.md \
    skills/intake-with-validation/SKILL.md \
    skills/mobile-component-testing-with-rntl/SKILL.md \
    | sort -u | while read -r path; do
      test -f "$path" || { echo "DANGLING: $path"; exit 1; }
    done
  ! grep -rn "reference-projects/agent-skills" \
    skills/team-lead skills/intake-with-validation skills/mobile-component-testing-with-rntl \
    agents/developer.md agents/web-researcher.md .claude/commands/team-lead.md \
    .claude-plugin/plugin.json .claude-plugin/marketplace.json
  ! grep -rn "agent-skills:" .claude/commands/
  jq -e . .claude-plugin/plugin.json > /dev/null
  jq -e . .claude-plugin/marketplace.json > /dev/null
  ```

---

### Checkpoint W3 — Plugin ready for first run

- [ ] All 22 tasks pass acceptance criteria
- [ ] All 22 verification commands return success
- [ ] No vendored content was edited at any point EXCEPT the T-06 prefix rewrite in `.claude/commands/*.md`
- [ ] Both manifest files are valid JSON
- [ ] Real-ticket validation deferred to first ai-crew run (covers assumptions 1, 2, 3, 4, 5 in their full form)

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| `cp -R` overwrites pre-existing destination files (e.g., stale state from a prior run) | Med | `diff -rq` after every vendor task fails on any byte difference |
| Vendored skills count discrepancy (design says 20, source has 21) | Low | Vendor literally; documented in this plan; user accepts via this checkpoint |
| `.claude/commands/` source has 7 files, design listed 6 | Low | Same — vendor literally |
| Team-lead skill grows too large for one task | Med | Acceptance criteria bound it: 6 sections + 9 lifecycle phases + 1 dispatch template |
| `detect-project-type.sh` portability across macOS/Linux | Med | TDD with 4 fixtures forces explicit handling; prefer pure POSIX shell |
| Frontmatter `tools:` syntax for subagents may need quoting under Claude Code | Med | T-19 verifies; if runtime rejects the file, fix in a follow-up |
| `using-agent-skills` skill auto-load may conflict with `team-lead` | Low | Both are designed to coexist in agent-skills; team-lead is invoked explicitly via `/team-lead` |
| **T-06 prefix rewrite scope creep** — risk that the rewrite touches unintended files | High → Low | T-06 verification step 4 explicitly diffs `skills/`, `agents/`, `references/`, `hooks/` against source after the rewrite. Any byte change outside `.claude/commands/` is a verification failure. |
| Marketplace.json `source` field — unclear what to use for an unpublished local plugin | Low | Use `{"source":"local"}` for v1; revise when publishing |

---

## Parallelization Summary

- **Wave 1 (T-01..T-06):** T-01..T-05 mutually independent; T-06 sequential after T-05. Practical execution: run T-01..T-05 in one shell, then T-06.
- **Wave 2 (T-07..T-15):** All 9 tasks independent of each other (depend only on Wave 1). Each can run as a separate Sonnet developer dispatch. T-09 (team-lead skill) and T-14 (TDD'd shell script) are the most expensive.
- **Wave 3 (T-16..T-22):** Validation tasks are read-only and independent. Run sequentially in <30 s.

## Verification Summary

- Total tasks: **22** (6 vendor+rewrite + 9 author + 7 validation)
- Total NEW files: **9** (includes marketplace.json per R2)
- Total VENDORED files: **40** (21 skill dirs + 3 agents + 4 references + 5 hooks + 7 commands; commands modified by T-06 only)
- Mandatory human checkpoint: **this plan approval**. After approval, the entire DAG executes without further human input until Wave 3 completes.

---

## Required Before Execution

1. **Approve this revised plan.** All three open questions are now resolved (R1, R2, R3).
2. After approval, Wave 1 begins immediately. No file in `skills/`, `agents/`, `references/`, `hooks/`, `.claude/commands/`, or `.claude-plugin/` is created until approval.
