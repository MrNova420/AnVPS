#!/usr/bin/env bash
set -euo pipefail

ANVPS_DIR="${HOME}/.anvps"
ANVPS_REPO="https://github.com/MrNova420/AnVPS"
ANVPS_BRANCH="master"
ANVPS_VERSION="1.0.0"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[x]${NC} $1"; }
info() { echo -e "${CYAN}[i]${NC} $1"; }

[ -t 0 ] && INTERACTIVE=true || INTERACTIVE=false

detect_environment() {
    info "Detecting environment..."
    if [ -n "${TERMUX_VERSION:-}" ]; then
        ENV_TYPE="termux"
        PKG_MGR="pkg"
        log "Termux environment detected"
    elif command -v apt &>/dev/null; then
        ENV_TYPE="linux"
        PKG_MGR="apt"
        log "Linux (Debian/Ubuntu) environment detected"
    elif command -v apk &>/dev/null; then
        ENV_TYPE="linux"
        PKG_MGR="apk"
        log "Linux (Alpine) environment detected"
    else
        ENV_TYPE="unknown"
        PKG_MGR="unknown"
        warn "Unknown environment — proceeding with best effort"
    fi

    ARCH=$(uname -m)
    case "$ARCH" in
        aarch64|arm64) ARCH_ALIAS="arm64" ;;
        armv7l|armhf)  ARCH_ALIAS="arm" ;;
        x86_64|amd64)  ARCH_ALIAS="amd64" ;;
        i686|i386)     ARCH_ALIAS="386" ;;
        *)             ARCH_ALIAS="$ARCH" ;;
    esac
    log "Architecture: $ARCH ($ARCH_ALIAS)"

    if [ "$(id -u)" = "0" ]; then
        HAS_ROOT=true
        log "Root access available"
    else
        HAS_ROOT=false
        if [ "$ENV_TYPE" = "termux" ]; then
            log "Termux — no root needed"
        else
            warn "No root access — some features limited"
        fi
    fi

    TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
    TOTAL_RAM_MB=$((TOTAL_RAM_KB / 1024))
    if [ "$TOTAL_RAM_KB" -lt 65536 ]; then
        TIER="shadow"
        log "RAM: ${TOTAL_RAM_MB}MB — Shadow tier (32MB ultra-light mode)"
    elif [ "$TOTAL_RAM_KB" -lt 262144 ]; then
        TIER="lite"
        log "RAM: ${TOTAL_RAM_MB}MB — Lite tier (minimal mode)"
    elif [ "$TOTAL_RAM_KB" -lt 524288 ]; then
        TIER="standard"
        log "RAM: ${TOTAL_RAM_MB}MB — Standard tier (balanced mode)"
    else
        TIER="full"
        log "RAM: ${TOTAL_RAM_MB}MB — Full tier (everything enabled)"
    fi
}

install_dependencies() {
    log "Installing base dependencies (tier: $TIER)..."
    local base_pkgs="curl wget git"
    local ssh_pkg="openssh"
    local extra=""

    [ "$TIER" = "shadow" ] && ssh_pkg="dropbear"
    [ "$TIER" != "shadow" ] && extra="$extra python3 python3-pip supervisor"

    case "$PKG_MGR" in
        pkg)
            pkg update -y 2>/dev/null || true
            pkg install -y $base_pkgs $ssh_pkg cronie termux-services termux-tools proot-distro sqlite $extra 2>/dev/null || true
            if [ "$TIER" = "shadow" ]; then pkg install -y busybox dropbear 2>/dev/null || true; fi
            ;;
        apt)
            apt update -y 2>/dev/null || true
            apt install -y $base_pkgs $ssh_pkg cron $extra ufw sqlite3 2>/dev/null || true
            if [ "$TIER" = "shadow" ]; then apt install -y busybox dropbear 2>/dev/null || true; fi
            ;;
        apk)
            apk update 2>/dev/null || true
            apk add $base_pkgs $ssh_pkg dcron $extra sqlite 2>/dev/null || true
            if [ "$TIER" = "shadow" ]; then apk add busybox dropbear 2>/dev/null || true; fi
            ;;
    esac
    log "Base dependencies installed ($TIER mode)"
}

