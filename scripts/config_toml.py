#!/usr/bin/env python3
"""Shared TOML loading and Codex MCP normalization."""

from __future__ import annotations

import copy
import json
from pathlib import Path
import sys
from typing import Any

try:
    import tomllib
except ModuleNotFoundError as error:  # pragma: no cover - exercised on old hosts
    raise RuntimeError(
        "Python 3.11+ is required for Codex configuration checks; "
        "install the managed Python with npm run setup"
    ) from error


MCP_FIELDS = (
    "command",
    "args",
    "cwd",
    "enabled",
    "url",
    "env",
    "http_headers",
)


def load_toml(path: Path) -> dict[str, Any]:
    try:
        with path.open("rb") as source:
            document = tomllib.load(source)
    except tomllib.TOMLDecodeError as error:
        raise ValueError(f"{path}: malformed TOML: {error}") from error
    if not isinstance(document, dict):
        raise ValueError(f"{path}: TOML root must be a table")
    return document


def mcp_servers(document: dict[str, Any], *, source: Path | None = None) -> dict[str, dict[str, Any]]:
    raw_servers = document.get("mcp_servers", {})
    if not isinstance(raw_servers, dict):
        raise ValueError(f"{source or 'configuration'}: mcp_servers must be a table")
    result: dict[str, dict[str, Any]] = {}
    for name, server in raw_servers.items():
        if not isinstance(server, dict):
            raise ValueError(f"{source or 'configuration'}: MCP server {name!r} must be a table")
        result[str(name)] = copy.deepcopy(server)
    return result


def normalized_mcp(server: dict[str, Any]) -> dict[str, Any]:
    """Return comparable transport fields without exposing their values in logs."""
    return {field: copy.deepcopy(server[field]) for field in MCP_FIELDS if field in server}


def load_mcp_servers(config_dir: Path, profile: str = "base") -> dict[str, dict[str, Any]]:
    base_path = config_dir / "config.toml"
    servers = mcp_servers(load_toml(base_path), source=base_path)
    if profile != "base":
        profile_path = config_dir / f"{profile}.config.toml"
        servers.update(mcp_servers(load_toml(profile_path), source=profile_path))
    return servers


def audit_summary(config_dir: Path) -> dict[str, Any]:
    base = load_toml(config_dir / "config.toml")
    apple = load_toml(config_dir / "apple.config.toml")
    review = load_toml(config_dir / "review.config.toml")
    return {
        "profiles": sorted(path.name for path in config_dir.glob("*.config.toml")),
        "base_mcp": sorted(mcp_servers(base)),
        "apple_mcp": sorted(mcp_servers(apple)),
        "playwright_enabled": mcp_servers(base).get("playwright", {}).get("enabled"),
        "web_search": base.get("web_search"),
        "base_reasoning": base.get("model_reasoning_effort"),
        "review_reasoning": review.get("model_reasoning_effort"),
        "hooks": base.get("features", {}).get("hooks"),
        "memories": base.get("features", {}).get("memories"),
    }


def _main() -> int:
    if len(sys.argv) == 3 and sys.argv[1] == "audit-summary":
        print(json.dumps(audit_summary(Path(sys.argv[2])), sort_keys=True))
        return 0
    print(f"Usage: {Path(sys.argv[0]).name} audit-summary CONFIG_DIR", file=sys.stderr)
    return 2


if __name__ == "__main__":
    try:
        raise SystemExit(_main())
    except (OSError, RuntimeError, ValueError) as error:
        print(error, file=sys.stderr)
        raise SystemExit(2)
