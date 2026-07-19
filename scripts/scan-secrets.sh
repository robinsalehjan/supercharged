#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"

if ! command -v rg >/dev/null 2>&1; then
    echo "ripgrep is required for secret scanning" >&2
    exit 1
fi

scan_paths=("$@")
if [ "${#scan_paths[@]}" -eq 0 ]; then
    scan_paths=("$PROJECT_ROOT")
fi

patterns=(
    'sk-[A-Za-z0-9_-]{20,}'
    'ghp_[A-Za-z0-9_]{20,}'
    'github_pat_[A-Za-z0-9_]{20,}'
    'AKIA[0-9A-Z]{16}'
    '-----BEGIN (RSA |OPENSSH |EC |DSA )?PRIVATE KEY-----'
    "(?i)(api[_-]?key|secret|token|password)[A-Za-z0-9_ -]{0,20}[:=][[:space:]]*[\"']?[A-Za-z0-9_./+=-]{24,}"
)

# Avoid flagging ordinary code references such as
# `max_output_tokens_per_file=args.max_output_tokens_per_file` while retaining
# matches for literal credential-shaped values. Scan individual matches so a
# code reference cannot suppress a real secret elsewhere on the same line.
code_reference_assignment="(?i)(api[_-]?key|secret|token|password)[A-Za-z0-9_ -]{0,20}[:=][[:space:]]*(args|self|config|options|env)\.[A-Za-z_][A-Za-z0-9_.]*[,;)]?['\"]?.*\$"

findings=""
for pattern in "${patterns[@]}"; do
    matches=$(rg \
        --hidden \
        --line-number \
        --no-heading \
        --only-matching \
        --color never \
        --glob '!.git/**' \
        --glob '!node_modules/**' \
        --glob '!package-lock.json' \
        --glob '!*.log' \
        --glob '!tests/fixtures/**' \
        --glob '!SECURITY.md' \
        --glob '!scripts/scan-secrets.sh' \
        "$pattern" \
        "${scan_paths[@]}" 2>/dev/null \
        | rg --invert-match "$code_reference_assignment" \
        || true)

    if [ -n "$matches" ]; then
        findings+="$matches"$'\n'
    fi
done

if [ -n "$findings" ]; then
    echo "Potential secrets found:"
    printf '%s' "$findings"
    exit 1
fi

echo "No likely secrets found"
