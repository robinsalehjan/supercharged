#!/bin/zsh
# Cut a new release: bump version in package.json, commit, tag, push.
#
# Usage:
#   ./scripts/release.sh <patch|minor|major|x.y.z>   # bump and tag
#   ./scripts/release.sh --dry-run <bump>            # preview only
#   ./scripts/release.sh --yes <bump>                # skip confirmations (for non-TTY)
#
# After push, the GitHub Actions release workflow creates the GitHub Release.

set -e

SCRIPT_DIR="${0:A:h}"
REPO_ROOT="${SCRIPT_DIR:h}"
cd "$REPO_ROOT"

# shellcheck source=utils.sh
source "$SCRIPT_DIR/utils.sh"

DRY_RUN=0
ASSUME_YES=0
BUMP=""

for arg in "$@"; do
    case "$arg" in
        --dry-run|-n) DRY_RUN=1 ;;
        --yes|-y) ASSUME_YES=1 ;;
        -h|--help)
            sed -n '2,10p' "$0" | sed 's/^# \?//'
            exit 0
            ;;
        *) BUMP="$arg" ;;
    esac
done

# Portable confirmation prompt that works in zsh and bash, with TTY and --yes support.
confirm() {
    local prompt="$1"
    if [[ $ASSUME_YES -eq 1 ]]; then
        return 0
    fi
    if [[ ! -t 0 ]]; then
        log_with_level "ERROR" "No TTY available. Re-run with --yes to skip confirmations."
        return 1
    fi
    printf '%s' "$prompt"
    local ans=""
    read -r ans
    [[ "$ans" =~ ^[Yy] ]]
}

if [[ -z "$BUMP" ]]; then
    log_with_level "ERROR" "Missing bump argument. Use: patch | minor | major | x.y.z"
    exit 1
fi

# Preflight: clean working tree, on main, up to date with origin.
if [[ -n "$(git status --porcelain)" ]]; then
    log_with_level "ERROR" "Working tree not clean. Commit or stash first."
    git status --short
    exit 1
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$BRANCH" != "main" ]]; then
    log_with_level "WARN" "Not on main (current: $BRANCH). Releases should be cut from main."
    confirm "Continue anyway? [y/N]: " || exit 1
fi

git fetch origin --quiet
LOCAL=$(git rev-parse "$BRANCH")
REMOTE=$(git rev-parse "origin/$BRANCH" 2>/dev/null || echo "")
if [[ -n "$REMOTE" && "$LOCAL" != "$REMOTE" ]]; then
    log_with_level "ERROR" "Local $BRANCH is out of sync with origin/$BRANCH. Pull/push first."
    exit 1
fi

CURRENT=$(node -p "require('./package.json').version")
log_with_level "INFO" "Current version: $CURRENT"

# Compute new version without writing yet.
if [[ "$BUMP" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    NEW="$BUMP"
else
    case "$BUMP" in
        patch|minor|major) ;;
        *) log_with_level "ERROR" "Invalid bump '$BUMP'. Use patch | minor | major | x.y.z"; exit 1 ;;
    esac
    NEW=$(node -e "
        const [maj,min,pat] = require('./package.json').version.split('.').map(Number);
        const b = process.argv[1];
        if (b === 'patch') console.log([maj, min, pat+1].join('.'));
        else if (b === 'minor') console.log([maj, min+1, 0].join('.'));
        else if (b === 'major') console.log([maj+1, 0, 0].join('.'));
    " "$BUMP")
fi

TAG="v${NEW}"

if git rev-parse "$TAG" >/dev/null 2>&1; then
    log_with_level "ERROR" "Tag $TAG already exists."
    exit 1
fi

log_with_level "INFO" "New version: $NEW (tag: $TAG)"

if [[ $DRY_RUN -eq 1 ]]; then
    log_with_level "INFO" "Dry run — no changes made."
    exit 0
fi

confirm "Cut release $TAG? [y/N]: " || { log_with_level "INFO" "Aborted."; exit 1; }

# Bump package.json + package-lock.json without auto-tagging (we tag explicitly).
npm version "$NEW" --no-git-tag-version >/dev/null

git add package.json package-lock.json
git commit -m "chore(release): $TAG"
git tag -a "$TAG" -m "Release $TAG"

log_with_level "INFO" "Pushing $BRANCH and $TAG to origin..."
git push origin "$BRANCH"
git push origin "$TAG"

log_with_level "SUCCESS" "Released $TAG. GitHub Actions will publish the release."
