#!/bin/zsh

# ============================================================================
# Claude Code Restore Script
# ============================================================================
# This script restores Claude Code configuration files from the repository's
# claude_config directory to ~/.claude
#
# Usage:
#   ./restore-claude.sh          # Restore if repo config is newer
#   ./restore-claude.sh --force  # Force restore regardless of timestamps

set -e
set -o pipefail

source "$(dirname "$0")/utils.sh"

# Get the directory where this script is located
PROJECT_ROOT="$UTILS_PROJECT_ROOT"
CLAUDE_CONFIG_DIR="$PROJECT_ROOT/claude_config"
AGENT_CONFIG_DIR="$PROJECT_ROOT/agent_config"
CLAUDE_HOME="$HOME/.claude"

# List of marketplaces to preserve locally (not overwritten during restore)
# These are work-related and should remain untouched
PRESERVE_MARKETPLACES=("vend-plugins")

# List of env vars to inject from ~/.secrets back into settings.json
# Must mirror SANITIZE_ENV_VARS in backup-claude.sh (what's stripped at backup, re-injected at restore)
INJECT_SETTINGS_ENV_VARS=("GITHUB_PERSONAL_ACCESS_TOKEN")

FORCE_RESTORE=false
SECRETS_LOADED=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_RESTORE=true
            shift
            ;;
        *)
            log_with_level "WARN" "Unknown option: $1"
            shift
            ;;
    esac
done

# Check if repository config exists
if [ ! -d "$CLAUDE_CONFIG_DIR" ]; then
    log_with_level "INFO" "No Claude configuration found in repository at $CLAUDE_CONFIG_DIR"
    exit 0
fi

# Check if any config files exist in repo
if [ ! -f "$CLAUDE_CONFIG_DIR/settings.json" ] && \
   [ ! -f "$CLAUDE_CONFIG_DIR/installed_plugins.json" ] && \
   [ ! -f "$CLAUDE_CONFIG_DIR/known_marketplaces.json" ] && \
   [ ! -f "$CLAUDE_CONFIG_DIR/keybindings.json" ] && \
   [ ! -f "$CLAUDE_CONFIG_DIR/CLAUDE.md" ] && \
   [ ! -f "$AGENT_CONFIG_DIR/AGENTS.md" ]; then
    log_with_level "INFO" "No Claude configuration files found in repository"
    exit 0
fi

# Cross-platform stat wrapper for modification time
# Returns mtime in seconds since epoch
get_file_mtime() {
    local file="$1"
    local mtime

    # Try macOS/BSD stat first
    if mtime=$(stat -f %m "$file" 2>/dev/null); then
        echo "$mtime"
        return 0
    fi

    # Fall back to GNU/Linux stat
    if mtime=$(stat -c %Y "$file" 2>/dev/null); then
        echo "$mtime"
        return 0
    fi

    # If both fail, return 0
    echo "0"
    return 1
}

