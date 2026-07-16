#!/usr/bin/env bash
set -euo pipefail

ANVPS_DIR="${HOME}/.anvps"
SERVICES_DIR="${ANVPS_DIR}/services"
LOG_DIR="${ANVPS_DIR}/logs"
SSH_PORT="${ANVPS_SSH_PORT:-7022}"

mkdir -p "$SERVICES_DIR" "$LOG_DIR"

start() {
    local pid_file="${SERVICES_DIR}/ssh.pid"
    if [ -f "$pid_file" ]; then
        local old_pid=$(cat "$pid_file")
        if kill -0 "$old_pid" 2>/dev/null; then
            echo "SSH already running (PID $old_pid)"
            return 0
        fi
        rm -f "$pid_file"
    fi

    local sshd_bin=""
    if command -v sshd &>/dev/null; then
        sshd_bin="sshd"
    elif [ -f "/data/data/com.termux/files/usr/bin/sshd" ]; then
        sshd_bin="/data/data/com.termux/files/usr/bin/sshd"
    else
        echo "sshd not found"
        return 1
    fi

    "$sshd_bin" >> "${LOG_DIR}/ssh.log" 2>&1 &
    local pid=$!
    echo $pid > "$pid_file"
    echo "SSH started (PID $pid, port $SSH_PORT)"
}

stop() {
    local pid_file="${SERVICES_DIR}/ssh.pid"
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        kill "$pid" 2>/dev/null || true
        rm -f "$pid_file"
        echo "SSH stopped"
    fi
    pkill -f "sshd" 2>/dev/null || true
}

case "${1:-start}" in
    start)  start ;;
    stop)   stop ;;
    restart) stop; sleep 1; start ;;
    *)      echo "Usage: $0 {start|stop|restart}" ;;
esac