setup_directory_structure() {
    log "Setting up directory structure..."
    mkdir -p "${ANVPS_DIR}"/{etc,data,logs,services,backup,tmp,ssl,tunnels}
    mkdir -p "${ANVPS_DIR}/etc/profiles"
    mkdir -p "${ANVPS_DIR}/data"/{databases,sites,containers}
    log "Directory structure created at $ANVPS_DIR"
}

deploy_self() {
    log "Deploying AnVPS files..."
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    ANVPS_SRC="${ANVPS_DIR}/src"
    mkdir -p "$ANVPS_SRC"

    if [ -d "$SCRIPT_DIR/../src" ]; then
        cp -r "$SCRIPT_DIR/../src/"* "$ANVPS_SRC/"
        cp -r "$SCRIPT_DIR/../config/"* "${ANVPS_DIR}/etc/" 2>/dev/null || true
        log "Deployed from local source"
    else
        warn "No local source — installing from repo is not yet implemented in standalone mode"
        mkdir -p "$ANVPS_SRC/cli/commands"
        mkdir -p "$ANVPS_SRC/core"
    fi

    chmod +x "${ANVPS_SRC}/cli/anvps" 2>/dev/null || true

    if [ ! -f "${ANVPS_DIR}/etc/anvps.conf" ]; then
        cat > "${ANVPS_DIR}/etc/anvps.conf" << CONFEOF
# AnVPS — Main Configuration
ANVPS_VERSION="1.0.0"
ANVPS_TIER="$TIER"
ANVPS_DIR="\${HOME}/.anvps"
ANVPS_HOSTNAME="anvps-device"
ANVPS_SSH_TYPE="$([ "$TIER" = "shadow" ] && echo "dropbear" || echo "auto")"
ANVPS_HTTPD_TYPE="$([ "$TIER" = "shadow" ] && echo "shell" || echo "auto")"
ANVPS_BOT_TYPE="$([ "$TIER" = "shadow" ] && echo "shell" || echo "auto")"
ANVPS_MONITORING="$([ "$TIER" = "shadow" ] && echo "minimal" || echo "auto")"
ANVPS_PORT_BASE=7000
ANVPS_SSH_PORT=7022
ANVPS_WEB_PORT=7080
ANVPS_HTTPS_PORT=7443
ANVPS_AUTO_UPDATE=true
ANVPS_AUTO_BACKUP=$([ "$TIER" = "shadow" ] && echo "false" || echo "true")
ANVPS_BACKUP_INTERVAL="weekly"
ANVPS_LOG_LEVEL="$([ "$TIER" = "shadow" ] && echo "error" || echo "info")"
ANVPS_LOG_RETENTION_DAYS=$([ "$TIER" = "shadow" ] && echo "3" || echo "30")
ANVPS_WATCHDOG=true
ANVPS_STEALTH=$([ "$TIER" = "shadow" ] && echo "true" || echo "false")
ANVPS_OBFUSCATE=$([ "$TIER" = "shadow" ] && echo "true" || echo "false")
ANVPS_TAMPER_DETECTION=true
ANVPS_TAMPER_MAX_FAILED=$([ "$TIER" = "shadow" ] && echo "5" || echo "10")
CONFEOF
    fi

    ln -sf "${ANVPS_SRC}/cli/anvps" "${ANVPS_DIR}/anvps" 2>/dev/null || true

    if [ -d "/data/data/com.termux/files/usr/bin" ]; then
        ln -sf "${ANVPS_SRC}/cli/anvps" "/data/data/com.termux/files/usr/bin/anvps" 2>/dev/null || true
    elif [ -d "/usr/local/bin" ]; then
        ln -sf "${ANVPS_SRC}/cli/anvps" "/usr/local/bin/anvps" 2>/dev/null || true
    fi
}

setup_boot_autostart() {
    log "Setting up auto-start..."
    if [ "$ENV_TYPE" = "termux" ]; then
        BOOT_DIR="${HOME}/.termux/boot"
        mkdir -p "$BOOT_DIR"
        cat > "$BOOT_DIR/anvps-start" << 'BOOT'
#!/data/data/com.termux/files/usr/bin/bash
exec ~/.anvps/src/core/supervisor.sh start
BOOT
        chmod +x "$BOOT_DIR/anvps-start"
        log "Termux boot script installed"
    elif command -v systemctl &>/dev/null && $HAS_ROOT; then
        cat > /etc/systemd/system/anvps.service << 'SVC'
[Unit]
Description=AnVPS - Android VPS
After=network.target

[Service]
Type=simple
ExecStart=%h/.anvps/src/core/supervisor.sh start
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SVC
        systemctl daemon-reload
        systemctl enable anvps.service 2>/dev/null || true
        log "Systemd service installed"
    else
        warn "Auto-start not configured — use supervisor manually"
    fi
}

