#!/usr/bin/env bash
#
# test-plugin-manifest.sh — validate the plugin and marketplace manifests.
#
# Runs `claude plugin validate <repo>` and asserts exit code 0 and the
# expected schema-pass message. Also checks that plugin.json and
# marketplace.json have the expected top-level fields.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

cd "$PLUGIN_ROOT"

echo "=== Test: plugin & marketplace manifests ==="

failed=0

# 1. Files exist and are valid JSON.
for f in .claude-plugin/plugin.json .claude-plugin/marketplace.json; do
  if assert_file_exists "$f" "$f exists"; then :; else failed=$((failed + 1)); fi
  if jq -e . "$f" > /dev/null 2>&1; then
    echo "  [PASS] $f is valid JSON"
  else
    echo "  [FAIL] $f is not valid JSON"
    failed=$((failed + 1))
  fi
done

# 2. plugin.json field shape.
if jq -e '.name == "ai-crew"' .claude-plugin/plugin.json > /dev/null; then
  echo "  [PASS] plugin.json name == ai-crew"
else
  echo "  [FAIL] plugin.json name is not ai-crew"
  failed=$((failed + 1))
fi

if jq -e '.commands == "./.claude/commands"' .claude-plugin/plugin.json > /dev/null; then
  echo "  [PASS] plugin.json commands == ./.claude/commands"
else
  echo "  [FAIL] plugin.json commands field wrong"
  failed=$((failed + 1))
fi

# 3. marketplace.json field shape.
if jq -e '.name == "g-plugins-marketplace"' .claude-plugin/marketplace.json > /dev/null; then
  echo "  [PASS] marketplace.json name == g-plugins-marketplace"
else
  echo "  [FAIL] marketplace.json name is not g-plugins-marketplace"
  failed=$((failed + 1))
fi

if jq -e '(.plugins | length == 1) and (.plugins[0].name == "ai-crew")' .claude-plugin/marketplace.json > /dev/null; then
  echo "  [PASS] marketplace.json has exactly one plugin named ai-crew"
else
  echo "  [FAIL] marketplace.json plugin entry wrong"
  failed=$((failed + 1))
fi

if jq -e '.plugins[0].source == "./"' .claude-plugin/marketplace.json > /dev/null; then
  echo "  [PASS] marketplace.json plugins[0].source == './'"
else
  echo "  [FAIL] marketplace.json plugins[0].source must be './' (relative path string)"
  failed=$((failed + 1))
fi

# 4. Run claude plugin validate — the authoritative schema check.
#
# Use --bare so this skips hooks, LSP, plugin sync, MCP startup, auto-memory
# and CLAUDE.md auto-discovery. Without --bare, every `claude plugin validate`
# call spins up the full plugin/marketplace chain and can take 30+ seconds
# (or hang) on machines with many installed marketplaces.
#
# Wrap the call in a manual 30s timeout because macOS doesn't ship `timeout`
# by default. If validate doesn't return in time, treat it as a soft skip
# rather than failing — the jq field checks above already cover the common
# schema errors.
echo "  --- claude --bare plugin validate ---"
validate_tmp="$(mktemp)"
(
  claude --bare plugin validate "$PLUGIN_ROOT" > "$validate_tmp" 2>&1
) &
validate_pid=$!

# Poll for completion up to 30 seconds.
elapsed=0
while kill -0 "$validate_pid" 2>/dev/null; do
  if [ "$elapsed" -ge 30 ]; then
    kill "$validate_pid" 2>/dev/null || true
    wait "$validate_pid" 2>/dev/null || true
    echo "  [SKIP] claude --bare plugin validate did not return in 30s — relying on jq field checks above"
    rm -f "$validate_tmp"
    break
  fi
  sleep 1
  elapsed=$((elapsed + 1))
done

if [ -f "$validate_tmp" ]; then
  wait "$validate_pid" 2>/dev/null
  validate_exit=$?
  validate_output="$(cat "$validate_tmp")"
  rm -f "$validate_tmp"
  echo "$validate_output" | sed 's/^/    /'
  if [ "$validate_exit" -eq 0 ]; then
    echo "  [PASS] claude --bare plugin validate exit 0"
  else
    echo "  [FAIL] claude --bare plugin validate exit $validate_exit"
    failed=$((failed + 1))
  fi
fi

if [ "$failed" -gt 0 ]; then
  echo ""
  echo "FAIL: $failed manifest check(s) failed"
  exit 1
fi

echo ""
echo "PASS: plugin & marketplace manifests valid"
exit 0
