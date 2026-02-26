#!/bin/bash

# Shellcheck validation script
# Validates shell scripts for common issues

set -eo pipefail

SCRIPT_DIRPATH=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
REPO_DIRPATH=$(realpath "$SCRIPT_DIRPATH/..")

echo "=== Running shellcheck ==="

cd "$REPO_DIRPATH"

# Check if shellcheck is installed
if ! command -v shellcheck &>/dev/null; then
    echo "ERROR: shellcheck is not installed"
    exit 1
fi

# Find and check all shell scripts
SCRIPTS=()

# Root level scripts
if [[ -f "lib.sh" ]]; then
    SCRIPTS+=("lib.sh")
fi

if [[ -f "systemd_banish.sh" ]]; then
    SCRIPTS+=("systemd_banish.sh")
fi

# Packer scripts
while IFS= read -r -d '' script; do
    SCRIPTS+=("$script")
done < <(find packer -name "*.sh" -print0 2>/dev/null)

# CI scripts (except this one to avoid recursion issues)
while IFS= read -r -d '' script; do
    if [[ "$script" != "ci/shellcheck.sh" ]]; then
        SCRIPTS+=("$script")
    fi
done < <(find ci -name "*.sh" -print0 2>/dev/null)

if [[ ${#SCRIPTS[@]} -eq 0 ]]; then
    echo "No shell scripts found to check"
    exit 0
fi

echo "Checking ${#SCRIPTS[@]} scripts..."

FAILED=0
for script in "${SCRIPTS[@]}"; do
    echo -n "  $script: "
    if shellcheck -x "$script"; then
        echo "OK"
    else
        echo "FAILED"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
if [[ $FAILED -gt 0 ]]; then
    echo "=== $FAILED script(s) failed shellcheck ==="
    exit 1
else
    echo "=== All scripts passed shellcheck ==="
fi
