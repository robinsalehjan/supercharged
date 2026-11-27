"""Install pinned skills into immutable releases and publish agent discovery links."""

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import tomllib
import subprocess
import sys
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "agent_config"
HOME_DIR = Path.home()
STATE = HOME_DIR / ".local/share/supercharged/skills"


def read(path):
    return json.loads(path.read_text())


def digest(path):
    result = hashlib.sha256()
    for item in sorted(path.rglob("*")):
        if item.is_symlink():
            raise ValueError(f"Unexpected symlink inside skill: {item}")
        if item.is_file():
            result.update(os.fsencode(item.relative_to(path)) + b"\0")
            result.update(hashlib.sha256(item.read_bytes()).digest())
            result.update(bytes([bool(item.stat().st_mode & 0o111)]))
    return result.hexdigest()


def catalog():
    data = read(CONFIG / "installed_skills.json")
    override = CONFIG / "installed_skills.local.json"
    local = read(override) if override.exists() else {}
    entries = data["skills"] | local.get("skills", {})
    retired = data.get("removed_skills", {}) | local.get("removed_skills", {})
    sources = []
    for key, entry in entries.items():
        if key in retired:
            continue
        if "local" in entry:
            path = (ROOT / entry["local"]).resolve(strict=True)
            if not path.is_relative_to(ROOT):
                raise ValueError(f"Local source outside repository: {key}")
            source = str(path)
            fingerprint = digest(path)
        else:
            repo = (
                entry["repo"].removeprefix("https://github.com/").removesuffix(".git")
            )
            ref = entry["ref"]
            path = entry.get("path", "")
            if not re.fullmatch(r"[\w.-]+/[\w.-]+", repo) or not re.fullmatch(
                "[a-f0-9]{40}", ref
            ):
                raise ValueError(f"Invalid pinned source: {key}")
            if ".." in Path(path).parts or path.startswith("/"):
                raise ValueError(f"Invalid skill subdirectory: {key}")
            source = f"https://github.com/{repo}/tree/{ref}" + (
                f"/{path}" if path else ""
            )
            fingerprint = ref
        names = entry.get("names", ["*"])
        if (
            not isinstance(names, list)
            or not names
            or not all(
                isinstance(n, str) and n and not n.startswith("-") for n in names
            )
        ):
            raise ValueError(f"Invalid skill selection: {key}")
        sources.append((key, source, names, fingerprint))
    return sources, retired


def build(sources, version, release):
    if (release / "inventory.json").is_file():
        inventory = read(release / "inventory.json")
        if any(
            digest(release / name) != expected for name, expected in inventory.items()
        ):
            raise ValueError(f"Managed release was edited: {release}")
        return inventory
    with tempfile.TemporaryDirectory(dir=release.parent) as tmp:
        assembly = Path(tmp) / "release"
        assembly.mkdir()
        inventory = {}
        for index, (key, source, names, fingerprint) in enumerate(sources):
            stage = Path(tmp) / str(index)
            stage.mkdir()
            subprocess.run(
                [
                    "npx",
                    "--yes",
                    f"skills@{version}",
                    "add",
                    source,
                    "--skill",
                    *names,
                    "-a",
                    "codex",
                    "--copy",
                    "-y",
                ],
                cwd=stage,
                check=True,
                env=dict(os.environ, DISABLE_TELEMETRY="1", CI="1"),
            )
            found = sorted((stage / ".agents/skills").glob("*/SKILL.md"))
            if not found:
                raise ValueError(f"No skills installed from {key}")
            if source.startswith("https://"):
                locked = read(stage / "skills-lock.json")["skills"]
                if (
                    ("*" not in names and set(names) != set(locked))
                    or not locked
                    or any(v.get("commit") != fingerprint for v in locked.values())
                ):
                    raise ValueError(f"Unexpected lock revision: {key}")
            for skill in found:
                name = skill.parent.name
                if name in inventory:
                    raise ValueError(f"Multiple catalog sources install {name}")
                inventory[name] = digest(skill.parent)
                skill.parent.rename(assembly / name)
        (assembly / "inventory.json").write_text(json.dumps(inventory))
        assembly.rename(release)
    return inventory


def release_path(sources, version):
    # A release is portable across worktrees containing the same catalog and local files.
    inputs = [
        (
            key,
            Path(source).relative_to(ROOT).as_posix()
            if Path(source).is_absolute()
            else source,
            names,
            revision,
        )
        for key, source, names, revision in sources
    ]
    identity = hashlib.sha256(json.dumps([version, inputs]).encode()).hexdigest()
    return STATE / "releases" / identity


