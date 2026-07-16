#!/usr/bin/env bash
set -euo pipefail

ANVPS_DIR="${HOME}/.anvps"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[uninstall]${NC} $1"; }
warn() { echo -e "${YELLOW}[uninstall]${NC} $1"; }
err()  { echo -e "${RED}[uninstall]${NC} $1"; }

confirm() {
    echo ""
    warn "This will REMOVE AnVPS entirely from this device."
    echo "  Location: $ANVPS_DIR"
    echo "  Binaries: /usr/local/bin/anvps, Termux bin"
    echo ""
    echo -n "Type 'REMOVE' to confirm: "
    read -r input
    [ "$input" = "REMOVE" ] && return 0 || return 1
}

stop_services() {
    if [ -f "${ANVPS_DIR}/src/cli/anvps" ]; then
        log "Stopping all services..."
        bash "${ANVPS_DIR}/src/cli/anvps" supervisor stop 2>/dev/null || true
    fi
    for pidf in "${ANVPS_DIR}/services"/*.pid; do
        [ -f "$pidf" ] || continue
        kill "$(cat "$pidf")" 2>/dev/null || true
        rm -f "$pidf"
    done
    pkill -f "anvps" 2>/dev/null || true
    sleep 1
    log "Services stopped"
}

remove_binaries() {
    rm -f /usr/local/bin/anvps 2>/dev/null || true
    rm -f /data/data/com.termux/files/usr/bin/anvps 2>/dev/null || true
    log "Binaries removed"
}

remove_data() {
    if [ -d "$ANVPS_DIR" ]; then
        log "Removing $ANVPS_DIR..."
        rm -rf "$ANVPS_DIR"
        log "Data directory removed"
    fi
}

cleanup_cron() {
    crontab -l 2>/dev/null | grep -v "anvps" | crontab - 2>/dev/null || true
    log "Cron entries cleaned"
}

cleanup_iptables() {
    if command -v iptables &>/dev/null && [ "$(id -u)" = "0" ]; then
        iptables -F 2>/dev/null || true
        iptables -X 2>/dev/null || true
        iptables -P INPUT ACCEPT 2>/dev/null || true
        iptables -P OUTPUT ACCEPT 2>/dev/null || true
        iptables -P FORWARD ACCEPT 2>/dev/null || true
    fi
    log "Firewall rules reset"
}

main() {
    echo "=== AnVPS Uninstaller ==="
    if ! confirm; then
        echo "Uninstall cancelled."
        exit 0
    fi
    stop_services
    remove_binaries
    cleanup_cron
    cleanup_iptables
    remove_data
    echo ""
    log "AnVPS has been fully uninstalled."
    echo "  You may also want to remove: ~/.anvps (already done)"
}

main "$@"
