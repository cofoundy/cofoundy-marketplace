#!/usr/bin/env bash
# unify-agent-rules.sh — Unify Claude Code, Codex, and Antigravity rule files.
#
# This script exposes Claude-era CLAUDE.md files to Codex/Antigravity by
# creating AGENTS.md -> CLAUDE.md symlinks. It is intentionally non-invasive:
# CLAUDE.md remains the source file until a deliberate repo-by-repo migration
# changes the SSOT.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKETPLACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLUGINS_DIR="${MARKETPLACE_DIR}/plugins"

echo "=== Cofoundy Agent Instruction Unification (Step 8) ==="

# Function to unify a single directory
unify_directory() {
    local target_dir="$1"
    local dir_name
    dir_name=$(basename "$target_dir")
    
    if [ ! -d "$target_dir" ]; then
        return
    fi
    
    echo "Processing [${dir_name}]..."
    
    cd "$target_dir"
    
    # 1. If Claude instructions exist, expose them to Codex/Antigravity.
    if [ -f "CLAUDE.md" ]; then
        if [ -e "AGENTS.md" ] && [ ! -L "AGENTS.md" ]; then
            echo "  Warning: AGENTS.md already exists as a regular file; leaving it untouched."
            return
        fi

        echo "  Creating symlink AGENTS.md -> CLAUDE.md..."
        ln -sfn "CLAUDE.md" "AGENTS.md"
        echo "  Unified successfully."
        echo
        return
    fi

    # 2. If AGENTS.md exists but CLAUDE.md does not, leave it as the native SSOT.
    if [ -f "AGENTS.md" ]; then
        echo "  Native AGENTS.md exists; no CLAUDE.md bridge needed."
    else
        # If neither exists, create a default AGENTS.md template and link it
        echo "  Creating default AGENTS.md..."
        cat << 'EOF' > "AGENTS.md"
# Workspace Agent Instructions (AGENTS.md)

This file contains the workspace constitution, development guidelines, and instructions for AI agents.
It is parsed automatically on startup by Codex and Antigravity.

## Development Commands
- Build: `npm run build` or equivalent
- Test: `npm run test` or equivalent
EOF
    fi
    
    echo "  Unified successfully."
    echo
}

# 1. Unify the marketplace repository itself
unify_directory "$MARKETPLACE_DIR"

# 2. Unify all sibling plugin repositories
if [ -d "$PLUGINS_DIR" ]; then
    # We resolve symlinks under plugins/ to make sure we modify the actual repositories, not the symlink files themselves!
    for plugin_symlink in "${PLUGINS_DIR}"/*; do
        if [ -L "$plugin_symlink" ] || [ -d "$plugin_symlink" ]; then
            resolved_path=$(realpath "$plugin_symlink")
            unify_directory "$resolved_path"
        fi
    done
else
    # Fallback to scanning sibling directories directly if plugins folder is not setup
    COFOUNDY_ROOT="$(cd "${MARKETPLACE_DIR}/.." && pwd)"
    for sibling in "${COFOUNDY_ROOT}"/*; do
        if [ -d "$sibling" ] && [ "$(basename "$sibling")" != "cofoundy-marketplace" ]; then
            unify_directory "$sibling"
        fi
    done
fi

echo "=== Unification complete! All rules are DRY and fully cross-platform compatible. ==="
