#!/usr/bin/env bash
install_tunnel() {
    local ENV_TYPE="$1"
    local ANVPS_DIR="${2:-${HOME}/.anvps}"
    local HAS_ROOT="${3:-false}"

    log "Installing tunnel clients..."

    local TUNNEL_DIR="${ANVPS_DIR}/tunnels"
    mkdir -p "$TUNNEL_DIR"

    install_cloudflare() {
        log "Installing Cloudflare Tunnel..."
        local arch
        case "$(uname -m)" in
            aarch64|arm64) arch="arm64" ;;
            armv7l|armhf)  arch="arm" ;;
            x86_64|amd64)  arch="amd64" ;;
        esac
        local url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${arch}"
        curl -sL "$url" -o "${TUNNEL_DIR}/cloudflared" 2>/dev/null && {
            chmod +x "${TUNNEL_DIR}/cloudflared"
            log "Cloudflare Tunnel installed"
        } || warn "Cloudflare Tunnel install failed"
    }

    install_ngrok() {
        log "Installing ngrok..."
        local arch
        case "$(uname -m)" in
            aarch64|arm64) arch="arm64" ;;
            armv7l|armhf)  arch="arm" ;;
            x86_64|amd64)  arch="amd64" ;;
        esac
        local url="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-${arch}.tgz"
        curl -sL "$url" -o "/tmp/ngrok.tgz" 2>/dev/null && {
            tar xzf "/tmp/ngrok.tgz" -C "$TUNNEL_DIR"
            chmod +x "${TUNNEL_DIR}/ngrok"
            log "ngrok installed"
        } || warn "ngrok install failed"
        rm -f "/tmp/ngrok.tgz"
    }

    install_bore() {
        log "Installing bore..."
        local arch
        case "$(uname -m)" in
            aarch64|arm64) arch="aarch64-linux" ;;
            armv7l|armhf)  arch="armv7-linux" ;;
            x86_64|amd64)  arch="x86_64-linux" ;;
        esac
        local ver=$(curl -s https://api.github.com/repos/ekzhang/bore/releases/latest | grep tag_name | cut -d'"' -f4 2>/dev/null || echo "v0.5.2")
        local url="https://github.com/ekzhang/bore/releases/download/${ver}/bore-${arch}"
        curl -sL "$url" -o "${TUNNEL_DIR}/bore" 2>/dev/null && {
            chmod +x "${TUNNEL_DIR}/bore"
            log "bore installed"
        } || warn "bore install failed"
    }

    install_cloudflare
    install_ngrok
    install_bore

    cat > "${ANVPS_DIR}/src/tunnels/tunnel-manager.sh" << 'TUNMGR'
#!/usr/bin/env bash
ANVPS_DIR="${HOME}/.anvps"
TUNNEL_DIR="${ANVPS_DIR}/tunnels"
CONFIG="${ANVPS_DIR}/etc/tunnel.conf"

load_config() {
    if [ -f "$CONFIG" ]; then
        source "$CONFIG"
    else
        TUNNEL_TYPE="${TUNNEL_TYPE:-cloudflare}"
        LOCAL_PORT="${LOCAL_PORT:-7080}"
        TUNNEL_TOKEN="${TUNNEL_TOKEN:-}"
        NGROK_TOKEN="${NGROK_TOKEN:-}"
    fi
}

start_cloudflare() {
    if [ ! -f "${TUNNEL_DIR}/cloudflared" ]; then
        echo "cloudflared not installed"
        return 1
    fi
    if [ -n "$TUNNEL_TOKEN" ]; then
        "${TUNNEL_DIR}/cloudflared" tunnel --no-autoupdate run --token "$TUNNEL_TOKEN" &
    else
        "${TUNNEL_DIR}/cloudflared" tunnel --no-autoupdate --url "http://localhost:${LOCAL_PORT}" &
    fi
    echo "Cloudflare Tunnel started (port: $LOCAL_PORT)"
}

start_ngrok() {
    if [ ! -f "${TUNNEL_DIR}/ngrok" ]; then
        echo "ngrok not installed"
        return 1
    fi
    if [ -n "$NGROK_TOKEN" ]; then
        "${TUNNEL_DIR}/ngrok" authtoken "$NGROK_TOKEN"
    fi
    "${TUNNEL_DIR}/ngrok" http "$LOCAL_PORT" --log=stdout &
    echo "ngrok tunnel started (port: $LOCAL_PORT)"
}

start_bore() {
    local BORE_PORT="${BORE_PORT:-7890}"
    if [ ! -f "${TUNNEL_DIR}/bore" ]; then
        echo "bore not installed"
        return 1
    fi
    "${TUNNEL_DIR}/bore" local "$LOCAL_PORT" --to "bore.pub" &
    echo "bore tunnel started (local port: $LOCAL_PORT)"
}

load_config
case "${1:-start}" in
    start)
        case "$TUNNEL_TYPE" in
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
        pkill -f "cloudflared" 2>/dev/null || true
        pkill -f "ngrok" 2>/dev/null || true
        pkill -f "bore" 2>/dev/null || true
        echo "Tunnels stopped"
        ;;
    status)
        echo "Cloudflare: $(pgrep -f cloudflared >/dev/null && echo running || echo stopped)"
        echo "ngrok: $(pgrep -f ngrok >/dev/null && echo running || echo stopped)"
        echo "bore: $(pgrep -f bore >/dev/null && echo running || echo stopped)"
        ;;
    *) echo "Usage: $0 {start|stop|status}" ;;
esac
TUNMGR
    chmod +x "${ANVPS_DIR}/src/tunnels/tunnel-manager.sh"
    log "Tunnel system installed"
}