# Function to get the newest modification time from a directory's JSON files
get_newest_mtime() {
    local dir="$1"
    local newest=0
    local mtime

    # Note: `local mtime` MUST be declared outside the loop. In zsh, redeclaring
    # `local` on an already-set variable inside a loop prints `var=value` to
    # stdout, corrupting the captured output of this function.
    for file in "$dir"/*.json; do
        if [ -f "$file" ]; then
            mtime=$(get_file_mtime "$file")
            if [ "$mtime" -gt "$newest" ]; then
                newest=$mtime
            fi
        fi
    done

    echo "$newest"
}

# Function to check if repo config is newer than home config
is_repo_newer() {
    local repo_mtime
    repo_mtime=$(get_newest_mtime "$CLAUDE_CONFIG_DIR")

    # If Claude home doesn't exist, repo is considered newer
    if [ ! -d "$CLAUDE_HOME" ]; then
        return 0
    fi

    local home_mtime=0
    local mtime

    # Check settings.json
    if [ -f "$CLAUDE_HOME/settings.json" ]; then
        mtime=$(get_file_mtime "$CLAUDE_HOME/settings.json")
        if [ "$mtime" -gt "$home_mtime" ]; then
            home_mtime=$mtime
        fi
    fi

    # Check plugin files
    if [ -f "$CLAUDE_HOME/plugins/installed_plugins.json" ]; then
        mtime=$(get_file_mtime "$CLAUDE_HOME/plugins/installed_plugins.json")
        if [ "$mtime" -gt "$home_mtime" ]; then
            home_mtime=$mtime
        fi
    fi

    if [ -f "$CLAUDE_HOME/plugins/known_marketplaces.json" ]; then
        mtime=$(get_file_mtime "$CLAUDE_HOME/plugins/known_marketplaces.json")
        if [ "$mtime" -gt "$home_mtime" ]; then
            home_mtime=$mtime
        fi
    fi

    # Check keybindings.json
    if [ -f "$CLAUDE_HOME/keybindings.json" ]; then
        mtime=$(get_file_mtime "$CLAUDE_HOME/keybindings.json")
        if [ "$mtime" -gt "$home_mtime" ]; then
            home_mtime=$mtime
        fi
    fi

    # Check CLAUDE.md
    if [ -f "$CLAUDE_HOME/CLAUDE.md" ]; then
        mtime=$(get_file_mtime "$CLAUDE_HOME/CLAUDE.md")
        if [ "$mtime" -gt "$home_mtime" ]; then
            home_mtime=$mtime
        fi
    fi

    # If home has no config files, repo is newer
    if [ "$home_mtime" -eq 0 ]; then
        return 0
    fi

    # Compare timestamps
    if [ "$repo_mtime" -gt "$home_mtime" ]; then
        return 0
    else
        return 1
    fi
}

# Function to restore a single config file
restore_config_file() {
    local src="$1"
    local dest="$2"
    local name="$3"

    if [ -f "$src" ]; then
        # Create destination directory if needed
        mkdir -p "$(dirname "$dest")"

        # Replace $HOME placeholder with actual home directory
        expand_portable_path < "$src" > "$dest"
        log_with_level "SUCCESS" "Restored $name"
    fi
}

# Function to merge plugin configs, preserving local plugins from protected marketplaces
# The file structure is: {"version": N, "plugins": {...}}
merge_plugin_config() {
    local src="$1"
    local dest="$2"
    local name="$3"

    if [ ! -f "$src" ]; then
        return
    fi

    # Create destination directory if needed
    mkdir -p "$(dirname "$dest")"

    # Expand $HOME placeholder in source
    local repo_content
    repo_content=$(expand_portable_path < "$src")

    # If destination doesn't exist, just copy
    if [ ! -f "$dest" ]; then
        printf '%s\n' "$repo_content" > "$dest"
        log_with_level "SUCCESS" "Restored $name"
        return
    fi

    # Check if jq is available for merging
    if ! command -v jq &> /dev/null; then
        log_with_level "ERROR" "jq is required for restore operations"
        return 1
    fi

    # Extract local plugins from preserved marketplaces (from .plugins object)
    local local_content
    local_content=$(cat "$dest")
    local preserved_plugins="{}"
    local marketplace_plugins

    # `local marketplace_plugins` is declared outside the loop — see note in
    # get_newest_mtime() about zsh re-declaration printing `var=value`.
    for marketplace in "${PRESERVE_MARKETPLACES[@]}"; do
        # Extract plugins ending with @marketplace from the .plugins object
        # Uses --arg to avoid jq filter injection from marketplace names
        marketplace_plugins=$(echo "$local_content" | jq --arg mp "@$marketplace" '.plugins // {} | to_entries | map(select(.key | endswith($mp))) | from_entries') || {
            log_with_level "WARN" "Failed to extract plugins for marketplace $marketplace"
            continue
        }
        if [ -n "$marketplace_plugins" ] && [ "$marketplace_plugins" != "{}" ]; then
            preserved_plugins=$(echo "$preserved_plugins" | jq --argjson mp "$marketplace_plugins" '. + $mp') || {
                log_with_level "WARN" "Failed to merge preserved plugins for $marketplace"
                continue
            }
            log_with_level "INFO" "Found plugins from $marketplace to preserve"
        fi
    done

    # Get repo plugins and merge with preserved local plugins
    local repo_plugins
    if ! repo_plugins=$(echo "$repo_content" | jq '.plugins // {}' 2>/dev/null); then
        log_with_level "ERROR" "Failed to extract plugins from repository configuration"
        return 1
    fi
    local merged_plugins
    if ! merged_plugins=$(echo "$repo_plugins" | jq --argjson preserved "$preserved_plugins" '. + $preserved' 2>/dev/null); then
        log_with_level "ERROR" "Failed to merge plugins: preserved_plugins=$preserved_plugins"
        return 1
    fi

    # Validate merge succeeded and produced valid JSON
    if [ -z "$merged_plugins" ] || ! echo "$merged_plugins" | jq empty 2>/dev/null; then
        log_with_level "ERROR" "Failed to merge plugins configuration"
        return 1
    fi

    # Get version from repo (or local if repo doesn't have it)
    local version
    if ! version=$(echo "$repo_content" | jq '.version // 2' 2>/dev/null); then
        log_with_level "ERROR" "Failed to read version from repository configuration"
        return 1
    fi

    # Build final merged object
    local merged
    merged=$(jq -n --argjson version "$version" --argjson plugins "$merged_plugins" '{version: $version, plugins: $plugins}')
    printf '%s\n' "$merged" > "$dest"

    local preserved_count
    preserved_count=$(echo "$preserved_plugins" | jq 'keys | length' 2>/dev/null || echo "0")
    if [ "$preserved_count" -gt 0 ]; then
        log_with_level "SUCCESS" "Restored $name (preserved $preserved_count local plugin(s))"
    else
        log_with_level "SUCCESS" "Restored $name"
    fi
}

# Function to merge marketplace configs, preserving local marketplaces
merge_marketplace_config() {
    local src="$1"
    local dest="$2"
    local name="$3"

    if [ ! -f "$src" ]; then
        return
    fi

    # Create destination directory if needed
    mkdir -p "$(dirname "$dest")"

    # Expand $HOME placeholder in source
    local repo_content
    repo_content=$(expand_portable_path < "$src")

    # If destination doesn't exist, just copy
    if [ ! -f "$dest" ]; then
        printf '%s\n' "$repo_content" > "$dest"
        log_with_level "SUCCESS" "Restored $name"
        return
    fi

    # Check if jq is available for merging
    if ! command -v jq &> /dev/null; then
        log_with_level "ERROR" "jq is required for restore operations"
        return 1
    fi

    # Extract preserved marketplaces from local config
    local local_content
    local_content=$(cat "$dest")
    local preserved_marketplaces="{}"
    local marketplace_entry

    # `local marketplace_entry` is declared outside the loop — see note in
    # get_newest_mtime() about zsh re-declaration printing `var=value`.
    for marketplace in "${PRESERVE_MARKETPLACES[@]}"; do
        # Uses --arg to avoid jq filter injection from marketplace names
        marketplace_entry=$(echo "$local_content" | jq --arg mp "$marketplace" 'if has($mp) then {($mp): .[$mp]} else {} end') || {
            log_with_level "WARN" "Failed to extract marketplace $marketplace"
            continue
        }
        if [ -n "$marketplace_entry" ] && [ "$marketplace_entry" != "{}" ]; then
            preserved_marketplaces=$(echo "$preserved_marketplaces" | jq --argjson entry "$marketplace_entry" '. + $entry') || {
                log_with_level "WARN" "Failed to merge marketplace $marketplace"
                continue
            }
            log_with_level "INFO" "Found marketplace $marketplace to preserve"
        fi
    done

    # Merge: repo content + preserved local marketplaces (local takes precedence)
    local merged
    if ! merged=$(echo "$repo_content" | jq --argjson preserved "$preserved_marketplaces" '. + $preserved' 2>/dev/null); then
        log_with_level "ERROR" "Failed to merge marketplaces: preserved_marketplaces=$preserved_marketplaces"
        return 1
    fi

    # Validate merge succeeded and produced valid JSON
    if [ -z "$merged" ] || ! echo "$merged" | jq empty 2>/dev/null; then
        log_with_level "ERROR" "Failed to merge marketplaces configuration"
        return 1
    fi

    printf '%s\n' "$merged" > "$dest"

    local preserved_count
    preserved_count=$(echo "$preserved_marketplaces" | jq 'keys | length' 2>/dev/null || echo "0")
    if [ "$preserved_count" -gt 0 ]; then
        log_with_level "SUCCESS" "Restored $name (preserved $preserved_count local marketplace(s))"
    else
        log_with_level "SUCCESS" "Restored $name"
    fi
}

# Function to remove plugin caches and marketplaces that are no longer tracked
# in the restored registry. Anything on disk under ~/.claude/plugins/cache or
# ~/.claude/plugins/marketplaces that isn't listed in installed_plugins.json /
# known_marketplaces.json (or whitelisted via PRESERVE_MARKETPLACES) gets
# nuked. Safe to run repeatedly — no-op when there's nothing orphaned.
uninstall_orphan_plugins() {
    local plugins_file="$CLAUDE_HOME/plugins/installed_plugins.json"
    local marketplaces_file="$CLAUDE_HOME/plugins/known_marketplaces.json"
    local cache_dir="$CLAUDE_HOME/plugins/cache"
    local marketplaces_dir="$CLAUDE_HOME/plugins/marketplaces"

    if [ ! -f "$plugins_file" ] || [ ! -f "$marketplaces_file" ]; then
        return 0
    fi

    if ! command -v jq &> /dev/null; then
        log_with_level "WARN" "jq not available — skipping orphan plugin cleanup"
        return 0
    fi

    # Desired set: marketplace names + plugin-keys ("plugin@marketplace") from
    # the restored registry, augmented by any marketplaces we always preserve.
    # Bail on jq parse errors — falling back to an empty set would mark every
    # cached plugin as orphaned and rm -rf the whole cache.
    local desired_marketplaces desired_plugin_keys jq_err
    if ! desired_marketplaces=$(jq -r 'keys[]' "$marketplaces_file" 2>&1); then
        jq_err="$desired_marketplaces"
        log_with_level "ERROR" "Failed to parse $marketplaces_file — skipping orphan plugin cleanup ($jq_err)"
        return 1
    fi
    if ! desired_plugin_keys=$(jq -r '.plugins // {} | keys[]' "$plugins_file" 2>&1); then
        jq_err="$desired_plugin_keys"
        log_with_level "ERROR" "Failed to parse $plugins_file — skipping orphan plugin cleanup ($jq_err)"
        return 1
    fi

    local keep_marketplaces="$desired_marketplaces"
    local mp
    for mp in "${PRESERVE_MARKETPLACES[@]}"; do
        keep_marketplaces+=$'\n'"$mp"
    done

    local removed_count=0
    local mp_path mp_name plugin_path plugin_name is_preserved

    # Walk cache: ~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/
    if [ -d "$cache_dir" ]; then
        for mp_path in "$cache_dir"/*/; do
            [ -d "$mp_path" ] || continue
            mp_name="${mp_path%/}"
            mp_name="${mp_name##*/}"

            # Marketplace fully gone — nuke its entire cache subtree.
            if ! grep -Fxq -- "$mp_name" <<<"$keep_marketplaces"; then
                rm -rf -- "$mp_path"
                log_with_level "INFO" "Removed orphan plugin cache: $mp_name"
                removed_count=$((removed_count + 1))
                continue
            fi

            # Preserved marketplaces keep every plugin under them, untouched.
            is_preserved=false
            for mp in "${PRESERVE_MARKETPLACES[@]}"; do
                [ "$mp_name" = "$mp" ] && is_preserved=true && break
            done
            if [ "$is_preserved" = true ]; then
                continue
            fi

            # Otherwise drop any plugin-dir not in the desired set.
            for plugin_path in "$mp_path"*/; do
                [ -d "$plugin_path" ] || continue
                plugin_name="${plugin_path%/}"
                plugin_name="${plugin_name##*/}"
                if ! grep -Fxq -- "${plugin_name}@${mp_name}" <<<"$desired_plugin_keys"; then
                    rm -rf -- "$plugin_path"
                    log_with_level "INFO" "Removed orphan plugin cache: ${plugin_name}@${mp_name}"
                    removed_count=$((removed_count + 1))
                fi
            done

            # Tidy up an empty marketplace cache dir.
            if [ -z "$(ls -A -- "$mp_path" 2>/dev/null)" ]; then
                rmdir -- "$mp_path" 2>/dev/null || true
            fi
        done
    fi

    # Walk marketplace registry dirs.
    if [ -d "$marketplaces_dir" ]; then
        for mp_path in "$marketplaces_dir"/*/; do
            [ -d "$mp_path" ] || continue
            mp_name="${mp_path%/}"
            mp_name="${mp_name##*/}"
            if ! grep -Fxq -- "$mp_name" <<<"$keep_marketplaces"; then
                rm -rf -- "$mp_path"
                log_with_level "INFO" "Removed orphan marketplace: $mp_name"
                removed_count=$((removed_count + 1))
            fi
        done
    fi

    if [ "$removed_count" -gt 0 ]; then
        log_with_level "SUCCESS" "Cleaned up $removed_count orphan plugin/marketplace entry(ies)"
    fi
}

