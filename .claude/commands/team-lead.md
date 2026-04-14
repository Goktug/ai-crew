---
description: Run the full ai-crew lifecycle on a request from intake to PR with one human checkpoint at plan approval.
---

Invoke the ai-crew:team-lead skill.

The team-lead skill encodes the full nine-phase lifecycle: Intake → Research → Spec → Plan → CHECKPOINT → Build → Verify → Review → Ship. It runs in this Opus session and dispatches Sonnet developers and Haiku web-researchers under strict 1-level dispatch using reference-based prompts.

There is exactly one human checkpoint: the user must approve `plan.md` before any file is written in Build.

The team-lead skill is responsible for invoking `ai-crew:using-agent-skills` first and then walking every phase via the Skill tool — this wrapper only has to kick it off.
