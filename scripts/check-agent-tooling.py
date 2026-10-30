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

    for name, definition in claude_mcp.items():
        if name not in codex_mcp:
            errors.append(f"Codex is missing shared MCP server: {name}")
            continue
        if normalized_mcp(definition) != normalized_mcp(codex_mcp[name]):
            errors.append(f"Shared MCP configuration differs for: {name}")

    canonical_dir = root / "agent_config/skills"
    canonical_skills = skill_names(canonical_dir, "*/SKILL.md")

    installed_skills = json.loads(
        (root / "agent_config/installed_skills.json").read_text()
    ).get("skills", {})
    claude_plugins = json.loads(
        (root / "claude_config/installed_plugins.json").read_text()
    )["plugins"]
    claude_marketplaces = json.loads(
        (root / "claude_config/known_marketplaces.json").read_text()
    )
    codex_registry = json.loads((root / "codex_config/plugins.json").read_text())
    codex_plugins = codex_registry["plugins"]
    codex_specific_skills = skill_names(root / "codex_config/skills", "*/SKILL.md")
    expected_profiles = {"apple.config.toml", "review.config.toml"}
    tracked_profiles = {
        path.name for path in (root / "codex_config").glob("*.config.toml")
    }
    for profile in sorted(tracked_profiles - expected_profiles):
        errors.append(f"Unexpected tracked Codex profile: {profile}")
    codex_profile_mcp: set[str] = set(codex_mcp) - set(claude_mcp)
    for profile in ("apple.config.toml",):
        profile_path = root / "codex_config" / profile
        codex_profile_mcp.update(mcp_servers(load_toml(profile_path), source=profile_path))

    report = {
        "ok": not errors,
        "shared": {
            "cli_tools": sorted(managed["tools"]),
            "mcp_servers": sorted(claude_mcp),
            "canonical_skills": canonical_skills,
            "git_skills": sorted(installed_skills),
        },
        "native_adapters": {
            "claude_marketplaces": sorted(claude_marketplaces),
            "claude_plugins": sorted(claude_plugins),
            "codex_marketplaces": sorted(
                marketplace["name"] for marketplace in codex_registry["marketplaces"]
            ),
            "codex_mcp_servers": sorted(codex_profile_mcp),
            "codex_plugins": sorted(plugin["id"] for plugin in codex_plugins),
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
        print(f"  skills: {', '.join(canonical_skills) or 'none'}")
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
