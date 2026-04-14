#!/usr/bin/env bash
#
# test-skill-description-length.sh — enforce Claude Code's 250-character
# limit on `description:` fields inside SKILL.md frontmatter.
#
# Failure policy:
#   - NEW skills (skills we authored in this repo): FAIL the test if any
#     description exceeds 250 characters. We can fix our own.
#   - Vendored skills (one-time copies of agent-skills): WARN only. Per
#     CLAUDE.md non-negotiable #5, vendored content is never edited — so
#     we can't fix overlong upstream descriptions even if we wanted to.
#     The warning surfaces them so we can file an upstream issue.
#
# Note on the limit: Claude Code's plugin loader trims/rejects descriptions
# longer than ~250 characters. Anything over that is a runtime risk: the
# skill may not register cleanly or may have its description truncated.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

cd "$PLUGIN_ROOT"

LIMIT=250

# Skills we authored in this repo. Anything else under skills/ is vendored.
NEW_SKILLS=(
  "skills/team-lead/SKILL.md"
  "skills/intake-with-validation/SKILL.md"
  "skills/mobile-component-testing-with-rntl/SKILL.md"
)

is_new_skill() {
  local path="$1"
  local entry
  for entry in "${NEW_SKILLS[@]}"; do
    if [ "$entry" = "$path" ]; then
      return 0
    fi
  done
  return 1
}

echo "=== Test: SKILL.md description length ≤ $LIMIT chars ==="
echo ""

failed=0
warned=0
checked=0

for f in skills/*/SKILL.md; do
  checked=$((checked + 1))

  # Extract the description value from the YAML frontmatter. Grabs the first
  # `description:` line and strips the key+spaces. If the value spans
  # multiple lines (folded YAML) this only catches the first physical line —
  # acceptable trade-off for a static check; folded descriptions are rare
  # in agent-skills and would also be a smell.
  desc="$(awk '/^description:/{sub(/^description:[[:space:]]*/, ""); print; exit}' "$f")"
  len="${#desc}"

  if [ "$len" -le "$LIMIT" ]; then
    if is_new_skill "$f"; then
      printf "  [PASS] %4d chars  %s (NEW)\n" "$len" "$f"
    fi
    # Vendored skills under the limit are silent — they're the common case.
    continue
  fi

  # Over the limit.
  if is_new_skill "$f"; then
    printf "  [FAIL] %4d chars  %s (NEW — exceeds %d)\n" "$len" "$f" "$LIMIT"
    printf "         description: %s\n" "$desc"
    failed=$((failed + 1))
  else
    printf "  [WARN] %4d chars  %s (vendored — exceeds %d, cannot fix per non-negotiable #5)\n" "$len" "$f" "$LIMIT"
    warned=$((warned + 1))
  fi
done

echo ""
echo "Checked: $checked SKILL.md files (limit: $LIMIT chars)"
echo "Failed:  $failed (NEW skills exceeding limit)"
echo "Warned:  $warned (vendored skills exceeding limit — upstream issue)"

if [ "$failed" -gt 0 ]; then
  echo ""
  echo "FAIL: $failed NEW skill description(s) exceed $LIMIT chars — shorten them."
  exit 1
fi

echo ""
echo "PASS: every NEW skill description is within the $LIMIT char limit"
exit 0
