#!/bin/zsh

# ============================================================================
# Claude Code Backup Script
# ============================================================================
# This script backs up non-sensitive Claude Code configuration files
# from ~/.claude to the repository's claude_config directory

set -e
set -o pipefail

source "$(dirname "$0")/utils.sh"

# Get the directory where this script is located (use pre-computed from utils.sh)
PROJECT_ROOT="$UTILS_PROJECT_ROOT"
CLAUDE_CONFIG_DIR="$PROJECT_ROOT/claude_config"
CLAUDE_HOME="$HOME/.claude"

# List of marketplaces to exclude from backup (work-related or sensitive plugins)
SANITIZE_MARKETPLACES=("vend-plugins")

# List of env var keys to exclude from backup (sensitive credentials)
SANITIZE_ENV_VARS=("GITHUB_PERSONAL_ACCESS_TOKEN")

# Validate that ~/.claude exists
if [ ! -d "$CLAUDE_HOME" ]; then
    log_with_level "ERROR" "Claude Code directory not found at $CLAUDE_HOME"
    log_with_level "INFO" "Please ensure Claude Code is installed first"
    exit 1
fi

# Validate jq is available for JSON manipulation
if ! command -v jq &> /dev/null; then
    log_with_level "ERROR" "jq is required for sanitizing JSON files"
    log_with_level "INFO" "Install with: brew install jq"
    exit 1
fi

log_with_level "INFO" "Backing up Claude Code configuration..."

# Create claude_config directory if it doesn't exist
mkdir -p "$CLAUDE_CONFIG_DIR"

# Backup settings.json (sanitize enabledPlugins from work-related marketplaces)
if [ -f "$CLAUDE_HOME/settings.json" ]; then
    # Filter enabledPlugins to remove work-related marketplaces
    settings_json=$(cat "$CLAUDE_HOME/settings.json")
    filtered_plugins=$(filter_json_by_marketplace "$settings_json" ".enabledPlugins" "${SANITIZE_MARKETPLACES[@]}")

    # Build jq filter to remove sensitive env vars
    env_del_filter=""
    for env_var in "${SANITIZE_ENV_VARS[@]}"; do
        env_del_filter="${env_del_filter} | del(.env[\"${env_var}\"])"
        env_del_filter="${env_del_filter} | del(.mcpServers[]?.env[\"${env_var}\"])"
    done

    # Preserve all fields except enabledPlugins, then apply sanitized enabledPlugins and strip sensitive env vars
    # Write to temp file first to avoid corrupting output on pipeline failure
    if ! jq -a --argjson plugins "$filtered_plugins" "(. + {enabledPlugins: \$plugins})${env_del_filter}" <<< "$settings_json" | \
        make_path_portable > "$CLAUDE_CONFIG_DIR/settings.json.tmp"; then
        rm -f "$CLAUDE_CONFIG_DIR/settings.json.tmp"
        log_with_level "ERROR" "Failed to sanitize settings.json - backup aborted"
        exit 1
    fi
    mv "$CLAUDE_CONFIG_DIR/settings.json.tmp" "$CLAUDE_CONFIG_DIR/settings.json"
    log_with_level "SUCCESS" "Backed up settings.json (sanitized ${#SANITIZE_MARKETPLACES[@]} marketplace(s) from enabledPlugins, stripped ${#SANITIZE_ENV_VARS[@]} env var(s), paths made portable)"
else
    log_with_level "WARN" "settings.json not found"
fi

