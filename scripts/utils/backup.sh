#!/bin/zsh

_configuration_restore_paths() {
    local file name

    printf '%s\n' "${MANAGED_DOTFILES[@]}"
    printf '%s\n' \
        ".gitconfig.local" \
        ".claude/settings.json" \
        ".claude/plugins/installed_plugins.json" \
        ".claude/plugins/known_marketplaces.json" \
        ".claude/keybindings.json" \
        ".claude/CLAUDE.md" \
        ".claude/statusline/Config.toml" \
        ".claude/skills" \
        ".claude.json" \
        ".codex/config.toml" \
        ".codex/hooks.json" \
        ".codex/RTK.md" \
        ".codex/AGENTS.md" \
        ".codex/hooks" \
        ".codex/rules" \
        ".codex/skills"

    # Include every direct Claude instruction file that exists locally or can
    # be created by the tracked CLAUDE.md references.
    if [ -d "$HOME/.claude" ]; then
        while IFS= read -r file; do
            name=$(basename "$file")
            printf '.claude/%s\n' "$name"
        done < <(find "$HOME/.claude" -maxdepth 1 -type f -name '*.md' | sort)
    fi
    if [ -d "$UTILS_PROJECT_ROOT/claude_config" ]; then
        while IFS= read -r file; do
            name=$(basename "$file")
            printf '.claude/%s\n' "$name"
        done < <(find "$UTILS_PROJECT_ROOT/claude_config" -maxdepth 1 -type f -name '*.md' | sort)
    fi
    if [ -f "$UTILS_PROJECT_ROOT/agent_config/AGENTS.md" ]; then
        printf '%s\n' ".claude/AGENTS.md"
    fi
}

_get_path_mode() {
    local path="$1"
    stat -f %Lp "$path" 2>/dev/null || stat -c %a "$path" 2>/dev/null || printf '600\n'
}

_record_saved_modes() {
    local source="$1"
    local modes_file="$2"
    local item relative mode

    if [ -d "$source" ]; then
        while IFS= read -r item; do
            relative="${item#"$HOME"/}"
            mode=$(_get_path_mode "$item")
            printf '%s\t%s\n' "$mode" "$relative" >> "$modes_file"
        done < <(find "$source" -print | sort)
    else
        relative="${source#"$HOME"/}"
        mode=$(_get_path_mode "$source")
        printf '%s\t%s\n' "$mode" "$relative" >> "$modes_file"
    fi
}

_is_safe_restore_relative_path() {
    local relative="$1"

    case "$relative" in
        ""|/*|..|../*|*/../*|*/..)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

