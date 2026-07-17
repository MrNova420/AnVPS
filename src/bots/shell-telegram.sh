#!/usr/bin/env bash
set -euo pipefail
# Zero-dependency Telegram bot — uses curl + Telegram REST API
ANVPS_DIR="${HOME}/.anvps"
TOKEN=""
CHAT_ID=""
LAST_UPDATE=0
PID_FILE="${ANVPS_DIR}/services/telegram-bot.pid"
LOG_FILE="${ANVPS_DIR}/logs/telegram-bot.log"

log() { echo "[telegram] $(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"; }

load_config() {
    local cfg="${ANVPS_DIR}/etc/anvps.conf"
    [ -f "$cfg" ] && source "$cfg"
    TOKEN="${ANVPS_TELEGRAM_BOT_TOKEN:-}"
    CHAT_ID="${ANVPS_TELEGRAM_CHAT_ID:-}"
}

send_msg() {
    local msg="$1"
    if [ -z "$TOKEN" ] || [ -z "$CHAT_ID" ]; then return; fi
    curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
        -d "chat_id=$CHAT_ID" -d "text=$msg" -d "parse_mode=Markdown" >/dev/null 2>&1 || true
}

send_alert() { send_msg "⚠️ $1"; }

process_update() {
    local msg="$1"
    local chat="$2"
    log "Command: $msg from $chat"
    case "$msg" in
        /start|/help)
            send_msg "AnVPS Bot\n/status — System status\n/services — List services\n/logs <name> — View logs\n/health — Health check\n/backup — Create backup\n/update — Run update" ;;
        /status)
            local uptime=$(uptime -p 2>/dev/null || echo "?")
            local mem=$(free -h 2>/dev/null | grep Mem | awk '{print $3"/"$2}' || echo "?")
            local cpu=$(cat /proc/loadavg 2>/dev/null | cut -d' ' -f1-3 || echo "?")
            send_msg "Uptime: $uptime\nCPU: $cpu\nMemory: $mem" ;;
        /services)
            local out=""; local count=0
            for pidf in "${ANVPS_DIR}/services"/*.pid; do
                [ -f "$pidf" ] || continue
                local name=$(basename "$pidf" .pid)
                local pid=$(cat "$pidf")
                local st="stopped"; kill -0 "$pid" 2>/dev/null && st="running"
                out="$out\n$name: $st"
                count=$((count + 1))
            done
            [ -z "$out" ] && out="No services" || out="Services ($count):$out"
            send_msg "$out" ;;
        /health)
            local r="ok"
            [ -f "${ANVPS_DIR}/src/core/healthcheck.sh" ] && r=$(bash "${ANVPS_DIR}/src/core/healthcheck.sh" 2>/dev/null | head -5 || echo "error")
            send_msg "Health: ${r:0:200}" ;;
        /backup)
            send_msg "Creating backup..."
            bash "${ANVPS_DIR}/src/cli/anvps" backup create >/dev/null 2>&1 || true
            send_msg "Backup complete" ;;
        /update)
            send_msg "Running updates..."
            bash "${ANVPS_DIR}/src/core/autoupdate.sh" >/dev/null 2>&1 || true
            send_msg "Updates complete" ;;
        /logs*)
            local svc=$(echo "$msg" | awk '{print $2}')
            [ -z "$svc" ] && svc="ssh"
            local logf="${ANVPS_DIR}/logs/${svc}.log"
            if [ -f "$logf" ]; then
                local lines=$(tail -10 "$logf")
                send_msg "Logs ($svc):\n${lines:0:300}"
            else send_msg "No logs for $svc"; fi
            ;;
    esac
}

poll() {
    while true; do
        if [ -z "$TOKEN" ]; then sleep 30; continue; fi
        local resp=$(curl -s "https://api.telegram.org/bot${TOKEN}/getUpdates?offset=$LAST_UPDATE&timeout=10" 2>/dev/null || echo '{"result":[]}')
        local updates=$(echo "$resp" | sed 's/{"update_id":/\n{"update_id":/g' | grep '{"update_id":' || true)
        while IFS= read -r item; do
            [ -z "$item" ] && continue
            local id=$(echo "$item" | sed 's/.*"update_id":\([0-9]*\).*/\1/')
            [ -z "$id" ] && continue
            [ "$id" -ge "$LAST_UPDATE" ] && LAST_UPDATE=$((id + 1))
            local text=$(echo "$item" | sed 's/.*"text":"//; s/","[a-z_]".*//; s/\\"/"/g; s/"}].*//')
            local chat=$(echo "$item" | sed 's/.*"chat":{"id":\([0-9-]*\).*/\1/')
            [ -n "$text" ] && [ -n "$chat" ] && process_update "$text" "$chat"
        done <<< "$updates"
        sleep 3
    done
}

start() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "Bot already running (PID $(cat "$PID_FILE"))"; return 0
    fi
    load_config
    if [ -z "$TOKEN" ]; then
        echo "ANVPS_TELEGRAM_BOT_TOKEN not set — bot disabled"
        return 1
    fi
    nohup bash "$0" poll >> "$LOG_FILE" 2>&1 &
    local pid=$!; echo $pid > "$PID_FILE"
    sleep 2
    if kill -0 "$pid" 2>/dev/null; then
        echo "Telegram bot started (PID $pid)"
        send_msg "AnVPS Telegram bot started"
    else echo "Bot failed to start"; fi
}

stop() {
    if [ -f "$PID_FILE" ]; then
        kill "$(cat "$PID_FILE")" 2>/dev/null || true
        rm -f "$PID_FILE"
        echo "Telegram bot stopped"
    fi
}

case "${1:-start}" in
    start) start ;;
    stop) stop ;;
    restart) stop; sleep 1; start ;;
    poll) poll ;;
    *) echo "Usage: $0 {start|stop|restart}" ;;
esac
