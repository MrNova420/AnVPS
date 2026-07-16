#!/usr/bin/env bash
set -euo pipefail

ANVPS_DIR="${HOME}/.anvps"
SERVICES_DIR="${ANVPS_DIR}/services"
LOG_DIR="${ANVPS_DIR}/logs"
PID_FILE="${SERVICES_DIR}/ssh.pid"
SSH_PORT="${ANVPS_SSH_PORT:-7022}"
HOST_KEY="${ANVPS_DIR}/data/ssh/dropbear_host_ed25519"

mkdir -p "$SERVICES_DIR" "$LOG_DIR" "${ANVPS_DIR}/data/ssh"

start() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then echo "Dropbear running (PID $pid)"; return 0; fi
        rm -f "$PID_FILE"
    fi
    if [ ! -f "$HOST_KEY" ]; then
        dropbearkey -t ed25519 -f "$HOST_KEY" 2>/dev/null || true
    fi
    dropbear -p "$SSH_PORT" -r "$HOST_KEY" -P "$PID_FILE" >> "${LOG_DIR}/ssh.log" 2>&1
    sleep 1
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "Dropbear started (PID $(cat "$PID_FILE"), port $SSH_PORT)"
    else
        echo "Dropbear failed to start"
        return 1
    fi
}

stop() {
    if [ -f "$PID_FILE" ]; then
        kill "$(cat "$PID_FILE")" 2>/dev/null || true; rm -f "$PID_FILE"
    fi
    pkill -f "dropbear" 2>/dev/null || true
    echo "Dropbear stopped"
}

case "${1:-start}" in
    start) start ;;
    stop) stop ;;
    restart) stop; sleep 1; start ;;
    *) echo "Usage: $0 {start|stop|restart}" ;;
esac