# Backup plugin configuration files (strip home directory for portability and remove work-related marketplaces)
if [ -f "$CLAUDE_HOME/plugins/installed_plugins.json" ]; then
    # Filter plugins to remove work-related marketplaces
    plugins_json=$(cat "$CLAUDE_HOME/plugins/installed_plugins.json")
    filtered_plugins=$(filter_json_by_marketplace "$plugins_json" ".plugins" "${SANITIZE_MARKETPLACES[@]}")

    # Save sanitized plugins to local file (machine-specific, gitignored)
    local_plugins=$(extract_json_by_marketplace "$plugins_json" ".plugins" "${SANITIZE_MARKETPLACES[@]}")
    local_count=$(jq 'length' <<< "$local_plugins")
    if [ "$local_count" -gt 0 ]; then
        jq --argjson plugins "$local_plugins" '{version: .version, plugins: $plugins}' <<< "$plugins_json" | \
            make_path_portable > "$CLAUDE_CONFIG_DIR/installed_plugins.local.json"
        log_with_level "SUCCESS" "Saved $local_count local plugin(s) to installed_plugins.local.json"
    fi

    # Preserve version and update plugins
    # Write to temp file first to avoid corrupting output on pipeline failure
    if ! jq --argjson plugins "$filtered_plugins" "{version: .version, plugins: \$plugins}" <<< "$plugins_json" | \
        make_path_portable > "$CLAUDE_CONFIG_DIR/installed_plugins.json.tmp"; then
        rm -f "$CLAUDE_CONFIG_DIR/installed_plugins.json.tmp"
        log_with_level "ERROR" "Failed to sanitize installed_plugins.json - backup aborted"
        exit 1
    fi
    mv "$CLAUDE_CONFIG_DIR/installed_plugins.json.tmp" "$CLAUDE_CONFIG_DIR/installed_plugins.json"
    log_with_level "SUCCESS" "Backed up installed_plugins.json (sanitized ${#SANITIZE_MARKETPLACES[@]} marketplace(s), paths made portable)"
else
    log_with_level "WARN" "installed_plugins.json not found"
fi

if [ -f "$CLAUDE_HOME/plugins/known_marketplaces.json" ]; then
    # Build jq filter to remove sanitized marketplaces
    # Uses --arg to avoid jq filter injection from marketplace names
    jq_args=()
    jq_filter='.'
    i=0
    for marketplace in "${SANITIZE_MARKETPLACES[@]}"; do
        jq_args+=(--arg "mp$i" "$marketplace")
        jq_filter="$jq_filter | del(.[(\$mp$i)])"
        i=$((i + 1))
    done

    full_json=$(cat "$CLAUDE_HOME/plugins/known_marketplaces.json")
    filtered_json=$(jq "${jq_args[@]}" "$jq_filter" <<< "$full_json")

    # Save sanitized marketplaces to local file (machine-specific, gitignored)
    local_marketplaces=$(jq --argjson filtered "$filtered_json" \
        'with_entries(select(.key as $k | $filtered | has($k) | not))' <<< "$full_json")
    local_mp_count=$(jq 'length' <<< "$local_marketplaces")
    if [ "$local_mp_count" -gt 0 ]; then
        make_path_portable <<< "$local_marketplaces" > "$CLAUDE_CONFIG_DIR/known_marketplaces.local.json"
        log_with_level "SUCCESS" "Saved $local_mp_count local marketplace(s) to known_marketplaces.local.json"
    fi

    # Write to temp file first to avoid corrupting output on pipeline failure
    if ! make_path_portable <<< "$filtered_json" > "$CLAUDE_CONFIG_DIR/known_marketplaces.json.tmp"; then
        rm -f "$CLAUDE_CONFIG_DIR/known_marketplaces.json.tmp"
        log_with_level "ERROR" "Failed to sanitize known_marketplaces.json - backup aborted"
        exit 1
    fi
    mv "$CLAUDE_CONFIG_DIR/known_marketplaces.json.tmp" "$CLAUDE_CONFIG_DIR/known_marketplaces.json"
    log_with_level "SUCCESS" "Backed up known_marketplaces.json (sanitized ${#SANITIZE_MARKETPLACES[@]} marketplace(s), paths made portable)"
else
    log_with_level "WARN" "known_marketplaces.json not found"
fi

