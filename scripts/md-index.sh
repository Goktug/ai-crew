#!/usr/bin/env bash
#
# md-index.sh — compute a line-range index for spec.md or plan.md.
#
# Used by the ai-crew team-lead to avoid hand-counting line numbers when writing
# the Section Index (spec.md) or Task Index (plan.md). Cites from the index let
# developer dispatches read only the slices they need instead of the whole file.
#
# Usage:
#   md-index.sh --sections <file>          print a Section Index table to stdout
#   md-index.sh --tasks    <file>          print a Task Index table to stdout
#   md-index.sh --sections --inject <file> inject/refresh the Section Index into <file>
#   md-index.sh --tasks    --inject <file> inject/refresh the Task Index into <file>
#
# Conventions (matches skills/team-lead/SKILL.md):
#   --sections matches ^## / ^### headings, labels each by its heading text.
#   --tasks    matches ^### T-NNN headings, labels each by the task ID alone
#              (any trailing colon or description is stripped).
#   --inject places the table between the sentinels
#       <!-- md-index:start -->
#       <!-- md-index:end -->
#     If the sentinels already exist, the existing block is stripped first; the
#     block is then re-inserted immediately after the h1 title. The same
#     deterministic code path handles first-insert and refresh.

set -euo pipefail

MODE=""
INJECT=0
FILE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --sections) MODE="sections"; shift ;;
    --tasks)    MODE="tasks";    shift ;;
    --inject)   INJECT=1;        shift ;;
    -h|--help)
      sed -n '3,26p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*) echo "Unknown option: $1" >&2; exit 2 ;;
    *)
      if [[ -z "$FILE" ]]; then FILE="$1"; shift
      else echo "Unexpected extra argument: $1" >&2; exit 2
      fi
      ;;
  esac
done

if [[ -z "$MODE" ]]; then
  echo "Error: must pass --sections or --tasks" >&2; exit 2
fi
if [[ -z "$FILE" ]]; then
  echo "Error: missing file argument" >&2; exit 2
fi
if [[ ! -f "$FILE" ]]; then
  echo "Error: file not found: $FILE" >&2; exit 2
fi

START_SENTINEL="<!-- md-index:start -->"
END_SENTINEL="<!-- md-index:end -->"

build_table() {
  local file="$1" mode="$2"
  local pattern title_col
  if [[ "$mode" == "sections" ]]; then
    pattern='^## |^### '
    title_col="Section"
  else
    pattern='^### T-[0-9]+'
    title_col="Task"
  fi

  awk -v pat="$pattern" -v mode="$mode" -v title_col="$title_col" '
    BEGIN {
      printf "## %s Index\n\n", (mode == "sections" ? "Section" : "Task")
      printf "| %s | Lines |\n|---|---|\n", title_col
      prev_label = ""; prev_start = 0
    }
    function emit(end_line,    label) {
      if (prev_start > 0) {
        label = prev_label
        sub(/^#+ +/, "", label)
        if (mode == "tasks") {
          sub(/[ \t].*$/, "", label)
          sub(/[:.,;]+$/, "", label)
        }
        printf "| %s | %d-%d |\n", label, prev_start, end_line
      }
    }
    $0 ~ pat {
      emit(NR - 1)
      prev_label = $0
      prev_start = NR
    }
    END { emit(NR) }
  ' "$file"
}

if [[ "$INJECT" -eq 0 ]]; then
  build_table "$FILE" "$MODE"
  exit 0
fi

# --- Inject path (single unified code path). ---
#
# 1. Strip any existing block so we always compute against a clean baseline.
# 2. Build the table from the stripped file. Line numbers in the table are
#    stripped-file line numbers.
# 3. Compute the final block size (5 + N table lines — see layout below) and
#    shift every range in the table by +block_size, because the block will be
#    inserted above every heading and thus pushes every heading down by that
#    amount in the final file.
# 4. Insert the block after the first h1 title line and its following blank.
#
# Block layout (6 framing lines + N table lines):
#   <!-- md-index:start -->
#   (blank)
#   N table lines (the build_table output)
#   (blank)
#   <!-- md-index:end -->
#   (blank)

TMP_STRIPPED=$(mktemp)
TMP_TABLE=$(mktemp)
TMP_OUT=$(mktemp)
trap 'rm -f "$TMP_STRIPPED" "$TMP_TABLE" "$TMP_OUT"' EXIT

if grep -qF "$START_SENTINEL" "$FILE" && grep -qF "$END_SENTINEL" "$FILE"; then
  # Strip the sentinel block AND the single blank line that followed the end
  # sentinel on insertion. Without this second strip, re-injection would
  # accumulate one extra blank per run and break idempotency.
  awk -v s="$START_SENTINEL" -v e="$END_SENTINEL" '
    index($0, s)                 { in_block = 1; next }
    in_block && index($0, e)     { in_block = 0; just_ended = 1; next }
    in_block                     { next }
    just_ended && $0 == ""       { just_ended = 0; next }
    { just_ended = 0; print }
  ' "$FILE" > "$TMP_STRIPPED"
else
  cp "$FILE" "$TMP_STRIPPED"
fi

build_table "$TMP_STRIPPED" "$MODE" > "$TMP_TABLE"

TABLE_LINES=$(wc -l < "$TMP_TABLE" | tr -d ' ')
# The block occupies TABLE_LINES + 5 lines in the final file:
#   1 start sentinel + 1 blank + TABLE_LINES + 1 blank + 1 end sentinel + 1 trailing blank.
# Every heading in the stripped file is below the h1 title (and thus below the
# block's insertion point), so every heading shifts by SHIFT lines.
SHIFT=$((TABLE_LINES + 5))

awk -v d="$SHIFT" '
  /\| [0-9]+-[0-9]+ \|/ {
    match($0, /[0-9]+-[0-9]+/)
    r = substr($0, RSTART, RLENGTH)
    split(r, parts, "-")
    new_r = (parts[1] + d) "-" (parts[2] + d)
    sub(/[0-9]+-[0-9]+/, new_r)
  }
  { print }
' "$TMP_TABLE" > "$TMP_TABLE.fixed"
mv "$TMP_TABLE.fixed" "$TMP_TABLE"

awk -v s="$START_SENTINEL" -v e="$END_SENTINEL" -v tf="$TMP_TABLE" '
  BEGIN { inserted = 0; saw_title = 0 }
  {
    print
    if (!inserted && !saw_title && $0 ~ /^# /) {
      saw_title = 1
      next
    }
    if (!inserted && saw_title && $0 ~ /^$/) {
      print s
      print ""
      while ((getline line < tf) > 0) print line
      close(tf)
      print ""
      print e
      print ""
      inserted = 1
    }
  }
  END {
    if (!inserted) {
      print ""
      print s
      print ""
      while ((getline line < tf) > 0) print line
      close(tf)
      print ""
      print e
    }
  }
' "$TMP_STRIPPED" > "$TMP_OUT"
mv "$TMP_OUT" "$FILE"
