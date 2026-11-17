#!/usr/bin/env bash
# test-update-plugin.sh — regression battery for update-plugin.sh against a THROWAWAY marketplace,
# throwaway plugin repos (with bare remotes) and a throwaway Claude home. Never touches ~/.claude,
# ~/cofoundy or the real `cofoundy` marketplace: HOME is fake and codex is kept off the PATH.
#
#   #2 preflight: a stale / feature-branch / dirty sibling checkout aborts (exit 4) naming the repo;
#      --force proceeds; the happy path is unchanged; a meta behind its own plugin.json is not
#      rewritten downward.
#   #3 one tree: with plugins/<name> on a worktree, the cache is published FROM that worktree and the
#      summary reports the version that was bumped.
#
# Usage: bash scripts/test-update-plugin.sh   (exit 0 = all pass)

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_SRC="${SYNC_PLUGIN_SRC:-$(realpath "$HERE/../plugins/cofoundy-toolkit/scripts/sync-plugin.sh" 2>/dev/null || true)}"
[ -f "$SYNC_SRC" ] || SYNC_SRC="$HOME/cofoundy/plugins/cofoundy-toolkit/scripts/sync-plugin.sh"
PASS=0
FAIL=0
ok() { echo "  ok   $1"; PASS=$((PASS + 1)); }
ko() { echo "  FAIL $1"; FAIL=$((FAIL + 1)); }

g() { git -c user.name=t -c user.email=t@t "$@"; }

meta() { # meta <name> <version>
  cat <<EOF
{
  "name": "$1",
  "version": "$2",
  "description": "test plugin $1",
  "author": {"name": "Cofoundy SAC"},
  "homepage": "https://cofoundy.dev",
  "license": "UNLICENSED",
  "repo": "cofoundy/$1",
  "codex": {"skills": "skills", "interface": {}}
}
EOF
}

# new_plugin <T> <name> <version>: bare remote + clone on main, with generated manifests committed.
new_plugin() {
  local T="$1" name="$2" version="$3" d="$1/src/$2"
  g init -q --bare -b main "$T/remotes/$name.git"
  g clone -q "$T/remotes/$name.git" "$d" 2>/dev/null
  mkdir -p "$d/.claude-plugin" "$d/.codex-plugin" "$d/skills/x"
  meta "$name" "$version" > "$d/plugin.meta.json"
  printf '{"name": "%s", "version": "%s"}\n' "$name" "$version" > "$d/.claude-plugin/plugin.json"
  printf '{"name": "%s", "version": "%s"}\n' "$name" "$version" > "$d/.codex-plugin/plugin.json"
  echo "# x" > "$d/skills/x/SKILL.md"
  (cd "$d" && g add -A && g commit -q -m init && g push -q -u origin main 2>/dev/null)
  git -C "$d" remote set-head origin main >/dev/null 2>&1 || true
}

# setup: prints the temp root. Marketplace with alpha + beta; alpha also has a "default" checkout
# at ~/cofoundy/plugins/alpha (fake HOME) that differs from the tree plugins/alpha points to.
setup() {
  local T
  T="$(realpath "$(mktemp -d)")"
  mkdir -p "$T/mkt/scripts" "$T/mkt/.claude-plugin" "$T/mkt/plugins/cofoundy-toolkit/scripts" \
           "$T/home/.claude/plugins" "$T/home/cofoundy/plugins"
  cp "$HERE/update-plugin.sh" "$HERE/plugin-manifests.py" "$T/mkt/scripts/"
  cp "$SYNC_SRC" "$T/mkt/plugins/cofoundy-toolkit/scripts/sync-plugin.sh"  # not a plugin: no manifest
  new_plugin "$T" alpha 0.1.0
  new_plugin "$T" beta 0.2.0
  ln -s "$T/src/alpha" "$T/mkt/plugins/alpha"
  ln -s "$T/src/beta" "$T/mkt/plugins/beta"
  cat > "$T/mkt/.claude-plugin/marketplace.json" <<'EOF'
{"name": "cofoundy", "plugins": [
  {"name": "alpha", "source": {"source": "github", "repo": "cofoundy/alpha"}, "description": "test plugin alpha", "version": "0.1.0", "author": {"name": "Cofoundy SAC"}, "homepage": "https://cofoundy.dev"},
  {"name": "beta", "source": {"source": "github", "repo": "cofoundy/beta"}, "description": "test plugin beta", "version": "0.2.0", "author": {"name": "Cofoundy SAC"}, "homepage": "https://cofoundy.dev"}
]}
EOF
  printf '{"version": 2, "plugins": {"alpha@cofoundy": [{"version": "0.0.0", "installPath": ""}]}}\n' \
    > "$T/home/.claude/plugins/installed_plugins.json"
  echo "$T"
}

