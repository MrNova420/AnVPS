#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" != "0" ] && { echo "Root required"; exit 1; }

ANVPS_DIR="${HOME}/.anvps"
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[x]${NC} $1"; }

BACKUP_DIR="${ANVPS_DIR}/backup"

detect_android() {
    if [ -f "/system/build.prop" ]; then
        log "Android system detected"
        ANDROID_SDK=$(getprop ro.build.version.sdk 2>/dev/null || echo "unknown")
        ANDROID_RELEASE=$(getprop ro.build.version.release 2>/dev/null || echo "unknown")
        log "Android API: $ANDROID_SDK, Version: $ANDROID_RELEASE"
        return 0
    fi
    warn "Not running on Android — skipping device-specific optimizations"
    return 1
}

optimize_kernel() {
    log "Optimizing kernel parameters..."
    local sysctl_conf="/etc/sysctl.d/99-anvps.conf"
    mkdir -p /etc/sysctl.d
    cat > "$sysctl_conf" << 'SYSCTL'
net.core.somaxconn = 1024
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_keepalive_time = 1200
vm.swappiness = 10
vm.vfs_cache_pressure = 50
kernel.numa_balancing = 0
SYSCTL
    sysctl -p "$sysctl_conf" 2>/dev/null || true
    log "Kernel parameters optimized"
}

setup_iptables() {
    log "Setting up iptables rules..."
    iptables -P INPUT ACCEPT 2>/dev/null || true
    iptables -P FORWARD ACCEPT 2>/dev/null || true
    iptables -P OUTPUT ACCEPT 2>/dev/null || true
    iptables -F 2>/dev/null || true
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -p tcp --dport 7022 -j ACCEPT
    iptables -A INPUT -p tcp --dport 7080 -j ACCEPT
    iptables -A INPUT -p tcp --dport 7443 -j ACCEPT
    iptables -A INPUT -j DROP 2>/dev/null || true
    log "iptables rules applied"
}

setup_real_docker() {
    log "Setting up Docker..."
    if command -v docker &>/dev/null; then
        log "Docker already installed"
        return
    fi
    if [ -f "/system/build.prop" ]; then
        log "Installing Docker for Android..."
        local docker_url="https://github.com/nicholasgasior/docker-android/releases/latest/download/docker-android.tar.gz"
        local tmp_dir="/tmp/docker-android"
        mkdir -p "$tmp_dir"
        curl -L "$docker_url" -o "${tmp_dir}/docker.tar.gz" 2>/dev/null || {
            warn "Docker binary download failed — install manually"
            return
        }
        tar xzf "${tmp_dir}/docker.tar.gz" -C "$tmp_dir"
        cp "${tmp_dir}/docker"/* /usr/local/bin/ 2>/dev/null || true
        chmod +x /usr/local/bin/docker* 2>/dev/null || true
        rm -rf "$tmp_dir"
        log "Docker binaries installed"
    else
        warn "Not on Android — skipping Docker-Android install"
    fi
}

setup_chroot_environment() {
    log "Setting up chroot environment..."
    local chroot_dir="${ANVPS_DIR}/data/chroot"
    mkdir -p "$chroot_dir"
    mkdir -p "$chroot_dir"/{proc,sys,dev,etc,home,tmp,var/log}
    mount --bind /proc "$chroot_dir/proc" 2>/dev/null || true
    mount --bind /sys "$chroot_dir/sys" 2>/dev/null || true
    mount --bind /dev "$chroot_dir/dev" 2>/dev/null || true
    log "Chroot environment prepared at $chroot_dir"
}

enable_power_management() {
    log "Configuring power management..."
    echo "2" > /sys/class/misc/performance/cpu_boost/enable 2>/dev/null || true
    echo "performance" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || true
    log "Power management optimized"
}

setup_systemd_service() {
    if ! command -v systemctl &>/dev/null; then
        return
    fi
    log "Installing systemd service..."
    cat > /etc/systemd/system/anvps-core.service << 'SVC'
[Unit]
Description=AnVPS Core Service
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${HOME}/.anvps/src/core/supervisor.sh start
ExecStop=${HOME}/.anvps/src/core/supervisor.sh stop
ExecReload=${HOME}/.anvps/src/core/supervisor.sh reload
Restart=always
RestartSec=5
Nice=-10
IOSchedulingClass=realtime
IOSchedulingPriority=0

[Install]
WantedBy=multi-user.target
SVC
    systemctl daemon-reload
    systemctl enable anvps-core.service 2>/dev/null || true
    log "Systemd service installed"
}

create_admin_user() {
    if ! $HAS_ROOT; then return; fi
    if id "anvps" &>/dev/null; then
        log "Admin user 'anvps' exists"
        return
    fi
    useradd -m -s /bin/bash -d "${ANVPS_DIR}" anvps 2>/dev/null || true
    echo "anvps:$(openssl rand -base64 12)" | chpasswd 2>/dev/null || true
    usermod -aG docker anvps 2>/dev/null || true
    log "Admin user created"
}

main() {
    echo ""
    echo "  AnVPS Root Features Enabler"
    echo "  ==========================="
    echo ""

    detect_android || true
    optimize_kernel
    setup_iptables
    create_admin_user
    setup_real_docker
    setup_chroot_environment
    enable_power_management
    setup_systemd_service

    echo ""
    log "Root features enabled successfully!"
    echo "  Reboot recommended for full effect"
}

main "$@"
