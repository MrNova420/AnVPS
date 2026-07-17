#!/usr/bin/env bash
set -euo pipefail

# ANVPS_DIR="${HOME}/.anvps"
# ANVPS_REPO="https://github.com/MrNova420/AnVPS"
# ANVPS_BRANCH="master"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[x]${NC} $1"; }
info() { echo -e "${CYAN}[i]${NC} $1"; }

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

    chmod -R +x "$tmpdir"/src/cli/anvps "$tmpdir"/src/core/*.sh "$tmpdir"/setup/modules/*.sh "$tmpdir"/setup/uninstall.sh "$tmpdir"/src/bots/*.sh "$tmpdir"/src/tunnels/*.sh 2>/dev/null || true

    echo "$tmpdir"
}

measure() {
    local path="$1"
    if command -v stat &>/dev/null; then
        stat -f%z "$path" 2>/dev/null || stat -c%s "$path" 2>/dev/null || echo "0"
    else
        wc -c < "$path" 2>/dev/null || echo "0"
    fi
}

generate_installer() {
    local tmpdir="$1"
    local archive="$tmpdir/payload.tar.gz"
    local total_kb=0

    tar czf "$archive" -C "$tmpdir" .
    local size=$(measure "$archive")
    total_kb=$((size / 1024))

    mkdir -p "$(dirname "$OUT_FILE")"

    cat > "$OUT_FILE" << 'PAYLOAD_HEADER'
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
    local line=0

    line=$(grep -an "^__PAYLOAD_BELOW__$" "$0" | cut -d: -f1)
    tail -n +$((line + 1)) "$0" > "$archive"

    tar xzf "$archive" -C "$tmpdir"
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
    local anvps_conf="$ANVPS_DIR/etc/anvps.conf"
    [ -f "$anvps_conf" ] && return

    ENV_TYPE="unknown"
    if [ -n "${TERMUX_VERSION:-}" ]; then
        ENV_TYPE="termux"
    elif command -v apt &>/dev/null; then
        ENV_TYPE="linux"
    fi

    local TOTAL_RAM_MB=0
    if [ -f /proc/meminfo ]; then
        TOTAL_RAM_MB=$(($(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0") / 1024))
    fi
    local TIER="full"
    if [ "$TOTAL_RAM_MB" -lt 64 ]; then TIER="shadow"
    elif [ "$TOTAL_RAM_MB" -lt 256 ]; then TIER="lite"
    elif [ "$TOTAL_RAM_MB" -lt 512 ]; then TIER="standard"
    fi

    mkdir -p "$(dirname "$anvps_conf")"
    cat > "$anvps_conf" << CONFEOF
ANVPS_VERSION="1.0.0"
ANVPS_TIER="$TIER"
ANVPS_DIR="\${HOME}/.anvps"
ANVPS_HOSTNAME="anvps-device"
ANVPS_SSH_TYPE="auto"
ANVPS_HTTPD_TYPE="auto"
ANVPS_BOT_TYPE="auto"
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

    log "Configuration generated ($ENV_TYPE, ${TOTAL_RAM_MB}MB, $TIER tier)"
}

start_services() {
    log "Starting services..."
    if [ -f "$ANVPS_DIR/src/core/supervisor.sh" ]; then
        bash "$ANVPS_DIR/src/core/supervisor.sh" start 2>&1 || warn "Supervisor start failed — run 'anvps service start' manually"
    fi
}

print_summary() {
    echo ""
    echo "  AnVPS v1.0.0 — Ready"
    echo "  ===================="
    echo "  Directory: $ANVPS_DIR"
    echo "  SSH Port:  7022"
    echo "  Web UI:    http://localhost:7080"
    echo ""
    echo "  Commands:"
    echo "    anvps status        — System status"
    echo "    anvps service list  — List services"
    echo "    anvps help          — All commands"
    echo ""
}

main() {
    echo ""
    echo "  AnVPS — Portable Installer"
    echo "  ==========================="

    local payload_dir=$(extract_payload)
    install_from_payload "$payload_dir"
    detect_and_configure
    start_services
    rm -rf "$payload_dir"
    print_summary
}

main "$@"
exit 0
__PAYLOAD_BELOW__
PAYLOAD_HEADER

    cat "$archive" >> "$OUT_FILE"
    chmod +x "$OUT_FILE"
    rm -rf "$tmpdir"

    echo "$total_kb"
}

main() {
    echo ""
    echo "  AnVPS Portable Package Builder"
    echo "  =============================="

    local tmpdir=$(collect_files)
    local total_kb=$(generate_installer "$tmpdir")
    local final_size=$(measure "$OUT_FILE")
    local final_kb=$((final_size / 1024))

    log "Portable installer created: $OUT_FILE"
    log "  Size: ${final_kb}KB"
    log "  Usage: bash ${OUT_FILE}"
    log "  Or:    curl -sSL https://github.com/MrNova420/AnVPS/releases/download/v1.0.0/anvps-portable.sh | bash"
    echo ""
}

main "$@"
