#!/usr/bin/env bash
set -euo pipefail

ANVPS_DIR="${HOME}/.anvps"
LOG_DIR="${ANVPS_DIR}/logs"
CONFIG="${ANVPS_DIR}/etc/anvps.conf"

log() { echo "[autoupdate] $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "${LOG_DIR}/update.log"; }

load_config() {
    [ -f "$CONFIG" ] && source "$CONFIG"
    : "${ANVPS_AUTO_UPDATE:=true}"
    : "${ANVPS_UPDATE_INTERVAL:=weekly}"
    : "${ANVPS_AUTO_BACKUP:=true}"
}

check_last_update() {
    local state_file="${ANVPS_DIR}/etc/.last_update"
    if [ ! -f "$state_file" ]; then
        echo "0" > "$state_file"
        return 1
    fi
    local last=$(cat "$state_file")
    local now=$(date +%s)
    local interval=$((7 * 24 * 3600))
    case "$ANVPS_UPDATE_INTERVAL" in
        daily)   interval=86400 ;;
        weekly)  interval=$((7 * 86400)) ;;
        monthly) interval=$((30 * 86400)) ;;
    esac
    [ $((now - last)) -ge "$interval" ]
}

update_packages() {
    local updated=0
    if command -v pkg &>/dev/null; then
        log "Updating Termux packages..."
        pkg upgrade -y 2>/dev/null && updated=$((updated + 1)) || log "pkg upgrade had warnings"
    fi
    if command -v apt &>/dev/null; then
        log "Updating APT packages..."
        apt update -y 2>/dev/null && apt upgrade -y 2>/dev/null && updated=$((updated + 1)) || true
    fi
    if command -v apk &>/dev/null; then
        log "Updating APK packages..."
        apk update 2>/dev/null && apk upgrade 2>/dev/null && updated=$((updated + 1)) || true
    fi
    if command -v pip3 &>/dev/null; then
        log "Updating Python packages..."
        pip3 install --upgrade --user anvps 2>/dev/null || true
    fi
    return $updated
}

update_self() {
    log "Checking for AnVPS updates..."
    local tmp_dir="/tmp/anvps-update"
    mkdir -p "$tmp_dir"

    if command -v git &>/dev/null && [ -d "${ANVPS_DIR}/.git" ]; then
        cd "${ANVPS_DIR}"
        git pull 2>/dev/null && log "AnVPS updated via git" || log "No git update needed"
        cd "$OLDPWD"
    elif command -v curl &>/dev/null; then
        local latest=$(curl -s https://api.github.com/repos/MrNova420/AnVPS/releases/latest 2>/dev/null | grep tag_name | cut -d'"' -f4 || echo "")
        if [ -n "$latest" ] && [ "$latest" != "v${ANVPS_VERSION:-}" ]; then
            log "New version available: $latest (current: v${ANVPS_VERSION:-})"
            local url="https://github.com/MrNova420/AnVPS/archive/refs/tags/${latest}.tar.gz"
            curl -sL "$url" -o "${tmp_dir}/update.tar.gz" 2>/dev/null && {
                tar xzf "${tmp_dir}/update.tar.gz" -C "$tmp_dir"
                cp -r "${tmp_dir}/anserver-"*/* "${ANVPS_DIR}/" 2>/dev/null || true
                log "AnVPS updated to $latest"
            } || warn "Update download failed"
        else
            log "AnVPS is up to date"
        fi
    fi
    rm -rf "$tmp_dir"
}

cleanup_logs() {
    log "Rotating logs..."
    find "${LOG_DIR}" -name "*.log" -size +10M -exec sh -c 'mv "$1" "$1.old" && : > "$1"' _ {} \; 2>/dev/null || true
    find "${LOG_DIR}" -name "*.old" -mtime +7 -delete 2>/dev/null || true
    find "${LOG_DIR}" -name "*.log" -mtime +30 -delete 2>/dev/null || true
    log "Log rotation complete"
}

cleanup_temp() {
    log "Cleaning temp files..."
    find "${ANVPS_DIR}/tmp" -type f -atime +1 -delete 2>/dev/null || true
    find /tmp -name "anvps-*" -type f -mtime +1 -delete 2>/dev/null || true
    log "Temp cleanup complete"
}

cleanup_packages() {
    if command -v apt &>/dev/null; then
        apt autoremove -y 2>/dev/null || true
        apt autoclean 2>/dev/null || true
    fi
    if command -v pkg &>/dev/null; then
        pkg autoclean 2>/dev/null || true
    fi
}

auto_backup() {
    if ! $ANVPS_AUTO_BACKUP; then return; fi
    local backup_script="${ANVPS_DIR}/src/cli/anvps"
    if [ -f "$backup_script" ]; then
        bash "$backup_script" backup create 2>/dev/null || true
    fi
}

update_config_version() {
    local state_file="${ANVPS_DIR}/etc/.last_update"
    date +%s > "$state_file"
}

main() {
    load_config
    if ! $ANVPS_AUTO_UPDATE; then
        log "Auto-update disabled"
        return
    fi
    if ! check_last_update; then
        log "Skipping — not yet time for update"
        return
    fi
    log "Starting auto-update cycle..."
    update_packages || true
    update_self || true
    cleanup_logs || true
    cleanup_temp || true
    cleanup_packages || true
    auto_backup || true
    update_config_version
    log "Auto-update cycle complete"
}

main "$@"