# Backup keybindings.json (custom keyboard shortcuts)
if [ -f "$CLAUDE_HOME/keybindings.json" ]; then
    if ! make_path_portable < "$CLAUDE_HOME/keybindings.json" > "$CLAUDE_CONFIG_DIR/keybindings.json.tmp"; then
        rm -f "$CLAUDE_CONFIG_DIR/keybindings.json.tmp"
        log_with_level "ERROR" "Failed to process keybindings.json - backup aborted"
        exit 1
    fi
    mv "$CLAUDE_CONFIG_DIR/keybindings.json.tmp" "$CLAUDE_CONFIG_DIR/keybindings.json"
    log_with_level "SUCCESS" "Backed up keybindings.json (paths made portable)"
else
    log_with_level "WARN" "keybindings.json not found"
fi

# Backup CLAUDE.md (global personal instructions)
if [ -f "$CLAUDE_HOME/CLAUDE.md" ]; then
    if ! make_path_portable < "$CLAUDE_HOME/CLAUDE.md" > "$CLAUDE_CONFIG_DIR/CLAUDE.md.tmp"; then
        rm -f "$CLAUDE_CONFIG_DIR/CLAUDE.md.tmp"
        log_with_level "ERROR" "Failed to process CLAUDE.md - backup aborted"
        exit 1
    fi
    mv "$CLAUDE_CONFIG_DIR/CLAUDE.md.tmp" "$CLAUDE_CONFIG_DIR/CLAUDE.md"
    log_with_level "SUCCESS" "Backed up CLAUDE.md (global instructions, paths made portable)"
else
    log_with_level "WARN" "CLAUDE.md not found"
fi

# Backup CLAUDE.md @-referenced files (RTK.md, claude-token-efficient.md, etc.)
claude_md_refs_backed_up=()
if [ -f "$CLAUDE_HOME/CLAUDE.md" ]; then
    while IFS= read -r ref_file; do
        if [ -f "$CLAUDE_HOME/$ref_file" ]; then
            if ! make_path_portable < "$CLAUDE_HOME/$ref_file" > "$CLAUDE_CONFIG_DIR/$ref_file.tmp"; then
                rm -f "$CLAUDE_CONFIG_DIR/$ref_file.tmp"
                log_with_level "ERROR" "Failed to process $ref_file - backup aborted"
                exit 1
            fi
            mv "$CLAUDE_CONFIG_DIR/$ref_file.tmp" "$CLAUDE_CONFIG_DIR/$ref_file"
            claude_md_refs_backed_up+=("$ref_file")
            log_with_level "SUCCESS" "Backed up $ref_file (CLAUDE.md @-reference, paths made portable)"
        else
            log_with_level "WARN" "$ref_file referenced in CLAUDE.md but not found"
        fi
    done < <(sed -n 's/^@\(.*\.md\)$/\1/p' "$CLAUDE_HOME/CLAUDE.md")
fi

# Backup statusline Config.toml (theme and display configuration)
STATUSLINE_CONFIG="$CLAUDE_HOME/statusline/Config.toml"
if [ -f "$STATUSLINE_CONFIG" ]; then
    mkdir -p "$CLAUDE_CONFIG_DIR/statusline"
    cp "$STATUSLINE_CONFIG" "$CLAUDE_CONFIG_DIR/statusline/Config.toml"
    log_with_level "SUCCESS" "Backed up statusline/Config.toml"
else
    log_with_level "WARN" "statusline/Config.toml not found"
fi

log_with_level "SUCCESS" "Claude Code configuration backup completed!"
echo ""
echo "📦 Backed up files:"
echo "   - settings.json"
echo "   - installed_plugins.json"
echo "   - known_marketplaces.json"
echo "   - keybindings.json"
echo "   - CLAUDE.md"
for ref_file in "${claude_md_refs_backed_up[@]}"; do
    echo "   - $ref_file"
done
echo "   - statusline/Config.toml"
echo ""
echo "💡 Commit these changes to git to save your Claude Code configuration"
