#!/usr/bin/env bash
install_code_server() {
    local ENV_TYPE="$1"
    local ANVPS_DIR="${2:-${HOME}/.anvps}"
    local CODE_PORT="${3:-7443}"

    log "Installing code-server (VS Code Web)..."

    local CODE_DIR="${ANVPS_DIR}/data/code-server"
    mkdir -p "$CODE_DIR"

    if command -v code-server &>/dev/null; then
        log "code-server already installed"
        return
    fi

    local arch
    case "$(uname -m)" in
        aarch64|arm64) arch="arm64" ;;
        armv7l|armhf)  arch="armv7l" ;;
        x86_64|amd64)  arch="amd64" ;;
        *)             arch="amd64" ;;
    esac

    if [ "$ENV_TYPE" = "termux" ]; then
        npm install -g code-server --unsafe-perm 2>/dev/null || {
            pkg install -y nodejs 2>/dev/null || true
            npm install -g code-server --unsafe-perm 2>/dev/null || {
                warn "code-server npm install failed"
                install_via_binary "$arch" "$CODE_DIR"
            }
        }
    else
        install_via_binary "$arch" "$CODE_DIR"
    fi

    if command -v code-server &>/dev/null; then
        mkdir -p "${ANVPS_DIR}/data/code-server/projects"
        cat > "${ANVPS_DIR}/data/code-server/config.yaml" << 'CFG'
bind-addr: 0.0.0.0:7443
auth: password
password: anvps_code
cert: false
CFG
        log "code-server installed — access at http://localhost:7443 (password: anvps_code)"
    fi
}

install_via_binary() {
    local arch="$1"
    local dest="$2"
    local ver=$(curl -s https://api.github.com/repos/coder/code-server/releases/latest | grep tag_name | cut -d'"' -f4 2>/dev/null || echo "4.96.4")
    local url="https://github.com/coder/code-server/releases/download/${ver}/code-server-${ver}-linux-${arch}.tar.gz"

    log "Downloading code-server ${ver} for ${arch}..."
    local tmp_dir="/tmp/code-server-install"
    mkdir -p "$tmp_dir"
    curl -L "$url" -o "${tmp_dir}/code-server.tar.gz" 2>/dev/null && {
        tar xzf "${tmp_dir}/code-server.tar.gz" -C "$tmp_dir"
        cp "${tmp_dir}/code-server-${ver}-linux-${arch}/code-server" "/usr/local/bin/" 2>/dev/null || true
        chmod +x "/usr/local/bin/code-server" 2>/dev/null || true
    } || warn "code-server binary download failed"
    rm -rf "$tmp_dir"
}
