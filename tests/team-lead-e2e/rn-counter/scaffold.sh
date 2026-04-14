#!/usr/bin/env bash
#
# scaffold.sh — create a fresh rn-counter test project at the target dir.
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

# Copy starter project files (package.json, configs, App.tsx stub).
cp -R "$SCRIPT_DIR/starter/." .

# Drop in the run artifacts.
cp "$SCRIPT_DIR/design.md" .
cp "$SCRIPT_DIR/spec.md" .
cp "$SCRIPT_DIR/plan.md" .
cat > progress.md <<'EOF'
# rn-counter — progress

Tasks (filled in by the team-lead during Build phase):

- [ ] T-01: RNTL test for initial render
- [ ] T-02: Counter component skeleton (initial render only)
- [ ] T-03: Add increment + decrement (with RED RNTL tests first)

## Verify
- [ ] All three task verification commands pass

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
    commit -q -m "scaffold: rn-counter fixture initial state"

echo "Scaffolded rn-counter at: $TARGET_DIR"
