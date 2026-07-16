#!/usr/bin/env bash
install_webserver() {
    local ENV_TYPE="$1"
    local ANVPS_DIR="${2:-${HOME}/.anvps}"
    local WEB_PORT="${3:-7080}"

    log "Installing web server..."

    local WEB_DIR="${ANVPS_DIR}/data/sites/default"
    mkdir -p "$WEB_DIR"
    echo "<html><body><h1>AnVPS Running</h1><p>Your Android VPS is active.</p></body></html>" > "${WEB_DIR}/index.html"

    case "$ENV_TYPE" in
        termux)
            pkg install -y nginx 2>/dev/null || pkg install -y lighttpd 2>/dev/null || {
                log "Using Python HTTP server as fallback"
                cat > "${ANVPS_DIR}/src/core/web-fallback.sh" << 'WEBFB'
#!/usr/bin/env bash
cd "${ANVPS_DIR}/data/sites/default"
python3 -m http.server ${WEB_PORT:-7080}
WEBFB
                chmod +x "${ANVPS_DIR}/src/core/web-fallback.sh"
                return
            }
            ;;
        linux)
            if command -v apt &>/dev/null; then
                apt install -y nginx 2>/dev/null || apt install -y apache2 2>/dev/null || apt install -y lighttpd 2>/dev/null || true
            elif command -v apk &>/dev/null; then
                apk add nginx 2>/dev/null || apk add apache2 2>/dev/null || apk add lighttpd 2>/dev/null || true
            fi
            ;;
    esac

    if command -v nginx &>/dev/null; then
        log "Nginx installed"
    elif command -v apache2ctl &>/dev/null; then
        log "Apache installed"
    elif command -v lighttpd &>/dev/null; then
        log "Lighttpd installed"
    else
        warn "No web server binary found — using Python fallback"
    fi

    log "Web server installation complete"
}