run() { # run <T> <args...> → stdout+stderr in $T/out, exit code echoed
  local T="$1"; shift
  (cd "$T/mkt" && HOME="$T/home" PATH="/usr/bin:/bin" bash scripts/update-plugin.sh "$@") >"$T/out" 2>&1
  echo $?
}

echo "update-plugin.sh regression battery"

# 1. happy path: clean, up to date, on main → bumps and publishes as before
T="$(setup)"
rc="$(run "$T" alpha --bump patch)"
if [ "$rc" = 0 ] && grep -q '"version": "0.1.1"' "$T/src/alpha/.claude-plugin/plugin.json" \
   && [ -f "$T/home/.claude/plugins/cache/cofoundy/alpha/0.1.1/skills/x/SKILL.md" ]; then
  ok "happy path bumps 0.1.0 → 0.1.1 and publishes it"
else ko "happy path (rc=$rc)"; sed 's/^/       /' "$T/out"; fi
rm -rf "$T"

# 2. #2: a sibling checkout behind origin aborts, naming it
T="$(setup)"
(cd "$T/src/beta" && echo y > y && g add y && g commit -q -m y && g push -q 2>/dev/null && g reset -q --hard HEAD~1)
rc="$(run "$T" alpha --bump patch)"
if [ "$rc" = 4 ] && grep -q "beta.*behind origin/main" "$T/out" && grep -q '"version": "0.1.0"' "$T/src/alpha/plugin.meta.json"; then
  ok "stale sibling (beta behind origin) aborts with exit 4 before any bump"
else ko "stale sibling (rc=$rc)"; sed 's/^/       /' "$T/out"; fi
# 3. --force prints and proceeds
rc="$(run "$T" alpha --bump patch --force)"
if [ "$rc" = 0 ] && grep -q "WARN --force" "$T/out" && grep -q '"version": "0.1.1"' "$T/src/alpha/plugin.meta.json"; then
  ok "--force prints the findings and proceeds"
else ko "--force (rc=$rc)"; sed 's/^/       /' "$T/out"; fi
rm -rf "$T"

# 4. #2: a sibling on a feature branch aborts
T="$(setup)"
g -C "$T/src/beta" checkout -q -b feat
rc="$(run "$T" alpha --bump patch)"
if [ "$rc" = 4 ] && grep -q "beta.*on branch 'feat'" "$T/out"; then
  ok "sibling on a feature branch aborts"
else ko "feature branch (rc=$rc)"; sed 's/^/       /' "$T/out"; fi
rm -rf "$T"

# 5. #2: a sibling with an uncommitted version file aborts
T="$(setup)"
meta beta 0.1.9 > "$T/src/beta/plugin.meta.json"
rc="$(run "$T" alpha --bump patch)"
if [ "$rc" = 4 ] && grep -q "beta.*uncommitted version files: plugin.meta.json" "$T/out"; then
  ok "sibling with a dirty plugin.meta.json aborts"
else ko "dirty sibling (rc=$rc)"; sed 's/^/       /' "$T/out"; fi
# 6. #2 mode 2: with --force, beta's own plugin.json (0.2.0) is NOT rewritten down to its meta (0.1.9)
rc="$(run "$T" alpha --bump patch --force)"
if grep -q '"version": "0.2.0"' "$T/src/beta/.claude-plugin/plugin.json" && grep -q "STALE beta" "$T/out"; then
  ok "a meta behind its own plugin.json is not rewritten downward"
else ko "per-plugin downgrade guard (rc=$rc)"; sed 's/^/       /' "$T/out"; fi
rm -rf "$T"

# 7. #3: plugins/alpha points at a worktree; ~/cofoundy/plugins/alpha is another tree at 0.0.5
T="$(setup)"
cp -R "$T/src/alpha" "$T/home/cofoundy/plugins/alpha"
meta alpha 0.0.5 > "$T/home/cofoundy/plugins/alpha/plugin.meta.json"
printf '{"name": "alpha", "version": "0.0.5"}\n' > "$T/home/cofoundy/plugins/alpha/.claude-plugin/plugin.json"
rc="$(run "$T" alpha --bump minor)"
if [ "$rc" = 0 ] && grep -q "SOURCE alpha: publishing from $T/src/alpha" "$T/out" \
   && grep -q "Plugin: alpha v0.2.0" "$T/out" && grep -q "activate v0.2.0" "$T/out" \
   && [ -d "$T/home/.claude/plugins/cache/cofoundy/alpha/0.2.0" ] && [ ! -d "$T/home/.claude/plugins/cache/cofoundy/alpha/0.0.5" ]; then
  ok "publishes from the bumped worktree (0.2.0), not ~/cofoundy/plugins (0.0.5)"
else ko "one tree (rc=$rc)"; sed 's/^/       /' "$T/out"; fi
rm -rf "$T"

echo
echo "passed $PASS, failed $FAIL"
[ "$FAIL" -eq 0 ]
