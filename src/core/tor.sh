#!/usr/bin/env bash
set -euo pipefail
# Tor gateway — route traffic through Tor for anonymity

ANVPS_DIR="${HOME}/.anvps"
PID_FILE="${ANVPS_DIR}/services/tor.pid"
LOG_FILE="${ANVPS_DIR}/logs/tor.log"
TORRC="${ANVPS_DIR}/etc/torrc"
DATA_DIR="${ANVPS_DIR}/data/tor"

mkdir -p "$DATA_DIR" "$(dirname "$LOG_FILE")"

start() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "Tor already running (PID $(cat "$PID_FILE"))"; return 0
    fi
    if ! command -v tor &>/dev/null; then echo "Tor not installed"; return 1; fi
    if [ ! -f "$TORRC" ]; then
        cat > "$TORRC" <<TORRC
SocksPort 9050
ControlPort 9051
CookieAuthentication 1
DataDirectory ${DATA_DIR}
SafeLogging 1
RunAsDaemon 1
Log notice file ${LOG_FILE}
TORRC
    fi
    tor -f "$TORRC" >> "$LOG_FILE" 2>&1 &
    local pid=$!; echo $pid > "$PID_FILE"
    sleep 3
    if kill -0 "$pid" 2>/dev/null; then
        echo "Tor started (PID $pid, SOCKS5 127.0.0.1:9050)"
    else echo "Tor failed to start"; rm -f "$PID_FILE"; return 1; fi
}

stop() {
    if [ -f "$PID_FILE" ]; then kill "$(cat "$PID_FILE")" 2>/dev/null || true; rm -f "$PID_FILE"; fi
    pkill -f "tor -f $TORRC" 2>/dev/null || true
    echo "Tor stopped"
}

status() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        local id=$(curl -s --socks5-hostname 127.0.0.1:9050 https://check.torproject.org/api/ip 2>/dev/null || echo '{"IsTor":false}')
        local is_tor=$(echo "$id" | grep -o '"IsTor":true' || echo "false")
        echo "Tor: running ($(test -n "$is_tor" && echo 'verified ✓' || echo 'checking...'))"
    else echo "Tor: stopped"; fi
}

case "${1:-status}" in
    start|up) start ;;
    stop|down) stop ;;
    restart) stop; sleep 2; start ;;
    status) status ;;
    *) echo "Usage: $0 {start|stop|restart|status}" ;;
esac
