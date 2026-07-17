#!/usr/bin/env bash
set -euo pipefail

ANVPS_DIR="${HOME}/.anvps"
TUNNEL_DIR="${ANVPS_DIR}/tunnels"
CONFIG="${ANVPS_DIR}/etc/tunnel.conf"
LOG_DIR="${ANVPS_DIR}/logs"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${GREEN}[tunnel]${NC} $1"; }
warn() { echo -e "${YELLOW}[tunnel]${NC} $1"; }
err()  { echo -e "${RED}[tunnel]${NC} $1"; }

load_config() {
    if [ -f "$CONFIG" ]; then
        source "$CONFIG"
    fi
    : "${TUNNEL_TYPE:=cloudflare}"
    : "${LOCAL_PORT:=7080}"
    : "${TUNNEL_TOKEN:=}"
    : "${NGROK_TOKEN:=}"
    : "${BORE_PORT:=7890}"
}

test_binary() {
    local bin="$1" name="$2"
    if [ ! -f "$bin" ]; then return 1; fi
    if "$bin" --version 2>/dev/null || "$bin" version 2>/dev/null || "$bin" --help 2>/dev/null | head -1; then
        return 0
    else
        warn "$name binary at $bin cannot execute — incompatible with this platform"
        rm -f "$bin"
        return 1
    fi
}

start_cloudflare() {
    local cloudflared_bin="${TUNNEL_DIR}/cloudflared"
    if [ ! -f "$cloudflared_bin" ]; then
        local arch
        case "$(uname -m)" in
            aarch64|arm64) arch="arm64" ;;
            armv7l|armhf)  arch="arm" ;;
            x86_64|amd64)  arch="amd64" ;;
        esac
        local url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${arch}"
        curl -sL "$url" -o "$cloudflared_bin" 2>/dev/null || { err "Cloudflare install failed"; return 1; }
        chmod +x "$cloudflared_bin"
        test_binary "$cloudflared_bin" "cloudflared" || return 1
    fi

    local pid_file="${ANVPS_DIR}/services/cloudflared.pid"
    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        log "Cloudflare already running (PID $(cat "$pid_file"))"
        return 0
    fi

    nohup "$cloudflared_bin" tunnel --no-autoupdate run --token "$TUNNEL_TOKEN" \
        >> "${LOG_DIR}/cloudflared.log" 2>&1 &
    echo $! > "$pid_file"
    sleep 2
    if kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        log "Cloudflare Tunnel started (PID $(cat "$pid_file"))"
    else
        warn "Cloudflare Tunnel failed to start — check token"
        rm -f "$pid_file"
    fi
}

start_ngrok() {
    local ngrok_bin="${TUNNEL_DIR}/ngrok"
    if [ ! -f "$ngrok_bin" ]; then
        local arch
        case "$(uname -m)" in
            aarch64|arm64) arch="arm64" ;;
            armv7l|armhf)  arch="arm" ;;
            x86_64|amd64)  arch="amd64" ;;
        esac
        local url="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-${arch}.tgz"
        curl -sL "$url" -o "/tmp/ngrok.tgz" && tar xzf "/tmp/ngrok.tgz" -C "$TUNNEL_DIR" && rm -f "/tmp/ngrok.tgz"
        chmod +x "$ngrok_bin"
        test_binary "$ngrok_bin" "ngrok" || return 1
    fi

    local pid_file="${ANVPS_DIR}/services/ngrok.pid"
    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        log "ngrok already running"
        return 0
    fi

    if [ -n "$NGROK_TOKEN" ]; then
        "$ngrok_bin" authtoken "$NGROK_TOKEN" >/dev/null 2>&1
    fi

    nohup "$ngrok_bin" http "$LOCAL_PORT" --log=stdout \
        >> "${LOG_DIR}/ngrok.log" 2>&1 &
    echo $! > "$pid_file"
    sleep 2
    if kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        log "ngrok tunnel started (port $LOCAL_PORT)"
    else
        warn "ngrok failed to start"
        rm -f "$pid_file"
    fi
}

start_bore() {
    local bore_bin="${TUNNEL_DIR}/bore"
    if [ ! -f "$bore_bin" ]; then
        local arch
        case "$(uname -m)" in
            aarch64|arm64) arch="aarch64-linux" ;;
            armv7l|armhf)  arch="armv7-linux" ;;
            x86_64|amd64)  arch="x86_64-linux" ;;
        esac
        local ver=$(curl -s https://api.github.com/repos/ekzhang/bore/releases/latest 2>/dev/null | grep tag_name | cut -d'"' -f4 || echo "v0.5.2")
        curl -sL "https://github.com/ekzhang/bore/releases/download/${ver}/bore-${arch}" -o "$bore_bin"
        chmod +x "$bore_bin"
        test_binary "$bore_bin" "bore" || return 1
    fi

    local pid_file="${ANVPS_DIR}/services/bore.pid"
    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        log "bore already running"
        return 0
    fi

    nohup "$bore_bin" local "$LOCAL_PORT" --to "bore.pub" \
        >> "${LOG_DIR}/bore.log" 2>&1 &
    echo $! > "$pid_file"
    sleep 2
    if kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        log "bore tunnel started (local port $LOCAL_PORT)"
    else
        warn "bore failed to start"
        rm -f "$pid_file"
    fi
}

stop_tunnel() {
    local name="$1"
    local pid_file="${ANVPS_DIR}/services/${name}.pid"
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        kill "$pid" 2>/dev/null || true
        rm -f "$pid_file"
        log "$name stopped"
    fi
}

stop_all() {
    for t in cloudflared ngrok bore; do
        stop_tunnel "$t"
    done
    pkill -f "cloudflared" 2>/dev/null || true
    pkill -f "ngrok" 2>/dev/null || true
    pkill -f "bore" 2>/dev/null || true
    log "All tunnels stopped"
}

status_tunnel() {
    local name="$1"
    local pid_file="${ANVPS_DIR}/services/${name}.pid"
    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        echo "$name: running (PID $(cat "$pid_file"))"
    else
        echo "$name: stopped"
    fi
}

status_all() {
    for t in cloudflared ngrok bore; do
        status_tunnel "$t"
    done
}

load_config
case "${1:-status}" in
    start)
        tunnel_type="${2:-$TUNNEL_TYPE}"
        case "$tunnel_type" in
            cloudflare) start_cloudflare ;;
            ngrok)      start_ngrok ;;
            bore)       start_bore ;;
            all)
                start_cloudflare
                start_ngrok
                start_bore
                ;;
        esac
        ;;
    stop)
        if [ -n "${2:-}" ]; then
            stop_tunnel "$2"
        else
            stop_all
        fi
        ;;
    restart)
        stop_all
        sleep 2
        start_cloudflare || true
        start_ngrok || true
        start_bore || true
        ;;
    status)
        status_all
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status} [cloudflare|ngrok|bore|all]"
        ;;
esac
