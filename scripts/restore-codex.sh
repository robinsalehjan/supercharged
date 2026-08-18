#!/bin/zsh

# ============================================================================
# Codex Restore Script
# ============================================================================
# Restores shared Codex configuration from the repository to ~/.codex.

set -e
set -o pipefail

source "$(dirname "$0")/utils.sh"

PROJECT_ROOT="$UTILS_PROJECT_ROOT"
CODEX_CONFIG_DIR="$PROJECT_ROOT/codex_config"
AGENT_CONFIG_DIR="$PROJECT_ROOT/agent_config"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"

FORCE_RESTORE=false
SKIP_BACKUP=false

show_help() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Restore Codex configuration from the repository"
    echo ""
    echo "Options:"
    echo "  --force      Force restore regardless of timestamps"
    echo "  --skip-backup  Internal: use an orchestrator-created restoration point"
    echo "  -h, --help   Show this help message"
}

get_file_mtime() {
    local file="$1"
    local mtime

    if mtime=$(stat -f %m "$file" 2>/dev/null); then
        echo "$mtime"
        return 0
    fi

    if mtime=$(stat -c %Y "$file" 2>/dev/null); then
        echo "$mtime"
        return 0
    fi

    echo "0"
    return 1
}

get_newest_mtime_in_dir() {
    local dir="$1"
    local newest=0
    local file mtime

    if [ ! -d "$dir" ]; then
        echo "0"
        return 0
    fi

    for file in "$dir"/**/*(.N); do
        mtime=$(get_file_mtime "$file")
        [ "$mtime" -gt "$newest" ] && newest="$mtime"
    done

    echo "$newest"
}

restore_config_file() {
    local src="$1"
    local dest="$2"
    local name="$3"

    if [ -f "$src" ]; then
        mkdir -p "$(dirname "$dest")"
        expand_portable_path < "$src" > "$dest.tmp"
        mv "$dest.tmp" "$dest"
        log_with_level "SUCCESS" "Restored $name"
    fi
}

restore_codex_agents() {
    local src="$AGENT_CONFIG_DIR/AGENTS.md"
    local dest="$CODEX_HOME/AGENTS.md"
    local rtk_ref="@$CODEX_HOME/RTK.md"

    if [ ! -f "$src" ]; then
        return 0
    fi

    mkdir -p "$(dirname "$dest")"
    expand_portable_path < "$src" > "$dest"

    if [ -f "$CODEX_CONFIG_DIR/RTK.md" ] && ! grep -Fx "$rtk_ref" "$dest" >/dev/null 2>&1; then
        {
            printf '\n'
            printf '%s\n' "$rtk_ref"
        } >> "$dest"
        log_with_level "INFO" "Added Codex RTK instruction include"
    fi

    log_with_level "SUCCESS" "Restored AGENTS.md"
}

