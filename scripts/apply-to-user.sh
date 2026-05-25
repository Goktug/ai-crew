#!/usr/bin/env bash
#
# apply-to-user.sh — copy this local dev repo into ~/.claude/plugins so you
# can try in-progress ai-crew changes without merging or publishing.
#
# What it does:
#   Claude Code resolves ai-crew via TWO on-disk locations:
#     1. The cache snapshot at the installPath in installed_plugins.json
#        (currently .../cache/g-plugins-marketplace/ai-crew/<version>/).
#     2. The marketplace clone at
#        .../marketplaces/g-plugins-marketplace/  (a git clone of the
#        marketplace source — for you, that IS the ai-crew repo).
#
#   Skills are sometimes loaded via the plugin loader (1) and sometimes
#   re-read directly from disk via `find` (2). Both must reflect the dev
#   repo for testing to be meaningful.
#
#   This script:
#     - Backs up each target to ".bak.<timestamp>" (once — subsequent runs
#       reuse the existing baseline).
#     - rsyncs the dev repo into both targets, excluding large/local stuff
#       (.git, reference-projects, .code-review-graph, dev workspace files).
#
#   installed_plugins.json is NEVER edited — it's shared across all your
#   plugins and corrupting it would break unrelated installs.
#
# Usage:
#   scripts/apply-to-user.sh             # copy dev repo into both targets
#   scripts/apply-to-user.sh --status    # show what's currently in place
#   scripts/apply-to-user.sh --restore   # remove copies, restore .bak's
#
# After applying, restart Claude Code to pick up the change.
# Run --restore before any /plugin update or marketplace refresh.

set -euo pipefail

PLUGIN_NAME="ai-crew"
MARKETPLACE="g-plugins-marketplace"
PLUGIN_KEY="${PLUGIN_NAME}@${MARKETPLACE}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$REPO_ROOT/.claude-plugin/plugin.json"
[ -f "$MANIFEST" ] || { echo "ERROR: not an ai-crew repo (missing $MANIFEST)" >&2; exit 1; }

DEV_VERSION="$(grep -E '"version"' "$MANIFEST" | head -1 | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"

INSTALLED_JSON="$HOME/.claude/plugins/installed_plugins.json"
CACHE_DIR="$HOME/.claude/plugins/cache/$MARKETPLACE/$PLUGIN_NAME"
MARKETPLACE_CLONE="$HOME/.claude/plugins/marketplaces/$MARKETPLACE"

# Read the active installPath for ai-crew from installed_plugins.json without
# requiring jq. Returns empty string if not found.
active_install_path() {
  [ -f "$INSTALLED_JSON" ] || return 0
  grep -A 5 "\"$PLUGIN_KEY\"" "$INSTALLED_JSON" 2>/dev/null \
    | grep '"installPath"' \
    | head -1 \
    | sed -E 's/.*"installPath"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/'
}

ACTIVE_PATH="$(active_install_path || true)"
if [ -n "$ACTIVE_PATH" ]; then
  ACTIVE_VERSION="$(basename "$ACTIVE_PATH")"
  CACHE_TARGET="$ACTIVE_PATH"
else
  ACTIVE_VERSION=""
  CACHE_TARGET="$CACHE_DIR/$DEV_VERSION"
fi

TARGETS=("$CACHE_TARGET" "$MARKETPLACE_CLONE")

RSYNC_EXCLUDES=(
  --exclude='.git/'
  --exclude='.code-review-graph/'
  --exclude='reference-projects/'
  --exclude='node_modules/'
  --exclude='.agents/'
  --exclude='.claude/worktrees/'
  --exclude='.claude/settings.json'
  --exclude='.mcp.json'
  --exclude='skills-lock.json'
  --exclude='.DS_Store'
)

latest_backup() {
  ls -td "$1".bak.* 2>/dev/null | head -1 || true
}

