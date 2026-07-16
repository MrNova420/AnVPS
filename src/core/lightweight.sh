#!/usr/bin/env bash
set -euo pipefail
# Lightweight mode controller — auto-selects minimal components based on RAM

ANVPS_DIR="${HOME}/.anvps"

detect_ram_tier() {
    local mem_total=0
    if [ -f /proc/meminfo ]; then
        mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    fi
    mem_total=${mem_total:-0}

    if [ "$mem_total" -eq 0 ]; then
        echo "unknown"
    elif [ "$mem_total" -lt 65536 ]; then
        echo "shadow"
    elif [ "$mem_total" -lt 262144 ]; then
        echo "lite"
    elif [ "$mem_total" -lt 524288 ]; then
        echo "standard"
    else
        echo "full"
    fi
}

tier_name() {
    case "${1:-}" in
        shadow)   echo "Shadow (32MB ultra-light)" ;;
        lite)     echo "Lite (64MB minimal)" ;;
        standard) echo "Standard (128MB balanced)" ;;
        full)     echo "Full (512MB+ everything)" ;;
        *)        echo "Unknown" ;;
    esac
}

select_ssh() {
    local tier="$1"
    case "$tier" in
        shadow|lite) echo "dropbear" ;;
        *)           echo "openssh" ;;
    esac
}

select_httpd() {
    local tier="$1"
    case "$tier" in
        shadow)   echo "shell" ;;
        lite)     echo "busybox" ;;
        standard) echo "busybox" ;;
        full)     echo "python" ;;
    esac
}

select_bots() {
    local tier="$1"
    case "$tier" in
        shadow|lite) echo "shell" ;;
        *)           echo "python" ;;
    esac
}

select_monitoring() {
    local tier="$1"
    case "$tier" in
        shadow)   echo "minimal" ;;
        lite)     echo "basic" ;;
        standard) echo "standard" ;;
        full)     echo "full" ;;
    esac
}

recommend_profile() {
    local tier="$1"
    case "$tier" in
        shadow)   echo "shadow" ;;
        lite)     echo "minimal" ;;
        standard) echo "webhost" ;;
        full)     echo "full" ;;
    esac
}

print_recommendations() {
    local tier=$(detect_ram_tier)
    echo ""
    echo "  Lightweight Auto-Detection"
    echo "  $(printf '%0.s-' {1..40})"
    echo ""
    echo "  Detected RAM tier: $(tier_name "$tier")"
    echo "  Recommended SSH:   $(select_ssh "$tier")"
    echo "  Recommended HTTPD: $(select_httpd "$tier")"
    echo "  Recommended Bots:  $(select_bots "$tier")"
    echo "  Recommended Profile: $(recommend_profile "$tier")"
    echo ""
    echo "  Set with: anvps config set ANVPS_TIER $tier"
}

case "${1:-detect}" in
    detect)
        local t=$(detect_ram_tier)
        echo "$t"
        ;;
    tier)
        local t=$(detect_ram_tier)
        tier_name "$t"
        ;;
    recommend)
        local t=$(detect_ram_tier)
        echo "$(recommend_profile "$t")"
        ;;
    info)
        print_recommendations
        ;;
    select-ssh)
        select_ssh "$(detect_ram_tier)"
        ;;
    select-httpd)
        select_httpd "$(detect_ram_tier)"
        ;;
    *)
        echo "Usage: $0 {detect|tier|recommend|info|select-ssh|select-httpd}"
        ;;
esac
