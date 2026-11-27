"""Small stdio client for the native Codex configuration and skill APIs."""

import json
import queue
import subprocess
import threading
from contextlib import contextmanager


@contextmanager
def codex_app_server():
    proc = subprocess.Popen(
        ["codex", "app-server", "--stdio"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        text=True,
    )
    responses = queue.Queue()

    def receive():
        try:
            for line in proc.stdout:
                responses.put(json.loads(line))
        finally:
            responses.put(None)

    def send(message):
        proc.stdin.write(json.dumps(message) + "\n")
        proc.stdin.flush()

    def request(i, method, params):
        send({"id": i, "method": method, "params": params})
        while True:
            try:
                message = responses.get(timeout=60)
            except queue.Empty as error:
                raise RuntimeError(f"Timed out waiting for Codex {method}") from error
            if message is None:
                raise RuntimeError(f"Codex closed the connection during {method}")
            if message.get("id") == i:
                if "error" in message:
                    raise RuntimeError(
                        f"Codex rejected {method}: {message['error']['message']}"
                    )
                return message["result"]

    threading.Thread(target=receive, daemon=True).start()
    try:
        request(
            1,
            "initialize",
            {
                "clientInfo": {"name": "supercharged", "version": "1"},
                "capabilities": {"experimentalApi": True},
            },
        )
        send({"method": "initialized"})
        yield request
    finally:
        proc.terminate()
        proc.wait(timeout=10)
