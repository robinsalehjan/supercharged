#!/usr/bin/env python3
"""Check discovery in fresh Codex and Claude CLI sessions without a model prompt."""

import json
import os
import re
import subprocess
from pathlib import Path

from codex_app_server import codex_app_server


def codex_paths():
    with codex_app_server() as request:
        blocks = request(
            2, "skills/list", {"cwds": [os.getcwd()], "forceReload": True}
        )["data"]
        if not blocks or any(b["errors"] for b in blocks):
            raise RuntimeError("Codex skill discovery failed")
        return {
            Path(s["path"]).resolve()
            for b in blocks
            for s in b["skills"]
            if s["enabled"]
        }


def claude_names():
    init = {
        "type": "control_request",
        "request_id": "skills",
        "request": {"subtype": "initialize"},
    }
    result = subprocess.run(
        [
            "claude",
            "-p",
            "--no-session-persistence",
            "--verbose",
            "--input-format",
            "stream-json",
            "--output-format",
            "stream-json",
        ],
        input=json.dumps(init) + "\n",
        text=True,
        capture_output=True,
        timeout=90,
        check=True,
    )
    for line in result.stdout.splitlines():
        message = json.loads(line)
        if message.get("type") == "control_response":
            return {c["name"] for c in message["response"]["response"]["commands"]}
    raise RuntimeError("Claude returned no command inventory")


if __name__ == "__main__":
    from shared_skills import CONFIG, catalog, read, release_path

    sources, _ = catalog()
    release = release_path(
        sources, read(CONFIG / "managed_tools.json")["tools"]["skills"]["version"]
    )
    if not (release / "inventory.json").is_file():
        raise SystemExit("Current catalog release is missing")
    inventory = read(release / "inventory.json")
    managed = [release / name / "SKILL.md" for name in inventory]
    missing = set()
    for skill in managed:
        for root in (Path.home() / ".agents/skills", Path.home() / ".claude/skills"):
            if (
                not skill.is_file()
                or (root / skill.parent.name / "SKILL.md").resolve() != skill.resolve()
            ):
                missing.add(skill)
    missing |= {p.resolve() for p in managed} - codex_paths()
    names = claude_names()
    for p in managed:
        if not p.is_file():
            continue
        declared = re.search(r"^name:\s*(.+)$", p.read_text(), re.M)
        if p.parent.name not in names and (
            not declared or declared[1].strip("'\"") not in names
        ):
            missing.add(p)
    if missing:
        raise SystemExit(
            "Missing from native discovery: "
            + ", ".join(sorted({p.parent.name for p in missing}))
        )
    print(f"Verified {len(managed)} managed skills in both agents")
