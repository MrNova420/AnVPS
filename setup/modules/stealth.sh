#!/usr/bin/env bash
install_stealth() {
    local ENV_TYPE="$1"
    local ANVPS_DIR="${2:-${HOME}/.anvps}"
    local HAS_ROOT="${3:-false}"

    log "Installing stealth modules..."

    if $HAS_ROOT && command -v apt &>/dev/null; then
        apt install -y knockd 2>/dev/null || true
        log "Port knocking daemon installed"
    fi

    log "Stealth modules prepared"
}
