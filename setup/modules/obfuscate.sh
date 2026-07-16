#!/usr/bin/env bash
install_obfuscate() {
    local ENV_TYPE="$1"
    local ANVPS_DIR="${2:-${HOME}/.anvps}"

    log "Installing device obfuscation..."

    case "$ENV_TYPE" in
        termux)
            pkg install -y macchanger 2>/dev/null || true
            pkg install -y nmap 2>/dev/null || true
            ;;
        linux)
            if command -v apt &>/dev/null; then
                apt install -y macchanger 2>/dev/null || true
            elif command -v apk &>/dev/null; then
                apk add macchanger 2>/dev/null || true
            fi
            ;;
    esac

    log "Device obfuscation tools installed"
}
