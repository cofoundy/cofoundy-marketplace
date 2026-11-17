#!/usr/bin/env python3
"""Regression for cache-drift.py on throwaway trees (never reads ~/.claude). Rebuilds the real
case from #4: the cache of cofoundy-docs 0.1.10 still had skills/docs after the source retired it.
Usage: python3 scripts/test-cache-drift.py   (exit 0 = all pass)"""

from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import tempfile
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("cache_drift", HERE / "cache-drift.py")
cd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cd)


def skill(root: Path, name: str) -> None:
    (root / "skills" / name).mkdir(parents=True, exist_ok=True)
    (root / "skills" / name / "SKILL.md").write_text("---\nname: x\n---\n")


def world(t: Path, *, listed=("cofoundy-docs",), enabled=True) -> tuple[Path, Path, Path]:
    home, mkt, src = t / "home/.claude", t / "mkt", t / "src/cofoundy-docs"
    cache = home / "plugins/cache/cofoundy/cofoundy-docs/0.1.10"
    for d in (home / "plugins", mkt / ".claude-plugin", mkt / "plugins", src):
        d.mkdir(parents=True, exist_ok=True)
    skill(cache, "docs")
    skill(cache, "publish")
    skill(src, "publish")
    (src / "plugin.meta.json").write_text(json.dumps({"name": "cofoundy-docs", "version": "0.1.10"}))
    (mkt / "plugins/cofoundy-docs").symlink_to(src)
    (mkt / ".claude-plugin/marketplace.json").write_text(json.dumps(
        {"name": "cofoundy", "plugins": [{"name": n} for n in listed]}))
    (home / "plugins/installed_plugins.json").write_text(json.dumps({"plugins": {
        "cofoundy-docs@cofoundy": [{"version": "0.1.10", "installPath": str(cache)}]}}))
    (home / "settings.json").write_text(json.dumps({"enabledPlugins": {"cofoundy-docs@cofoundy": enabled}}))
    return home, mkt, src


PASS = FAIL = 0


def check(label: str, cond: bool, extra: object = "") -> None:
    global PASS, FAIL
    print(f"  {'ok  ' if cond else 'FAIL'} {label}" + (f"\n       {extra}" if not cond else ""))
    PASS, FAIL = PASS + cond, FAIL + (not cond)


with tempfile.TemporaryDirectory() as tmp:
    home, mkt, src = world(Path(tmp))
    f = cd.findings(home, mkt)
    check("the retired skill (cache has skills/docs, source does not) is reported as resucitada",
          [(x["tipo"], x["plugin"], x["version_cache"]) for x in f] == [("resucitada", "cofoundy-docs", "0.1.10")]
          and "skills/docs" in f[0]["detalle"] and "update-plugin.sh cofoundy-docs" in f[0]["remedio"], f)
    skill(src, "docs")
    check("source and cache aligned → no findings", cd.findings(home, mkt) == [])
    (src / "plugin.meta.json").write_text(json.dumps({"name": "cofoundy-docs", "version": "0.1.11"}))
    check("source version ahead of the installed one → stale",
          [x["tipo"] for x in cd.findings(home, mkt)] == ["stale"])

with tempfile.TemporaryDirectory() as tmp:
    home, mkt, src = world(Path(tmp), listed=("otro",))
    check("installed but dropped from the catalog → desregistrado",
          [x["tipo"] for x in cd.findings(home, mkt)] == ["desregistrado"])

with tempfile.TemporaryDirectory() as tmp:
    home, mkt, src = world(Path(tmp))
    (mkt / "plugins/cofoundy-docs").unlink()
    check("no local source clone → no false positive", cd.findings(home, mkt) == [])

with tempfile.TemporaryDirectory() as tmp:
    home, mkt, src = world(Path(tmp), enabled=False)
    check("a disabled plugin is not reported", cd.findings(home, mkt) == [])

with tempfile.TemporaryDirectory() as tmp:
    home, mkt, src = world(Path(tmp))
    t0 = time.time()
    r = subprocess.run([sys.executable, str(HERE / "cache-drift.py"), "--hook", "--claude-home", str(home),
                        "--marketplace-dir", str(mkt)], capture_output=True, text=True)
    check("--hook exits 0 with findings, under 2 s, and prints them",
          r.returncode == 0 and "resucitada" in r.stdout and time.time() - t0 < 2, r)
    skill(src, "docs")
    r = subprocess.run([sys.executable, str(HERE / "cache-drift.py"), "--hook", "--claude-home", str(home),
                        "--marketplace-dir", str(mkt)], capture_output=True, text=True)
    check("--hook is silent when clean", r.returncode == 0 and r.stdout == "", r)
    r = subprocess.run([sys.executable, str(HERE / "cache-drift.py"), "--claude-home", str(home),
                        "--marketplace-dir", str(mkt)], capture_output=True, text=True)
    check("on demand: exit 0 when clean", r.returncode == 0, r)

print(f"\npassed {PASS}, failed {FAIL}")
sys.exit(1 if FAIL else 0)
