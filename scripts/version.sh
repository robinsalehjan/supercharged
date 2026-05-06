#!/bin/zsh
# Print supercharged version, git SHA, tag, and host info.
# Useful for comparing what's installed across machines.

set -e

SCRIPT_DIR="${0:A:h}"
REPO_ROOT="${SCRIPT_DIR:h}"
cd "$REPO_ROOT"

VERSION=$(node -p "require('./package.json').version" 2>/dev/null || echo "unknown")

if git rev-parse --git-dir >/dev/null 2>&1; then
    SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    TAG=$(git describe --tags --exact-match 2>/dev/null || echo "")
    DESCRIBE=$(git describe --tags --always --dirty 2>/dev/null || echo "unknown")
    BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
else
    SHA="not-a-git-repo"
    TAG=""
    DESCRIBE="not-a-git-repo"
    BRANCH=""
fi

HOST=$(hostname -s 2>/dev/null || hostname)

echo "supercharged v${VERSION}"
echo "  describe : ${DESCRIBE}"
echo "  commit   : ${SHA}"
[[ -n "$TAG" ]] && echo "  tag      : ${TAG}"
[[ -n "$BRANCH" ]] && echo "  branch   : ${BRANCH}"
echo "  host     : ${HOST}"