describe_target() {
  local target="$1"
  if [ -L "$target" ]; then
    echo "SYMLINK → $(readlink "$target")"
  elif [ -d "$target" ]; then
    if [ -f "$target/.applied-from-dev" ]; then
      echo "COPY of dev repo (applied $(cat "$target/.applied-from-dev"))"
    else
      echo "real directory (untouched)"
    fi
  elif [ -e "$target" ]; then
    echo "non-directory file"
  else
    echo "missing"
  fi
}

status() {
  echo "Dev repo:        $REPO_ROOT"
  echo "Dev version:     $DEV_VERSION (from .claude-plugin/plugin.json)"
  if [ -n "$ACTIVE_VERSION" ]; then
    echo "Active version:  $ACTIVE_VERSION (from installed_plugins.json)"
  else
    echo "Active version:  <not installed — run '/plugin install ${PLUGIN_KEY}' first>"
  fi
  echo ""
  for target in "${TARGETS[@]}"; do
    echo "Target:          $target"
    echo "  State:         $(describe_target "$target")"
    bak="$(latest_backup "$target")"
    if [ -n "$bak" ]; then
      echo "  Latest backup: $bak"
    fi
    echo ""
  done
}

apply_one() {
  local target="$1"
  mkdir -p "$(dirname "$target")"

  if [ -L "$target" ]; then
    echo "Removing existing symlink: $target"
    rm "$target"
  elif [ -d "$target" ]; then
    if [ -f "$target/.applied-from-dev" ]; then
      echo "Clearing previous dev-copy at: $target"
      rm -rf "$target"
    else
      backup="$target.bak.$(date +%Y%m%d-%H%M%S)"
      echo "Backing up untouched install: $target → $backup"
      mv "$target" "$backup"
    fi
  fi

  mkdir -p "$target"
  rsync -a "${RSYNC_EXCLUDES[@]}" "$REPO_ROOT/" "$target/"
  date -u +%Y-%m-%dT%H:%M:%SZ > "$target/.applied-from-dev"
  echo "Copied dev repo → $target"
}

apply() {
  if [ -z "$ACTIVE_PATH" ]; then
    echo "ERROR: ai-crew is not installed via marketplace '$MARKETPLACE'." >&2
    echo "Install it first: /plugin install ${PLUGIN_KEY}" >&2
    exit 1
  fi

  for target in "${TARGETS[@]}"; do
    apply_one "$target"
  done

  echo ""
  echo "Done. Restart Claude Code to pick up the dev copy."
  echo "Run 'scripts/apply-to-user.sh --restore' before any /plugin update."
}

restore_one() {
  local target="$1"
  local bak
  bak="$(latest_backup "$target")"

  if [ -L "$target" ]; then
    rm "$target"
    echo "Removed symlink: $target"
  elif [ -d "$target" ]; then
    if [ -f "$target/.applied-from-dev" ]; then
      rm -rf "$target"
      echo "Removed dev-copy at: $target"
    else
      echo "WARNING: $target is a real directory without .applied-from-dev sentinel."
      echo "         Leaving it alone to avoid destroying unrelated content."
      return
    fi
  fi

  if [ -n "$bak" ] && [ -e "$bak" ]; then
    mv "$bak" "$target"
    echo "Restored backup: $bak → $target"
  else
    echo "No backup found for: $target"
    echo "If Claude Code can't find ai-crew, reinstall from the marketplace:"
    echo "  /plugin install ${PLUGIN_KEY}"
  fi
}

restore() {
  for target in "${TARGETS[@]}"; do
    restore_one "$target"
  done
  echo ""
  echo "Restart Claude Code to pick up the restore."
}

cmd="${1:-apply}"
case "$cmd" in
  --status|status)   status ;;
  --restore|restore) restore ;;
  apply|--apply|"")  apply ;;
  -h|--help|help)
    sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'
    ;;
  *)
    echo "Unknown command: $cmd" >&2
    echo "Try: $0 --help" >&2
    exit 2
    ;;
esac
