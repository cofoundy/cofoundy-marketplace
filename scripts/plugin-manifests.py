#!/usr/bin/env python3
"""Generate Cofoundy plugin manifests from plugin.meta.json.

The source of truth lives in each plugin source repo:

    ~/cofoundy/plugins/<plugin>/plugin.meta.json

Generated outputs:

    <plugin>/.claude-plugin/plugin.json
    <plugin>/.codex-plugin/plugin.json
    cofoundy-marketplace/.claude-plugin/marketplace.json

The Codex marketplace intentionally stays path-only for local development.
"""

from __future__ import annotations

import argparse
import copy
import json
import sys
from pathlib import Path
from typing import Any


MARKETPLACE_DIR = Path(__file__).resolve().parent.parent
PLUGINS_DIR = MARKETPLACE_DIR / "plugins"
CLAUDE_MARKETPLACE = MARKETPLACE_DIR / ".claude-plugin" / "marketplace.json"

COMMON_PLUGIN_KEYS = [
    "name",
    "version",
    "description",
    "author",
    "homepage",
    "license",
]
CODEX_PLUGIN_KEYS = [
    "name",
    "version",
    "description",
    "skills",
    "author",
    "homepage",
    "license",
    "interface",
]


def read_json(path: Path) -> dict[str, Any]:
    with path.open() as f:
        return json.load(f)


def write_json(path: Path, data: dict[str, Any], *, check: bool) -> bool:
    rendered = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    if path.exists() and path.read_text() == rendered:
        return False
    if check:
        print(f"DRIFT {path}")
        return True
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(rendered)
    print(f"WROTE {path}")
    return True


def semver_key(version: str) -> tuple[int, int, int, str]:
    parts = version.split(".", 2)
    nums: list[int] = []
    for part in parts:
        digits = ""
        for char in part:
            if not char.isdigit():
                break
            digits += char
        nums.append(int(digits or 0))
    while len(nums) < 3:
        nums.append(0)
    return nums[0], nums[1], nums[2], version


def plugin_source_paths() -> list[Path]:
    paths: list[Path] = []
    for item in sorted(PLUGINS_DIR.iterdir()):
        if item.name.startswith("."):
            continue
        resolved = item.resolve()
        if (resolved / ".claude-plugin" / "plugin.json").exists() or (
            resolved / ".codex-plugin" / "plugin.json"
        ).exists():
            paths.append(resolved)
    return paths


def marketplace_entry_by_name() -> dict[str, dict[str, Any]]:
    if not CLAUDE_MARKETPLACE.exists():
        return {}
    marketplace = read_json(CLAUDE_MARKETPLACE)
    return {entry["name"]: entry for entry in marketplace.get("plugins", [])}


def init_meta(plugin_dir: Path, *, force: bool = False) -> None:
    meta_path = plugin_dir / "plugin.meta.json"
    if meta_path.exists() and not force:
        print(f"SKIP {meta_path}")
        return

    claude_path = plugin_dir / ".claude-plugin" / "plugin.json"
    codex_path = plugin_dir / ".codex-plugin" / "plugin.json"
    claude = read_json(claude_path) if claude_path.exists() else {}
    codex = read_json(codex_path) if codex_path.exists() else {}
    market = marketplace_entry_by_name().get(codex.get("name") or claude.get("name"), {})

    versions = [
        v
        for v in [claude.get("version"), codex.get("version"), market.get("version")]
        if isinstance(v, str) and v
    ]
    version = max(versions, key=semver_key) if versions else "0.1.0"

    base: dict[str, Any] = {
        "name": codex.get("name") or claude.get("name") or plugin_dir.name,
        "version": version,
        "description": codex.get("description")
        or claude.get("description")
        or market.get("description")
        or "",
        "author": codex.get("author")
        or claude.get("author")
        or market.get("author")
        or {"name": "Cofoundy SAC", "url": "https://cofoundy.dev"},
        "homepage": codex.get("homepage")
        or claude.get("homepage")
        or market.get("homepage")
        or "https://cofoundy.dev",
        "license": codex.get("license") or claude.get("license") or "UNLICENSED",
        "repo": f"cofoundy/{plugin_dir.name}",
    }

    codex_meta = {
        "skills": codex.get("skills", "skills"),
        "interface": codex.get("interface", {}),
    }
    claude_extra = {key: value for key, value in claude.items() if key not in COMMON_PLUGIN_KEYS}

    meta: dict[str, Any] = base
    meta["codex"] = codex_meta
    if claude_extra:
        meta["claude"] = {"extra": claude_extra}

    write_json(meta_path, meta, check=False)


