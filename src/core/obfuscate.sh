#!/usr/bin/env bash
set -euo pipefail
# Device obfuscation — mask Android fingerprints, randomize identifiers

ANVPS_DIR="${HOME}/.anvps"
STATE_FILE="${ANVPS_DIR}/etc/.obfuscated"

random_str() { tr -dc 'a-z0-9' < /dev/urandom 2>/dev/null | head -c"${1:-8}" || echo "anvps$(date +%s)"; }

random_mac() {
    printf '02:%02x:%02x:%02x:%02x:%02x\n' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256))
}

obfuscate_hostname() {
    local new_hostname="anvps-$(random_str 6)"
    if [ "$(id -u)" = "0" ]; then
        echo "$new_hostname" > /proc/sys/kernel/hostname 2>/dev/null || true
        echo "$new_hostname" > /etc/hostname 2>/dev/null || true
    fi
    echo "$new_hostname" > "${ANVPS_DIR}/etc/.hostname"
    echo "Hostname obfuscated: $new_hostname"
}

obfuscate_ssh_keys() {
    echo "Rotating SSH host keys..."
    for key in "${ANVPS_DIR}/data/ssh"/*; do
        [ -f "$key" ] && rm -f "$key"
    done
    if command -v ssh-keygen &>/dev/null; then
        ssh-keygen -t ed25519 -f "${ANVPS_DIR}/data/ssh/ssh_host_ed25519_key" -N "" 2>/dev/null || true
    fi
    if command -v dropbearkey &>/dev/null; then
        dropbearkey -t ed25519 -f "${ANVPS_DIR}/data/ssh/dropbear_host_ed25519" 2>/dev/null || true
    fi
    echo "SSH host keys rotated"
}

obfuscate_mac() {
    if [ "$(id -u)" != "0" ]; then echo "MAC randomization requires root"; return 1; fi
    local changed=0
    if command -v macchanger &>/dev/null; then
        for iface in /sys/class/net/wlan* /sys/class/net/eth* /sys/class/net/usb* /sys/class/net/enp* /sys/class/net/enx*; do
            [ -d "$iface" ] || continue
            local name=$(basename "$iface")
            ip link set "$name" down 2>/dev/null || true
            macchanger -r "$name" 2>/dev/null || true
            ip link set "$name" up 2>/dev/null || true
            echo "MAC randomized for $name"
            changed=1
        done
    elif command -v ip &>/dev/null; then
        for iface in /sys/class/net/wlan* /sys/class/net/eth* /sys/class/net/usb* /sys/class/net/enp* /sys/class/net/enx*; do
            [ -d "$iface" ] || continue
            local name=$(basename "$iface")
            local new_mac=$(printf '02:%02x:%02x:%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
            ip link set "$name" down 2>/dev/null || true
            ip link set "$name" address "$new_mac" 2>/dev/null || true
            ip link set "$name" up 2>/dev/null || true
            echo "MAC randomized for $name -> $new_mac"
            changed=1
        done
    fi
    if [ "$changed" -eq 0 ]; then echo "No interfaces found or no tools available"; fi
}

obfuscate_http_headers() {
    local ua_file="${ANVPS_DIR}/etc/.user_agent"
    local agents=(
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0"
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Safari/17.2"
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120.0.0.0"
    )
    printf "%s\n" "${agents[$RANDOM % ${#agents[@]}]}" > "$ua_file"
    echo "HTTP User-Agent randomized"
}

obfuscate_all() {
    echo "Running full device obfuscation..."
    obfuscate_hostname
    obfuscate_ssh_keys
    obfuscate_mac 2>/dev/null || true
    obfuscate_http_headers
    date +%s > "$STATE_FILE"
    echo "Device obfuscation complete"
}

status() {
    if [ -f "$STATE_FILE" ]; then
        local last=$(date -d "@$(cat "$STATE_FILE")" 2>/dev/null || echo "unknown")
        echo "Device obfuscated (last: $last)"
    else echo "Device NOT obfuscated"; fi
    local host=$(cat "${ANVPS_DIR}/etc/.hostname" 2>/dev/null || hostname 2>/dev/null || echo "?")
    echo "Hostname: $host"
}

case "${1:-status}" in
    all) obfuscate_all ;;
    hostname) obfuscate_hostname ;;
    ssh) obfuscate_ssh_keys ;;
    mac) obfuscate_mac ;;
    http) obfuscate_http_headers ;;
    status) status ;;
    *) echo "Usage: $0 {all|hostname|ssh|mac|http|status}" ;;
esac
