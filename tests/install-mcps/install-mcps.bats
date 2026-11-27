#!/usr/bin/env bats
load '../helpers/setup'

setup() {
  setup_test_env
  root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  install="$root/scripts/install-mcps.py"
  export CODEX_HOME="$HOME/.codex"
  unset CLAUDE_CONFIG_DIR
  mkdir -p "$CODEX_HOME" "$TEST_TEMP_DIR/bin"
  export PATH="$TEST_TEMP_DIR/bin:$PATH"
  cat > "$TEST_TEMP_DIR/bin/claude" <<'PY'
#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
assert sys.argv[1:5] == ["mcp", "add-json", "--scope", "user"]
user = Path(os.environ.get("CLAUDE_CONFIG_DIR", Path.home())) / ".claude.json"
config = json.loads(user.read_text()) if user.exists() else {}
servers = config.setdefault("mcpServers", {})
name, definition = sys.argv[5:]
assert name not in servers
servers[name] = json.loads(definition)
user.write_text(json.dumps(config))
PY
  chmod +x "$TEST_TEMP_DIR/bin/claude"
}
teardown() { teardown_test_env; }

@test "Claude installs both transports at user scope and preserves local and project state" {
  printf '%s\n' '{"projects":{"example":{}},"mcpServers":{"XcodeBuildMCP":{"command":"local"}}}' > "$HOME/.claude.json"
  run "$install" --harness claude
  [ "$status" -eq 0 ]
  jq -e '.mcpServers.cloudflare == {"type":"http","url":"https://mcp.cloudflare.com/mcp"} and
    .mcpServers.playwright == {"command":"playwright-mcp","args":["--headless"]} and
    .mcpServers.XcodeBuildMCP.command == "local" and .projects.example == {} and
    (.mcpServers | has("code-review-graph") or has("openaiDeveloperDocs") or has("xcode") | not)' "$HOME/.claude.json"
  [ ! -e "$CODEX_HOME/config.toml" ]
  run "$install" --harness claude --ios
  [ "$status" -eq 0 ]
  jq -e '.mcpServers.xcode == {"command":"xcrun","args":["mcpbridge"]}' "$HOME/.claude.json"
  run "$install" --harness claude --ios
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "Codex preview includes both scopes and never writes either agent home" {
  run "$install" --harness codex --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *'Register Codex MCP cloudflare'* ]]
  [[ "$output" == *'Register Codex MCP code-review-graph'* ]]
  [[ "$output" == *'Register Codex apple profile MCP xcode'* ]]
  [[ "$output" != *Claude* ]]
  [ ! -e "$CODEX_HOME/config.toml" ]
  [ ! -e "$CODEX_HOME/apple.config.toml" ]
  [ ! -e "$HOME/.claude.json" ]
}

@test "Codex profile conflict aborts both harnesses before any registration" {
  echo '[mcp_servers.xcode]' > "$CODEX_HOME/apple.config.toml"
  echo 'command = "local"' >> "$CODEX_HOME/apple.config.toml"
  run "$install"
  [ "$status" -ne 0 ]
  [[ "$output" == *'Existing Codex apple profile MCP xcode differs'* ]]
  [ ! -e "$HOME/.claude.json" ]
  [ ! -e "$CODEX_HOME/config.toml" ]
}

@test "Codex batches full server definitions and preserves existing Apple profile settings" {
  cat > "$TEST_TEMP_DIR/bin/codex" <<'PY'
#!/usr/bin/env python3
import json, sys
from pathlib import Path
for line in sys.stdin:
    req = json.loads(line)
    method = req["method"]
    if method == "initialized":
        continue
    result = {}
    if method == "config/read":
        result = {"layers":[{"name":{"type":"user"},"config":{},"version":"fixture"}]}
    if method == "config/batchWrite":
        assert req["params"]["expectedVersion"] == "fixture"
        (Path.home() / "writes.json").write_text(json.dumps(req["params"]["edits"]))
    print(json.dumps({"id":req["id"],"result":result}), flush=True)
PY
  chmod +x "$TEST_TEMP_DIR/bin/codex"
  printf '%s\n' '# keep' 'model="local"' '[mcp_servers.personal]' 'command="personal"' > "$CODEX_HOME/apple.config.toml"
  run "$install" --harness codex
  [ "$status" -eq 0 ]
  jq -e 'map({key:.keyPath,value:.value})|from_entries|
    .["mcp_servers.cloudflare"].url == "https://mcp.cloudflare.com/mcp" and
    .["mcp_servers.code-review-graph"].tools.get_review_context_tool.approval_mode == "approve" and
    .["mcp_servers.xcode"] == null' "$HOME/writes.json"
  python3 - "$CODEX_HOME/apple.config.toml" <<'PY'
import sys, tomllib
from pathlib import Path
s = Path(sys.argv[1]).read_text()
assert "# keep" in s
d = tomllib.loads(s)
assert d["model"] == "local" and d["mcp_servers"]["personal"]["command"] == "personal"
assert d["mcp_servers"]["xcode"] == {"command": "xcrun", "args": ["mcpbridge"]}
PY
  [ ! -e "$HOME/.claude.json" ]
}
