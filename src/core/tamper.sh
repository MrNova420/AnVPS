#!/usr/bin/env bash
set -euo pipefail
# Tamper detection + auto-wipe + dead man switch

ANVPS_DIR="${HOME}/.anvps"
STATE_DIR="${ANVPS_DIR}/etc"
CHECKSUM_FILE="${STATE_DIR}/.checksums"
TIMER_FILE="${STATE_DIR}/.last_seen"
WIPE_FLAG="${STATE_DIR}/.wipe_triggered"
MAX_FAILED_AUTH="${ANVPS_TAMPER_MAX_FAILED:-10}"
DEAD_MAN_DAYS="${ANVPS_DEAD_MAN_DAYS:-30}"
FAILED_COUNT=0

log() { echo "[tamper] $(date '+%Y-%m-%d %H:%M:%S') $1" >> "${ANVPS_DIR}/logs/tamper.log"; }

init_checksums() {
    echo "Initializing integrity checksums..."
    > "$CHECKSUM_FILE"
    for f in "${ANVPS_DIR}/etc/anvps.conf" "${ANVPS_DIR}/etc/services.conf"; do
        [ -f "$f" ] && sha256sum "$f" >> "$CHECKSUM_FILE"
    done
    for f in "${ANVPS_DIR}/src/core"/*.sh "${ANVPS_DIR}/src/cli/anvps"; do
        [ -f "$f" ] && sha256sum "$f" >> "$CHECKSUM_FILE"
    done
    chmod 400 "$CHECKSUM_FILE"
    log "Checksums initialized"
}

verify_integrity() {
    if [ ! -f "$CHECKSUM_FILE" ]; then
        log "No checksum file — initializing first run"
        init_checksums
        return 0
    fi
    local violations=0
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        local expected_hash=$(echo "$line" | awk '{print $1}')
        local file=$(echo "$line" | awk '{print $2}')
        if [ ! -f "$file" ]; then
            log "MISSING: $file"
            violations=$((violations + 1))
            continue
        fi
        local actual_hash=$(sha256sum "$file" | awk '{print $1}')
        if [ "$expected_hash" != "$actual_hash" ]; then
            log "TAMPER DETECTED: $file (hash mismatch)"
            violations=$((violations + 1))
        fi
    done < "$CHECKSUM_FILE"
    if [ "$violations" -gt 0 ]; then
        log "INTEGRITY FAILURE: $violations file(s) tampered"
        trigger_wipe "integrity_check"
        return 1
    fi
    log "Integrity check passed"
    return 0
}

check_failed_auth() {
    local logfile="${ANVPS_DIR}/logs/ssh.log"
    [ ! -f "$logfile" ] && return
    local recent=$(grep -cE "Failed password|auth failure|Bad protocol" "$logfile" 2>/dev/null || echo 0)
    FAILED_COUNT=$recent
    if [ "$recent" -gt "$MAX_FAILED_AUTH" ]; then
        log "BRUTE FORCE DETECTED: $recent failed auth attempts"
        trigger_wipe "brute_force"
    fi
}

check_dead_man() {
    if [ ! -f "$TIMER_FILE" ]; then
        date +%s > "$TIMER_FILE"
        return
    fi
    local last=$(cat "$TIMER_FILE")
    local now=$(date +%s)
    local elapsed=$(( (now - last) / 86400 ))
    if [ "$elapsed" -gt "$DEAD_MAN_DAYS" ]; then
        log "DEAD MAN SWITCH: device offline ${elapsed} days"
        trigger_wipe "dead_man"
    fi
    date +%s > "$TIMER_FILE"
}

trigger_wipe() {
    local reason="$1"
    log "WIPE TRIGGERED: $reason"
    echo "$reason" > "$WIPE_FLAG"
    touch "${ANVPS_DIR}/tmp/wipe_pending"
    if [ -f "${ANVPS_DIR}/src/core/wipe.sh" ]; then
        log "Executing wipe..."
        bash "${ANVPS_DIR}/src/core/wipe.sh" auto "$reason" &
        disown
    fi
}

check_wipe_pending() {
    if [ -f "${ANVPS_DIR}/tmp/wipe_pending" ]; then
        local reason=$(cat "$WIPE_FLAG" 2>/dev/null || echo "unknown")
        log "Wipe already pending for: $reason"
        return 0
    fi
    return 1
}

reset() {
    [ -f "$CHECKSUM_FILE" ] && rm -f "$CHECKSUM_FILE"
    init_checksums
    rm -f "$WIPE_FLAG" "${ANVPS_DIR}/tmp/wipe_pending"
    date +%s > "$TIMER_FILE"
    log "Tamper state reset"
}

case "${1:-status}" in
    init) init_checksums ;;
    verify) verify_integrity ;;
    check) check_failed_auth; check_dead_man ;;
    wipe) trigger_wipe "${2:-manual}" ;;
    reset) reset ;;
    status)
        echo "Integrity: $( [ -f "$CHECKSUM_FILE" ] && echo 'initialized' || echo 'uninitialized' )"
        echo "Wipe pending: $( [ -f "${ANVPS_DIR}/tmp/wipe_pending" ] && echo 'YES' || echo 'no' )"
        echo "Max failed auth: $MAX_FAILED_AUTH"
        echo "Dead man days: $DEAD_MAN_DAYS"
        if [ -f "$TIMER_FILE" ]; then
            local last=$(cat "$TIMER_FILE")
            local ago=$(( ($(date +%s) - last) / 86400 ))
            echo "Last seen: ${ago} days ago"
        fi
        ;;
    *) echo "Usage: $0 {init|verify|check|wipe|reset|status}" ;;
esac
