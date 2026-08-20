#!/usr/bin/env python3
"""Probe configured MCP servers by completing the initialize handshake."""

from __future__ import annotations

import argparse
import json
import os
import selectors
import shutil
import signal
import subprocess
import sys
import time
import urllib.error
import urllib.request
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any


PROTOCOL_VERSION = "2025-06-18"
CLIENT_INFO = {"name": "supercharged-mcp-health", "version": "1.0"}


@dataclass
class ProbeResult:
    name: str
    transport: str
    status: str
    detail: str
    server_name: str | None = None
    server_version: str | None = None


def initialize_request() -> dict[str, Any]:
    return {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": PROTOCOL_VERSION,
            "capabilities": {},
            "clientInfo": CLIENT_INFO,
        },
    }


def parse_initialize_response(payload: Any) -> tuple[str, str | None, str | None]:
    if not isinstance(payload, dict):
        raise ValueError("initialize response is not a JSON object")
    if payload.get("id") != 1:
        raise ValueError("initialize response has an unexpected request id")
    if "error" in payload:
        error = payload["error"]
        if isinstance(error, dict):
            raise ValueError(str(error.get("message", error)))
        raise ValueError(str(error))
    result = payload.get("result")
    if not isinstance(result, dict) or not result.get("protocolVersion"):
        raise ValueError("initialize response is missing result.protocolVersion")
    server_info = result.get("serverInfo")
    if not isinstance(server_info, dict):
        server_info = {}
    return (
        str(result["protocolVersion"]),
        str(server_info["name"]) if server_info.get("name") else None,
        str(server_info["version"]) if server_info.get("version") else None,
    )


def read_stdio_response(process: subprocess.Popen[bytes], timeout: float) -> dict[str, Any]:
    if process.stdout is None:
        raise RuntimeError("MCP process stdout is unavailable")

    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    deadline = time.monotonic() + timeout
    buffer = b""

    try:
        while time.monotonic() < deadline:
            wait = max(0.0, deadline - time.monotonic())
            events = selector.select(wait)
            if not events:
                break
            chunk = os.read(process.stdout.fileno(), 65536)
            if not chunk:
                break
            buffer += chunk
            while b"\n" in buffer:
                line, buffer = buffer.split(b"\n", 1)
                if not line.strip():
                    continue
                try:
                    message = json.loads(line)
                except (UnicodeDecodeError, json.JSONDecodeError):
                    continue
                if isinstance(message, dict) and message.get("id") == 1:
                    return message
    finally:
        selector.close()

    if buffer.strip():
        try:
            message = json.loads(buffer)
            if isinstance(message, dict) and message.get("id") == 1:
                return message
        except (UnicodeDecodeError, json.JSONDecodeError):
            pass

    if process.poll() is not None:
        raise RuntimeError(f"connection closed before initialize response (exit {process.returncode})")
    raise TimeoutError(f"initialize response timed out after {timeout:g}s")


def stop_process(process: subprocess.Popen[bytes]) -> None:
    if process.poll() is not None:
        return
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except (ProcessLookupError, PermissionError):
        try:
            process.terminate()
        except ProcessLookupError:
            pass
    try:
        process.wait(timeout=1)
    except subprocess.TimeoutExpired:
        if process.poll() is None:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except (ProcessLookupError, PermissionError):
                try:
                    process.kill()
                except ProcessLookupError:
                    pass
            process.wait(timeout=1)


def probe_stdio(name: str, config: dict[str, Any], timeout: float) -> ProbeResult:
    command = config.get("command")
    if not isinstance(command, str) or not command:
        return ProbeResult(name, "stdio", "fail", "missing command")

    args = config.get("args", [])
    if not isinstance(args, list) or not all(isinstance(arg, str) for arg in args):
        return ProbeResult(name, "stdio", "fail", "args must be an array of strings")

    cwd_value = config.get("cwd")
    cwd = Path(cwd_value).expanduser() if isinstance(cwd_value, str) else Path.cwd()
    executable = command
    if "/" in command:
        command_path = Path(command).expanduser()
        if not command_path.is_absolute():
            command_path = cwd / command_path
        executable = str(command_path)
        if not command_path.is_file() or not os.access(command_path, os.X_OK):
            return ProbeResult(name, "stdio", "fail", f"executable not found: {command_path}")
    elif shutil.which(command) is None:
        return ProbeResult(name, "stdio", "fail", f"executable not found on PATH: {command}")

    env = os.environ.copy()
    configured_env = config.get("env", {})
    if isinstance(configured_env, dict):
        env.update({str(key): str(value) for key, value in configured_env.items()})

    process: subprocess.Popen[bytes] | None = None
    try:
        process = subprocess.Popen(
            [executable, *args],
            cwd=cwd,
            env=env,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            start_new_session=True,
        )
        if process.stdin is None:
            raise RuntimeError("MCP process stdin is unavailable")
        process.stdin.write(json.dumps(initialize_request(), separators=(",", ":")).encode() + b"\n")
        process.stdin.flush()
        payload = read_stdio_response(process, timeout)
        protocol, server_name, server_version = parse_initialize_response(payload)
        return ProbeResult(
            name,
            "stdio",
            "pass",
            f"initialized with protocol {protocol}",
            server_name,
            server_version,
        )
    except (OSError, RuntimeError, TimeoutError, ValueError) as error:
        detail = str(error)
        if process is not None:
            stop_process(process)
        if process is not None and process.stderr is not None:
            try:
                stderr = process.stderr.read(4096).decode(errors="replace").strip()
            except OSError:
                stderr = ""
            if stderr:
                detail = f"{detail}: {stderr.splitlines()[-1]}"
        return ProbeResult(name, "stdio", "fail", detail)
    finally:
        if process is not None:
            stop_process(process)


