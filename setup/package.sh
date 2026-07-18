#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
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
    local b64data=$(base64 -w0 < "$archive" 2>/dev/null || openssl base64 -A < "$archive" 2>/dev/null || base64 -b 0 < "$archive")
    mkdir -p "$(dirname "$OUT_FILE")"

    cat > "$OUT_FILE" << 'HEADER'
#!/usr/bin/env bash
set -euo pipefail

ANVPS_DIR="${HOME}/.anvps"
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[x]${NC} $1"; }

detect_env() {
    if [ -n "${TERMUX_VERSION:-}" ]; then
        echo "termux"; return
    fi
    command -v apt &>/dev/null && echo "debian" && return
    command -v apk &>/dev/null && echo "alpine" && return
    echo "unknown"
}

check_tools() {
    local missing=""
    command -v base64 &>/dev/null || missing="$missing base64"
    command -v tar &>/dev/null || missing="$missing tar"
    command -v curl &>/dev/null || missing="$missing curl"
    command -v tr &>/dev/null || missing="$missing tr"
    if [ -n "$missing" ]; then
        local env=$(detect_env)
        if [ "$env" = "termux" ]; then
            log "Installing missing tools:$missing"
            pkg install -y coreutils tar curl 2>/dev/null || true
        elif [ "$env" = "debian" ]; then
            apt update -qq 2>/dev/null || true
            apt install -y coreutils tar curl 2>/dev/null || true
        else
            err "Missing tools:$missing — install coreutils, tar, curl"
            exit 1
        fi
    fi
}

extract_payload() {
    local tmpdir=$(mktemp -d)
    local archive="$tmpdir/payload.tar.gz"
    echo "$PAYLOAD_B64" | tr -d '[:space:]' | base64 -d > "$archive" 2>/dev/null || echo "$PAYLOAD_B64" | tr -d '[:space:]' | openssl base64 -d > "$archive" 2>/dev/null || {
        err "base64 decode failed"
        rm -rf "$tmpdir"; exit 1
    }
    tar xzf "$archive" -C "$tmpdir" 2>/dev/null || {
        err "tar extraction failed"
        rm -rf "$tmpdir"; exit 1
    }
    rm -f "$archive"
    echo "$tmpdir"
}

install_packages() {
    local env=$(detect_env)
    local tier="${1:-full}"
    log "Installing packages ($tier mode)..."
    local base_pkgs="curl wget git openssh"
    local extra_pkg=""
    local python_pkg="python"
    local termux_extras="procps iproute2 net-tools coreutils util-linux dnsutils"

    [ "$tier" = "shadow" ] && base_pkgs="curl wget dropbear"
    [ "$tier" != "shadow" ] && extra_pkg="$python_pkg"

    case "$env" in
        termux)
            pkg update -y 2>/dev/null || true
            pkg install -y $base_pkgs $extra_pkg cronie termux-services sqlite $termux_extras 2>/dev/null || true
            [ "$tier" = "shadow" ] && pkg install -y busybox 2>/dev/null || true
            ;;
        debian)
            apt update -qq 2>/dev/null || true
            apt install -y $base_pkgs $extra_pkg cron sqlite3 ufw 2>/dev/null || true
            ;;
        alpine)
            apk update 2>/dev/null || true
            apk add $base_pkgs $extra_pkg dcron sqlite 2>/dev/null || true
            ;;
    esac

    if [ "$tier" != "shadow" ]; then
        for pip_cmd in pip pip3; do
            command -v "$pip_cmd" &>/dev/null && {
                log "Installing Python packages..."
                $pip_cmd install fastapi uvicorn 2>/dev/null || true
                break
            }
        done
    fi

    log "Packages installed"
}

