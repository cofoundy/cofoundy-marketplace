#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "pyyaml",
#     "rich",
# ]
# ///
"""
antigravity-harness.py — Specialized harness utility for Antigravity & other agent runtimes.

This script acts as the interoperability bridge for Antigravity to discover,
inspect, and execute the skills and agent personas defined across all Cofoundy plugins.

Usage:
  uv run scripts/antigravity-harness.py list                     # List all plugins, skills, and agents
  uv run scripts/antigravity-harness.py skill <skill-name>       # View detailed instructions for a specific skill
  uv run scripts/antigravity-harness.py agent <agent-name>       # Load the persona prompt of an agent
  uv run scripts/antigravity-harness.py matrix                  # Print the Claude Code / Codex / Antigravity matrix
"""

import argparse
import sys
from pathlib import Path
import yaml
from rich.console import Console
from rich.table import Table
from rich.markdown import Markdown

console = Console()

# Resolve base paths
MARKETPLACE_DIR = Path(__file__).resolve().parent.parent
PLUGINS_DIR = MARKETPLACE_DIR / ".agents" / "plugins"


def get_all_plugin_paths() -> dict[str, Path]:
    """Returns a dict of plugin_name -> absolute_path."""
    plugins = {}
    if not PLUGINS_DIR.exists():
        console.print(f"[bold red]Error:[/bold red] plugins/ directory not found in {MARKETPLACE_DIR}")
        return plugins

    # Check symlinks or actual directories under plugins/
    for item in PLUGINS_DIR.iterdir():
        if item.is_dir() or item.is_symlink():
            plugins[item.name] = item.resolve()
    return plugins

def get_skills_for_plugin(plugin_path: Path) -> dict[str, Path]:
    """Scans for skills in a plugin's skills/ directory."""
    skills = {}
    skills_dir = plugin_path / "skills"
    if skills_dir.is_dir():
        for skill_dir in skills_dir.iterdir():
            if skill_dir.is_dir():
                skill_md = skill_dir / "SKILL.md"
                if skill_md.is_file():
                    skills[skill_dir.name] = skill_md
    return skills

def get_agents_for_plugin(plugin_path: Path) -> dict[str, Path]:
    """Scans for agent personas in a plugin's agents/ directory."""
    agents = {}
    agents_dir = plugin_path / "agents"
    if agents_dir.is_dir():
        for agent_file in agents_dir.iterdir():
            if agent_file.is_file() and agent_file.suffix == ".md":
                agents[agent_file.stem] = agent_file
    return agents

def cmd_list(args):
    """Lists all plugins, skills, and agents."""
    plugins = get_all_plugin_paths()
    if not plugins:
        console.print("[bold yellow]No plugins discovered.[/bold yellow]")
        sys.exit(0)

    table = Table(title="Cofoundy Plugin Ecosystem - Capabilities Registry")
    table.add_column("Plugin", style="cyan", no_wrap=True)
    table.add_column("Skills", style="green")
    table.add_column("Agent Personas", style="magenta")

    for plugin_name, path in sorted(plugins.items()):
        skills = get_skills_for_plugin(path)
        agents = get_agents_for_plugin(path)

        skills_list = ", ".join(sorted(skills.keys())) if skills else "[italic dim]none[/italic dim]"
        agents_list = ", ".join(sorted(agents.keys())) if agents else "[italic dim]none[/italic dim]"

        table.add_row(plugin_name, skills_list, agents_list)

    console.print(table)

def cmd_skill(args):
    """View details of a specific skill."""
    target_skill = args.name.lower()
    plugins = get_all_plugin_paths()
    found = False

    for plugin_name, path in plugins.items():
        skills = get_skills_for_plugin(path)
        if target_skill in skills:
            skill_md_path = skills[target_skill]
            content = skill_md_path.read_text()
            
            console.print(f"[bold green]=== Skill: {target_skill} (Plugin: {plugin_name}) ===[/bold green]")
            console.print(f"[dim]Source file: {skill_md_path}[/dim]\n")
            
            # Print frontmatter if yaml
            if content.startswith("---"):
                parts = content.split("---", 2)
                if len(parts) >= 3:
                    try:
                        metadata = yaml.safe_load(parts[1])
                        console.print("[bold yellow]Metadata:[/bold yellow]")
                        for k, v in metadata.items():
                            console.print(f"  {k}: {v}")
                        console.print()
                        content = parts[2]
                    except Exception:
                        pass
            
            console.print(Markdown(content))
            found = True
            break

    if not found:
        console.print(f"[bold red]Error:[/bold red] Skill '{target_skill}' not found in any plugin.")
        sys.exit(1)

