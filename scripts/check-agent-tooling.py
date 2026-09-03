#!/usr/bin/env python3
"""Report shared agent capabilities and reject avoidable harness drift."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import sys


def normalized_mcp(server: dict) -> dict:
    return {
        key: server[key]
        for key in ("command", "args", "url")
        if key in server
    }


def skill_names(directory: Path, pattern: str) -> list[str]:
    return sorted(path.parent.name for path in directory.glob(pattern))


def load_codex_mcp(path: Path) -> dict[str, dict]:
    """Read the simple top-level MCP adapter fields without a TOML dependency."""
    servers: dict[str, dict] = {}
    current: dict | None = None
    section_pattern = re.compile(r"^\[mcp_servers\.([^].]+)\]$")
    for raw_line in path.read_text().splitlines():
        line = raw_line.strip()
        section = section_pattern.match(line)
        if section:
            current = servers.setdefault(section.group(1), {})
            continue
        if line.startswith("["):
            current = None
            continue
        if current is None or not line or line.startswith("#") or "=" not in line:
            continue
        key, value = (part.strip() for part in line.split("=", 1))
        if key in {"command", "args", "url"}:
            current[key] = json.loads(value)
    return servers


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
    codex_mcp = load_codex_mcp(root / "codex_config/config.toml")

    for name, definition in claude_mcp.items():
        if name not in codex_mcp:
            errors.append(f"Codex is missing shared MCP server: {name}")
            continue
        if normalized_mcp(definition) != normalized_mcp(codex_mcp[name]):
            errors.append(f"Shared MCP configuration differs for: {name}")

    canonical_dir = root / "agent_config/skills"
    canonical_skills = skill_names(canonical_dir, "*/SKILL.md")
    claude_mirror_dir = root / ".claude/skills"
    claude_mirrors = sorted(path.stem for path in claude_mirror_dir.glob("*.md"))
    if canonical_skills != claude_mirrors:
        errors.append("Claude shared-skill mirror inventory differs from the canonical inventory")
    else:
        for name in canonical_skills:
            canonical = canonical_dir / name / "SKILL.md"
            mirror = claude_mirror_dir / f"{name}.md"
            if canonical.read_bytes() != mirror.read_bytes():
                errors.append(f"Claude shared-skill mirror content differs for: {name}")

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
    codex_profile_mcp: set[str] = set(codex_mcp) - set(claude_mcp)
    for profile in ("apple.config.toml", "apple-headless.config.toml"):
        codex_profile_mcp.update(load_codex_mcp(root / "codex_config" / profile))

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
            print("Shared MCP and skill adapters are in sync")

    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