install_from_payload() {
    local payload_dir="$1"
    log "Deploying AnVPS to $ANVPS_DIR..."
    mkdir -p "$ANVPS_DIR"/{src/{cli/commands,core,bots,web/{backend,frontend},tunnels},setup/modules,etc/profiles,data/{databases,sites,containers},logs,services,backup,tmp,ssl,tunnels}
    cp -r "$payload_dir"/src/* "$ANVPS_DIR/src/"
    cp -r "$payload_dir"/setup/* "$ANVPS_DIR/setup/"
    [ -d "$payload_dir/config" ] && cp -r "$payload_dir"/config/* "$ANVPS_DIR/etc/"
    [ -f "$payload_dir/README.md" ] && cp "$payload_dir/README.md" "$ANVPS_DIR/"
    chmod +x "$ANVPS_DIR/src/cli/anvps"
    ln -sf "$ANVPS_DIR/src/cli/anvps" "$ANVPS_DIR/anvps" 2>/dev/null || true
    local target=""
    [ -d "/data/data/com.termux/files/usr/bin" ] && target="/data/data/com.termux/files/usr/bin/anvps"
    [ -z "$target" ] && [ -d "/usr/local/bin" ] && target="/usr/local/bin/anvps"
    [ -n "$target" ] && [ ! -f "$target" ] && ln -sf "$ANVPS_DIR/src/cli/anvps" "$target" 2>/dev/null || true
    log "Files deployed"
}

generate_config() {
    local conf="$ANVPS_DIR/etc/anvps.conf"
    [ -f "$conf" ] && return
    local env=$(detect_env)
    local RAM_MB=0
    [ -f /proc/meminfo ] && RAM_MB=$(( $(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0") / 1024 ))
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
    log "Configuration generated"
}

start_services() {
    log "Starting services..."
    [ -f "$ANVPS_DIR/src/core/supervisor.sh" ] && bash "$ANVPS_DIR/src/core/supervisor.sh" start 2>&1 || warn "Supervisor start had issues — run 'anvps service start' later"
}

print_summary() {
    local anvps_cmd="anvps"
    [ -f "/data/data/com.termux/files/usr/bin/anvps" ] || anvps_cmd="bash $ANVPS_DIR/src/cli/anvps"
    echo ""
    echo "  AnVPS v1.0.0 — Ready"
    echo "  ====================="
    echo "  Directory: $ANVPS_DIR"
    echo "  SSH Port:  7022"
    echo "  Web UI:    http://localhost:7080"
    echo ""
    echo "  Commands:"
    echo "    $anvps_cmd status        — System status"
    echo "    $anvps_cmd service list  — List services"
    echo "    $anvps_cmd help          — All commands"
    echo ""
}

main() {
    echo ""
    echo "  AnVPS — Portable Installer"
    echo "  ==========================="
    check_tools
    local env=$(detect_env)
    log "Environment: $env"
    local payload_dir=$(extract_payload)
    install_from_payload "$payload_dir"
    rm -rf "$payload_dir"

    local RAM_MB=0
    [ -f /proc/meminfo ] && RAM_MB=$(( $(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0") / 1024 ))
    local TIER="full"
    [ "$RAM_MB" -lt 64 ] && TIER="shadow"
    [ "$RAM_MB" -lt 256 ] && TIER="lite"
    [ "$RAM_MB" -lt 512 ] && TIER="standard"

    generate_config
    install_packages "$TIER"
    start_services
    print_summary
}

PAYLOAD_B64="
HEADER
    echo "$b64data" >> "$OUT_FILE"
    cat >> "$OUT_FILE" << 'FOOTER'
"
main "$@"
FOOTER
    chmod +x "$OUT_FILE"
    rm -rf "$tmpdir" "$archive"
    local kb=$(($(wc -c < "$OUT_FILE") / 1024))
    echo "$kb"
}

main() {
    echo ""
    echo "  AnVPS Portable Package Builder"
    echo "  =============================="
    local tmpdir=$(collect_files)
    local kb=$(generate_installer "$tmpdir")
    log "Built: $OUT_FILE (${kb}KB)"
    log "Run:  bash $OUT_FILE"
    echo ""
}

main "$@"
