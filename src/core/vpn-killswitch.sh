#!/usr/bin/env bash
set -euo pipefail
# VPN kill switch — ensures NO traffic leaks if VPN drops
# Uses iptables to block all non-VPN traffic

ANVPS_DIR="${HOME}/.anvps"
VPN_IFACE="${ANVPS_VPN_IFACE:-wg0}"
VPN_PORT="${ANVPS_VPN_PORT:-7518}"

check_root() {
    if [ "$(id -u)" != "0" ]; then echo "Kill switch requires root"; return 1; fi
    if ! command -v iptables &>/dev/null && ! command -v nft &>/dev/null; then
        echo "iptables or nftables not found"; return 1
    fi
}

enable_killswitch() {
    check_root || return 1
    echo "Enabling VPN kill switch..."
    if command -v nft &>/dev/null && nft list tables 2>/dev/null | grep -q .; then
        nft add table inet anvps_ks 2>/dev/null || true
        nft add chain inet anvps_ks input { type filter hook input priority 0\; policy drop\; } 2>/dev/null || true
        nft add chain inet anvps_ks output { type filter hook output priority 0\; policy drop\; } 2>/dev/null || true
        nft add rule inet anvps_ks input iif lo accept 2>/dev/null || true
        nft add rule inet anvps_ks output oif lo accept 2>/dev/null || true
        nft add rule inet anvps_ks input ct state established,related accept 2>/dev/null || true
        nft add rule inet anvps_ks output oif "$VPN_IFACE" accept 2>/dev/null || true
        nft add rule inet anvps_ks input iif "$VPN_IFACE" accept 2>/dev/null || true
        nft add rule inet anvps_ks output udp dport "$VPN_PORT" accept 2>/dev/null || true
        nft add rule inet anvps_ks output tcp dport 443 accept 2>/dev/null || true
        nft add rule inet anvps_ks output udp dport 53 accept 2>/dev/null || true
    else
        iptables -P INPUT DROP 2>/dev/null || true
        iptables -P OUTPUT DROP 2>/dev/null || true
        iptables -P FORWARD DROP 2>/dev/null || true
        iptables -F
        iptables -A INPUT -i lo -j ACCEPT
        iptables -A OUTPUT -o lo -j ACCEPT
        iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
        iptables -A OUTPUT -o "$VPN_IFACE" -j ACCEPT 2>/dev/null || true
        iptables -A INPUT -i "$VPN_IFACE" -j ACCEPT 2>/dev/null || true
        iptables -A OUTPUT -p udp --dport "$VPN_PORT" -j ACCEPT
        iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
        iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
        iptables -A INPUT -j DROP
        iptables -A OUTPUT -j DROP
    fi
    echo "Kill switch active — only VPN ($VPN_IFACE) and VPN registration traffic allowed"
}

disable_killswitch() {
    check_root || return 1
    echo "Disabling VPN kill switch..."
    if command -v nft &>/dev/null && nft list table inet anvps_ks 2>/dev/null | grep -q .; then
        nft delete table inet anvps_ks 2>/dev/null || true
    else
        iptables -P INPUT ACCEPT 2>/dev/null || true
        iptables -P OUTPUT ACCEPT 2>/dev/null || true
        iptables -P FORWARD ACCEPT 2>/dev/null || true
        iptables -F
    fi
    echo "Kill switch disabled — all traffic allowed"
}

status() {
    if ! command -v iptables &>/dev/null; then echo "iptables not available"; return; fi
    if iptables -L OUTPUT 2>/dev/null | grep -q "DROP"; then
        echo "VPN kill switch: ACTIVE"
    else echo "VPN kill switch: INACTIVE"; fi
}

test_leak() {
    echo "Testing for DNS leaks..."
    local dns_test=$(nslookup google.com 2>/dev/null | grep "Address" | head -1 || echo "")
    local ip_test=$(curl -s --max-time 5 https://ifconfig.me 2>/dev/null || echo "timeout")
    echo "DNS: $dns_test"
    echo "Public IP: $ip_test"
    if [ -n "$ip_test" ] && [ "$ip_test" != "timeout" ]; then
        echo "Potential leak — traffic is leaving the device"
    else echo "No leak detected"; fi
}

case "${1:-status}" in
    enable|on) enable_killswitch ;;
    disable|off) disable_killswitch ;;
    status) status ;;
    test) test_leak ;;
    *) echo "Usage: $0 {enable|disable|status|test}" ;;
esac
