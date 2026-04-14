---
description: Run the full ai-crew lifecycle on a request from intake to PR with one human checkpoint at plan approval.
---

Invoke the ai-crew:team-lead skill.

The team-lead skill encodes the full nine-phase lifecycle: Intake → Research → Spec → Plan → CHECKPOINT → Build → Verify → Review → Ship. It runs in this Opus session and dispatches Sonnet developers and Haiku web-researchers under strict 1-level dispatch using reference-based prompts.

There is exactly one human checkpoint: the user must approve `plan.md` before any file is written in Build.

Begin by reading `<plugin>/skills/using-agent-skills/SKILL.md` and `<plugin>/skills/team-lead/SKILL.md`, then proceed to Phase 1 (Intake).
