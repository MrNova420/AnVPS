#!/usr/bin/env bash
set -euo pipefail

ANVPS_DIR="${HOME}/.anvps"
LOG_DIR="${ANVPS_DIR}/logs"
FAIL_LOG="${LOG_DIR}/auth-failures.log"
BAN_LIST="${ANVPS_DIR}/etc/.ban_list"
PID_FILE="${ANVPS_DIR}/services/fail2ban.pid"
MAX_ATTEMPTS=5
BAN_TIME=3600

log() { echo "[fail2ban] $(date '+%Y-%m-%d %H:%M:%S') $1" >> "${LOG_DIR}/fail2ban.log"; }

ban_ip() {
    local ip="$1"
    if [ -f "$BAN_LIST" ] && grep -q "^$ip " "$BAN_LIST" 2>/dev/null; then
        return
    fi
    echo "$ip $(date +%s) $BAN_TIME" >> "$BAN_LIST"
    if command -v iptables &>/dev/null && [ "$(id -u)" = "0" ]; then
        iptables -A INPUT -s "$ip" -j DROP 2>/dev/null || true
        log "Banned $ip via iptables"
    fi
    log "Banned $ip for ${BAN_TIME}s"
}

unban_expired() {
    [ -f "$BAN_LIST" ] || return
    local now=$(date +%s)
    local tmp=$(mktemp)
    while IFS=' ' read -r ip time duration; do
        [ -z "$ip" ] && continue
        local elapsed=$((now - time))
        if [ "$elapsed" -ge "$duration" ]; then
            if command -v iptables &>/dev/null && [ "$(id -u)" = "0" ]; then
                iptables -D INPUT -s "$ip" -j DROP 2>/dev/null || true
            fi
            log "Unbanned $ip (expired)"
        else
            echo "$ip $time $duration" >> "$tmp"
        fi
    done < "$BAN_LIST"
    mv "$tmp" "$BAN_LIST"
}

check_logs() {
    local logfiles=("${LOG_DIR}/ssh.log" "${LOG_DIR}/dropbear.log")
    for lf in "${logfiles[@]}"; do
        [ -f "$lf" ] || continue
        local recent=$(grep -cE "Failed password|auth failure|Bad protocol" "$lf" 2>/dev/null || echo 0)
        if [ "$recent" -gt 0 ]; then
            local ips=$(grep -oE "from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" "$lf" 2>/dev/null | cut -d' ' -f2 | sort -u)
            for ip in $ips; do
                local count=$(grep -c "$ip" "$lf" 2>/dev/null || echo 0)
                if [ "$count" -ge "$MAX_ATTEMPTS" ]; then
                    ban_ip "$ip"
                fi
            done
        fi
    done
}

loop() {
    while true; do
        unban_expired
        check_logs
        sleep 60
    done
}

start() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "fail2ban already running (PID $(cat "$PID_FILE"))"
        return 0
    fi
    mkdir -p "$LOG_DIR"
    nohup bash "$0" loop >> "${LOG_DIR}/fail2ban.log" 2>&1 &
    local pid=$!
    echo $pid > "$PID_FILE"
    sleep 1
    if kill -0 "$pid" 2>/dev/null; then
        echo "fail2ban started (PID $pid)"
    else
        echo "fail2ban failed to start"
    fi
}

stop() {
    if [ -f "$PID_FILE" ]; then
        kill "$(cat "$PID_FILE")" 2>/dev/null || true
        rm -f "$PID_FILE"
    fi
    echo "fail2ban stopped"
}

status() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "fail2ban: RUNNING (PID $(cat "$PID_FILE"))"
    else
        echo "fail2ban: STOPPED"
    fi
    local banned=0
    [ -f "$BAN_LIST" ] && banned=$(wc -l < "$BAN_LIST")
    echo "Banned IPs: $banned"
}

case "${1:-status}" in
    start) start ;;
    stop) stop ;;
    restart) stop; sleep 1; start ;;
    status) status ;;
    loop) loop ;;
    *) echo "Usage: $0 {start|stop|restart|status}" ;;
esac
