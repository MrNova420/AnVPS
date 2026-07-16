#!/usr/bin/env bash
set -euo pipefail

ANVPS_DIR="${HOME}/.anvps"
LOG_DIR="${ANVPS_DIR}/logs"
CONFIG="${ANVPS_DIR}/etc/anvps.conf"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${GREEN}[security]${NC} $1"; }
warn() { echo -e "${YELLOW}[security]${NC} $1"; }
err()  { echo -e "${RED}[security]${NC} $1"; }

detect_root() {
    [ "$(id -u)" = "0" ] && return 0 || return 1
}

cmd_status() {
    echo ""
    echo "  Security Status"
    echo "  $(printf '%0.s-' {1..40})"
    echo ""
    echo "  Root:         $(detect_root && echo YES || echo NO)"

    if [ -f "${ANVPS_DIR}/etc/ssh.port" ]; then
        local ssh_port=$(cat "${ANVPS_DIR}/etc/ssh.port")
        echo "  SSH Port:     $ssh_port"
    fi

    if detect_root; then
        echo "  Firewall:     $(command -v iptables &>/dev/null && iptables -L INPUT 2>/dev/null | head -1 || echo 'not available')"
    else
        echo "  Firewall:     unavailable (no root)"
    fi

    echo "  Last Scan:    $(date -r "${LOG_DIR}/security_scan.log" 2>/dev/null || echo 'never')"
    echo ""
}

cmd_scan() {
    log "Running security scan..."
    local report="${LOG_DIR}/security_scan.log"
    {
        echo "=== Security Scan: $(date '+%Y-%m-%d %H:%M:%S') ==="
    } > "$report"

    local issues=0

    check_ssh_config() {
        local ssh_cfg
        if [ -d "/data/data/com.termux" ]; then
            ssh_cfg="${HOME}/../usr/etc/ssh/sshd_config"
        else
            ssh_cfg="/etc/ssh/sshd_config"
        fi
        if [ -f "$ssh_cfg" ]; then
            if grep -q "^PermitRootLogin yes" "$ssh_cfg" 2>/dev/null; then
                echo "WARN: Root login enabled via SSH" >> "$report"
                issues=$((issues + 1))
            fi
            if ! grep -q "^PasswordAuthentication no" "$ssh_cfg" 2>/dev/null; then
                echo "WARN: Password authentication enabled" >> "$report"
                issues=$((issues + 1))
            fi
            local port=$(grep "^Port " "$ssh_cfg" 2>/dev/null | awk '{print $2}')
            if [ "$port" = "22" ]; then
                echo "INFO: SSH on default port 22 — consider changing" >> "$report"
            fi
        else
            echo "INFO: No SSH config found" >> "$report"
        fi
    }

    check_open_ports() {
        local risky_ports=(23 21 110 143 445 554 3306 3389 5900)
        for port in "${risky_ports[@]}"; do
            if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
                echo "WARN: Risky port open: $port" >> "$report"
                issues=$((issues + 1))
            fi
        done
    }

    check_permissions() {
        local issues_found=0
        for dir in "${ANVPS_DIR}/etc" "${ANVPS_DIR}/data/ssh"; do
            if [ -d "$dir" ]; then
                local perms=$(stat -c "%a" "$dir" 2>/dev/null)
                if [ "$perms" != "700" ] && [ "$perms" != "750" ]; then
                    echo "WARN: Permissions on $dir: $perms" >> "$report"
                    issues=$((issues + 1))
                fi
            fi
        done
    }

    check_updates() {
        if command -v apt &>/dev/null; then
            local updates=$(apt list --upgradable 2>/dev/null | wc -l)
            if [ "$updates" -gt 1 ]; then
                echo "INFO: $((updates - 1)) package updates available" >> "$report"
            fi
        fi
    }

    check_failed_logins() {
        local log_file
        if [ -f "/var/log/auth.log" ]; then
            log_file="/var/log/auth.log"
        elif [ -f "${LOG_DIR}/ssh.log" ]; then
            log_file="${LOG_DIR}/ssh.log"
        fi
        if [ -n "${log_file:-}" ] && [ -f "$log_file" ]; then
            local failed=$(grep -c "Failed password" "$log_file" 2>/dev/null || echo 0)
            if [ "$failed" -gt 10 ]; then
                echo "WARN: $failed failed SSH login attempts" >> "$report"
                issues=$((issues + 1))
            fi
        fi
    }

    check_ssh_config
    check_open_ports
    check_permissions
    check_updates
    check_failed_logins

    {
        echo "---"
        echo "Issues found: $issues"
        echo "Scan completed: $(date '+%Y-%m-%d %H:%M:%S')"
    } >> "$report"

    cat "$report"

    if [ "$issues" -gt 0 ]; then
        warn "$issues security issue(s) found — review $report"
    else
        log "No security issues found"
    fi
}

cmd_harden() {
    log "Applying security hardening..."
    local changes=0

    fix_ssh_config() {
        local ssh_cfg
        if [ -d "/data/data/com.termux" ]; then
            ssh_cfg="${HOME}/../usr/etc/ssh/sshd_config"
        else
            ssh_cfg="/etc/ssh/sshd_config"
        fi
        if [ -f "$ssh_cfg" ]; then
            sed -i 's/^PermitRootLogin yes/PermitRootLogin prohibit-password/' "$ssh_cfg" 2>/dev/null || true
            sed -i 's/^#PermitRootLogin yes/PermitRootLogin prohibit-password/' "$ssh_cfg" 2>/dev/null || true
            sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' "$ssh_cfg" 2>/dev/null || true
            if ! grep -q "^MaxAuthTries" "$ssh_cfg" 2>/dev/null; then
                echo "MaxAuthTries 3" >> "$ssh_cfg"
            fi
            if ! grep -q "^ClientAliveInterval" "$ssh_cfg" 2>/dev/null; then
                echo "ClientAliveInterval 300" >> "$ssh_cfg"
                echo "ClientAliveCountMax 2" >> "$ssh_cfg"
            fi
            changes=$((changes + 1))
            log "SSH hardened"
        fi
    }

    fix_permissions() {
        chmod 700 "${ANVPS_DIR}/etc" 2>/dev/null || true
        chmod 700 "${ANVPS_DIR}/data/ssh" 2>/dev/null || true
        chmod 600 "${ANVPS_DIR}/etc/anvps.conf" 2>/dev/null || true
        changes=$((changes + 1))
    }

    fix_firewall() {
        if detect_root && command -v iptables &>/dev/null; then
            iptables -P INPUT DROP 2>/dev/null || true
            iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
            iptables -A INPUT -i lo -j ACCEPT 2>/dev/null || true
            local ssh_port=$(cat "${ANVPS_DIR}/etc/ssh.port" 2>/dev/null || echo "7022")
            iptables -A INPUT -p tcp --dport "$ssh_port" -j ACCEPT 2>/dev/null || true
            iptables -A INPUT -p tcp --dport 7080 -j ACCEPT 2>/dev/null || true
            iptables -A INPUT -p tcp --dport 7443 -j ACCEPT 2>/dev/null || true
            iptables -A INPUT -p tcp --dport 7444 -j ACCEPT 2>/dev/null || true
            changes=$((changes + 1))
            log "Firewall rules applied"
        fi
    }

    fix_ssh_config
    fix_permissions
    fix_firewall

    log "Hardening complete ($changes changes applied)"
}

case "${1:-status}" in
    status) cmd_status ;;
    scan)   cmd_scan ;;
    harden) cmd_harden ;;
    *) echo "Usage: $0 {status|scan|harden}" ;;
esac
