#!/usr/bin/env bash
set -euo pipefail
# Encrypted storage — encrypts AnVPS data at rest using encfs/gocryptfs

ANVPS_DIR="${HOME}/.anvps"
ENCRYPTED_DIR="${ANVPS_DIR}/data/encrypted"
MOUNT_DIR="${ANVPS_DIR}/data/private"
KEY_FILE="${ANVPS_DIR}/etc/.encrypt_key"
PID_FILE="${ANVPS_DIR}/services/encrypt.pid"
PASSWORD="${ANVPS_ENCRYPT_PASSWORD:-}"

mkdir -p "$ENCRYPTED_DIR" "$MOUNT_DIR"

log() { echo "[encrypt] $(date '+%Y-%m-%d %H:%M:%S') $1" >> "${ANVPS_DIR}/logs/encrypt.log"; }

detect_tool() {
    if command -v gocryptfs &>/dev/null; then echo "gocryptfs"; return 0; fi
    if command -v encfs &>/dev/null; then echo "encfs"; return 0; fi
    echo ""
}

init_encrypted() {
    local tool=$(detect_tool)
    if [ -z "$tool" ]; then
        echo "No encryption tool found (install gocryptfs or encfs)"
        return 1
    fi
    if [ -d "$MOUNT_DIR" ] && mountpoint -q "$MOUNT_DIR" 2>/dev/null; then
        echo "Already mounted at $MOUNT_DIR"
        return 0
    fi
    local pass="${PASSWORD:-$(tr -dc 'A-Za-z0-9!@#$%^&*()_+' < /dev/urandom 2>/dev/null | head -c32 || echo 'anvps_default_key_2024')}"
    echo "$pass" > "$KEY_FILE"
    chmod 400 "$KEY_FILE"
    case "$tool" in
        gocryptfs)
            if [ ! -f "${ENCRYPTED_DIR}/gocryptfs.conf" ]; then
                echo "$pass" | gocryptfs -init -passfile /dev/stdin "$ENCRYPTED_DIR" 2>/dev/null || {
                    gocryptfs -init "$ENCRYPTED_DIR" <<< "$pass" 2>/dev/null || true
                }
            fi
            echo "$pass" | gocryptfs "$ENCRYPTED_DIR" "$MOUNT_DIR" 2>/dev/null || {
                gocryptfs "$ENCRYPTED_DIR" "$MOUNT_DIR" <<< "$pass" 2>/dev/null || true
            }
            ;;
        encfs)
            if [ ! -f "${ENCRYPTED_DIR}/.encfs6.xml" ]; then
                echo "$pass" | encfs --stdinpass --reverse "$MOUNT_DIR" "$ENCRYPTED_DIR" 2>/dev/null || {
                    encfs -S "$ENCRYPTED_DIR" "$MOUNT_DIR" <<< "$pass" 2>/dev/null || true
                }
            else
                echo "$pass" | encfs --stdinpass "$ENCRYPTED_DIR" "$MOUNT_DIR" 2>/dev/null || true
            fi
            ;;
    esac
    if mountpoint -q "$MOUNT_DIR" 2>/dev/null; then
        log "Encrypted storage mounted at $MOUNT_DIR"
        echo "Encrypted storage active at $MOUNT_DIR"
        echo $$ > "$PID_FILE"
    else
        echo "Failed to mount encrypted storage"
        return 1
    fi
}

unmount() {
    local tool=$(detect_tool)
    case "$tool" in
        gocryptfs) fusermount -u "$MOUNT_DIR" 2>/dev/null || true ;;
        encfs) fusermount -u "$MOUNT_DIR" 2>/dev/null || true ;;
    esac
    if ! mountpoint -q "$MOUNT_DIR" 2>/dev/null; then
        log "Encrypted storage unmounted"
        echo "Encrypted storage unmounted"
        rm -f "$PID_FILE"
    else echo "Failed to unmount"; fi
}

status() {
    if mountpoint -q "$MOUNT_DIR" 2>/dev/null; then
        echo "Encrypted storage: MOUNTED at $MOUNT_DIR"
        local used=$(du -sh "$MOUNT_DIR" 2>/dev/null | cut -f1 || echo "?")
        echo "Data: $used"
    else echo "Encrypted storage: NOT MOUNTED"; fi
    local tool=$(detect_tool)
    [ -n "$tool" ] && echo "Tool: $tool" || echo "Tool: none"
}

setup() {
    local tool=$(detect_tool)
    if [ -n "$tool" ]; then
        echo "Encryption tool already installed: $tool"
        return 0
    fi
    if [ -n "${TERMUX_VERSION:-}" ] && command -v pkg &>/dev/null; then
        pkg install -y gocryptfs 2>/dev/null || pkg install -y encfs 2>/dev/null || true
    elif command -v apt &>/dev/null && command -v sudo &>/dev/null; then
        sudo apt install -y gocryptfs 2>/dev/null || sudo apt install -y encfs 2>/dev/null || true
    fi
    tool=$(detect_tool)
    if [ -n "$tool" ]; then
        echo "Installed: $tool"
    else
        echo "No encryption tool available — install gocryptfs or encfs manually"
    fi
}

case "${1:-status}" in
    init|mount|start) init_encrypted ;;
    umount|unmount|stop) unmount ;;
    restart) unmount; sleep 1; init_encrypted ;;
    status) status ;;
    setup) setup ;;
    *) echo "Usage: $0 {init|unmount|restart|status|setup}" ;;
esac
