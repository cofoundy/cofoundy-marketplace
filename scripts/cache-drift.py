#!/usr/bin/env python3
"""cache-drift.py — what the Claude Code cache serves that the plugin source no longer has.

The cache only changes when someone runs update-plugin.sh → sync-plugin.sh. If a source repo
retires a skill and nobody syncs, the installed version keeps serving it: cofoundy-docs:docs lived
~6 weeks after its source deleted it (3c0a527, 2026-06-20 → still in every session on 2026-08-01),
competing with basalt for «publish this» (#4). This REPORTS; it never touches the cache (sessions
pin cached versions; the retention policy exists for that). The remedy is the printed command.

For every installed + enabled `<name>@<marketplace>` plugin:
  resucitada     a skill / command / agent in the installed cache version that the source lacks
  stale          the source's plugin.meta.json version is newer than the installed version
  desregistrado  installed from this marketplace, but the catalog no longer lists it
A plugin with no local source clone under plugins/ is skipped (no false positive).

Usage:
  cache-drift.py [--json] [--hook] [--claude-home DIR] [--marketplace-dir DIR]
Exit: 0 clean, 1 findings (with --hook: always 0, and silent when clean).
Regression: scripts/test-cache-drift.py.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

MARKETPLACE_DIR = Path(__file__).resolve().parent.parent


def semver(v: str) -> tuple[int, ...]:
    return tuple(int(n) for n in re.findall(r"\d+", v or "")[:3]) or (0,)


def inventory(root: Path) -> set[str]:
    """skills/<x>, commands/<x>, agents/<x> present under a plugin tree."""
    out: set[str] = set()
    skills = root / "skills"
    if skills.is_dir():
        out |= {f"skills/{d.name}" for d in skills.iterdir() if (d / "SKILL.md").is_file()}
    for kind in ("commands", "agents"):
        d = root / kind
        if d.is_dir():
            out |= {f"{kind}/{f.stem}" for f in d.glob("*.md")}
    return out


def read_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return {}


def findings(claude_home: Path, marketplace_dir: Path) -> list[dict]:
    catalog = read_json(marketplace_dir / ".claude-plugin" / "marketplace.json")
    market = catalog.get("name", "cofoundy")
    listed = {e.get("name") for e in catalog.get("plugins", [])}
    installed = read_json(claude_home / "plugins" / "installed_plugins.json").get("plugins", {})
    settings = read_json(claude_home / "settings.json")
    enabled = settings.get("enabledPlugins") if isinstance(settings.get("enabledPlugins"), dict) else None
    remedy_sync = f"bash {marketplace_dir}/scripts/update-plugin.sh {{name}} --bump patch"

    out: list[dict] = []
    for key, entries in sorted(installed.items()):
        name, _, mk = key.partition("@")
        if mk != market or not entries:
            continue
        if enabled is not None and not enabled.get(key):
            continue
        inst = entries[0]
        cache = Path(inst.get("installPath") or "")
        cver = inst.get("version") or (cache.name if cache.name else "?")
        if catalog and name not in listed:
            out.append({"plugin": name, "tipo": "desregistrado", "version_cache": cver, "detalle":
                        f"{key} sigue instalado pero el catálogo ya no lo lista",
                        "remedio": f"claude plugin uninstall {key}"})
            continue
        src_link = marketplace_dir / "plugins" / name
        if not src_link.exists():
            continue  # no local clone: nothing to compare against
        src = src_link.resolve()
        sver = read_json(src / "plugin.meta.json").get("version") or read_json(
            src / ".claude-plugin" / "plugin.json").get("version")
        if cache.is_dir():
            for item in sorted(inventory(cache) - inventory(src)):
                out.append({"plugin": name, "tipo": "resucitada", "version_cache": cver, "detalle":
                            f"{item} se sirve desde el cache {cver} pero el source ({src}) ya no la tiene",
                            "remedio": remedy_sync.format(name=name)})
        if isinstance(sver, str) and semver(sver) > semver(cver):
            out.append({"plugin": name, "tipo": "stale", "version_cache": cver, "detalle":
                        f"source en {sver}, instalado {cver}",
                        "remedio": remedy_sync.format(name=name)})
    return out


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--hook", action="store_true", help="SessionStart: exit 0 always, silent when clean")
    ap.add_argument("--claude-home", default=str(Path.home() / ".claude"))
    ap.add_argument("--marketplace-dir", default=str(MARKETPLACE_DIR))
    a = ap.parse_args(argv)
    found = findings(Path(a.claude_home).expanduser(), Path(a.marketplace_dir).expanduser())
    if a.json:
        print(json.dumps(found, indent=2, ensure_ascii=False))
    elif found:
        print(f"cache-drift: {len(found)} hallazgo(s) entre el cache de plugins y su source")
        for f in found:
            print(f"  [{f['tipo']}] {f['plugin']}: {f['detalle']}\n      → {f['remedio']}")
    if a.hook:
        return 0
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
