#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${GREEN}[+]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_FILE="${REPO_ROOT}/dist/anvps-portable.sh"

collect_files() {
    local tmpdir=$(mktemp -d)
    mkdir -p "$tmpdir"/{src/{cli/commands,core,bots,web/{backend,frontend},tunnels},setup/modules,config/profiles,docs}
    cp -r "$REPO_ROOT"/src/cli/*       "$tmpdir/src/cli/" 2>/dev/null || true
    cp -r "$REPO_ROOT"/src/core/*      "$tmpdir/src/core/"
    cp -r "$REPO_ROOT"/src/bots/*      "$tmpdir/src/bots/"
    cp -r "$REPO_ROOT"/src/web/*       "$tmpdir/src/web/"
    cp -r "$REPO_ROOT"/src/tunnels/*   "$tmpdir/src/tunnels/"
    cp -r "$REPO_ROOT"/setup/modules/* "$tmpdir/setup/modules/" 2>/dev/null || true
    cp "$REPO_ROOT"/setup/uninstall.sh "$tmpdir/setup/uninstall.sh" 2>/dev/null || true
    cp "$REPO_ROOT"/config/anvps.conf  "$tmpdir/config/" 2>/dev/null || true
    cp "$REPO_ROOT"/config/services.conf "$tmpdir/config/" 2>/dev/null || true
    cp -r "$REPO_ROOT"/config/profiles/* "$tmpdir/config/profiles/" 2>/dev/null || true
    cp "$REPO_ROOT"/docs/*.md          "$tmpdir/docs/" 2>/dev/null || true
    cp "$REPO_ROOT"/README.md          "$tmpdir/" 2>/dev/null || true
    chmod -R +x "$tmpdir"/src/cli/anvps "$tmpdir"/src/core/*.sh "$tmpdir"/setup/modules/*.sh 2>/dev/null || true
    echo "$tmpdir"
}

generate_installer() {
    local tmpdir="$1"
    local archive="$tmpdir/payload.tar.gz"

    tar czf "$archive" -C "$tmpdir" . 2>/dev/null
    local b64data
    b64data=$(base64 -w0 < "$archive" 2>/dev/null || openssl base64 -A < "$archive" 2>/dev/null || base64 -b 0 < "$archive")

    mkdir -p "$(dirname "$OUT_FILE")"

    # Write script header (quoted heredoc = no expansion)
    cat > "$OUT_FILE" << 'HEADER'
#!/usr/bin/env bash
set -euo pipefail

ANVPS_DIR="${HOME}/.anvps"
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[x]${NC} $1"; }

extract_payload() {
    local tmpdir=$(mktemp -d)
    local archive="$tmpdir/payload.tar.gz"
    echo "$PAYLOAD_B64" > "$archive.tmp"
    tr -d '[:space:]' < "$archive.tmp" > "$archive.b64"
    base64 -d < "$archive.b64" > "$archive" 2>/dev/null || openssl base64 -d < "$archive.b64" > "$archive" 2>/dev/null || {
        err "base64 decode failed -- install coreutils (pkg install coreutils)"
        rm -rf "$tmpdir"
        exit 1
    }
    rm -f "$archive.tmp" "$archive.b64"
    tar xzf "$archive" -C "$tmpdir" 2>/dev/null || {
        err "tar extraction failed"
        rm -rf "$tmpdir"
        exit 1
    }
    rm -f "$archive"
    echo "$tmpdir"
}

install_from_payload() {
    local payload_dir="$1"
    log "Installing AnVPS to $ANVPS_DIR..."
    mkdir -p "$ANVPS_DIR"/{src/{cli/commands,core,bots,web/{backend,frontend},tunnels},setup/modules,etc/profiles,data/{databases,sites,containers},logs,services,backup,tmp,ssl,tunnels}
    cp -r "$payload_dir"/src/* "$ANVPS_DIR/src/"
    cp -r "$payload_dir"/setup/* "$ANVPS_DIR/setup/"
    if [ -d "$payload_dir/config" ]; then
        cp -r "$payload_dir"/config/* "$ANVPS_DIR/etc/"
    fi
    if [ -f "$payload_dir/README.md" ]; then
        cp "$payload_dir/README.md" "$ANVPS_DIR/"
    fi
    chmod +x "$ANVPS_DIR/src/cli/anvps"
    ln -sf "$ANVPS_DIR/src/cli/anvps" "$ANVPS_DIR/anvps" 2>/dev/null || true
    local symlink_target=""
    if [ -d "/data/data/com.termux/files/usr/bin" ]; then
        symlink_target="/data/data/com.termux/files/usr/bin/anvps"
    elif [ -d "/usr/local/bin" ]; then
        symlink_target="/usr/local/bin/anvps"
    fi
    if [ -n "$symlink_target" ] && [ ! -f "$symlink_target" ]; then
        ln -sf "$ANVPS_DIR/src/cli/anvps" "$symlink_target" 2>/dev/null || warn "Could not create symlink at $symlink_target"
    fi
    log "Files deployed to $ANVPS_DIR"
}

detect_and_configure() {
    local conf="$ANVPS_DIR/etc/anvps.conf"
    [ -f "$conf" ] && return
    local ENV_TYPE="unknown"
    if [ -n "${TERMUX_VERSION:-}" ]; then ENV_TYPE="termux"
    elif command -v apt &>/dev/null; then ENV_TYPE="linux"; fi
    local RAM_MB=0
    if [ -f /proc/meminfo ]; then
        RAM_MB=$(( $(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0") / 1024 ))
    fi
    local TIER="full"
    [ "$RAM_MB" -lt 64 ] && TIER="shadow"
    [ "$RAM_MB" -lt 256 ] && TIER="lite"
    [ "$RAM_MB" -lt 512 ] && TIER="standard"
    mkdir -p "$(dirname "$conf")"
    cat > "$conf" << CONFEOF
ANVPS_VERSION="1.0.0"
ANVPS_TIER="$TIER"
ANVPS_DIR="\${HOME}/.anvps"
ANVPS_HOSTNAME="anvps-device"
ANVPS_SSH_TYPE="auto"
ANVPS_HTTPD_TYPE="auto"
ANVPS_BOT_TYPE="auto"
ANVPS_MONITORING=$([ "$TIER" = "shadow" ] && echo "minimal" || echo "auto")
ANVPS_PORT_BASE=7000
ANVPS_SSH_PORT=7022
ANVPS_WEB_PORT=7080
ANVPS_HTTPS_PORT=7443
ANVPS_AUTO_UPDATE=true
ANVPS_AUTO_BACKUP=$([ "$TIER" = "shadow" ] && echo "false" || echo "true")
ANVPS_BACKUP_INTERVAL="weekly"
ANVPS_LOG_LEVEL=$([ "$TIER" = "shadow" ] && echo "error" || echo "info")
ANVPS_LOG_RETENTION_DAYS=$([ "$TIER" = "shadow" ] && echo "3" || echo "30")
ANVPS_WATCHDOG=true
ANVPS_STEALTH=$([ "$TIER" = "shadow" ] && echo "true" || echo "false")
ANVPS_OBFUSCATE=$([ "$TIER" = "shadow" ] && echo "true" || echo "false")
ANVPS_TAMPER_DETECTION=true
ANVPS_TAMPER_MAX_FAILED=$([ "$TIER" = "shadow" ] && echo "5" || echo "10")
CONFEOF
    log "Configuration generated ($ENV_TYPE, ${RAM_MB}MB, $TIER tier)"
}

start_services() {
    log "Starting services..."
    if [ -f "$ANVPS_DIR/src/core/supervisor.sh" ]; then
        bash "$ANVPS_DIR/src/core/supervisor.sh" start 2>&1 || warn "Supervisor start failed -- run 'anvps service start' manually"
    fi
}

print_summary() {
    echo ""
    echo "  AnVPS v1.0.0 -- Ready"
    echo "  ====================="
    echo "  Directory: $ANVPS_DIR"
    echo "  SSH Port:  7022"
    echo "  Web UI:    http://localhost:7080"
    echo ""
    echo "  Commands:"
    echo "    anvps status        -- System status"
    echo "    anvps service list  -- List services"
    echo "    anvps help          -- All commands"
    echo ""
}

main() {
    echo ""
    echo "  AnVPS -- Portable Installer"
    echo "  ==========================="
    local payload_dir=$(extract_payload)
    install_from_payload "$payload_dir"
    detect_and_configure
    start_services
    rm -rf "$payload_dir"
    print_summary
}

PAYLOAD_B64="
HEADER

    # Write base64 payload
    echo "$b64data" >> "$OUT_FILE"

    # Write footer
    cat >> "$OUT_FILE" << 'FOOTER'
"
main "$@"
FOOTER

    chmod +x "$OUT_FILE"
    rm -rf "$tmpdir" "$archive"

    local final_size=$(wc -c < "$OUT_FILE")
    echo $((final_size / 1024))
}

main() {
    echo ""
    echo "  AnVPS Portable Package Builder"
    echo "  =============================="
    local tmpdir=$(collect_files)
    local kb=$(generate_installer "$tmpdir")
    log "Portable installer created: $OUT_FILE"
    log "  Size: ${kb}KB"
    log "  Usage: bash $OUT_FILE"
    log "  Or:    curl -sSL https://raw.githubusercontent.com/MrNova420/AnVPS/master/dist/anvps-portable.sh | bash"
    echo ""
}

main "$@"
