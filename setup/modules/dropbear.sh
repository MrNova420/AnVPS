#!/usr/bin/env bash
install_dropbear() {
    local ENV_TYPE="$1"
    local ANVPS_DIR="${2:-${HOME}/.anvps}"
    local SSH_PORT="${3:-7022}"

    log "Installing Dropbear SSH (lightweight)..."

    case "$ENV_TYPE" in
        termux) pkg install -y dropbear 2>/dev/null || true ;;
        linux)
            if command -v apt &>/dev/null; then apt install -y dropbear 2>/dev/null || true
            elif command -v apk &>/dev/null; then apk add dropbear 2>/dev/null || true; fi
            ;;
    esac

    if ! command -v dropbear &>/dev/null; then
        warn "Dropbear not available via package — trying static binary"
        local arch
        case "$(uname -m)" in
            aarch64|arm64) arch="aarch64" ;;
            armv7l|armhf)  arch="armhf" ;;
            x86_64|amd64)  arch="x86_64" ;;
        esac
        local tmp_dir="/tmp/dropbear-install"
        mkdir -p "$tmp_dir"
        curl -sL "https://github.com/mkj/dropbear/archive/refs/tags/DROPBEAR_2024.85.tar.gz" -o "${tmp_dir}/dropbear.tar.gz" 2>/dev/null && {
            tar xzf "${tmp_dir}/dropbear.tar.gz" -C "$tmp_dir" 2>/dev/null || true
            if [ -f "${tmp_dir}/dropbear" ]; then
                cp "${tmp_dir}/dropbear" "${ANVPS_DIR}/bin/" 2>/dev/null || true
            fi
        } || warn "Static binary fallback failed"
        rm -rf "$tmp_dir"
    fi

    if command -v dropbear &>/dev/null; then
        mkdir -p "${ANVPS_DIR}/data/ssh"
        local host_key="${ANVPS_DIR}/data/ssh/dropbear_host_ed25519"
        if [ ! -f "$host_key" ]; then
            dropbearkey -t ed25519 -f "$host_key" 2>/dev/null || true
        fi

        mkdir -p "${HOME}/.ssh"
        if [ ! -f "${HOME}/.ssh/authorized_keys" ]; then
            [ -f "${HOME}/.ssh/id_ed25519.pub" ] && cp "${HOME}/.ssh/id_ed25519.pub" "${HOME}/.ssh/authorized_keys"
        fi

        echo "$SSH_PORT" > "${ANVPS_DIR}/etc/ssh.port"
        log "Dropbear installed for port $SSH_PORT"
    else
        err "Dropbear installation failed"
    fi
}
