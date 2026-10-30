#!/bin/zsh

# Cross-platform modification time, in seconds since the epoch.
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

# Restore a portable repository file without imposing a product-specific merge
# policy. Claude and Codex keep their merge decisions in their own scripts.
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