# Create a configuration-only restoration point. Runtime state, credentials,
# sessions, histories, databases, logs, secrets, auth, and plugin caches are
# deliberately outside this snapshot.
create_restoration_point() {
    local timestamp backup_base backup_dir manifest modes_file
    local relative source target type mode suffix=0

    timestamp=$(date +%Y%m%d_%H%M%S)
    backup_base="$HOME/.supercharged_backups"
    backup_dir="$backup_base/$timestamp"
    while [ -e "$backup_dir" ]; do
        suffix=$((suffix + 1))
        backup_dir="$backup_base/${timestamp}_$suffix"
    done

    log_with_level "INFO" "Creating restoration point at $backup_dir"
    if ! mkdir -p "$backup_dir/files"; then
        log_with_level "ERROR" "Failed to create backup directory: $backup_dir"
        return 1
    fi
    chmod 700 "$backup_base" "$backup_dir" "$backup_dir/files"

    manifest="$backup_dir/presence.tsv"
    modes_file="$backup_dir/modes.tsv"
    : > "$manifest"
    : > "$modes_file"

    while IFS= read -r relative; do
        [ -n "$relative" ] || continue
        _is_safe_restore_relative_path "$relative" || {
            log_with_level "ERROR" "Unsafe restoration path: $relative"
            return 1
        }

        source="$HOME/$relative"
        target="$backup_dir/files/$relative"
        if [ -L "$source" ]; then
            type="link"
        elif [ -d "$source" ]; then
            type="dir"
        elif [ -f "$source" ]; then
            type="file"
        else
            type="missing"
        fi
        printf '%s\t%s\n' "$type" "$relative" >> "$manifest"

        if [ "$type" != "missing" ]; then
            mkdir -p "$(dirname "$target")"
            cp -R "$source" "$target"
            _record_saved_modes "$source" "$modes_file"
            log_with_level "INFO" "Backed up $relative"
        fi
    done < <(_configuration_restore_paths | awk '!seen[$0]++')

    # Backups contain configuration and registries, so make the stored copy
    # private even when the live file had broader permissions. Original modes
    # are kept separately and reapplied during rollback.
    find "$backup_dir" -type d -exec chmod 700 {} +
    find "$backup_dir" -type f -exec chmod 600 {} +

    printf '%s\n' "$backup_dir" > "$HOME/.supercharged_last_backup"
    chmod 600 "$HOME/.supercharged_last_backup"

    if [[ "$backup_base" == "$HOME/.supercharged_backups" ]]; then
        local backup_count
        backup_count=$(find "$backup_base" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
        if [ "$backup_count" -gt "$BACKUP_RETENTION_COUNT" ]; then
            log_with_level "INFO" "Cleaning up old backups (keeping last $BACKUP_RETENTION_COUNT)..."
            find "$backup_base" -mindepth 1 -maxdepth 1 -type d -print0 | \
                xargs -0 ls -1dt | tail -n +$((BACKUP_RETENTION_COUNT + 1)) | while IFS= read -r dir; do
                    rm -rf "$dir"
                done
        fi
    fi

    log_with_level "SUCCESS" "Restoration point created successfully"
    return 0
}

_restore_manifest_backup() {
    local backup_dir="$1"
    local manifest="$backup_dir/presence.tsv"
    local modes_file="$backup_dir/modes.tsv"
    local type relative source destination mode

    while IFS=$'\t' read -r type relative || [ -n "$relative" ]; do
        [ -n "$relative" ] || continue
        if ! _is_safe_restore_relative_path "$relative"; then
            log_with_level "ERROR" "Unsafe path in restoration manifest: $relative"
            return 1
        fi

        source="$backup_dir/files/$relative"
        destination="$HOME/$relative"
        case "$type" in
            missing)
                rm -rf "$destination"
                log_with_level "INFO" "Removed restore-created $relative"
                ;;
            file|link)
                mkdir -p "$(dirname "$destination")"
                rm -rf "$destination"
                cp -R "$source" "$destination"
                log_with_level "INFO" "Restored $relative"
                ;;
            dir)
                mkdir -p "$(dirname "$destination")"
                rm -rf "$destination"
                cp -R "$source" "$destination"
                log_with_level "INFO" "Restored $relative"
                ;;
            *)
                log_with_level "ERROR" "Unknown manifest entry type '$type' for $relative"
                return 1
                ;;
        esac
    done < "$manifest"

    if [ -f "$modes_file" ]; then
        while IFS=$'\t' read -r mode relative || [ -n "$relative" ]; do
            [ -n "$relative" ] || continue
            _is_safe_restore_relative_path "$relative" || continue
            [ -e "$HOME/$relative" ] || [ -L "$HOME/$relative" ] || continue
            chmod "$mode" "$HOME/$relative" 2>/dev/null || true
        done < "$modes_file"
    fi
}

_restore_legacy_backup() {
    local backup_dir="$1"
    local file

    for file in "${MANAGED_DOTFILES[@]}"; do
        if [ -f "$backup_dir/$file" ]; then
            cp "$backup_dir/$file" "$HOME/"
            log_with_level "INFO" "Restored $file"
        fi
    done

    if [ -d "$backup_dir/claude_config" ]; then
        mkdir -p "$HOME/.claude/plugins"
        if [ -f "$backup_dir/claude_config/settings.json" ]; then
            cp "$backup_dir/claude_config/settings.json" "$HOME/.claude/"
            log_with_level "INFO" "Restored Claude Code settings.json"
        fi
        if [ -f "$backup_dir/claude_config/installed_plugins.json" ]; then
            expand_portable_path < "$backup_dir/claude_config/installed_plugins.json" > "$HOME/.claude/plugins/installed_plugins.json"
            log_with_level "INFO" "Restored Claude Code installed_plugins.json"
        fi
        if [ -f "$backup_dir/claude_config/known_marketplaces.json" ]; then
            expand_portable_path < "$backup_dir/claude_config/known_marketplaces.json" > "$HOME/.claude/plugins/known_marketplaces.json"
            log_with_level "INFO" "Restored Claude Code known_marketplaces.json"
        fi
    fi
}

restore_from_backup() {
    local backup_dir="${1:-}"

    if [ -z "$backup_dir" ] && [ -f "$HOME/.supercharged_last_backup" ]; then
        backup_dir=$(<"$HOME/.supercharged_last_backup")
    fi

    if [ ! -d "$backup_dir" ]; then
        log_with_level "ERROR" "Backup directory not found: $backup_dir"
        return 1
    fi

    log_with_level "INFO" "Restoring from backup: $backup_dir"
    if [ -f "$backup_dir/presence.tsv" ]; then
        _restore_manifest_backup "$backup_dir"
    else
        log_with_level "INFO" "Legacy backup detected; restoring available files without absence cleanup"
        _restore_legacy_backup "$backup_dir"
    fi

    log_with_level "SUCCESS" "Restoration completed"
    return 0
}