def probe_http(name: str, config: dict[str, Any], timeout: float) -> ProbeResult:
    url = config.get("url")
    if not isinstance(url, str) or not url:
        return ProbeResult(name, "http", "fail", "missing URL")

    headers = {
        "Accept": "application/json, text/event-stream",
        "Content-Type": "application/json",
    }
    static_headers = config.get("http_headers", {})
    if isinstance(static_headers, dict):
        headers.update({str(key): str(value) for key, value in static_headers.items()})

    request = urllib.request.Request(
        url,
        data=json.dumps(initialize_request(), separators=(",", ":")).encode(),
        headers=headers,
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            content_type = response.headers.get_content_type()
            if content_type == "text/event-stream":
                payload: Any | None = None
                while line := response.readline():
                    if line.startswith(b"data:"):
                        payload = json.loads(line.removeprefix(b"data:").strip())
                        break
                if payload is None:
                    raise ValueError("event stream closed before initialize response")
            else:
                payload = json.load(response)
        protocol, server_name, server_version = parse_initialize_response(payload)
        return ProbeResult(
            name,
            "http",
            "pass",
            f"initialized with protocol {protocol}",
            server_name,
            server_version,
        )
    except (OSError, TimeoutError, ValueError, json.JSONDecodeError, urllib.error.HTTPError) as error:
        return ProbeResult(name, "http", "fail", str(error))


def parse_mcp_servers(path: Path) -> dict[str, dict[str, Any]]:
    """Parse the simple top-level MCP tables used by tracked Codex configs."""
    servers: dict[str, dict[str, Any]] = {}
    current: dict[str, Any] | None = None

    for raw_line in path.read_text().splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            parts = section.split(".")
            if len(parts) == 2 and parts[0] == "mcp_servers":
                current = servers.setdefault(parts[1], {})
            else:
                current = None
            continue
        if current is None or "=" not in line:
            continue
        key, raw_value = (part.strip() for part in line.split("=", 1))
        if key not in {"command", "args", "cwd", "enabled", "url"}:
            continue
        try:
            current[key] = json.loads(raw_value)
        except json.JSONDecodeError as error:
            raise ValueError(f"{path}: invalid {key} value: {error.msg}") from error
    return servers


def load_servers(config_dir: Path, profile: str) -> dict[str, dict[str, Any]]:
    servers = parse_mcp_servers(config_dir / "config.toml")

    if profile != "base":
        profile_path = config_dir / f"{profile}.config.toml"
        for name, server in parse_mcp_servers(profile_path).items():
            servers[name] = server
    return servers


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--config-dir",
        type=Path,
        default=Path(__file__).resolve().parent.parent / "codex_config",
        help="Directory containing config.toml and profile config files",
    )
    parser.add_argument(
        "--profile",
        choices=("base", "apple", "apple-headless", "review"),
        default="base",
    )
    parser.add_argument("--server", action="append", dest="servers", help="Probe only this server")
    parser.add_argument("--timeout", type=float, default=10.0)
    parser.add_argument("--json", action="store_true", dest="json_output")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.timeout <= 0:
        print("--timeout must be greater than zero", file=sys.stderr)
        return 2

    try:
        servers = load_servers(args.config_dir, args.profile)
    except (OSError, ValueError) as error:
        print(f"Failed to load MCP configuration: {error}", file=sys.stderr)
        return 2

    selected = set(args.servers or [])
    unknown = selected.difference(servers)
    if unknown:
        print(f"Unknown MCP server(s): {', '.join(sorted(unknown))}", file=sys.stderr)
        return 2

    results: list[ProbeResult] = []
    for name in sorted(servers):
        if selected and name not in selected:
            continue
        config = servers[name]
        if config.get("enabled", True) is False:
            results.append(ProbeResult(name, "disabled", "skip", "disabled in config"))
        elif "url" in config:
            results.append(probe_http(name, config, args.timeout))
        else:
            results.append(probe_stdio(name, config, args.timeout))

    if args.json_output:
        print(json.dumps([asdict(result) for result in results], separators=(",", ":")))
    else:
        for result in results:
            identity = result.server_name or result.name
            if result.server_version:
                identity = f"{identity} {result.server_version}"
            print(f"{result.status.upper():4}  {result.name} ({result.transport}) — {identity}: {result.detail}")

    return 1 if any(result.status == "fail" for result in results) else 0


if __name__ == "__main__":
    raise SystemExit(main())
