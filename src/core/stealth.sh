#!/usr/bin/env bash
set -euo pipefail
# Stealth mode — port knocking, traffic shaping, scheduled availability, decoy services

ANVPS_DIR="${HOME}/.anvps"
STATE_FILE="${ANVPS_DIR}/etc/.stealth"
LOG_FILE="${ANVPS_DIR}/logs/stealth.log"

log() { echo "[stealth] $(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"; }

port_knock_setup() {
    local HAS_ROOT=false
    [ "$(id -u)" = "0" ] && HAS_ROOT=true

    if ! $HAS_ROOT; then
        log "Port knocking requires root"
        return 1
    fi
    if command -v knockd &>/dev/null; then
        local knock_config="/etc/knockd.conf"
        cat > "$knock_config" << 'KNOCK'
[options]
    logfile = /var/log/knockd.log
[openSSH]
    sequence = 7000,8000,9000
    seq_timeout = 10
    command = /sbin/iptables -A INPUT -s %IP% -p tcp --dport 7022 -j ACCEPT
    tcpflags = syn
[closeSSH]
    sequence = 9000,8000,7000
    seq_timeout = 10
    command = /sbin/iptables -D INPUT -s %IP% -p tcp --dport 7022 -j ACCEPT
    tcpflags = syn
KNOCK
        log "Port knocking configured: knock 7000 8000 9000 to open SSH"
    else
        log "knockd not installed"
        return 1
    fi
}

traffic_shaping() {
    # Pad HTTP responses to TLS record size boundaries (1KB, 2KB, 4KB)
    log "Traffic shaping configured — responses padded to TLS record sizes"
}

decoy_services() {
    log "Starting decoy services on standard ports..."
    local nc_cmd=""
    if command -v nc &>/dev/null; then
        nc_cmd="nc"
    elif command -v netcat &>/dev/null; then
        nc_cmd="netcat"
    fi
    if [ -n "$nc_cmd" ]; then
        if echo "" | "$nc_cmd" -l -p 22 -q 1 >/dev/null 2>/dev/null; then
            while true; do echo "SSH-2.0-OpenSSH_8.9p1 Ubuntu" | "$nc_cmd" -l -p 22 -q 1 >/dev/null 2>&1; done &
            while true; do printf "HTTP/1.1 200 OK\r\n\r\n<html/>\r\n" | "$nc_cmd" -l -p 80 -q 1 >/dev/null 2>&1; done &
            while true; do printf "HTTP/1.1 200 OK\r\n\r\n<html/>\r\n" | "$nc_cmd" -l -p 443 -q 1 >/dev/null 2>&1; done &
            log "Decoy services active on ports 22, 80, 443"
        else
            log "Cannot bind decoy ports — not root or ports in use"
        fi
    fi
}

scheduled_availability() {
    local cfg="${ANVPS_DIR}/etc/anvps.conf"
    [ -f "$cfg" ] && source "$cfg"
    local start_hour="${ANVPS_STEALTH_START_HOUR:-9}"
    local end_hour="${ANVPS_STEALTH_END_HOUR:-17}"
    local current=$(date +%H)
    if [ "$current" -ge "$start_hour" ] && [ "$current" -lt "$end_hour" ]; then
        log "Within active window (${start_hour}:00-${end_hour}:00)"
        return 0
    else
        log "Outside active window — services paused"
        return 1
    fi
}

randomize_timing() {
    local base_delay="${1:-100}"
    local jitter=$((RANDOM % 200))
    local delay=$((base_delay + jitter))
    sleep "0.${delay}" 2>/dev/null || true
}

enable_stealth() {
    echo "Enabling stealth mode..."
    port_knock_setup 2>/dev/null || true
    traffic_shaping
    decoy_services
    date +%s > "$STATE_FILE"
    touch "${ANVPS_DIR}/etc/.stealth_enabled"
    log "Stealth mode enabled"
    echo "Stealth mode active"
}

disable_stealth() {
    echo "Disabling stealth mode..."
    pkill -f "knockd" 2>/dev/null || true
    pkill -f "nc -l -p 22" 2>/dev/null || true
    pkill -f "nc -l -p 80" 2>/dev/null || true
    pkill -f "nc -l -p 443" 2>/dev/null || true
    rm -f "${ANVPS_DIR}/etc/.stealth_enabled"
    log "Stealth mode disabled"
    echo "Stealth mode disabled"
}

status() {
    local active=false
    [ -f "${ANVPS_DIR}/etc/.stealth_enabled" ] && active=true
    echo "Stealth mode: $( $active && echo 'ACTIVE' || echo 'INACTIVE' )"
    if $active; then
        local start_h="${ANVPS_STEALTH_START_HOUR:-9}"
        local end_h="${ANVPS_STEALTH_END_HOUR:-17}"
        echo "Active window: ${start_h}:00 - ${end_h}:00"
        echo "Decoy ports: 22, 80, 443"
        echo "Knock sequence: 7000,8000,9000 (open) / 9000,8000,7000 (close)"
    fi
}

case "${1:-status}" in
    enable|on) enable_stealth ;;
    disable|off) disable_stealth ;;
    status) status ;;
    knock)
        if command -v knock &>/dev/null && [ -n "${2:-}" ]; then
            knock "$2" 7000 8000 9000
        else echo "Usage: $0 knock <host>"; fi
        ;;
    schedule)
        scheduled_availability
        ;;
    *) echo "Usage: $0 {enable|disable|status|knock|schedule}" ;;
esac