restore_codex_skills() {
    local src_dir="$CODEX_CONFIG_DIR/skills"
    local dest_dir="$CODEX_HOME/skills"
    local skill name copied=0

    if [ ! -d "$src_dir" ]; then
        return 0
    fi

    mkdir -p "$dest_dir"
    for skill in "$src_dir"/*(N/); do
        name=$(basename "$skill")
        rm -rf "${dest_dir:?}/${name:?}"
        mkdir -p "$dest_dir/$name"
        cp -R "$skill/." "$dest_dir/$name/"
        copied=$((copied + 1))
    done

    if [ "$copied" -gt 0 ]; then
        log_with_level "SUCCESS" "Restored $copied Codex skill(s)"
    fi
}

restore_shared_agent_skills() {
    local src_dir="$AGENT_CONFIG_DIR/skills"
    local dest_dir="$CODEX_HOME/skills"
    local skill name copied=0

    if [ ! -d "$src_dir" ]; then
        return 0
    fi

    mkdir -p "$dest_dir"
    while IFS= read -r skill; do
        name=$(basename "$(dirname "$skill")")
        rm -rf "${dest_dir:?}/${name:?}"
        mkdir -p "$dest_dir/$name"
        cp "$skill" "$dest_dir/$name/SKILL.md"
        copied=$((copied + 1))
    done < <(find "$src_dir" -mindepth 2 -maxdepth 2 -type f -name 'SKILL.md' | sort)

    if [ "$copied" -gt 0 ]; then
        log_with_level "SUCCESS" "Restored $copied canonical shared skill(s) for Codex"
    fi
}

restore_codex_rules() {
    local src_dir="${1:-$CODEX_CONFIG_DIR/rules}"
    local dest_dir="${2:-$CODEX_HOME/rules}"
    local rule name copied=0

    if [ ! -d "$src_dir" ]; then
        return 0
    fi

    mkdir -p "$dest_dir"
    while IFS= read -r rule; do
        name=$(basename "$rule")
        cp "$rule" "$dest_dir/$name"
        copied=$((copied + 1))
    done < <(find "$src_dir" -maxdepth 1 -type f -name '*.rules' | sort)

    if [ "$copied" -gt 0 ]; then
        log_with_level "SUCCESS" "Restored $copied Codex rule file(s)"
    fi
}

restore_codex_hook_scripts() {
    local src_dir="${1:-$CODEX_CONFIG_DIR/hooks}"
    local dest_dir="${2:-$CODEX_HOME/hooks}"
    local hook name copied=0

    if [ ! -d "$src_dir" ]; then
        return 0
    fi

    mkdir -p "$dest_dir"
    while IFS= read -r hook; do
        name=$(basename "$hook")
        cp "$hook" "$dest_dir/$name"
        chmod +x "$dest_dir/$name"
        copied=$((copied + 1))
    done < <(find "$src_dir" -maxdepth 1 -type f | sort)

    if [ "$copied" -gt 0 ]; then
        log_with_level "SUCCESS" "Restored $copied Codex hook script(s)"
    fi
}

restore_codex_config() {
    local src="$CODEX_CONFIG_DIR/config.toml"
    local dest="$CODEX_HOME/config.toml"
    local local_top_level=""
    local local_tables=""

    if [ ! -f "$src" ]; then
        log_with_level "WARN" "codex_config/config.toml not found"
        return
    fi

    mkdir -p "$CODEX_HOME"

    if [ -f "$dest" ]; then
        local_top_level=$(extract_local_codex_top_level < "$dest")
        local_tables=$(extract_local_codex_tables < "$dest")
    fi

    {
        if [ -n "$local_top_level" ]; then
            printf '%s\n\n' "$local_top_level"
        fi

        expand_portable_path < "$src"
    } > "$dest.tmp"

    if [ -n "$local_tables" ]; then
        {
            printf '\n'
            printf '%s\n' "$local_tables"
        } >> "$dest.tmp"
        log_with_level "INFO" "Preserved local Codex runtime state"
    fi

    mv "$dest.tmp" "$dest"
    log_with_level "SUCCESS" "Restored config.toml"
}

restore_codex_profile() {
    local name="$1"

    restore_config_file \
        "$CODEX_CONFIG_DIR/${name}.config.toml" \
        "$CODEX_HOME/${name}.config.toml" \
        "${name}.config.toml"
}

is_repo_newer() {
    local repo_mtime=0
    local home_mtime=0
    local mtime

    if [ -f "$CODEX_CONFIG_DIR/config.toml" ]; then
        repo_mtime=$(get_file_mtime "$CODEX_CONFIG_DIR/config.toml")
    fi
    for profile in apple review; do
        if [ -f "$CODEX_CONFIG_DIR/${profile}.config.toml" ]; then
            mtime=$(get_file_mtime "$CODEX_CONFIG_DIR/${profile}.config.toml")
            [ "$mtime" -gt "$repo_mtime" ] && repo_mtime="$mtime"
        fi
    done
    if [ -f "$AGENT_CONFIG_DIR/AGENTS.md" ]; then
        mtime=$(get_file_mtime "$AGENT_CONFIG_DIR/AGENTS.md")
        [ "$mtime" -gt "$repo_mtime" ] && repo_mtime="$mtime"
    fi
    if [ -f "$CODEX_CONFIG_DIR/hooks.json" ]; then
        mtime=$(get_file_mtime "$CODEX_CONFIG_DIR/hooks.json")
        [ "$mtime" -gt "$repo_mtime" ] && repo_mtime="$mtime"
    fi
    if [ -f "$CODEX_CONFIG_DIR/RTK.md" ]; then
        mtime=$(get_file_mtime "$CODEX_CONFIG_DIR/RTK.md")
        [ "$mtime" -gt "$repo_mtime" ] && repo_mtime="$mtime"
    fi
    if [ -f "$CODEX_CONFIG_DIR/plugins.json" ]; then
        mtime=$(get_file_mtime "$CODEX_CONFIG_DIR/plugins.json")
        [ "$mtime" -gt "$repo_mtime" ] && repo_mtime="$mtime"
    fi
    if [ -f "$AGENT_CONFIG_DIR/installed_skills.json" ]; then
        mtime=$(get_file_mtime "$AGENT_CONFIG_DIR/installed_skills.json")
        [ "$mtime" -gt "$repo_mtime" ] && repo_mtime="$mtime"
    fi
    mtime=$(get_newest_mtime_in_dir "$CODEX_CONFIG_DIR/skills")
    [ "$mtime" -gt "$repo_mtime" ] && repo_mtime="$mtime"
    mtime=$(get_newest_mtime_in_dir "$CODEX_CONFIG_DIR/rules")
    [ "$mtime" -gt "$repo_mtime" ] && repo_mtime="$mtime"
    mtime=$(get_newest_mtime_in_dir "$CODEX_CONFIG_DIR/hooks")
    [ "$mtime" -gt "$repo_mtime" ] && repo_mtime="$mtime"
    mtime=$(get_newest_mtime_in_dir "$AGENT_CONFIG_DIR/skills")
    [ "$mtime" -gt "$repo_mtime" ] && repo_mtime="$mtime"

    if [ -f "$CODEX_HOME/config.toml" ]; then
        home_mtime=$(get_file_mtime "$CODEX_HOME/config.toml")
    fi
    for profile in apple review; do
        if [ -f "$CODEX_HOME/${profile}.config.toml" ]; then
            mtime=$(get_file_mtime "$CODEX_HOME/${profile}.config.toml")
            [ "$mtime" -gt "$home_mtime" ] && home_mtime="$mtime"
        fi
    done
    if [ -f "$CODEX_HOME/AGENTS.md" ]; then
        mtime=$(get_file_mtime "$CODEX_HOME/AGENTS.md")
        [ "$mtime" -gt "$home_mtime" ] && home_mtime="$mtime"
    fi
    if [ -f "$CODEX_HOME/hooks.json" ]; then
        mtime=$(get_file_mtime "$CODEX_HOME/hooks.json")
        [ "$mtime" -gt "$home_mtime" ] && home_mtime="$mtime"
    fi
    if [ -f "$CODEX_HOME/RTK.md" ]; then
        mtime=$(get_file_mtime "$CODEX_HOME/RTK.md")
        [ "$mtime" -gt "$home_mtime" ] && home_mtime="$mtime"
    fi
    mtime=$(get_newest_mtime_in_dir "$CODEX_HOME/skills")
    [ "$mtime" -gt "$home_mtime" ] && home_mtime="$mtime"
    mtime=$(get_newest_mtime_in_dir "$CODEX_HOME/rules")
    [ "$mtime" -gt "$home_mtime" ] && home_mtime="$mtime"
    mtime=$(get_newest_mtime_in_dir "$CODEX_HOME/hooks")
    [ "$mtime" -gt "$home_mtime" ] && home_mtime="$mtime"

    if [ "$home_mtime" -eq 0 ]; then
        return 0
    fi

    [ "$repo_mtime" -gt "$home_mtime" ]
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)
                FORCE_RESTORE=true
                shift
                ;;
            --skip-backup)
                SKIP_BACKUP=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_with_level "WARN" "Unknown option: $1"
                shift
                ;;
        esac
    done

    if [ ! -f "$CODEX_CONFIG_DIR/config.toml" ] && \
       [ ! -f "$AGENT_CONFIG_DIR/AGENTS.md" ] && \
       [ ! -f "$CODEX_CONFIG_DIR/hooks.json" ] && \
       [ ! -f "$CODEX_CONFIG_DIR/RTK.md" ] && \
       [ ! -f "$CODEX_CONFIG_DIR/plugins.json" ] && \
       [ ! -f "$CODEX_CONFIG_DIR/apple.config.toml" ] && \
       [ ! -f "$CODEX_CONFIG_DIR/review.config.toml" ] && \
       [ ! -f "$AGENT_CONFIG_DIR/installed_skills.json" ] && \
       [ ! -d "$CODEX_CONFIG_DIR/skills" ] && \
       [ ! -d "$CODEX_CONFIG_DIR/rules" ] && \
       [ ! -d "$CODEX_CONFIG_DIR/hooks" ]; then
        log_with_level "INFO" "No Codex configuration found in repository"
        exit 0
    fi

    if [ "$FORCE_RESTORE" = true ]; then
        log_with_level "INFO" "Force restoring Codex configuration..."
    elif is_repo_newer; then
        log_with_level "INFO" "Repository config is newer, restoring Codex configuration..."
    else
        log_with_level "INFO" "Local Codex config is up-to-date, skipping restore"
        exit 0
    fi

    if [ "$SKIP_BACKUP" != true ]; then
        create_restoration_point
    fi

    mkdir -p "$CODEX_HOME"

    restore_codex_config
    restore_codex_profile "apple"
    restore_codex_profile "review"
    restore_config_file \
        "$CODEX_CONFIG_DIR/hooks.json" \
        "$CODEX_HOME/hooks.json" \
        "hooks.json"
    restore_config_file \
        "$CODEX_CONFIG_DIR/RTK.md" \
        "$CODEX_HOME/RTK.md" \
        "RTK.md"
    restore_codex_agents
    restore_codex_skills
    restore_shared_agent_skills
    restore_codex_rules
    restore_codex_hook_scripts

    if [ -f "$AGENT_CONFIG_DIR/installed_skills.json" ]; then
        log_with_level "INFO" "Installing shared agent skills..."
        if "$PROJECT_ROOT/scripts/install-skills.sh"; then
            log_with_level "SUCCESS" "Shared agent skills installed"
        else
            log_with_level "WARN" "Skill installation failed — run 'npm run install:skills' manually"
        fi
    fi

    log_with_level "INFO" "Installing managed Codex plugins..."
    if "$PROJECT_ROOT/scripts/install-codex-plugins.sh"; then
        log_with_level "SUCCESS" "Managed Codex plugins installed"
    else
        log_with_level "WARN" "Codex plugin installation failed — run 'npm run install:codex-plugins' manually"
    fi

    log_with_level "SUCCESS" "Codex configuration restored!"
    echo ""
    echo "📥 Restored files to ~/.codex:"
    echo "   - config.toml"
    echo "   - apple.config.toml (use: codex -p apple)"
    echo "   - review.config.toml (use: codex -p review)"
    echo "   - hooks.json"
    echo "   - RTK.md"
    echo "   - AGENTS.md"
    echo "   - skills/plannotator-*"
    echo "   - shared git skills from agent_config/installed_skills.json"
    echo "   - canonical shared skills from agent_config/skills"
    echo "   - rules/*.rules"
    echo "   - hooks/*"
    echo "   - managed plugins from codex_config/plugins.json"
    echo ""
    echo "💡 Axiom hooks require one-time trust review on the first Codex run"
    echo "💡 Restart Codex for changes to take effect"
}

if [[ -n "${ZSH_EVAL_CONTEXT:-}" ]]; then
    if [[ "${ZSH_EVAL_CONTEXT}" != *file* ]]; then
        main "$@"
    fi
else
    if [[ "${BASH_SOURCE[0]:-$0}" == "${0}" ]]; then
        main "$@"
    fi
fi
