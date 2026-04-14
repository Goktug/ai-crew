#!/usr/bin/env bash
# detect-project-type.sh — classifies a project directory by inspecting its package.json
#
# Output: a single JSON object on stdout, e.g. {"projectType":"react-native"}
# Exit code: 0 on success (including "unknown")
#
# Usage:
#   detect-project-type.sh                  # uses current working directory
#   detect-project-type.sh /path/to/repo    # uses the given directory
#
# Detection precedence (highest first):
#   1. react-native     — package.json has "react-native" in dependencies or devDependencies
#   2. nextjs           — package.json has "next"         in dependencies or devDependencies
#   3. node-typescript  — package.json has "typescript"   in dependencies or devDependencies
#   4. unknown          — no package.json, or none of the above
#
# Pure POSIX shell. No jq, no node, no python required.
# Designed to be run as a Claude Code session-start hook in the ai-crew plugin.

set -e

target_dir="${1:-$PWD}"
pkg="$target_dir/package.json"

emit() {
  printf '{"projectType":"%s"}\n' "$1"
}

if [ ! -f "$pkg" ]; then
  emit "unknown"
  exit 0
fi

# Look for "react-native": in any dependency block. The trailing colon ensures we
# match a JSON key, not a substring inside a value or another package name (e.g.
# "react-native-svg" would be caught by a bare "react-native" search but not by
# "react-native":).
if grep -q '"react-native"[[:space:]]*:' "$pkg"; then
  emit "react-native"
  exit 0
fi

if grep -q '"next"[[:space:]]*:' "$pkg"; then
  emit "nextjs"
  exit 0
fi

if grep -q '"typescript"[[:space:]]*:' "$pkg"; then
  emit "node-typescript"
  exit 0
fi

emit "unknown"
exit 0