# Load ~/.secrets once; sets SECRETS_LOADED=true on success.
# Accepts either a single file at ~/.secrets or a directory of *.sh files
# under ~/.secrets/ (non-shell files like GCP JSON are ignored by the loader
# and remain available on disk to be referenced by path).
load_secrets() {
    local secrets_path="$HOME/.secrets"

    if [ -f "$secrets_path" ]; then
        # shellcheck source=/dev/null
        source "$secrets_path" 2>/dev/null || {
            log_with_level "WARN" "Failed to source $secrets_path"
            return 1
        }
        SECRETS_LOADED=true
        return 0
    fi

    if [ -d "$secrets_path" ]; then
        local _f sourced=0
        # Iterate top-level *.sh files in lexical order. find + NUL-delimited
        # read works under both zsh (script shebang) and bash (shellcheck mode).
        while IFS= read -r -d '' _f; do
            # shellcheck source=/dev/null
            if source "$_f" 2>/dev/null; then
                sourced=$((sourced + 1))
            else
                log_with_level "WARN" "Failed to source $_f"
            fi
        done < <(find "$secrets_path" -maxdepth 1 -type f -name '*.sh' -print0 | sort -z)
        if [ "$sourced" -eq 0 ]; then
            log_with_level "WARN" "No *.sh files found in $secrets_path - credentials will not be injected"
            return 1
        fi
        SECRETS_LOADED=true
        return 0
    fi

    log_with_level "WARN" "No secrets found at $secrets_path - credentials will not be injected"
    log_with_level "WARN" "Copy dot_files/.secrets/ to ~/.secrets/ (or create ~/.secrets/*.sh) and fill in your values"
    return 1
}