enable_root_features() {
    if ! $HAS_ROOT; then
        warn "No root — skipping root-specific optimizations"
        return
    fi
    log "Enabling root-specific optimizations..."
    if command -v iptables &>/dev/null; then
        iptables -P INPUT ACCEPT 2>/dev/null || true
        iptables -P FORWARD ACCEPT 2>/dev/null || true
        log "Firewall base rules set"
    fi
    echo "anvps-device" > /etc/hostname 2>/dev/null || true
    log "Root features enabled"
}

run_post_install() {
    log "Running post-install setup..."
    if [ "$ENV_TYPE" = "termux" ]; then
        cat > "${ANVPS_DIR}/etc/profile" << 'PROF'
export ANVPS_DIR="${HOME}/.anvps"
export PATH="${ANVPS_DIR}/src/cli:${PATH}"
PROF
        if ! grep -q "anvps" "${HOME}/.bashrc" 2>/dev/null; then
            echo "source ${ANVPS_DIR}/etc/profile" >> "${HOME}/.bashrc"
        fi
    fi

    log "AnVPS initialized for first use"
    if [ -f "${ANVPS_DIR}/src/cli/anvps" ]; then
        bash "${ANVPS_DIR}/src/cli/anvps" service setup 2>&1 || true
    fi
}

run_health_check() {
    log "Running initial health check..."
    if [ -f "${ANVPS_DIR}/src/core/healthcheck.sh" ]; then
        bash "${ANVPS_DIR}/src/core/healthcheck.sh" || true
    fi
}

print_summary() {
    local tier_name=""
    case "$TIER" in
        shadow)   tier_name="Shadow (32MB ultra-light)" ;;
        lite)     tier_name="Lite (64MB minimal)" ;;
        standard) tier_name="Standard (128MB balanced)" ;;
        full)     tier_name="Full (512MB+ everything)" ;;
        *)        tier_name="$TIER" ;;
    esac
    echo ""
    echo "============================================"
    echo "  AnVPS v${ANVPS_VERSION} — Installation Complete"
    echo "============================================"
    echo "  Environment: ${ENV_TYPE}"
    echo "  Root:        ${HAS_ROOT}"
    echo "  Architecture: ${ARCH} (${ARCH_ALIAS})"
    echo "  RAM:         ${TOTAL_RAM_MB}MB (${tier_name})"
    echo "  Directory:   ${ANVPS_DIR}"
    echo "  SSH Port:    7022"
    echo "  Web UI:      http://localhost:7080"
    echo ""
    echo "  Quick start:"
    echo "    anvps status        — View system status"
    echo "    anvps service list  — List all services"
    echo "    anvps monitor       — Open monitoring"
    echo "    anvps security      — Security tools"
    echo "    anvps stealth on    — Enable stealth mode"
    echo "    anvps obfuscate all — Mask device identity"
    echo ""
    echo "  Run 'anvps help' for all commands"
    echo "============================================"
}

main() {
    echo ""
    echo "  █████╗ ███╗   ██╗██╗   ██╗██████╗ ███████╗"
    echo "  ██╔══██╗████╗  ██║██║   ██║██╔══██╗██╔════╝"
    echo "  ███████║██╔██╗ ██║██║   ██║██████╔╝███████╗"
    echo "  ██╔══██║██║╚██╗██║╚██╗ ██╔╝██╔═══╝ ╚════██║"
    echo "  ██║  ██║██║ ╚████║ ╚████╔╝ ██║     ███████║"
    echo "  ╚═╝  ╚═╝╚═╝  ╚═══╝  ╚═══╝  ╚═╝     ╚══════╝"
    echo "  Android VPS — Auto-Managed Server Platform"
    echo ""

    detect_environment
    install_dependencies
    setup_directory_structure
    deploy_self
    enable_root_features
    setup_boot_autostart
    run_post_install
    run_health_check
    print_summary
}

main "$@"
