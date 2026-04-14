#!/usr/bin/env bash
#
# scaffold.sh — create a fresh ts-utility-pack test project at the target dir.
# Copies the starter project, design.md, spec.md, plan.md, and an empty
# progress.md into the target. Sets up .claude/settings.local.json with a
# permissive allow-list for the test run.
#
# Usage: ./scaffold.sh /path/to/target

set -e

TARGET_DIR="${1:?Usage: $0 <target-directory>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

# Copy starter project files (package.json, configs).
cp -R "$SCRIPT_DIR/starter/." .

# Drop in the run artifacts.
cp "$SCRIPT_DIR/design.md" .
cp "$SCRIPT_DIR/spec.md" .
cp "$SCRIPT_DIR/plan.md" .
cat > progress.md <<'EOF'
# ts-utility-pack — progress

Tasks (filled in by the team-lead during Build phase):

- [ ] T-01: slugify(text: string): string  [Independent]
- [ ] T-02: chunk<T>(arr: T[], size: number): T[][]  [Independent]
- [ ] T-03: clamp(value: number, min: number, max: number): number  [Independent]

## Verify
- [ ] All three task verification commands pass
- [ ] All three were dispatched in a single Wave-1 fan-out (parallel)

## Review
- [ ] code-review-and-quality
- [ ] security-and-hardening
- [ ] code-simplification
- [ ] performance-optimization
EOF

# Permissive .claude/settings for the headless test run.
mkdir -p .claude
cat > .claude/settings.local.json <<'SETTINGS'
{
  "permissions": {
    "allow": [
      "Read(**)",
      "Edit(**)",
      "Write(**)",
      "Bash(mkdir:*)",
      "Bash(test:*)",
      "Bash(grep:*)",
      "Bash(cat:*)",
      "Bash(ls:*)",
      "Bash(git:*)"
    ]
  }
}
SETTINGS

# Initialize a git repo so the team-lead can commit RED→GREEN steps if it wants.
git init -q
git add -A
git -c user.email="test@ai-crew.local" -c user.name="ai-crew-test" \
    commit -q -m "scaffold: ts-utility-pack fixture initial state"

echo "Scaffolded ts-utility-pack at: $TARGET_DIR"