def claude_manifest(meta: dict[str, Any]) -> dict[str, Any]:
    data = {key: copy.deepcopy(meta[key]) for key in COMMON_PLUGIN_KEYS if key in meta}
    data.update(copy.deepcopy(meta.get("claude", {}).get("extra", {})))
    return data


def codex_manifest(meta: dict[str, Any]) -> dict[str, Any]:
    data = {key: copy.deepcopy(meta[key]) for key in COMMON_PLUGIN_KEYS if key in meta}
    codex = meta.get("codex", {})
    data["skills"] = codex.get("skills", "skills")
    data["interface"] = copy.deepcopy(codex.get("interface", {}))
    return {key: data[key] for key in CODEX_PLUGIN_KEYS if key in data}


def update_claude_marketplace(metas: dict[str, dict[str, Any]], *, check: bool) -> bool:
    marketplace = read_json(CLAUDE_MARKETPLACE)
    changed = False
    for entry in marketplace.get("plugins", []):
        meta = metas.get(entry.get("name"))
        if not meta:
            continue
        source = entry.get("source", {})
        new_entry = {
            "name": meta["name"],
            "source": source,
            "description": meta["description"],
            "version": meta["version"],
            "author": {"name": meta.get("author", {}).get("name", "Cofoundy SAC")},
            "homepage": meta.get("homepage", "https://cofoundy.dev"),
        }
        if entry != new_entry:
            entry.clear()
            entry.update(new_entry)
            changed = True
    if changed:
        return write_json(CLAUDE_MARKETPLACE, marketplace, check=check)
    return False


def load_metas() -> dict[str, dict[str, Any]]:
    metas: dict[str, dict[str, Any]] = {}
    for plugin_dir in plugin_source_paths():
        meta_path = plugin_dir / "plugin.meta.json"
        if not meta_path.exists():
            continue
        meta = read_json(meta_path)
        metas[meta["name"]] = meta
    return metas


def generate(*, check: bool) -> int:
    drift = False
    metas = load_metas()
    for plugin_dir in plugin_source_paths():
        meta_path = plugin_dir / "plugin.meta.json"
        if not meta_path.exists():
            print(f"MISSING {meta_path}", file=sys.stderr)
            drift = True
            continue
        meta = read_json(meta_path)
        drift |= write_json(
            plugin_dir / ".claude-plugin" / "plugin.json",
            claude_manifest(meta),
            check=check,
        )
        drift |= write_json(
            plugin_dir / ".codex-plugin" / "plugin.json",
            codex_manifest(meta),
            check=check,
        )
    drift |= update_claude_marketplace(metas, check=check)
    return 1 if drift and check else 0


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    init = sub.add_parser("init-meta")
    init.add_argument("--force", action="store_true")
    init.add_argument("plugins", nargs="*")
    sub.add_parser("generate")
    sub.add_parser("check")
    args = parser.parse_args()

    if args.command == "init-meta":
        requested = set(args.plugins)
        for plugin_dir in plugin_source_paths():
            if requested and plugin_dir.name not in requested:
                continue
            init_meta(plugin_dir, force=args.force)
        return 0
    if args.command == "generate":
        return generate(check=False)
    if args.command == "check":
        return generate(check=True)
    raise AssertionError(args.command)


if __name__ == "__main__":
    raise SystemExit(main())
