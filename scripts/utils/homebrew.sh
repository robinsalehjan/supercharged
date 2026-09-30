#!/bin/zsh

# Reconcile Homebrew 6's third-party tap trust without granting whole-tap
# access. Formula definitions are executable Ruby, so keep this list limited to
# the exact third-party formulae managed by this repository.
reconcile_homebrew_taps() {
    local dry_run="${1:-false}"
    local installed_taps tap formula
    local -a trusted_formulae retired_taps

    command -v brew >/dev/null 2>&1 || return 0

    trusted_formulae=(
        "danger/tap/danger-js"
        "danger/tap/danger-swift"
        "hashicorp/tap/terraform"
        "jundot/omlx/omlx"
        "mobai-app/tap/simslim"
        "replicate/tap/replicate"
        "xcodesorg/made/xcodes"
    )
    retired_taps=(
        "finn/brew"
        "getsentry/tools"
        "getsentry/xcodebuildmcp"
        "ldayton/dippy"
        "peripheryapp/periphery"
        "thoughtbot/formulae"
    )

    installed_taps=$(brew tap 2>/dev/null || true)

    for formula in "${trusted_formulae[@]}"; do
        tap="${formula%/*}"
        if ! printf '%s\n' "$installed_taps" | grep -Fxq "$tap"; then
            continue
        fi

        if [ "$dry_run" = true ]; then
            log_with_level "INFO" "Would trust managed Homebrew formula: $formula"
        elif ! brew trust --formula "$formula" >/dev/null; then
            log_with_level "WARN" "Could not trust managed Homebrew formula: $formula"
        fi
    done

    for tap in "${retired_taps[@]}"; do
        if ! printf '%s\n' "$installed_taps" | grep -Fxq "$tap"; then
            continue
        fi

        if [ "$dry_run" = true ]; then
            log_with_level "INFO" "Would remove unused Homebrew tap: $tap"
        elif brew untap "$tap" >/dev/null 2>&1; then
            log_with_level "SUCCESS" "Removed unused Homebrew tap: $tap"
        else
            # Homebrew refuses to untap repositories that still provide an
            # installed item. Never force removal: leave locally used tools in
            # place and report the remaining migration explicitly.
            log_with_level "WARN" "Kept Homebrew tap $tap because it still provides an installed item"
        fi
    done
}

# On newer macOS releases the Xcodes tap can fall back to a quiet Swift source
# build, which can appear to hang after printing Xcode/CLT compatibility
# warnings. Use its bottle only when Homebrew confirms one is usable, and keep
# the remaining formulae on Homebrew's normal upgrade path.
upgrade_homebrew_formulae() {
    local formula
    local -a regular_formulae

    regular_formulae=()
    while IFS= read -r formula; do
        [ -n "$formula" ] || continue
        case "$formula" in
            xcodes|xcodesorg/made/xcodes)
                if brew upgrade --formula --force-bottle --dry-run xcodesorg/made/xcodes >/dev/null 2>&1; then
                    log_with_level "INFO" "Updating xcodes from its prebuilt Homebrew bottle..."
                    if brew upgrade --formula --force-bottle xcodesorg/made/xcodes; then
                        log_with_level "SUCCESS" "Updated xcodes from its prebuilt bottle"
                    else
                        log_with_level "WARN" "Could not update xcodes from its prebuilt bottle; skipped the slow source build"
                    fi
                else
                    log_with_level "WARN" "Skipping xcodes update because its tap has no usable bottle; run 'brew upgrade xcodesorg/made/xcodes' manually to allow a source build"
                fi
                ;;
            *) regular_formulae+=("$formula") ;;
        esac
    done <<< "$(brew outdated --formula --quiet)"

    if [ "${#regular_formulae[@]}" -gt 0 ]; then
        brew upgrade --formula "${regular_formulae[@]}"
    fi
}
