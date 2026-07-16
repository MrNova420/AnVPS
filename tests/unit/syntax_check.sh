#!/usr/bin/env bash
cd "$(dirname "$0")/../.."
errors=0
while IFS= read -r -d '' f; do
    if bash -n "$f" 2>/dev/null; then
        echo "PASS: $f"
    else
        echo "FAIL: $(bash -n "$f" 2>&1)"
        errors=$((errors + 1))
    fi
done < <(find . -name "*.sh" -type f -print0; find . -name "anvps" -type f -print0)
[ "$errors" -eq 0 ] && echo "All passed" || echo "$errors failed"
exit $errors
