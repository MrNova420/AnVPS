#!/usr/bin/env bash
install_docker_module() {
    local ENV_TYPE="$1"
    local ANVPS_DIR="${2:-${HOME}/.anvps}"
    local HAS_ROOT="${3:-false}"

    log "Installing container support..."

    if $HAS_ROOT; then
        if command -v docker &>/dev/null; then
            log "Docker already installed"
            return
        fi
        log "Attempting Docker installation..."
        local tmp_dir="/tmp/docker-install"
        mkdir -p "$tmp_dir"
        case "$(uname -m)" in
            aarch64|arm64)
                local docker_url="https://github.com/nicholasgasior/docker-android/releases/latest/download/docker-aarch64.tar.gz"
                ;;
            armv7l|armhf)
                local docker_url="https://github.com/nicholasgasior/docker-android/releases/latest/download/docker-armv7l.tar.gz"
                ;;
            x86_64|amd64)
                local docker_url="https://github.com/nicholasgasior/docker-android/releases/latest/download/docker-x86_64.tar.gz"
                ;;
        esac
        if [ -n "${docker_url:-}" ]; then
            curl -L "$docker_url" -o "${tmp_dir}/docker.tar.gz" 2>/dev/null && {
                tar xzf "${tmp_dir}/docker.tar.gz" -C "$tmp_dir" 2>/dev/null || true
                if [ -d "${tmp_dir}/docker" ]; then
                    cp "${tmp_dir}/docker"/* /usr/local/bin/ 2>/dev/null || true
                    chmod +x /usr/local/bin/docker* 2>/dev/null || true
                    dockerd &>/dev/null &
                    sleep 3
                    log "Docker installed and started"
                fi
            } || warn "Docker download failed — install manually"
        fi
        rm -rf "$tmp_dir"
    else
        log "No root — installing proot-based container support..."
        case "$ENV_TYPE" in
            termux)
                if command -v proot-distro &>/dev/null; then
                    proot-distro install ubuntu 2>/dev/null || true
                    log "Proot Ubuntu container ready"
                    cat > "${ANVPS_DIR}/src/core/container.sh" << 'CTR'
#!/data/data/com.termux/files/usr/bin/bash
exec proot-distro login ubuntu "$@"
CTR
                    chmod +x "${ANVPS_DIR}/src/core/container.sh"
                fi
                ;;
            linux)
                if command -v apt &>/dev/null; then
                    apt install -y podman 2>/dev/null && log "Podman installed" || {
                        warn "No container runtime available — use Python virtualenvs instead"
                    }
                elif command -v apk &>/dev/null; then
                    apk add podman 2>/dev/null && log "Podman installed" || true
                fi
                ;;
        esac
    fi

    log "Container support installation complete"
}
