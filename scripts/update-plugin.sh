#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/update-plugin.sh <plugin-name> [--bump patch|minor|major|none]
  scripts/update-plugin.sh --all [--bump patch|minor|major|none]

Run this after editing, creating, or deleting a Cofoundy plugin skill/command/agent/hook.

It updates plugin.meta.json, regenerates runtime manifests, validates drift, refreshes
the Claude Code cache, and refreshes the Codex plugin cache when the CLI is available.

CAVEAT: marketplace.json is regenerated from ALL local plugin.meta.json files. If any
plugin repo's local checkout is stale (behind its remote), this SILENTLY DOWNGRADES that
plugin's version in the manifest. Always `git pull` every plugin repo before regenerating,
or the manifest will regress entries you didn't touch. (Bit us 2026-06-08: founders
0.9.52 → 0.9.51.)

PREFLIGHT: the bump target is checked against the Claude cache BEFORE anything is
mutated. A bump whose target version is already published aborts here with exit 3 —
see the comment on preflight_cache_collision().

Env overrides (optional, for testing against a throwaway cache):
  SYNC_PLUGIN_CLAUDE_HOME   default $HOME/.claude
  SYNC_PLUGIN_CACHE_ROOT    default <claude-home>/plugins/cache/cofoundy
  SYNC_PLUGIN_FORCE=1       proceed despite a colliding bump target (dangerous)
USAGE
}

MARKETPLACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGINS_DIR="${MARKETPLACE_DIR}/plugins"
MANIFESTS="${MARKETPLACE_DIR}/scripts/plugin-manifests.py"
SYNC_PLUGIN="${MARKETPLACE_DIR}/plugins/cofoundy-toolkit/scripts/sync-plugin.sh"
CLAUDE_HOME="${SYNC_PLUGIN_CLAUDE_HOME:-$HOME/.claude}"
CACHE_ROOT="${SYNC_PLUGIN_CACHE_ROOT:-$CLAUDE_HOME/plugins/cache/cofoundy}"
BUMP="patch"
ALL=0
PLUGINS=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --all)
      ALL=1
      shift
      ;;
    --bump)
      BUMP="${2:-}"
      shift 2
      ;;
    --bump=*)
      BUMP="${1#--bump=}"
      shift
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      PLUGINS+=("$1")
      shift
      ;;
  esac
done

case "$BUMP" in
  patch|minor|major|none) ;;
  *)
    echo "Invalid --bump value: $BUMP" >&2
    usage >&2
    exit 2
    ;;
esac

if [ "$ALL" -eq 1 ] && [ "${#PLUGINS[@]}" -gt 0 ]; then
  echo "Use either --all or explicit plugin names, not both." >&2
  exit 2
fi

if [ "$ALL" -eq 0 ] && [ "${#PLUGINS[@]}" -eq 0 ]; then
  usage >&2
  exit 2
fi

if [ "$ALL" -eq 1 ]; then
  while IFS= read -r plugin_dir; do
    PLUGINS+=("$(basename "$plugin_dir")")
  done < <(find "$PLUGINS_DIR" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) | sort)
fi

plugin_dir_for() {
  local plugin="$1"
  local path="${PLUGINS_DIR}/${plugin}"
  if [ ! -e "$path" ]; then
    echo "Plugin not found under marketplace plugins/: $plugin" >&2
    return 1
  fi
  realpath "$path"
}

