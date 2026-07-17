#!/usr/bin/env bash
set -euo pipefail

ANVPS_DIR="${HOME}/.anvps"
LOG_DIR="${ANVPS_DIR}/logs"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${GREEN}[storage]${NC} $1"; }
warn() { echo -e "${YELLOW}[storage]${NC} $1"; }

get_usage() {
    local dir="${1:-$ANVPS_DIR}"
    du -sh "$dir" 2>/dev/null | cut -f1 || echo "0"
}

get_percent() {
    df "${ANVPS_DIR}" 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//' || echo "0"
}

cmd_status() {
    echo ""
    echo "  Storage Status"
    echo "  $(printf '%0.s-' {1..40})"
    echo ""
    echo "  AnVPS Home:  $(get_usage "$ANVPS_DIR")"
    echo "  Data:        $(get_usage "${ANVPS_DIR}/data")"
    echo "  Logs:        $(get_usage "${LOG_DIR}")"
    echo "  Backups:     $(get_usage "${ANVPS_DIR}/backup")"
    echo "  Total Used:  $(df -h "${ANVPS_DIR}" 2>/dev/null | tail -1 | awk '{print $3" / "$2" ("$5")"}')"
    echo ""
}

cmd_cleanup() {
    log "Running storage cleanup..."
    local freed=0

    local before=$(du -sb "${ANVPS_DIR}" 2>/dev/null | cut -f1)

    find "${LOG_DIR}" -name "*.log" -size +5M -exec sh -c '> "$1"' _ {} \; 2>/dev/null && freed=$((freed + 1))
    find "${LOG_DIR}" -name "*.old" -delete 2>/dev/null && freed=$((freed + 1))
    find "${ANVPS_DIR}/tmp" -type f -atime +1 -delete 2>/dev/null && freed=$((freed + 1))

    if command -v docker &>/dev/null; then
        docker system prune -f 2>/dev/null && freed=$((freed + 1)) || true
    fi

    local after=$(du -sb "${ANVPS_DIR}" 2>/dev/null | cut -f1)
    local saved=$(( (before - after) / 1024 ))

    log "Cleanup complete — freed ${saved}KB across $freed areas"
}

cmd_analyze() {
    echo "  Storage Analysis"
    echo "  $(printf '%0.s-' {1..40})"
    echo ""
    du -sh "${ANVPS_DIR}"/*/ 2>/dev/null | sort -rh | while IFS= read -r line; do
        echo "  $line"
    done
    echo ""
}

case "${1:-status}" in
    status)  cmd_status ;;
    cleanup) cmd_cleanup ;;
    analyze) cmd_analyze ;;
    *) echo "Usage: $0 {status|cleanup|analyze}" ;;
esac