# Function to inject global env vars from ~/.secrets back into settings.json
restore_settings_env() {
    local settings_json="$CLAUDE_HOME/settings.json"

    if [ ! -f "$settings_json" ]; then
        log_with_level "WARN" "settings.json not found, skipping env var injection"
        return
    fi

    # Count vars that are actually set
    local injected_count=0
    for var in "${INJECT_SETTINGS_ENV_VARS[@]}"; do
        if printenv "$var" > /dev/null 2>&1; then
            injected_count=$((injected_count + 1))
        fi
    done

    if [ "$injected_count" -eq 0 ]; then
        log_with_level "INFO" "No env vars to inject (not found in ~/.secrets)"
        return
    fi

    # Build JSON array of var names, then use jq env[] to read their values
    local vars_json
    vars_json=$(printf '%s\n' "${INJECT_SETTINGS_ENV_VARS[@]}" | jq -R . | jq -s .)

    local updated
    if ! updated=$(jq -a --argjson vars "$vars_json" '
        .env = (.env // {}) + (
            $vars |
            map(select(env[.] != null)) |
            map({(.): env[.]}) |
            add // {}
        )
    ' "$settings_json" 2>/dev/null); then
        log_with_level "ERROR" "Failed to inject env vars into settings.json"
        return 1
    fi

    local tmp="${settings_json}.tmp.$$"
    if printf '%s\n' "$updated" > "$tmp" && mv "$tmp" "$settings_json"; then
        log_with_level "SUCCESS" "Injected $injected_count env var(s) into settings.json from ~/.secrets"
    else
        rm -f "$tmp"
        log_with_level "ERROR" "Failed to write settings.json"
        return 1
    fi
}

# Function to restore global MCP server configs into ~/.claude/settings.json
# Sources ~/.secrets to substitute $VAR_NAME placeholders with actual env values
# MCPs are injected globally so they work across all projects
restore_mcp_servers() {
    local src="$CLAUDE_CONFIG_DIR/mcp_servers.json"
    local settings_json="$CLAUDE_HOME/settings.json"

    if [ ! -f "$src" ]; then
        log_with_level "INFO" "No MCP server configuration found in repository"
        return
    fi

    if [ ! -f "$settings_json" ]; then
        log_with_level "WARN" "settings.json not found, skipping MCP server restore"
        return
    fi

    if [ "$SECRETS_LOADED" = false ]; then
        log_with_level "WARN" "Skipping MCP server restore - API key placeholders would remain unsubstituted"
        return 1
    fi

    # Expand $HOME placeholders and substitute $VAR_NAME env placeholders via jq env object
    local mcp_with_secrets
    if ! mcp_with_secrets=$(expand_portable_path < "$src" | jq -a 'to_entries | map(
        .value.env = (.value.env // {} | to_entries | map(
            if (.value | type == "string") and (.value | startswith("$")) then
                .value = (env[.value[1:]] // .value)
            else . end
        ) | from_entries)
    ) | from_entries' 2>/dev/null); then
        log_with_level "ERROR" "Failed to process MCP server configuration"
        return 1
    fi

    # Merge MCP servers into settings.json (repo servers take precedence, local extras preserved)
    local updated
    if ! updated=$(jq -a --argjson mcp "$mcp_with_secrets" '
        .mcpServers = ((.mcpServers // {}) + $mcp)
    ' "$settings_json" 2>/dev/null); then
        log_with_level "ERROR" "Failed to merge MCP servers into settings.json"
        return 1
    fi

    local tmp="${settings_json}.tmp.$$"
    if printf '%s\n' "$updated" > "$tmp" && mv "$tmp" "$settings_json"; then
        local server_count
        server_count=$(echo "$mcp_with_secrets" | jq 'keys | length' 2>/dev/null || echo "?")
        log_with_level "SUCCESS" "Restored $server_count global MCP server(s) to settings.json"
    else
        rm -f "$tmp"
        log_with_level "ERROR" "Failed to write settings.json"
        return 1
    fi
}

# Main restore logic
if [ "$FORCE_RESTORE" = true ]; then
    log_with_level "INFO" "Force restoring Claude Code configuration..."
elif is_repo_newer; then
    log_with_level "INFO" "Repository config is newer, restoring Claude Code configuration..."
else
    log_with_level "INFO" "Local Claude config is up-to-date, skipping restore"
    exit 0
fi

# Create Claude directories if needed
mkdir -p "$CLAUDE_HOME"
mkdir -p "$CLAUDE_HOME/plugins"

# Restore settings.json (simple overwrite, no sensitive data)
restore_config_file \
    "$CLAUDE_CONFIG_DIR/settings.json" \
    "$CLAUDE_HOME/settings.json" \
    "settings.json"

# Load ~/.secrets once — used by both restore_settings_env and restore_mcp_servers
load_secrets || true

# Re-inject sensitive env vars stripped at backup time (sourced from ~/.secrets)
restore_settings_env

# Restore installed_plugins.json (merge to preserve local work plugins)
merge_plugin_config \
    "$CLAUDE_CONFIG_DIR/installed_plugins.json" \
    "$CLAUDE_HOME/plugins/installed_plugins.json" \
    "installed_plugins.json"

# Restore known_marketplaces.json (merge to preserve local work marketplaces)
merge_marketplace_config \
    "$CLAUDE_CONFIG_DIR/known_marketplaces.json" \
    "$CLAUDE_HOME/plugins/known_marketplaces.json" \
    "known_marketplaces.json"

# Restore keybindings.json (custom keyboard shortcuts)
restore_config_file \
    "$CLAUDE_CONFIG_DIR/keybindings.json" \
    "$CLAUDE_HOME/keybindings.json" \
    "keybindings.json"

# Restore CLAUDE.md (global personal instructions)
restore_config_file \
    "$CLAUDE_CONFIG_DIR/CLAUDE.md" \
    "$CLAUDE_HOME/CLAUDE.md" \
    "CLAUDE.md"

# Restore CLAUDE.md @-referenced files (RTK.md, claude-token-efficient.md, etc.)
claude_md_refs_restored=()
if [ -f "$CLAUDE_CONFIG_DIR/CLAUDE.md" ]; then
    while IFS= read -r ref_file; do
        ref_src="$CLAUDE_CONFIG_DIR/$ref_file"
        if [ "$ref_file" = "AGENTS.md" ]; then
            ref_src="$AGENT_CONFIG_DIR/AGENTS.md"
        fi

        if [ -f "$ref_src" ]; then
            restore_config_file \
                "$ref_src" \
                "$CLAUDE_HOME/$ref_file" \
                "$ref_file"
            claude_md_refs_restored+=("$ref_file")
        fi
    done < <(sed -n 's/^@\(.*\.md\)$/\1/p' "$CLAUDE_CONFIG_DIR/CLAUDE.md")
fi

# Restore statusline Config.toml (theme and display configuration)
if [ -f "$CLAUDE_CONFIG_DIR/statusline/Config.toml" ]; then
    mkdir -p "$CLAUDE_HOME/statusline"
    cp "$CLAUDE_CONFIG_DIR/statusline/Config.toml" "$CLAUDE_HOME/statusline/Config.toml"
    log_with_level "SUCCESS" "Restored statusline/Config.toml"
fi

# Restore MCP server configurations into ~/.claude.json (env vars sourced from ~/.secrets)
restore_mcp_servers

log_with_level "SUCCESS" "Claude Code configuration restored!"

# Install plugins from the restored configuration
log_with_level "INFO" "Installing plugins..."
if "$PROJECT_ROOT/scripts/install-plugins.sh"; then
    log_with_level "SUCCESS" "Plugins installed"
else
    log_with_level "WARN" "Plugin installation failed — run 'npm run install:plugins' manually"
fi

# Prune caches/marketplaces no longer in the newly-restored registry — must
# run after install-plugins.sh so freshly-installed entries aren't pruned.
uninstall_orphan_plugins

# Install git-cloned skills from the restored configuration
if [ -f "$CLAUDE_CONFIG_DIR/installed_skills.json" ]; then
    log_with_level "INFO" "Installing skills..."
    if "$PROJECT_ROOT/scripts/install-skills.sh"; then
        log_with_level "SUCCESS" "Skills installed"
    else
        log_with_level "WARN" "Skill installation failed — run 'npm run install:skills' manually"
    fi
fi

echo ""
echo "📥 Restored files to ~/.claude:"
echo "   - settings.json"
echo "   - plugins/installed_plugins.json"
echo "   - plugins/known_marketplaces.json"
echo "   - keybindings.json"
echo "   - CLAUDE.md"
for ref_file in "${claude_md_refs_restored[@]}"; do
    echo "   - $ref_file"
done
echo "   - statusline/Config.toml"
echo "   - settings.json MCP servers (global, env vars from ~/.secrets)"
echo ""
echo "💡 Restart Claude Code for changes to take effect"
