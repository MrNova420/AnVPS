#!/usr/bin/env bash
install_tor() {
    local ENV_TYPE="$1"
    local ANVPS_DIR="${2:-${HOME}/.anvps}"

    log "Installing Tor..."

    case "$ENV_TYPE" in
        termux)
            pkg install -y tor torsocks 2>/dev/null || true
            ;;
        linux)
            if command -v apt &>/dev/null; then
                apt install -y tor torsocks 2>/dev/null || true
            elif command -v apk &>/dev/null; then
                apk add tor torsocks 2>/dev/null || true
            fi
            ;;
    esac

    if ! command -v tor &>/dev/null; then
        warn "Tor not available — install manually"
        return
    fi

    mkdir -p "${ANVPS_DIR}/data/tor"
    local torrc="${ANVPS_DIR}/etc/torrc"
    cat > "$torrc" << 'TORRC'
SocksPort 9050
ControlPort 9051
CookieAuthentication 1
DataDirectory ~/.anvps/data/tor
SafeLogging 1
RunAsDaemon 1
Log notice file ~/.anvps/logs/tor.log
TORRC

    log "Tor installed (SOCKS5 on 127.0.0.1:9050)"
}
