#!/usr/bin/env bash
install_vpn() {
    local ENV_TYPE="$1"
    local ANVPS_DIR="${2:-${HOME}/.anvps}"
    local HAS_ROOT="${3:-false}"
    local VPN_PORT="${4:-7518}"

    log "Installing VPN server..."

    local VPN_DIR="${ANVPS_DIR}/data/vpn"
    mkdir -p "$VPN_DIR"
    mkdir -p "${VPN_DIR}/clients"

    if ! $HAS_ROOT; then
        log "No root — installing WireGuard via userspace implementation (boringtun)"
        case "$ENV_TYPE" in
            termux)
                pkg install -y wireguard-tools 2>/dev/null || true
                pip install boringtun 2>/dev/null || true
                ;;
            linux)
                if command -v apt &>/dev/null; then
                    apt install -y wireguard-tools 2>/dev/null || true
                elif command -v apk &>/dev/null; then
                    apk add wireguard-tools 2>/dev/null || true
                fi
                pip3 install boringtun 2>/dev/null || true
                ;;
        esac
    else
        log "Root available — installing real WireGuard"
        case "$ENV_TYPE" in
            termux)
                pkg install -y wireguard-tools 2>/dev/null || true
                ;;
            linux)
                if command -v apt &>/dev/null; then
                    apt install -y wireguard 2>/dev/null || apt install -y wireguard-tools 2>/dev/null || true
                elif command -v apk &>/dev/null; then
                    apk add wireguard wireguard-tools 2>/dev/null || true
                fi
                ;;
        esac
    fi

    cat > "${ANVPS_DIR}/src/core/vpn-manager.sh" << 'VPNMGR'
#!/usr/bin/env bash
ANVPS_DIR="${HOME}/.anvps"
VPN_DIR="${ANVPS_DIR}/data/vpn"

generate_config() {
    local CLIENT_NAME="${1:-client}"
    local VPN_PORT="${2:-7518}"
    local SERVER_PRIV="${VPN_DIR}/server_private"
    local SERVER_PUB="${VPN_DIR}/server_public"
    local CLIENT_PRIV="${VPN_DIR}/clients/${CLIENT_NAME}_private"
    local CLIENT_PUB="${VPN_DIR}/clients/${CLIENT_NAME}_public"

    mkdir -p "${VPN_DIR}/clients"

    if [ ! -f "$SERVER_PRIV" ]; then
        wg genkey | tee "$SERVER_PRIV" | wg pubkey > "$SERVER_PUB"
    fi
    wg genkey | tee "$CLIENT_PRIV" | wg pubkey > "$CLIENT_PUB"
    SERVER_KEY=$(cat "$SERVER_PRIV")
    CLIENT_KEY=$(cat "$CLIENT_PRIV")
    CLIENT_PUBKEY=$(cat "$CLIENT_PUB")

    cat > "${VPN_DIR}/wg0.conf" << SRV
[Interface]
Address = 10.0.0.1/24
ListenPort = ${VPN_PORT}
PrivateKey = ${SERVER_KEY}

[Peer]
PublicKey = ${CLIENT_PUBKEY}
AllowedIPs = 10.0.0.2/32
SRV

    local SERVER_PUBKEY=$(cat "$SERVER_PUB")
    cat > "${VPN_DIR}/clients/${CLIENT_NAME}.conf" << CLI
[Interface]
Address = 10.0.0.2/24
PrivateKey = ${CLIENT_KEY}
DNS = 1.1.1.1

[Peer]
PublicKey = ${SERVER_PUBKEY}
Endpoint = $(curl -s ifconfig.me 2>/dev/null || echo "CHANGE_ME"):${VPN_PORT}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
CLI

    echo "Client config: ${VPN_DIR}/clients/${CLIENT_NAME}.conf"
    cat "${VPN_DIR}/clients/${CLIENT_NAME}.conf"
}

start_vpn() {
    local VPN_PORT="${1:-7518}"
    if command -v wg-quick &>/dev/null; then
        wg-quick up "${VPN_DIR}/wg0.conf" 2>/dev/null || true
    elif command -v wg &>/dev/null; then
        wg setconf wg0 "${VPN_DIR}/wg0.conf" 2>/dev/null || true
        ip link add wg0 type wireguard 2>/dev/null || true
        ip addr add 10.0.0.1/24 dev wg0 2>/dev/null || true
        ip link set wg0 up 2>/dev/null || true
    fi
}

case "${1:-}" in
    generate) generate_config "${2:-client}" "${3:-7518}" ;;
    start)    start_vpn "${2:-7518}" ;;
    client)   cat "${VPN_DIR}/clients/${2:-client}.conf" 2>/dev/null || echo "Client not found. Run: vpn-manager.sh generate <name>" ;;
    *)        echo "Usage: $0 {generate|start|client} [name]" ;;
esac
VPNMGR
    chmod +x "${ANVPS_DIR}/src/core/vpn-manager.sh"
    log "VPN manager installed (port: $VPN_PORT)"
}
