#!/usr/bin/env python3
"""Register repository-owned MCP servers, preserving existing user settings."""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import tomllib
from pathlib import Path

from codex_app_server import codex_app_server
from config_toml import load_mcp_servers

ROOT = Path(__file__).resolve().parents[1]


def comparable(entry):
    # The native clients may omit these defaults when serializing a registration.
    fields = dict(entry)
    if fields.get("type") == "stdio":
        del fields["type"]
    if fields.get("env") == {}:
        del fields["env"]
    if fields.get("enabled") is True:
        del fields["enabled"]
    return fields


def missing_servers(host, desired, current):
    missing = {}
    for name, definition in desired.items():
        if name not in current:
            missing[name] = definition
        elif comparable(current[name]) != comparable(definition):
            raise ValueError(
                f"Existing {host} MCP {name} differs; review the local registration"
            )
    return missing


def claude_additions(ios):
    user = Path(os.environ.get("CLAUDE_CONFIG_DIR") or Path.home()) / ".claude.json"
    desired = json.loads((ROOT / "claude_config/mcp_servers.json").read_text())
    if ios:
        desired.update(
            json.loads((ROOT / "claude_config/apple.mcp_servers.json").read_text())
        )
    current = (
        json.loads(user.read_text()).get("mcpServers", {}) if user.exists() else {}
    )
    return missing_servers("Claude", desired, current)


def register_codex(desired):
    # The native config writer handles approval tables and HTTP options without
    # starting an interactive OAuth login. A concurrent edit invalidates the version.
    with codex_app_server() as request:
        layers = request(2, "config/read", {"includeLayers": True})["layers"]
        user = next(layer for layer in layers if layer["name"]["type"] == "user")
        missing = missing_servers(
            "Codex", desired, user["config"].get("mcp_servers", {})
        )
        if missing:
            edits = [
                {
                    "keyPath": "mcp_servers." + name,
                    "value": value,
                    "mergeStrategy": "replace",
                }
                for name, value in missing.items()
            ]
            request(
                3,
                "config/batchWrite",
                {"edits": edits, "expectedVersion": user["version"]},
            )


def apple_profile_plan(before):
    # Codex's config API writes only the user base file. Copy missing tables
    # from the tracked profile and validate the result before publishing it.
    tracked = (ROOT / "codex_config/apple.config.toml").read_text()
    desired = tomllib.loads(tracked)["mcp_servers"]
    current = tomllib.loads(before or "")
    missing = missing_servers(
        "Codex apple profile", desired, current.get("mcp_servers", {})
    )
    if not before or not missing:
        return missing, tracked if not before else before
    blocks = []
    for block in re.split(r"(?m)(?=^\[)", tracked):
        if tomllib.loads(block).get("mcp_servers", {}).keys() & missing.keys():
            blocks.append(block)
    after = before + "\n\n" + "".join(blocks)
    expected = current | {"mcp_servers": current.get("mcp_servers", {}) | missing}
    if tomllib.loads(after) != expected:
        raise ValueError("Unable to merge the tracked Apple MCP profile")
    return missing, after


def write_profile(path, before, after):
    with tempfile.NamedTemporaryFile(dir=path.parent, mode="w", delete=False) as staged:
        temp = Path(staged.name)
        try:
            staged.write(after)
            staged.flush()
            if before is None:
                os.link(temp, path)
            else:
                if path.read_text() != before:
                    raise ValueError("Codex Apple profile changed during setup; retry")
                temp.chmod(path.stat().st_mode & 0o777)
                os.replace(temp, path)
        finally:
            temp.unlink(missing_ok=True)


def install(harness, dry, ios):
    additions = {}
    if harness in ("both", "claude"):
        additions["Claude"] = claude_additions(ios)
    if harness in ("both", "codex"):
        home = Path(os.environ.get("CODEX_HOME") or Path.home() / ".codex")
        desired = load_mcp_servers(ROOT / "codex_config")
        current = load_mcp_servers(home) if (home / "config.toml").exists() else {}
        additions["Codex"] = missing_servers("Codex", desired, current)
        profile = (home / "apple.config.toml").resolve()
        before = profile.read_text() if profile.exists() else None
        additions["Codex apple profile"], after = apple_profile_plan(before)

    for host, servers in additions.items():
        for name in servers:
            prefix = "[dry-run] " if dry else ""
            print(f"{prefix}Register {host} MCP {name}", flush=True)
    if dry:
        return
    for cli in ("Claude", "Codex"):
        if additions.get(cli) and not shutil.which(cli.lower()):
            raise ValueError(f"{cli} CLI is required for MCP registration")
    if additions.get("Codex"):
        home.mkdir(parents=True, exist_ok=True)
        register_codex(desired)
    if additions.get("Codex apple profile"):
        profile.parent.mkdir(parents=True, exist_ok=True)
        write_profile(profile, before, after)
    for name, definition in additions.get("Claude", {}).items():
        cmd = [
            "claude",
            "mcp",
            "add-json",
            "--scope",
            "user",
            name,
            json.dumps(definition),
        ]
        if subprocess.run(cmd, check=False, timeout=60).returncode:
            raise RuntimeError(f"Claude could not register MCP {name}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--ios", action="store_true")
    parser.add_argument(
        "--harness", choices=("both", "claude", "codex"), default="both"
    )
    args = parser.parse_args()
    try:
        install(args.harness, args.dry_run, args.ios)
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        sys.exit(f"MCP registration stopped: {error}")
