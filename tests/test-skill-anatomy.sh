#!/usr/bin/env bash
#
# test-skill-anatomy.sh — verify each NEW skill follows agent-skills' standard
# anatomy: YAML frontmatter (name + description), and the six standard sections
# (Overview, When to Use, Process, Common Rationalizations, Red Flags, Verification).
#
# Also verifies content guarantees specific to each NEW skill.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

cd "$PLUGIN_ROOT"

echo "=== Test: NEW skill anatomy ==="

failed=0

NEW_SKILLS=(
  "skills/team-lead/SKILL.md:team-lead"
  "skills/intake-with-validation/SKILL.md:intake-with-validation"
  "skills/mobile-component-testing-with-rntl/SKILL.md:mobile-component-testing-with-rntl"
)

REQUIRED_SECTIONS=(
  "Overview"
  "When to Use"
  "Process"
  "Common Rationalizations"
  "Red Flags"
  "Verification"
)

for entry in "${NEW_SKILLS[@]}"; do
  path="${entry%%:*}"
  expected_name="${entry##*:}"

  if [ ! -f "$path" ]; then
    echo "  [FAIL] missing skill file: $path"
    failed=$((failed + 1))
    continue
  fi

  # Frontmatter checks.
  if head -5 "$path" | grep -q "^name: $expected_name\$"; then
    echo "  [PASS] $path frontmatter name == $expected_name"
  else
    echo "  [FAIL] $path frontmatter name is not $expected_name"
    failed=$((failed + 1))
  fi

  if head -5 "$path" | grep -q "^description: "; then
    echo "  [PASS] $path frontmatter has description"
  else
    echo "  [FAIL] $path frontmatter missing description"
    failed=$((failed + 1))
  fi

  # Section checks.
  for section in "${REQUIRED_SECTIONS[@]}"; do
    if grep -q "^## $section\$" "$path"; then
      :  # silent on each section to keep output short
    else
      echo "  [FAIL] $path missing section: ## $section"
      failed=$((failed + 1))
    fi
  done
  echo "  [PASS] $path has all 6 standard sections"
done

# Skill-specific content guarantees.

# team-lead: 9 lifecycle phases + 4 review skills + dispatch template + using-agent-skills
TEAM_LEAD="skills/team-lead/SKILL.md"
for phase in Intake Research Spec Plan Build Verify Review Ship; do
  if grep -qi "$phase" "$TEAM_LEAD"; then :; else
    echo "  [FAIL] $TEAM_LEAD missing lifecycle phase: $phase"
    failed=$((failed + 1))
  fi
done
echo "  [PASS] $TEAM_LEAD references all 8 lifecycle phases (Intake..Ship)"

for review_skill in code-review-and-quality security-and-hardening code-simplification performance-optimization; do
  if grep -q "$review_skill" "$TEAM_LEAD"; then :; else
    echo "  [FAIL] $TEAM_LEAD missing review skill: $review_skill"
    failed=$((failed + 1))
  fi
done
echo "  [PASS] $TEAM_LEAD references all 4 review skills"

if grep -q "using-agent-skills" "$TEAM_LEAD"; then
  echo "  [PASS] $TEAM_LEAD loads using-agent-skills foundation"
else
  echo "  [FAIL] $TEAM_LEAD does not reference using-agent-skills"
  failed=$((failed + 1))
fi

if grep -q "Skills to read first" "$TEAM_LEAD"; then
  echo "  [PASS] $TEAM_LEAD contains the dispatch template"
else
  echo "  [FAIL] $TEAM_LEAD missing dispatch template"
  failed=$((failed + 1))
fi

# intake-with-validation: must mention spec.md and spec-driven-development.
INTAKE="skills/intake-with-validation/SKILL.md"
if grep -q "spec.md" "$INTAKE"; then
  echo "  [PASS] $INTAKE flows findings into spec.md"
else
  echo "  [FAIL] $INTAKE does not mention spec.md"
  failed=$((failed + 1))
fi
if grep -q "spec-driven-development" "$INTAKE"; then
  echo "  [PASS] $INTAKE references spec-driven-development"
else
  echo "  [FAIL] $INTAKE does not reference spec-driven-development"
  failed=$((failed + 1))
fi

# mobile-component-testing-with-rntl: must mention RNTL + TDD + RED/GREEN, NOT Maestro/Detox as required tooling.
RNTL="skills/mobile-component-testing-with-rntl/SKILL.md"
if grep -q "@testing-library/react-native" "$RNTL"; then
  echo "  [PASS] $RNTL references @testing-library/react-native"
else
  echo "  [FAIL] $RNTL does not reference @testing-library/react-native"
  failed=$((failed + 1))
fi
if grep -q "test-driven-development" "$RNTL"; then
  echo "  [PASS] $RNTL references test-driven-development"
else
  echo "  [FAIL] $RNTL does not reference test-driven-development"
  failed=$((failed + 1))
fi
if grep -qi "RED\|GREEN\|failing test" "$RNTL"; then
  echo "  [PASS] $RNTL references RED/GREEN cycle"
else
  echo "  [FAIL] $RNTL missing RED/GREEN reference"
  failed=$((failed + 1))
fi

if [ "$failed" -gt 0 ]; then
  echo ""
  echo "FAIL: $failed skill anatomy check(s) failed"
  exit 1
fi

echo ""
echo "PASS: NEW skill anatomy verified"
exit 0
