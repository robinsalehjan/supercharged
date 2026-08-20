#!/usr/bin/env bats

load '../helpers/setup'

setup() {
    setup_test_env
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    CHECKER="$PROJECT_ROOT/scripts/check-mcps.py"
    CONFIG_DIR="$TEST_TEMP_DIR/config"
    mkdir -p "$CONFIG_DIR" "$TEST_TEMP_DIR/bin"

    cat > "$TEST_TEMP_DIR/bin/healthy-mcp" <<'EOF'
#!/bin/sh
IFS= read -r request
printf '%s\n' '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-06-18","capabilities":{},"serverInfo":{"name":"healthy","version":"1.2.3"}}}'
EOF
    cat > "$TEST_TEMP_DIR/bin/broken-mcp" <<'EOF'
#!/bin/sh
echo 'ImportError: dependency exploded' >&2
exit 1
EOF
    chmod +x "$TEST_TEMP_DIR/bin/healthy-mcp" "$TEST_TEMP_DIR/bin/broken-mcp"
}

teardown() {
    if [ -n "${HTTP_SERVER_PID:-}" ]; then
        kill "$HTTP_SERVER_PID" 2>/dev/null || true
        wait "$HTTP_SERVER_PID" 2>/dev/null || true
    fi
    teardown_test_env
}

@test "MCP checker reports healthy, broken, and disabled stdio servers" {
    cat > "$CONFIG_DIR/config.toml" <<EOF
[mcp_servers.healthy]
command = "$TEST_TEMP_DIR/bin/healthy-mcp"

[mcp_servers.broken]
command = "$TEST_TEMP_DIR/bin/broken-mcp"

[mcp_servers.disabled]
command = "missing-command"
enabled = false
EOF

    run "$CHECKER" --config-dir "$CONFIG_DIR" --json --timeout 2

    [ "$status" -eq 1 ]
    run jq -e '
        any(.[]; .name == "healthy" and .status == "pass" and .server_version == "1.2.3") and
        any(.[]; .name == "broken" and .status == "fail" and (.detail | contains("dependency exploded"))) and
        any(.[]; .name == "disabled" and .status == "skip")
    ' <<<"$output"
    [ "$status" -eq 0 ]
}

@test "MCP checker includes the selected profile inventory" {
    printf '%s\n' '# base config' > "$CONFIG_DIR/config.toml"
    cat > "$CONFIG_DIR/apple-headless.config.toml" <<EOF
[mcp_servers.XcodeBuildMCP]
command = "$TEST_TEMP_DIR/bin/healthy-mcp"
args = ["mcp"]
EOF

    run "$CHECKER" --config-dir "$CONFIG_DIR" --profile apple-headless \
        --server XcodeBuildMCP --json --timeout 2

    [ "$status" -eq 0 ]
    run jq -e 'length == 1 and .[0].name == "XcodeBuildMCP" and .[0].status == "pass"' <<<"$output"
    [ "$status" -eq 0 ]
}

@test "MCP checker initializes a streamable HTTP server" {
    cat > "$TEST_TEMP_DIR/http-mcp.py" <<'PYEOF'
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        size = int(self.headers.get("Content-Length", "0"))
        self.rfile.read(size)
        payload = {
            "jsonrpc": "2.0",
            "id": 1,
            "result": {
                "protocolVersion": "2025-06-18",
                "capabilities": {},
                "serverInfo": {"name": "http-test", "version": "4.5.6"},
            },
        }
        body = f"event: message\ndata: {json.dumps(payload)}\n\n".encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass

server = HTTPServer(("127.0.0.1", 0), Handler)
with open(sys.argv[1], "w") as port_file:
    port_file.write(str(server.server_port))
server.serve_forever()
PYEOF
    port_file="$TEST_TEMP_DIR/http-port"
    server_log="$TEST_TEMP_DIR/http-mcp.log"
    python3 "$TEST_TEMP_DIR/http-mcp.py" "$port_file" >"$server_log" 2>&1 &
    HTTP_SERVER_PID=$!
    for _ in {1..100}; do
        [ -s "$port_file" ] && break
        if ! kill -0 "$HTTP_SERVER_PID" 2>/dev/null; then
            echo "HTTP MCP test server exited before becoming ready" >&2
            cat "$server_log" >&2
            return 1
        fi
        sleep 0.1
    done

    if [ ! -s "$port_file" ]; then
        echo "Timed out waiting for HTTP MCP test server" >&2
        cat "$server_log" >&2
        return 1
    fi

    port=$(<"$port_file")
    cat > "$CONFIG_DIR/config.toml" <<EOF
[mcp_servers.docs]
url = "http://127.0.0.1:$port/mcp"
EOF

    run "$CHECKER" --config-dir "$CONFIG_DIR" --server docs --json --timeout 2

    [ "$status" -eq 0 ]
    run jq -e '.[0].transport == "http" and .[0].server_name == "http-test" and .[0].status == "pass"' <<<"$output"
    [ "$status" -eq 0 ]
}
