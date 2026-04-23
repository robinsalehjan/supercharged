#!/bin/zsh

# Create restoration point
create_restoration_point() {
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_base="$HOME/.supercharged_backups"
    local backup_dir="$backup_base/$timestamp"

    log_with_level "INFO" "Creating restoration point at $backup_dir"
    mkdir -p "$backup_dir"

    # Backup existing configurations
    for file in "${MANAGED_DOTFILES[@]}"; do
        if [ -f "$HOME/$file" ]; then
            cp "$HOME/$file" "$backup_dir/"
            log_with_level "INFO" "Backed up $file"
        fi
    done

    # Backup Claude Code configuration if available (strip home directory for portability)
    if [ -d "$HOME/.claude" ]; then
        mkdir -p "$backup_dir/claude_config"
        if [ -f "$HOME/.claude/settings.json" ]; then
            cp "$HOME/.claude/settings.json" "$backup_dir/claude_config/"
            log_with_level "INFO" "Backed up Claude Code settings.json"
        fi
        if [ -f "$HOME/.claude/plugins/installed_plugins.json" ]; then
            make_path_portable < "$HOME/.claude/plugins/installed_plugins.json" > "$backup_dir/claude_config/installed_plugins.json"
            log_with_level "INFO" "Backed up Claude Code installed_plugins.json (paths made portable)"
        fi
        if [ -f "$HOME/.claude/plugins/known_marketplaces.json" ]; then
            make_path_portable < "$HOME/.claude/plugins/known_marketplaces.json" > "$backup_dir/claude_config/known_marketplaces.json"
            log_with_level "INFO" "Backed up Claude Code known_marketplaces.json (paths made portable)"
        fi
    fi

    # Store brew list if available
    if command -v brew >/dev/null 2>&1; then
        brew list > "$backup_dir/brew_packages.txt" 2>/dev/null || true
        brew list --cask > "$backup_dir/brew_casks.txt" 2>/dev/null || true
    fi

    # Store asdf plugins if available
    if command -v asdf >/dev/null 2>&1; then
        asdf plugin list > "$backup_dir/asdf_plugins.txt" 2>/dev/null || true
        asdf list > "$backup_dir/asdf_versions.txt" 2>/dev/null || true
    fi

    echo "$backup_dir" > "$HOME/.supercharged_last_backup"

    # Clean up old backups, keeping only the last N
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

# Restore from backup
restore_from_backup() {
    local backup_dir="${1:-}"

    if [ -z "$backup_dir" ] && [ -f "$HOME/.supercharged_last_backup" ]; then
        backup_dir=$(cat "$HOME/.supercharged_last_backup")
    fi

    if [ ! -d "$backup_dir" ]; then
        log_with_level "ERROR" "Backup directory not found: $backup_dir"
        return 1
    fi

    log_with_level "INFO" "Restoring from backup: $backup_dir"

    for file in "${MANAGED_DOTFILES[@]}"; do
        if [ -f "$backup_dir/$file" ]; then
            cp "$backup_dir/$file" "$HOME/"
            log_with_level "INFO" "Restored $file"
        fi
    done

    # Restore Claude Code configuration if available in backup (expand $HOME placeholder)
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

    log_with_level "SUCCESS" "Restoration completed"
    return 0
}
