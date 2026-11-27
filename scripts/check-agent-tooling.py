#!/usr/bin/env python3
"""Report shared agent capabilities and reject avoidable harness drift."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import sys

try:
    from config_toml import load_mcp_servers, load_toml, mcp_servers, normalized_mcp
except RuntimeError as error:
    print(error, file=sys.stderr)
    raise SystemExit(2)


def skill_names(directory: Path, pattern: str) -> list[str]:
    return sorted(path.parent.name for path in directory.glob(pattern))


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Check shared Claude/Codex tooling parity and report native adapters."
    )
    parser.add_argument("--json", action="store_true", help="emit machine-readable JSON")
    args = parser.parse_args()

    default_root = Path(__file__).resolve().parent.parent
    root = Path(os.environ.get("SUPERCHARGED_PROJECT_ROOT", default_root))
    errors: list[str] = []

    managed = json.loads((root / "agent_config/managed_tools.json").read_text())
    claude_mcp = json.loads((root / ".mcp.json").read_text())["mcpServers"]
    try:
        codex_mcp = load_mcp_servers(root / "codex_config")
    except (OSError, ValueError) as error:
        print(f"Failed to load Codex TOML: {error}", file=sys.stderr)
        return 2

    claude_user = json.loads((root / "claude_config/mcp_servers.json").read_text())
    duplicate = set(claude_mcp) & set(claude_user)
    if duplicate:
        errors.append(f"Duplicate Claude project and user MCPs: {', '.join(sorted(duplicate))}")
    claude_mcp.update(claude_user)
    for name, definition in claude_mcp.items():
        if name == "openwiki" and definition.get("args") == ["mcp", "--host", "claude"]:
            definition = dict(definition, args=["mcp", "--host", "codex"])
        if name not in codex_mcp:
            errors.append(f"Codex is missing shared MCP server: {name}")
            continue
        if normalized_mcp(definition) != normalized_mcp(codex_mcp[name]):
            errors.append(f"Shared MCP configuration differs for: {name}")

    installed_skills = json.loads(
        (root / "agent_config/installed_skills.json").read_text()
    ).get("skills", {})
    claude_plugins = json.loads(
        (root / "claude_config/installed_plugins.json").read_text()
    )["plugins"]
    claude_marketplaces = json.loads(
        (root / "claude_config/known_marketplaces.json").read_text()
    )
    codex_config = load_toml(root / "codex_config/config.toml")
    codex_specific_skills = skill_names(root / "codex_config/skills", "*/SKILL.md")
    expected_profiles = {"apple.config.toml", "review.config.toml"}
    tracked_profiles = {
        path.name for path in (root / "codex_config").glob("*.config.toml")
    }
    for profile in sorted(tracked_profiles - expected_profiles):
        errors.append(f"Unexpected tracked Codex profile: {profile}")
    codex_profile_mcp: set[str] = set(codex_mcp) - set(claude_mcp)
    profile_path = root / "codex_config/apple.config.toml"
    apple_servers = mcp_servers(load_toml(profile_path), source=profile_path)
    claude_apple = json.loads((root / "claude_config/apple.mcp_servers.json").read_text())
    if set(claude_apple) & (set(claude_mcp) | set(codex_mcp)):
        errors.append("Optional Apple MCP also appears in the base configuration")
    for name, definition in claude_apple.items():
        if name not in apple_servers or normalized_mcp(definition) != normalized_mcp(apple_servers[name]):
            errors.append(f"Shared Apple MCP configuration differs for: {name}")
    codex_profile_mcp.update(apple_servers)

    report = {
        "ok": not errors,
        "shared": {
            "cli_tools": sorted(managed["tools"]),
            "mcp_servers": sorted(claude_mcp),
            "apple_mcp_servers": sorted(claude_apple),
            "canonical_skills": sorted(
                name for entry in installed_skills.values() if "local" in entry
                for name in skill_names(root / entry["local"], "**/SKILL.md")
            ),
            "git_skills": sorted(key for key, entry in installed_skills.items() if "repo" in entry),
        },
        "native_adapters": {
            "claude_marketplaces": sorted(claude_marketplaces),
            "claude_plugins": sorted(claude_plugins),
            "codex_marketplaces": sorted(codex_config.get("marketplaces", {})),
            "codex_mcp_servers": sorted(codex_profile_mcp),
            "codex_plugins": sorted(codex_config.get("plugins", {})),
            "codex_skills": codex_specific_skills,
        },
        "errors": errors,
    }

    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        print("Shared agent tooling")
        print(f"  CLIs: {', '.join(report['shared']['cli_tools']) or 'none'}")
        print(f"  MCPs: {', '.join(report['shared']['mcp_servers']) or 'none'}")
        print(f"  Apple MCPs (Claude iOS selection / Codex apple profile): {', '.join(claude_apple)}")
        print(f"  skills: {', '.join(sorted(installed_skills)) or 'none'}")
        print("Native harness adapters")
        print(f"  Claude marketplaces: {', '.join(report['native_adapters']['claude_marketplaces']) or 'none'}")
        print(f"  Claude plugins: {', '.join(report['native_adapters']['claude_plugins']) or 'none'}")
        print(f"  Codex marketplaces: {', '.join(report['native_adapters']['codex_marketplaces']) or 'none'}")
        print(f"  Codex MCPs: {', '.join(report['native_adapters']['codex_mcp_servers']) or 'none'}")
        print(f"  Codex plugins: {', '.join(report['native_adapters']['codex_plugins']) or 'none'}")
        print(f"  Codex-only skills: {', '.join(codex_specific_skills) or 'none'}")
        if errors:
            print("Parity errors", file=sys.stderr)
            for error in errors:
                print(f"  - {error}", file=sys.stderr)
        else:
            print("Shared MCP adapters are in sync")

    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
