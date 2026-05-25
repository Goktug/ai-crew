#!/usr/bin/env bash
#
# apply-to-user.sh — symlink this local dev repo into ~/.claude/plugins so you
# can try in-progress ai-crew changes without merging or publishing.
#
# How it works:
#   Claude Code loads ai-crew from the installPath recorded in
#   ~/.claude/plugins/installed_plugins.json (currently
#   .../cache/g-plugins-marketplace/ai-crew/<version>/).
#
#   This script replaces that directory with a symlink to your dev repo,
#   after backing the original up as ".bak.<timestamp>".
#
#   installed_plugins.json is NEVER edited — it's shared across all your
#   plugins and corrupting it would break unrelated installs.
#
# Usage:
#   scripts/apply-to-user.sh             # link the dev repo as the active version
#   scripts/apply-to-user.sh --status    # show what's currently active
#   scripts/apply-to-user.sh --restore   # remove the symlink, restore the latest .bak
#
# After applying, restart Claude Code to pick up the linked dev version.

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

# Read the active installPath for ai-crew from installed_plugins.json without
# requiring jq or gawk. Returns empty string if not found.
active_install_path() {
  [ -f "$INSTALLED_JSON" ] || return 0
  grep -A 5 "\"$PLUGIN_KEY\"" "$INSTALLED_JSON" 2>/dev/null \
    | grep '"installPath"' \
    | head -1 \
    | sed -E 's/.*"installPath"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/'
}

ACTIVE_PATH="$(active_install_path || true)"
if [ -z "$ACTIVE_PATH" ]; then
  ACTIVE_VERSION=""
  LINK_PATH="$CACHE_DIR/$DEV_VERSION"
else
  ACTIVE_VERSION="$(basename "$ACTIVE_PATH")"
  LINK_PATH="$ACTIVE_PATH"
fi

cmd="${1:-apply}"

status() {
  echo "Dev repo:        $REPO_ROOT"
  echo "Dev version:     $DEV_VERSION (from .claude-plugin/plugin.json)"
  if [ -n "$ACTIVE_VERSION" ]; then
    echo "Active version:  $ACTIVE_VERSION (from installed_plugins.json)"
  else
    echo "Active version:  <not installed — run '/plugin install ${PLUGIN_KEY}' first>"
  fi
  echo "Target path:     $LINK_PATH"
  if [ -L "$LINK_PATH" ]; then
    echo "State:           LINKED → $(readlink "$LINK_PATH")"
  elif [ -d "$LINK_PATH" ]; then
    echo "State:           real directory (not linked to dev)"
  else
    echo "State:           missing"
  fi
  if [ "$ACTIVE_VERSION" != "" ] && [ "$ACTIVE_VERSION" != "$DEV_VERSION" ]; then
    echo ""
    echo "Note: active version ($ACTIVE_VERSION) differs from dev version ($DEV_VERSION)."
    echo "      The symlink uses the active path so Claude Code actually picks it up."
  fi
  echo ""
  echo "All versions cached in $CACHE_DIR:"
  if [ -d "$CACHE_DIR" ]; then
    ls -la "$CACHE_DIR" 2>/dev/null | tail -n +2 || true
  else
    echo "  (cache dir does not exist yet)"
  fi
}

apply() {
  if [ -z "$ACTIVE_PATH" ]; then
    echo "ERROR: ai-crew is not installed via marketplace '$MARKETPLACE'." >&2
    echo "Install it first:" >&2
    echo "  /plugin install ${PLUGIN_KEY}" >&2
    exit 1
  fi

  mkdir -p "$CACHE_DIR"

  if [ -L "$LINK_PATH" ]; then
    current="$(readlink "$LINK_PATH")"
    if [ "$current" = "$REPO_ROOT" ]; then
      echo "Already linked to $REPO_ROOT — nothing to do."
      return
    fi
    echo "Refreshing symlink (was → $current)"
    rm "$LINK_PATH"
  elif [ -e "$LINK_PATH" ]; then
    backup="$LINK_PATH.bak.$(date +%Y%m%d-%H%M%S)"
    echo "Backing up existing install:"
    echo "  $LINK_PATH"
    echo "  → $backup"
    mv "$LINK_PATH" "$backup"
  fi

  ln -s "$REPO_ROOT" "$LINK_PATH"
  echo "Linked: $LINK_PATH → $REPO_ROOT"
  echo ""
  echo "Active version stays $ACTIVE_VERSION (per installed_plugins.json),"
  echo "but its contents are now your dev repo at $DEV_VERSION."
  echo ""
  echo "Done. Restart Claude Code to pick up the linked dev version."
  echo "Run 'scripts/apply-to-user.sh --restore' to revert."
}

restore() {
  if [ ! -L "$LINK_PATH" ]; then
    echo "No symlink at $LINK_PATH — nothing to restore."
    return
  fi
  rm "$LINK_PATH"
  echo "Removed symlink: $LINK_PATH"

  # Find the newest backup and restore it.
  latest_bak="$(ls -td "$LINK_PATH".bak.* 2>/dev/null | head -1 || true)"
  if [ -n "$latest_bak" ] && [ -e "$latest_bak" ]; then
    mv "$latest_bak" "$LINK_PATH"
    echo "Restored backup: $latest_bak → $LINK_PATH"
  else
    echo "No backup found. The cache path is now missing — if Claude Code can't"
    echo "find ai-crew, re-install from the marketplace:"
    echo "  /plugin install ai-crew@$MARKETPLACE"
  fi
  echo ""
  echo "Restart Claude Code to pick up the change."
}

case "$cmd" in
  --status|status)   status ;;
  --restore|restore) restore ;;
  apply|--apply|"")  apply ;;
  -h|--help|help)
    sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
    ;;
  *)
    echo "Unknown command: $cmd" >&2
    echo "Try: $0 --help" >&2
    exit 2
    ;;
esac
