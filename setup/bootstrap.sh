#!/usr/bin/env bash
set -euo pipefail

ANVPS_DIR="${HOME}/.anvps"
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[x]${NC} $1"; }

ensure_termux() {
    if [ -z "${TERMUX_VERSION:-}" ]; then
        err "This bootstrap is for Termux only"
        exit 1
    fi
}

setup_storage() {
    log "Setting up storage access..."
    termux-setup-storage 2>/dev/null || true
    sleep 1
    if [ -d "${HOME}/storage" ]; then
        log "Storage access granted"
    else
        warn "Storage permission not granted — run 'termux-setup-storage' manually"
    fi
}

install_termux_packages() {
    log "Installing Termux essential packages..."
    local packages=(
        bash bash-completion
        curl wget
        git
        python
        openssh
        nmap
        cronie termux-services
        proot-distro
        termux-tools
        termux-auth
        nano vim
        htop
        tmux
        screen
        rsync
        sqlite
        openssl-tool
        resolv-conf
        procps iproute2 net-tools coreutils util-linux
    )

    pkg update -y
    for pkg in "${packages[@]}"; do
        if ! pkg list-installed 2>/dev/null | grep -qi "^${pkg} "; then
            log "Installing $pkg..."
            pkg install -y "$pkg" 2>/dev/null || warn "Failed to install $pkg"
        else
            info "$pkg already installed"
        fi
    done
    log "Termux packages installed"
}

setup_proot_distro() {
    log "Setting up Proot Linux distribution..."
    if proot-distro list 2>/dev/null | grep -qi "ubuntu"; then
        log "Proot Ubuntu already installed"
        return
    fi
    proot-distro install ubuntu
    log "Proot Ubuntu installed"
    cat > "${ANVPS_DIR}/etc/proot.sh" << 'PROOT'
#!/data/data/com.termux/files/usr/bin/bash
exec proot-distro login ubuntu
PROOT
    chmod +x "${ANVPS_DIR}/etc/proot.sh"
}

setup_termux_keys() {
    log "Generating SSH keys..."
    if [ ! -f "${HOME}/.ssh/id_ed25519" ]; then
        ssh-keygen -t ed25519 -f "${HOME}/.ssh/id_ed25519" -N "" -C "anvps@termux"
    fi
    if [ ! -f "${HOME}/.ssh/authorized_keys" ]; then
        cp "${HOME}/.ssh/id_ed25519.pub" "${HOME}/.ssh/authorized_keys"
    fi
    chmod 700 "${HOME}/.ssh"
    chmod 600 "${HOME}/.ssh/authorized_keys"
    log "SSH keys ready"
}

configure_termux() {
    log "Configuring Termux..."
    cat >> "${HOME}/.bashrc" << 'BASHRC'
export ANVPS_DIR="${HOME}/.anvps"
export PATH="${ANVPS_DIR}/src/cli:${PATH}"
alias anvps="bash ${ANVPS_DIR}/src/cli/anvps"
BASHRC
    log "Termux configured"
}

setup_cron() {
    log "Setting up cron service..."
    if command -v crond &>/dev/null; then
        crond 2>/dev/null || true
        log "Cron started"
    fi
}

main() {
    echo "  AnVPS Termux Bootstrap"
    echo "  ======================"
    ensure_termux
    setup_storage
    install_termux_packages
    setup_proot_distro
    setup_termux_keys
    configure_termux
    setup_cron
    echo ""
    log "Termux bootstrap complete!"
    echo "  Run 'anvps help' to get started"
}

main "$@"