# Refuse a bump whose target version is ALREADY PUBLISHED in the Claude cache.
#
# The bump is computed purely from plugin.meta.json and never looked at what the
# cache already holds. So a desynced manifest (meta 0.11.0 while the cache had
# 0.12.0 published) aimed `--bump minor` straight at a live version, and
# sync-plugin.sh's `cp -r` overwrote it — v0.12.0 then meant two different things
# depending on when you looked (cofoundy-orchestrator#71).
#
# This check lives HERE, before any mutation, on purpose: sync-plugin.sh also
# guards (it protects direct callers, and it can compare content, which we can't
# yet), but by the time it runs the manifest has already been bumped, the runtime
# manifests regenerated, and marketplace.json rewritten — a half-applied commit
# the operator has to unwind by hand. Early = nothing to unwind. Late = complete
# coverage. Both are wanted; neither alone is enough.
#
# Unlike sync-plugin.sh's guard, this one is content-blind and NEEDS to be: a
# bump means "publish a NEW version". If its target already exists, the manifest
# is desynced from the cache, and that is an error whatever the bytes say.
preflight_cache_collision() {
  local plugin="$1"
  local plugin_dir="$2"
  local bump="$3"
  # --bump none publishes the CURRENT version: re-syncing an unchanged version is
  # legitimately idempotent, so that case belongs to sync-plugin.sh's content-aware
  # check, not here.
  if [ "$bump" = "none" ]; then
    return 0
  fi
  # No manifest yet → nothing published yet; init-meta runs in the loop below.
  if [ ! -f "${plugin_dir}/plugin.meta.json" ]; then
    return 0
  fi

  PLUGIN="$plugin" PLUGIN_DIR="$plugin_dir" BUMP="$bump" \
  CACHE_DIR="${CACHE_ROOT}/${plugin}" FORCE="${SYNC_PLUGIN_FORCE:-0}" python3 - <<'PY'
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

SEMVER = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")

plugin = os.environ["PLUGIN"]
meta_path = Path(os.environ["PLUGIN_DIR"]) / "plugin.meta.json"
bump = os.environ["BUMP"]
cache_dir = Path(os.environ["CACHE_DIR"])
force = os.environ.get("FORCE") == "1"

version = json.loads(meta_path.read_text()).get("version")
if not isinstance(version, str) or not SEMVER.match(version):
    # bump_meta raises on this with a better message; don't duplicate the error.
    sys.exit(0)

major, minor, patch = (int(part) for part in version.split("."))
if bump == "major":
    target = f"{major + 1}.0.0"
elif bump == "minor":
    target = f"{major}.{minor + 1}.0"
else:
    target = f"{major}.{minor}.{patch + 1}"

published = sorted(
    (e.name for e in cache_dir.iterdir() if SEMVER.match(e.name)),
    key=lambda v: [int(n) for n in v.split(".")],
) if cache_dir.is_dir() else []

if target not in published:
    # Not a collision, but still worth saying out loud: publishing BELOW the
    # newest cached version is the same manifest desync one step earlier, and
    # the next bump in that direction is the one that collides.
    if published:
        newest = published[-1]
        if [int(n) for n in target.split(".")] < [int(n) for n in newest.split(".")]:
            print(
                f"WARN {plugin}: bump target {target} is BELOW newest published {newest} "
                f"— plugin.meta.json looks desynced from the cache.",
                file=sys.stderr,
            )
    sys.exit(0)

tm, tn, tp = (int(n) for n in target.split("."))
p = tp + 1
while f"{tm}.{tn}.{p}" in published:
    p += 1
n = tn + 1
while f"{tm}.{n}.0" in published:
    n += 1

msg = [
    f"ERROR {plugin}: --bump {bump} targets v{target}, which is ALREADY PUBLISHED in the cache.",
    f"  cache:     {cache_dir}",
    f"  published: {', '.join(published)}",
    f"  manifest:  {meta_path} says {version}",
    "  Overwriting a published version makes one version number mean two different",
    "  things — sibling sessions pinned that snapshot at boot.",
    f"  Set plugin.meta.json to a version whose bump lands free: next free patch "
    f"{tm}.{tn}.{p}, next free minor {tm}.{n}.0.",
    "  To proceed anyway (only if you are certain nothing is pinned): SYNC_PLUGIN_FORCE=1",
]
print("\n".join(msg), file=sys.stderr)
sys.exit(0 if force else 1)
PY
}

bump_meta() {
  local plugin_dir="$1"
  local bump="$2"
  if [ "$bump" = "none" ]; then
    return 0
  fi

  PLUGIN_DIR="$plugin_dir" BUMP="$bump" python3 - <<'PY'
import json
import os
import re
from pathlib import Path

path = Path(os.environ["PLUGIN_DIR"]) / "plugin.meta.json"
bump = os.environ["BUMP"]
data = json.loads(path.read_text())
version = data.get("version")
if not isinstance(version, str) or not re.fullmatch(r"\d+\.\d+\.\d+", version):
    raise SystemExit(f"{path}: version must be plain semver x.y.z, got {version!r}")

major, minor, patch = [int(part) for part in version.split(".")]
if bump == "major":
    major += 1
    minor = 0
    patch = 0
elif bump == "minor":
    minor += 1
    patch = 0
elif bump == "patch":
    patch += 1
else:
    raise SystemExit(f"unsupported bump: {bump}")

data["version"] = f"{major}.{minor}.{patch}"
path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
print(f"BUMP {path} {version} -> {data['version']}")
PY
}

refresh_claude() {
  local plugin="$1"
  if [ ! -x "$SYNC_PLUGIN" ] && [ ! -f "$SYNC_PLUGIN" ]; then
    echo "SKIP Claude cache: sync-plugin.sh not found at $SYNC_PLUGIN"
    return 0
  fi
  if [ ! -d "$CLAUDE_HOME" ]; then
    echo "SKIP Claude cache: $CLAUDE_HOME not found"
    return 0
  fi
  bash "$SYNC_PLUGIN" "$plugin"
}

refresh_codex() {
  local plugin="$1"
  if ! command -v codex >/dev/null 2>&1; then
    echo "SKIP Codex cache: codex CLI not found"
    return 0
  fi
  if ! codex plugin add "${plugin}@cofoundy"; then
    echo "WARN Codex cache refresh failed for ${plugin}; check that marketplace 'cofoundy' is installed." >&2
    return 0
  fi
}

# Preflight ALL plugins before mutating ANY of them: with --all, one colliding
# plugin must not leave the other twenty half-bumped.
for plugin in "${PLUGINS[@]}"; do
  plugin_dir="$(plugin_dir_for "$plugin")"
  preflight_cache_collision "$plugin" "$plugin_dir" "$BUMP" || exit 3
done

for plugin in "${PLUGINS[@]}"; do
  plugin_dir="$(plugin_dir_for "$plugin")"
  if [ ! -f "${plugin_dir}/plugin.meta.json" ]; then
    python3 "$MANIFESTS" init-meta "$plugin"
  fi
  bump_meta "$plugin_dir" "$BUMP"
done

python3 "$MANIFESTS" generate
python3 "$MANIFESTS" check

for plugin in "${PLUGINS[@]}"; do
  refresh_claude "$plugin"
  refresh_codex "$plugin"
done

echo
echo "Done. Commit the source plugin repo(s) and cofoundy-marketplace together."
echo "TELL THE USER to run /reload-plugins in Claude Code to load the new version — the agent can't reload plugins itself (each session uses the cache snapshot taken at startup)."
