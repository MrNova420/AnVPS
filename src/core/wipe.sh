#!/usr/bin/env bash
set -euo pipefail
# Secure wipe — destroy all AnVPS data securely, with optional device wipe

ANVPS_DIR="${HOME}/.anvps"
MODE="${1:-manual}"
REASON="${2:-user_requested}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${RED}[wipe]${NC} $1"; }
warn() { echo -e "${YELLOW}[wipe]${NC} $1"; }

CONFIRMED=false

confirm_wipe() {
    if [ "$MODE" = "auto" ]; then
        CONFIRMED=true
        return
    fi
    echo ""
    warn "WARNING: This will DESTROY all AnVPS data on this device!"
    echo "  Location: $ANVPS_DIR"
    echo "  Reason: $REASON"
    echo ""
    echo -n "Type 'YES' to confirm: "
    read -r input
    [ "$input" = "YES" ] && CONFIRMED=true
}

stop_services() {
    log "Stopping all services..."
    for pidf in "${ANVPS_DIR}/services"/*.pid; do
        [ -f "$pidf" ] || continue
        local pid=$(cat "$pidf")
        kill "$pid" 2>/dev/null || true
        rm -f "$pidf"
    done
    pkill -f "anvps" 2>/dev/null || true
    sleep 2
    log "All services stopped"
}

secure_delete() {
    local target="$1"
    if [ ! -e "$target" ]; then return; fi
    if command -v shred &>/dev/null; then
        find "$target" -type f -exec shred -f -z -n 3 {} \; 2>/dev/null || true
    else
        find "$target" -type f -exec sh -c 'dd if=/dev/urandom of="$1" bs=1M 2>/dev/null; rm -f "$1"' _ {} \; 2>/dev/null || true
    fi
    rm -rf "$target"
    log "Securely deleted: $target"
}

wipe_anvps_data() {
    log "Wiping AnVPS data..."
    for dir in data logs tmp backup; do
        [ -d "${ANVPS_DIR}/${dir}" ] && secure_delete "${ANVPS_DIR}/${dir}"
    done
    [ -d "${ANVPS_DIR}/etc" ] && secure_delete "${ANVPS_DIR}/etc"
    [ -f "${ANVPS_DIR}/src/cli/anvps" ] && rm -f "${ANVPS_DIR}/src/cli/anvps"
    log "AnVPS data wiped"
}

unlink_binaries() {
    rm -f /usr/local/bin/anvps 2>/dev/null || true
    rm -f /data/data/com.termux/files/usr/bin/anvps 2>/dev/null || true
    log "Binaries unlinked"
}

notify_remote() {
    if [ -f "${ANVPS_DIR}/etc/anvps.conf" ]; then
        source "${ANVPS_DIR}/etc/anvps.conf"
        local msg="AnVPS WIPE EXECUTED: $REASON at $(date '+%Y-%m-%d %H:%M:%S')"
        if [ -n "${ANVPS_TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${ANVPS_TELEGRAM_CHAT_ID:-}" ]; then
            curl -s -X POST "https://api.telegram.org/bot${ANVPS_TELEGRAM_BOT_TOKEN}/sendMessage" \
                -d "chat_id=${ANVPS_TELEGRAM_CHAT_ID}" -d "text=$msg" >/dev/null 2>&1 || true
        fi
    fi
    log "Remote notification sent"
}

device_factory_reset() {
    if [ "$(id -u)" != "0" ]; then
        warn "Factory reset requires root — skipping"
        return
    fi
    if [ -f "/system/build.prop" ]; then
        log "Triggering factory reset..."
        sync
        command -v setprop &>/dev/null && setprop sys.powerctl reboot,recovery 2>/dev/null || true
    elif [ -f "/system/bin/recovery" ]; then
        log "Recovery binary found but not Android — skipping setprop"
    else
        warn "Not an Android device — factory reset not supported"
    fi
}

main() {
    confirm_wipe
    if ! $CONFIRMED; then
        log "Wipe cancelled"
        exit 0
    fi
    log "WIPE INITIATED — Reason: $REASON"
    notify_remote
    stop_services
    wipe_anvps_data
    unlink_binaries
    if [ "${3:-}" = "--factory" ]; then
        device_factory_reset
    fi
    log "Wipe complete — device is clean"
}

main "$@"
