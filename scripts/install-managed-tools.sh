#!/bin/zsh

set -euo pipefail

source "$(dirname "$0")/utils.sh"

DRY_RUN=false
if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=true
elif [ -n "${1:-}" ]; then
    echo "Usage: $(basename "$0") [--dry-run]" >&2
    exit 2
fi

typeset -a setup_args
$DRY_RUN && setup_args=(--dry-run) || setup_args=()

retire_legacy_xcode_mcps "${setup_args[@]}"
if [ -f "$HOME/.supercharged_preferences" ]; then
    load_supercharged_preferences "$HOME/.supercharged_preferences"
fi
if [[ "${INSTALL_CLOUD_TOOLS:-Y}" =~ ^[Yy] ]]; then
    setup_firebase "${setup_args[@]}"
fi
setup_openwiki "${setup_args[@]}"
setup_openwiki_watcher "${setup_args[@]}"
setup_playwright_cli "${setup_args[@]}"
setup_playwright_mcp "${setup_args[@]}"
setup_plannotator "${setup_args[@]}"
setup_code_review_graph "${setup_args[@]}"
setup_crg_watcher "${setup_args[@]}"

setup_obscura "${setup_args[@]}"
