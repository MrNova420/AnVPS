#!/usr/bin/env bash
set -euo pipefail

install_encrypt() {
    local env_type="${1:-termux}"
    echo "Installing encrypted storage support..."
    case "$env_type" in
        termux) pkg install -y gocryptfs 2>/dev/null || pkg install -y encfs 2>/dev/null || true ;;
        linux)
            if command -v apt &>/dev/null; then
                apt install -y gocryptfs 2>/dev/null || apt install -y encfs 2>/dev/null || true
            elif command -v apk &>/dev/null; then
                apk add gocryptfs 2>/dev/null || apk add encfs 2>/dev/null || true
            fi
            ;;
    esac
    echo "Encryption setup complete"
    if command -v gocryptfs &>/dev/null; then
        echo "Using: gocryptfs"
    elif command -v encfs &>/dev/null; then
        echo "Using: encfs"
    else
        echo "No encryption tool found — install gocryptfs or encfs manually"
    fi
}