def reconcile(args, sources, retired, version, roots):
    releases = STATE / "releases"
    releases.mkdir(exist_ok=True)
    release = release_path(sources, version)
    inventory = build(sources, version, release)
    known = read(CONFIG / "legacy_skill_hashes.json")
    changes = {}
    legacy_codex = Path(os.environ.get("CODEX_HOME", HOME_DIR / ".codex")) / "skills"
    desired_roots = roots
    inspect_roots = list(roots)
    if args.harness != "claude" and legacy_codex not in roots:
        inspect_roots.append(legacy_codex)
    for root in inspect_roots:
        if root not in desired_roots and not root.exists():
            continue
        root.mkdir(parents=True, exist_ok=True)
        existing = set(inventory) | {
            p.name
            for p in root.iterdir()
            if p.is_symlink()
            and p.readlink().parent.parent == releases
            and p.readlink().name == p.name
        }
        if args.migrate:
            existing |= set(known) | set(retired)
        for name in sorted(existing):
            if Path(name).name != name or name.startswith("."):
                raise ValueError(f"Invalid skill name: {name}")
            target = root / name
            desired = (
                release / name if name in inventory and root in desired_roots else None
            )
            if target.is_symlink() and target.readlink() == desired:
                continue
            if target.is_symlink():
                if (
                    target.readlink().parent.parent != releases
                    or target.readlink().name != name
                ):
                    if desired or name in inventory:
                        raise ValueError(f"Unmanaged link: {target}")
                    continue
            elif target.exists():
                if not args.migrate:
                    if desired or name in inventory:
                        raise ValueError(
                            f"Existing skill {target}; preview migrate:skills"
                        )
                    continue
                if name in retired and (target / ".git").is_dir():
                    origin = subprocess.check_output(
                        ["git", "-C", target, "remote", "get-url", "origin"], text=True
                    ).strip()
                    dirty = subprocess.check_output(
                        ["git", "-C", target, "status", "--porcelain"], text=True
                    )
                    if origin != retired[name]["repo"] or dirty:
                        continue
                elif not target.is_dir() or digest(target) not in known.get(
                    name, []
                ) + ([inventory[name]] if desired else []):
                    if desired or name in inventory:
                        raise ValueError(
                            f"Unrecognized local skill; preserve or relocate before migration: {target}"
                        )
                    continue
            elif not desired:
                continue
            changes[target] = desired
    if not changes:
        return
    backup = STATE / "snapshots" / uuid.uuid4().hex
    backup.mkdir(parents=True)
    journal = []
    for i, (path, desired) in enumerate(changes.items()):
        journal.append(
            dict(
                path=str(path),
                saved=str(backup / str(i)),
                link=str(desired) if desired else None,
            )
        )
    (backup / "changes.json").write_text(json.dumps(journal, indent=2))
    print(f"Skill link rollback journal: {backup}", flush=True)
    try:
        for row in journal:
            path = Path(row["path"])
            if os.path.lexists(path):
                path.rename(row["saved"])
            if row["link"]:
                path.symlink_to(row["link"], target_is_directory=True)
    except BaseException:
        rollback(backup)
        raise


def rollback(backup):
    for row in reversed(read(backup / "changes.json")):
        path, saved = Path(row["path"]), Path(row["saved"])
        if path.is_symlink() and str(path.readlink()) == row["link"]:
            path.unlink()
        if os.path.lexists(saved):
            if os.path.lexists(path):
                raise ValueError(f"Rollback target occupied: {path}")
            saved.rename(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--harness", choices=["both", "claude", "codex"], default="both"
    )
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--migrate", action="store_true")
    parser.add_argument("--rollback", type=Path)
    args = parser.parse_args()
    if args.rollback:
        if args.dry_run or args.migrate:
            parser.error("--rollback is a separate operation")
        backup = args.rollback.resolve(strict=True)
        if backup.parent != (STATE / "snapshots").resolve():
            raise ValueError("Expected a managed snapshot directory")
        with (STATE / "lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            rollback(backup)
        return
    sources, retired = catalog()
    version = read(CONFIG / "managed_tools.json")["tools"]["skills"]["version"]
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError("Invalid skills CLI pin")
    roots = []
    if args.harness != "claude":
        roots.append(
            Path(os.environ.get("CODEX_SKILLS_DIR", HOME_DIR / ".agents/skills"))
        )
    if args.harness != "codex":
        roots.append(
            Path(
                os.environ.get(
                    "CLAUDE_SKILLS_DIR",
                    Path(os.environ.get("CLAUDE_HOME", HOME_DIR / ".claude"))
                    / "skills",
                )
            )
        )
    if not args.migrate:
        retired_plugins = {"axiom@axiom-marketplace", "firebase@firebase"}
        config = Path(os.environ.get("CODEX_HOME", HOME_DIR / ".codex")) / "config.toml"
        registry = (
            Path(os.environ.get("CLAUDE_HOME", HOME_DIR / ".claude"))
            / "plugins/installed_plugins.json"
        )
        installed = set()
        if args.harness != "claude" and config.exists():
            installed.update(tomllib.loads(config.read_text()).get("plugins", {}))
        if args.harness != "codex" and registry.exists():
            installed.update(
                plugin
                for plugin, records in read(registry).get("plugins", {}).items()
                if any(record.get("scope") == "user" for record in records)
            )
        if retired_plugins & installed:
            message = "Legacy native skill plugins detected; run npm run migrate:skills -- --dry-run"
            if not args.dry_run:
                raise ValueError(message)
            print(message)
    if args.dry_run:
        for key, source, names, _ in sources:
            print(
                f"[dry-run] {key}: {source} ({', '.join(names)}) -> {', '.join(map(str, roots))}"
            )
        preview_roots = list(roots)
        if args.migrate and args.harness != "claude":
            legacy = Path(os.environ.get("CODEX_HOME", HOME_DIR / ".codex")) / "skills"
            if legacy not in preview_roots:
                preview_roots.append(legacy)
        for root in preview_roots:
            if root.exists():
                for item in sorted(root.glob("*/SKILL.md")):
                    if not item.parent.is_symlink():
                        print(
                            f"[dry-run] Existing local skill to check during migration: {item.parent}"
                        )
        return
    STATE.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (STATE / "lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        reconcile(args, sources, retired, version, roots)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, KeyError, subprocess.SubprocessError) as error:
        sys.exit(f"Skill reconciliation failed: {error}")