def cmd_agent(args):
    """View details or load persona prompt of an agent."""
    target_agent = args.name.lower()
    plugins = get_all_plugin_paths()
    found = False

    for plugin_name, path in plugins.items():
        agents = get_agents_for_plugin(path)
        if target_agent in agents:
            agent_md_path = agents[target_agent]
            content = agent_md_path.read_text()
            
            console.print(f"[bold magenta]=== Agent Persona: {target_agent} (Plugin: {plugin_name}) ===[/bold magenta]")
            console.print(f"[dim]Source file: {agent_md_path}[/dim]\n")
            console.print(Markdown(content))
            found = True
            break

    if not found:
        console.print(f"[bold red]Error:[/bold red] Agent persona '{target_agent}' not found in any plugin.")
        sys.exit(1)

def cmd_matrix(args):
    """Prints the Claude Code / Codex / Antigravity matrix."""
    markdown_matrix = """
# Platform Compatibility Matrix

| Feature | Claude Code | Codex | Antigravity |
|---|---|---|---|
| **Plugin Discovery** | `.claude-plugin/plugin.json` | `.codex-plugin/plugin.json` | Reuses Codex structure via `antigravity-harness.py` |
| **Marketplace Manifest** | `.claude-plugin/marketplace.json` | `.agents/plugins/marketplace.json` | Discovers via `marketplace.json` or local plugins |
| **Skills (`skills/*/SKILL.md`)** | Loaded as slash commands | Loaded as slash commands | Interpreted agentically on-demand via harness load |
| **Agent Personas (`agents/*.md`)** | Not natively multi-agent | Personas defined under `agents/` | **Fully supported** natively using `define_subagent` loaded from prompt |
| **Custom Commands** | Platform commands & hooks | Platform commands & hooks | Direct terminal execution using `run_command` |
| **MCP Integration** | Standard MCP JSON | Standard MCP JSON | Direct tool access in context |

## Execution Protocol for Antigravity:
1. **Discover Capabilities**: Run `uv run scripts/antigravity-harness.py list` to see what skills/personas are active.
2. **Execute a Skill**: Load its details using `uv run scripts/antigravity-harness.py skill <skill-name>` and follow the instructions manually.
3. **Instantiate a Persona**: Run `uv run scripts/antigravity-harness.py agent <agent-name>` to view/copy the prompt, then call `define_subagent` and `invoke_subagent` to delegate to it in a specialized sub-task.
"""
    console.print(Markdown(markdown_matrix))

def main():
    parser = argparse.ArgumentParser(description="Antigravity capability harness for Cofoundy plugins.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # list
    subparsers.add_parser("list", help="List all plugins, skills, and agents in the workspace.")

    # skill
    parser_skill = subparsers.add_parser("skill", help="View instructions for a specific skill.")
    parser_skill.add_argument("name", type=str, help="Name of the skill to inspect.")

    # agent
    parser_agent = subparsers.add_parser("agent", help="Load the persona prompt for a specialized agent.")
    parser_agent.add_argument("name", type=str, help="Name of the agent persona to inspect.")

    # matrix
    subparsers.add_parser("matrix", help="View the Claude / Codex / Antigravity capability matrix.")

    args = parser.parse_args()

    if args.command == "list":
        cmd_list(args)
    elif args.command == "skill":
        cmd_skill(args)
    elif args.command == "agent":
        cmd_agent(args)
    elif args.command == "matrix":
        cmd_matrix(args)

if __name__ == "__main__":
    main()
