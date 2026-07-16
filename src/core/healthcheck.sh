#!/usr/bin/env bash
set -euo pipefail

ANVPS_DIR="${HOME}/.anvps"
LOG_DIR="${ANVPS_DIR}/logs"
SERVICES_DIR="${ANVPS_DIR}/services"

log() { echo "[healthcheck] $(date '+%Y-%m-%d %H:%M:%S') $1"; }

RESULTS=()
PASSED=0
FAILED=0
WARNINGS=0

check_cpu() {
    local load=$(cat /proc/loadavg 2>/dev/null | cut -d' ' -f1 || echo "0")
    local cores=$(nproc 2>/dev/null || echo 1)
    local load_int=${load/./} 2>/dev/null || load_int=0
    local threshold=$((cores * 9))
    load_int=${load_int##0}
    load_int=${load_int:-0}
    if [ "${#load_int}" -gt 2 ]; then
        RESULTS+=("WARN: High CPU load: $load (cores: $cores)")
        WARNINGS=$((WARNINGS + 1))
    else
        PASSED=$((PASSED + 1))
    fi
}

check_memory() {
    if ! command -v free &>/dev/null; then
        RESULTS+=("PASS: Memory check unavailable")
        PASSED=$((PASSED + 1))
        return
    fi
    local mem_avail=$(free -m 2>/dev/null | grep Mem | awk '{print $7}')
    if [ -n "$mem_avail" ] && [ "$mem_avail" -lt 50 ] 2>/dev/null; then
        RESULTS+=("WARN: Low memory: ${mem_avail}MB available")
        WARNINGS=$((WARNINGS + 1))
    else
        PASSED=$((PASSED + 1))
    fi
}

check_disk() {
    local usage=$(df "${ANVPS_DIR}" 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ -n "$usage" ]; then
        if [ "$usage" -gt 90 ] 2>/dev/null; then
            RESULTS+=("CRIT: Disk usage at ${usage}%")
            FAILED=$((FAILED + 1))
        elif [ "$usage" -gt 75 ] 2>/dev/null; then
            RESULTS+=("WARN: Disk usage at ${usage}%")
            WARNINGS=$((WARNINGS + 1))
        else
            PASSED=$((PASSED + 1))
        fi
    fi
}

check_services() {
    local count=0
    for pidf in "${SERVICES_DIR}"/*.pid; do
        [ -f "$pidf" ] || continue
        count=$((count + 1))
        local name=$(basename "$pidf" .pid)
        local pid=$(cat "$pidf" 2>/dev/null)
        if kill -0 "$pid" 2>/dev/null; then
            local rss=$(ps -o rss= -p "$pid" 2>/dev/null | awk '{printf "%.0f", $1/1024}')
            RESULTS+=("PASS: $name running (PID $pid, RSS ${rss}MB)")
            PASSED=$((PASSED + 1))
        else
            RESULTS+=("CRIT: $name crashed (stale PID $pid)")
            FAILED=$((FAILED + 1))
            rm -f "$pidf"
        fi
    done
    if [ "$count" -eq 0 ]; then
        RESULTS+=("INFO: No services registered")
        PASSED=$((PASSED + 1))
    fi
}

check_network() {
    local ports=("7022" "7080" "7443" "7444")
    local netcmd="ss -tlnp"
    if ! command -v ss &>/dev/null; then netcmd="netstat -tlnp"; fi
    for port in "${ports[@]}"; do
        if $netcmd 2>/dev/null | grep -q ":${port} "; then
            PASSED=$((PASSED + 1))
        fi
    done
    if curl -s --max-time 3 https://1.1.1.1 >/dev/null 2>&1; then
        RESULTS+=("PASS: Internet connectivity OK")
        PASSED=$((PASSED + 1))
    else
        RESULTS+=("WARN: No internet connectivity")
        WARNINGS=$((WARNINGS + 1))
    fi
}

check_temp() {
    if [ -d "/sys/class/thermal" ]; then
        for zone in /sys/class/thermal/thermal_zone*/temp; do
            [ -f "$zone" ] || continue
            local raw=$(cat "$zone" 2>/dev/null)
            local temp=$((raw / 1000)) 2>/dev/null || continue
            if [ "$temp" -gt 70 ] 2>/dev/null; then
                RESULTS+=("WARN: Temperature ${temp}C — throttling risk")
                WARNINGS=$((WARNINGS + 1))
            fi
            break
        done
    fi
}

auto_heal() {
    local healed=0
    local max_restarts=5
    local restart_count_file="${ANVPS_DIR}/tmp/.restart_count"
    mkdir -p "${ANVPS_DIR}/tmp"
    local total_restarts=0
    [ -f "$restart_count_file" ] && total_restarts=$(cat "$restart_count_file")
    if [ "$total_restarts" -ge "$max_restarts" ]; then
        log "Max restarts ($max_restarts) reached — skipping auto-heal to avoid crash loop"
        return
    fi
    for pidf in "${SERVICES_DIR}"/*.pid; do
        [ -f "$pidf" ] || continue
        local name=$(basename "$pidf" .pid)
        local pid=$(cat "$pidf" 2>/dev/null)
        if ! kill -0 "$pid" 2>/dev/null; then
            log "Auto-healing $name..."
            rm -f "$pidf"
            if [ -f "${ANVPS_DIR}/src/core/${name}.sh" ]; then
                bash "${ANVPS_DIR}/src/core/${name}.sh" start 2>/dev/null || true
                healed=$((healed + 1))
            fi
        fi
    done
    if [ "$healed" -gt 0 ]; then
        total_restarts=$((total_restarts + healed))
        echo "$total_restarts" > "$restart_count_file"
        log "Auto-healed $healed service(s) (total restarts: $total_restarts)"
    else
        rm -f "$restart_count_file" 2>/dev/null
    fi
}

generate_report() {
    local total=$((PASSED + FAILED + WARNINGS))
    local ts=$(date '+%Y-%m-%d %H:%M:%S')
    local report="${LOG_DIR}/healthcheck_$(date '+%Y%m%d').log"

    {
        echo "=== AnVPS Health Check Report ==="
        echo "Timestamp: $ts"
        echo "Results: $PASSED passed, $WARNINGS warnings, $FAILED failed"
        echo "---"
        for result in "${RESULTS[@]}"; do
            echo "$result"
        done
        echo "================================="
    } >> "$report"

    if [ "$FAILED" -gt 0 ] || [ "$WARNINGS" -gt 5 ]; then
        log "SUMMARY: $PASSED passed, $WARNINGS warnings, $FAILED failed — issues found"
        auto_heal
    else
        log "SUMMARY: $PASSED passed, $WARNINGS warnings, $FAILED failed — healthy"
    fi

    echo "$PASSED/$total"
}

main() {
    check_cpu
    check_memory
    check_disk
    check_services
    check_network
    check_temp
    generate_report
}

main "$@"
