#!/usr/bin/env bash
set -euo pipefail
# Zero-dependency Discord bot — uses curl + Discord REST API
ANVPS_DIR="${HOME}/.anvps"
TOKEN=""
CHANNEL_ID=""
LAST_MESSAGE_ID=""
PID_FILE="${ANVPS_DIR}/services/discord-bot.pid"
LOG_FILE="${ANVPS_DIR}/logs/discord-bot.log"

log() { echo "[discord] $(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"; }

load_config() {
    local cfg="${ANVPS_DIR}/etc/anvps.conf"
    [ -f "$cfg" ] && source "$cfg"
    TOKEN="${ANVPS_DISCORD_BOT_TOKEN:-}"
    CHANNEL_ID="${ANVPS_DISCORD_CHANNEL_ID:-}"
}

API="https://discord.com/api/v10"

send_msg() {
    [ -z "$TOKEN" ] || [ -z "$CHANNEL_ID" ] && return
    curl -s -X POST "${API}/channels/${CHANNEL_ID}/messages" \
        -H "Authorization: Bot ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"content\": \"$1\"}" >/dev/null 2>&1 || true
}

send_alert() { send_msg "⚠️ **$1**"; }

process_command() {
    local cmd="$1"
    log "Command: $cmd"
    case "$cmd" in
        an!help)
            send_msg "**AnVPS Commands**\nan!status — System status\nan!services — List services\nan!logs <name> — View logs\nan!health — Health check\nan!backup — Create backup\nan!update — Run update" ;;
        an!status)
            local uptime=$(uptime -p 2>/dev/null || echo "?")
            local mem=$(free -h 2>/dev/null | grep Mem | awk '{print $3"/"$2}' || echo "?")
            local cpu=$(cat /proc/loadavg 2>/dev/null | cut -d' ' -f1-3 || echo "?")
            send_msg "**AnVPS Status**\nUptime: $uptime\nCPU: $cpu\nMemory: $mem" ;;
        an!services)
            local out=""; local count=0
            for pidf in "${ANVPS_DIR}/services"/*.pid; do
                [ -f "$pidf" ] || continue
                local name=$(basename "$pidf" .pid)
                local pid=$(cat "$pidf")
                local st="🔴"; kill -0 "$pid" 2>/dev/null && st="🟢"
                out="$out\n$st $name"
                count=$((count + 1))
            done
            [ -z "$out" ] && out="No services" || out="**Services ($count):**$out"
            send_msg "$out" ;;
        an!health)
            local r="ok"
            [ -f "${ANVPS_DIR}/src/core/healthcheck.sh" ] && r=$(bash "${ANVPS_DIR}/src/core/healthcheck.sh" 2>/dev/null | head -5 || echo "error")
            send_msg "**Health:** ${r:0:200}" ;;
        an!backup)
            send_msg "Creating backup..."
            bash "${ANVPS_DIR}/src/cli/anvps" backup create >/dev/null 2>&1 || true
            send_msg "Backup complete" ;;
        an!update)
            send_msg "Running updates..."
            bash "${ANVPS_DIR}/src/core/autoupdate.sh" >/dev/null 2>&1 || true
            send_msg "Updates complete" ;;
        an!logs*)
            local svc=$(echo "$cmd" | awk '{print $2}')
            [ -z "$svc" ] && svc="ssh"
            local logf="${ANVPS_DIR}/logs/${svc}.log"
            if [ -f "$logf" ]; then
                local lines=$(tail -10 "$logf")
                send_msg "**Logs ($svc):**\n\`\`\`${lines:0:300}\`\`\`"
            else send_msg "No logs for $svc"; fi
            ;;
    esac
}

poll() {
    while true; do
        if [ -z "$TOKEN" ] || [ -z "$CHANNEL_ID" ]; then sleep 30; continue; fi
        local params="limit=5"
        [ -n "$LAST_MESSAGE_ID" ] && params="$params&after=$LAST_MESSAGE_ID"
        local resp=$(curl -s "${API}/channels/${CHANNEL_ID}/messages?${params}" \
            -H "Authorization: Bot ${TOKEN}" 2>/dev/null || echo '[]')
        local items=$(echo "$resp" | sed 's/{"id":"/\n{"id":"/g' | grep '{"id":"' || true)
        while IFS= read -r item; do
            [ -z "$item" ] && continue
            local id=$(echo "$item" | sed 's/.*"id":"\([0-9]*\)".*/\1/')
            local author=$(echo "$item" | sed 's/.*"username":"\([^"]*\)".*/\1/')
            [ -z "$id" ] && continue
            [ "$id" = "$LAST_MESSAGE_ID" ] && continue
            [ "$author" = "AnVPS Bot" ] && continue
            LAST_MESSAGE_ID="$id"
            local content=$(echo "$item" | sed 's/.*"content":"//; s/","[a-z_]".*//; s/\\"/"/g; s/"}].*//')
            [ -n "$content" ] && process_command "$content"
        done <<< "$items"
        sleep 3
    done
}

start() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "Bot already running (PID $(cat "$PID_FILE"))"; return 0
    fi
    load_config
    if [ -z "$TOKEN" ] || [ -z "$CHANNEL_ID" ]; then
        echo "Discord token/channel not set — bot disabled"
        return 1
    fi
    nohup bash "$0" poll >> "$LOG_FILE" 2>&1 &
    local pid=$!; echo $pid > "$PID_FILE"
    sleep 2
    if kill -0 "$pid" 2>/dev/null; then
        echo "Discord bot started (PID $pid)"
        send_msg "AnVPS Discord bot started"
    else echo "Bot failed to start"; fi
}

stop() {
    if [ -f "$PID_FILE" ]; then kill "$(cat "$PID_FILE")" 2>/dev/null || true; rm -f "$PID_FILE"; fi
    echo "Discord bot stopped"
}

case "${1:-start}" in
    start) start ;;
    stop) stop ;;
    restart) stop; sleep 1; start ;;
    poll) poll ;;
    *) echo "Usage: $0 {start|stop|restart}" ;;
esac
