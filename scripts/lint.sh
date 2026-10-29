#!/bin/zsh

set -euo pipefail

PROJECT_ROOT="${LINT_PROJECT_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$PROJECT_ROOT"

typeset -a shellcheck_files syntax_files
shellcheck_files=(
    scripts/*.sh
    scripts/utils/*.sh
    codex_config/hooks/*.sh
    tests/helpers/*.bash
)
syntax_files=(
    scripts/*.sh
    scripts/utils/*.sh
    codex_config/hooks/*.sh
    dot_files/.zshrc
    dot_files/.zprofile
    dot_files/.p10k.zsh
)

for file in "${shellcheck_files[@]}"; do
    shellcheck --shell=bash --severity=info "$file"
done

# zsh stops parsing after the first error in a multi-file invocation. Checking
# files independently guarantees a later filename cannot be skipped silently.
for file in "${syntax_files[@]}"; do
    zsh -n "$file"
done

actionlint
