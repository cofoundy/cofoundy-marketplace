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
USAGE
}

MARKETPLACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGINS_DIR="${MARKETPLACE_DIR}/plugins"
MANIFESTS="${MARKETPLACE_DIR}/scripts/plugin-manifests.py"
SYNC_PLUGIN="${MARKETPLACE_DIR}/plugins/cofoundy-toolkit/scripts/sync-plugin.sh"
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
  if [ ! -d "$HOME/.claude" ]; then
    echo "SKIP Claude cache: ~/.claude not found"
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
