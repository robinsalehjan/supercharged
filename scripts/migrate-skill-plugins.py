#!/usr/bin/env python3
"""Configure standalone servers and retire only the superseded user plugin IDs."""

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tomllib

ROOT = Path(__file__).resolve().parents[1]
CLAUDE = Path.home() / ".claude"
CODEX = Path.home() / ".codex"
RETIRED = {"axiom@axiom-marketplace", "firebase@firebase"}


def read_json(path):
    return json.loads(path.read_text()) if path.exists() else {}


def run(args):
    subprocess.run(args, check=True, timeout=180)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    dry = parser.parse_args().dry_run
    desired = read_json(ROOT / "claude_config/mcp_servers.json")
    config = CODEX / "config.toml"
    codex = tomllib.loads(config.read_text()) if config.exists() else {}
    claude_config = (
        Path(os.environ.get("CLAUDE_CONFIG_DIR", Path.home())) / ".claude.json"
    )
    existing = {
        "claude": read_json(claude_config).get("mcpServers", {}),
        "codex": codex.get("mcp_servers", {}),
    }
    tracked_codex = tomllib.loads((ROOT / "codex_config/config.toml").read_text())[
        "mcp_servers"
    ]
    additions = []
    for host, servers in existing.items():
        for name in ("axiom", "firebase-tools", "openwiki"):
            definition = desired[name] if host == "claude" else tracked_codex[name]
            if name in servers:
                current = dict(servers[name])
                if current.get("type") == "stdio":
                    current.pop("type")
                if current.get("env") == {}:
                    current.pop("env")
                if current != definition:
                    raise ValueError(
                        f"Existing {host} MCP {name} differs; review before migration"
                    )
                continue
            if host == "claude":
                command = [
                    "claude",
                    "mcp",
                    "add-json",
                    "--scope",
                    "user",
                    name,
                    json.dumps(definition),
                ]
            else:
                command = ["codex", "mcp", "add", name]
                for key, value in definition.get("env", {}).items():
                    command.extend(["--env", f"{key}={value}"])
                command.extend(["--", definition["command"], *definition["args"]])
            additions.append(command)
            print(f"Configure {host} MCP {name}", flush=True)

    removals = []
    for pid in sorted(RETIRED & set(codex.get("plugins", {}))):
        removals.append(["codex", "plugin", "remove", pid])
    registry = read_json(CLAUDE / "plugins/installed_plugins.json").get("plugins", {})
    for pid in sorted(RETIRED & set(registry)):
        if any(record.get("scope") == "user" for record in registry[pid]):
            removals.append(
                ["claude", "plugin", "uninstall", "--scope", "user", "--keep-data", pid]
            )
    for command in removals:
        print("Retire " + command[0] + " plugin " + command[-1], flush=True)
    if dry:
        return
    for command in additions:
        run(command)
    run([sys.executable, ROOT / "scripts/verify-skill-discovery.py"])
    run(
        [
            sys.executable,
            ROOT / "scripts/check-mcps.py",
            "--config-dir",
            CODEX,
            "--timeout",
            "90",
            "--server",
            "axiom",
            "--server",
            "firebase-tools",
            "--server",
            "openwiki",
        ]
    )
    for command in removals:
        run(command)
    if removals:
        run([sys.executable, ROOT / "scripts/verify-skill-discovery.py"])


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        sys.exit(f"Migration stopped: {error}")
