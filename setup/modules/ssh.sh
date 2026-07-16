#!/usr/bin/env bash
install_ssh() {
    local ENV_TYPE="$1"
    local ANVPS_DIR="${2:-${HOME}/.anvps}"
    local SSH_PORT="${3:-7022}"

    log "Installing SSH server..."

    case "$ENV_TYPE" in
        termux)
            pkg install -y openssh 2>/dev/null || true
            SSH_CONFIG="${HOME}/../usr/etc/ssh/sshd_config"
            if [ -f "$SSH_CONFIG" ]; then
                sed -i "s/^#Port 22/Port $SSH_PORT/" "$SSH_CONFIG"
                sed -i "s/^Port 22/Port $SSH_PORT/" "$SSH_CONFIG"
                sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' "$SSH_CONFIG"
                sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' "$SSH_CONFIG"
                sed -i 's/^#PermitRootLogin yes/PermitRootLogin no/' "$SSH_CONFIG"
                echo "AllowUsers ${USER}" >> "$SSH_CONFIG"
            fi
            ;;
        linux)
            if command -v apt &>/dev/null; then
                apt install -y openssh-server 2>/dev/null || true
            elif command -v apk &>/dev/null; then
                setup-apk add openssh 2>/dev/null || true
            fi
            sed -i "s/^#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
            sed -i "s/^Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
            ;;
    esac

    mkdir -p "${ANVPS_DIR}/data/ssh"
    local host_key="${ANVPS_DIR}/data/ssh/ssh_host_ed25519_key"
    if [ ! -f "$host_key" ]; then
        ssh-keygen -t ed25519 -f "$host_key" -N "" 2>/dev/null || true
    fi

    if command -v sshd &>/dev/null; then
        sshd -t 2>/dev/null && {
            sshd 2>/dev/null || true
            log "SSH server started on port $SSH_PORT"
        } || warn "SSH config has errors"
    fi

    echo "$SSH_PORT" > "${ANVPS_DIR}/etc/ssh.port"
    log "SSH installation complete (port: $SSH_PORT)"
}
