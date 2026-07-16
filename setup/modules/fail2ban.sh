#!/usr/bin/env bash
set -euo pipefail

install_fail2ban() {
    local env_type="${1:-termux}"
    echo "Installing fail2ban..."
    case "$env_type" in
        termux)
            pkg install -y fail2ban 2>/dev/null || true
            mkdir -p "${2:-$HOME/.anvps}/etc/fail2ban"
            cp /data/data/com.termux/files/usr/etc/fail2ban/jail.conf "${2:-$HOME/.anvps}/etc/fail2ban/" 2>/dev/null || true
            ;;
        linux)
            if command -v apt &>/dev/null; then
                apt install -y fail2ban 2>/dev/null || true
            elif command -v apk &>/dev/null; then
                apk add fail2ban 2>/dev/null || true
            fi
            mkdir -p "${2:-$HOME/.anvps}/etc/fail2ban"
            cp /etc/fail2ban/jail.conf "${2:-$HOME/.anvps}/etc/fail2ban/" 2>/dev/null || true
            ;;
    esac
    echo "fail2ban setup complete"
}
