#!/usr/bin/env bash
# AnVPS Unit Tests — Run with: bash tests/unit/test_install.sh
set -euo pipefail
PASS=0; FAIL=0
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

assert() {
    if "$@"; then echo -e "${GREEN}[PASS]${NC} $*"; PASS=$((PASS+1));
    else echo -e "${RED}[FAIL]${NC} $*"; FAIL=$((FAIL+1)); fi
}

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

echo "=== AnVPS Unit Tests ==="
echo ""

# --- Setup scripts ---
echo "-- Setup --"
assert test -f "${PROJECT_DIR}/setup/install.sh"
assert test -f "${PROJECT_DIR}/setup/bootstrap.sh"
assert test -f "${PROJECT_DIR}/setup/root-enable.sh"
assert test -d "${PROJECT_DIR}/setup/modules"

# --- Module installers ---
echo "-- Modules --"
for mod in ssh webserver database docker code-server file-server vpn tunnel; do
    assert test -f "${PROJECT_DIR}/setup/modules/${mod}.sh"
done

# --- Core ---
echo "-- Core --"
for core in supervisor healthcheck autoupdate security ssh storage; do
    assert test -f "${PROJECT_DIR}/src/core/${core}.sh"
done

# --- CLI ---
echo "-- CLI --"
assert test -f "${PROJECT_DIR}/src/cli/anvps"
assert test -d "${PROJECT_DIR}/src/cli/commands"

# --- Tunnels ---
echo "-- Tunnels --"
assert test -f "${PROJECT_DIR}/src/tunnels/tunnel-manager.sh"

# --- Web ---
echo "-- Web --"
assert test -f "${PROJECT_DIR}/src/web/backend/main.py"
assert test -f "${PROJECT_DIR}/src/web/frontend/index.html"

# --- Bots ---
echo "-- Bots --"
assert test -f "${PROJECT_DIR}/src/bots/telegram/bot.py"
assert test -f "${PROJECT_DIR}/src/bots/discord/bot.py"

# --- Config ---
echo "-- Config --"
assert test -f "${PROJECT_DIR}/config/anvps.conf"
assert test -f "${PROJECT_DIR}/config/services.conf"
for prof in minimal webhost dev full; do
    assert test -f "${PROJECT_DIR}/config/profiles/${prof}.conf"
done

# --- Docs ---
echo "-- Docs --"
assert test -f "${PROJECT_DIR}/README.md"
for doc in architecture installation commands; do
    assert test -f "${PROJECT_DIR}/docs/${doc}.md"
done

# --- Shell syntax check ---
echo "-- Syntax --"
if command -v bash &>/dev/null; then
    for shfile in $(find "${PROJECT_DIR}" -name "*.sh" -type f); do
        bash -n "$shfile" 2>/dev/null && PASS=$((PASS+1)) || {
            echo -e "${RED}[FAIL]${NC} bash syntax: $shfile"; FAIL=$((FAIL+1));
        }
    done
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
