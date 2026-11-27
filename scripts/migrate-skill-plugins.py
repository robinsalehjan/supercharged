#!/usr/bin/env python3
"""Verify the replacement skills and servers, then retire superseded user plugins."""

import argparse
import json
import subprocess
import sys
import tomllib
from pathlib import Path

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
    config = CODEX / "config.toml"
    codex = tomllib.loads(config.read_text()) if config.exists() else {}

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
