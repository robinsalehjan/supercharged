#!/bin/zsh

# Reconcile the shared agent tooling layer first, then adapt each available
# harness through its native marketplace and plugin commands.

set -euo pipefail

source "$(dirname "$0")/utils.sh"

PROJECT_ROOT="$UTILS_PROJECT_ROOT"
MANAGED_TOOLS_INSTALLER="${MANAGED_TOOLS_INSTALLER:-$PROJECT_ROOT/scripts/install-managed-tools.sh}"
MCP_INSTALLER="${MCP_INSTALLER:-$PROJECT_ROOT/scripts/install-mcps.py}"
SKILLS_INSTALLER="${SKILLS_INSTALLER:-$PROJECT_ROOT/scripts/install-skills.sh}"
CLAUDE_PLUGINS_INSTALLER="${CLAUDE_PLUGINS_INSTALLER:-$PROJECT_ROOT/scripts/install-plugins.sh}"
DRY_RUN=false
HARNESS=both

cleanup() {
    :
}
trap cleanup EXIT

show_help() {
    echo "Usage: $(basename "$0") [--dry-run] [--harness both|claude|codex]"
    echo ""
    echo "Reconcile shared CLIs, skills, MCP registrations and selected native plugins."
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --harness)
            if [ $# -lt 2 ]; then
                log_with_level "ERROR" "--harness requires both, claude, or codex"
                show_help
                exit 2
            fi
            HARNESS="${2:-}"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_with_level "ERROR" "Unknown option: $1"
            show_help
            exit 2
            ;;
    esac
done

case "$HARNESS" in
    both|claude|codex) ;;
    *)
        log_with_level "ERROR" "Invalid harness: $HARNESS"
        show_help
        exit 2
        ;;
esac

typeset -a installer_args
$DRY_RUN && installer_args=(--dry-run) || installer_args=()

typeset -a available_agents mcp_args
available_agents=()
for agent in claude codex; do
    [[ "$HARNESS" == both || "$HARNESS" == "$agent" ]] || continue
    if $DRY_RUN || command_exists "$agent"; then
        available_agents+=("$agent")
    else
        log_with_level WARN "Skipping $agent MCP registration because its CLI is unavailable"
    fi
done
mcp_args=()
if (( ${#available_agents[@]} )); then
    mcp_harness=both
    if (( ${#available_agents[@]} == 1 )); then
        mcp_harness="${available_agents[1]}"
    fi
    mcp_args=(--harness "$mcp_harness")
    ios_tools_selected && mcp_args+=(--ios)
    # Detect conflicts across selected agents before changing tools or skills.
    if $DRY_RUN; then
        "$MCP_INSTALLER" --dry-run "${mcp_args[@]}"
    else
        "$MCP_INSTALLER" --dry-run "${mcp_args[@]}" >/dev/null
    fi
fi

log_with_level "INFO" "Reconciling shared agent CLIs and skills..."
"$MANAGED_TOOLS_INSTALLER" "${installer_args[@]}"
"$SKILLS_INSTALLER" "${installer_args[@]}" --harness "$HARNESS"

if [ "$DRY_RUN" = false ] && (( ${#mcp_args[@]} )); then
    "$MCP_INSTALLER" "${mcp_args[@]}"
fi

reconcile_harness() {
    local harness="$1"
    local installer="$2"

    if [ "$DRY_RUN" = true ] || command_exists "$harness"; then
        log_with_level "INFO" "Reconciling $harness marketplaces and plugins..."
        "$installer" "${installer_args[@]}"
    else
        log_with_level "WARN" "Skipping $harness plugins because the $harness CLI is not installed"
    fi
}

if [ "$HARNESS" = both ] || [ "$HARNESS" = claude ]; then
    reconcile_harness claude "$CLAUDE_PLUGINS_INSTALLER"
fi

log_with_level "SUCCESS" "Shared agent tooling and native harness adapters are reconciled"
