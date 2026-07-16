#!/usr/bin/env bash
set -euo pipefail

ANVPS_DIR="${HOME}/.anvps"
ANVPS_SRC="${ANVPS_DIR}/src"
SERVICES_DIR="${ANVPS_DIR}/services"
LOG_DIR="${ANVPS_DIR}/logs"
PID_DIR="${ANVPS_DIR}/tmp"

mkdir -p "$SERVICES_DIR" "$LOG_DIR" "$PID_DIR"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${GREEN}[supervisor]${NC} $1"; }
warn() { echo -e "${YELLOW}[supervisor]${NC} $1"; }
err()  { echo -e "${RED}[supervisor]${NC} $1"; }

SERVICES=()

register_service() {
    local name="$1"
    local cmd="$2"
    local pid_file="${SERVICES_DIR}/${name}.pid"
    local log_file="${LOG_DIR}/${name}.log"
    SERVICES+=("$name:$cmd:$pid_file:$log_file")
}

load_services() {
    SERVICES=()

    local cfg="${ANVPS_DIR}/etc/anvps.conf"
    [ -f "$cfg" ] && source "$cfg"
    local ssh_type="${ANVPS_SSH_TYPE:-auto}"
    if [ "$ssh_type" = "dropbear" ] || [ "$ssh_type" = "auto" ] && command -v dropbear &>/dev/null; then
        register_service "ssh" "${ANVPS_SRC}/core/dropbear.sh start"
    else
        register_service "ssh" "${ANVPS_SRC}/core/ssh.sh start"
    fi

    if [ -f "${ANVPS_SRC}/core/httpd.sh" ]; then
        register_service "web" "${ANVPS_SRC}/core/httpd.sh start"
    fi
    if [ -f "${ANVPS_SRC}/core/file-server.py" ]; then
        register_service "files" "python3 ${ANVPS_SRC}/core/file-server.py"
    fi
    if [ -f "${ANVPS_SRC}/core/fail2ban.sh" ]; then
        register_service "fail2ban" "${ANVPS_SRC}/core/fail2ban.sh start"
    fi

    local custom_services="${ANVPS_DIR}/etc/services.conf"
    if [ -f "$custom_services" ]; then
        while IFS='=' read -r name cmd; do
            [ -z "$name" ] || [ -z "$cmd" ] && continue
            [[ "$name" =~ ^# ]] && continue
            register_service "$name" "$cmd"
        done < "$custom_services"
    fi
}

start_service() {
    local name="$1"
    local cmd="$2"
    local pid_file="$3"
    local log_file="$4"

    if [ -f "$pid_file" ]; then
        local old_pid=$(cat "$pid_file")
        if kill -0 "$old_pid" 2>/dev/null; then
            log "$name already running (PID $old_pid)"
            return 0
        fi
        rm -f "$pid_file"
    fi

    nohup bash -c "$cmd" >> "$log_file" 2>&1 &
    local pid=$!
    echo $pid > "$pid_file"

    sleep 1
    if kill -0 "$pid" 2>/dev/null; then
        log "$name started (PID $pid)"
        return 0
    else
        err "$name failed to start"
        rm -f "$pid_file"
        return 1
    fi
}

stop_service() {
    local name="$1"
    local pid_file="$2"

    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            sleep 1
            kill -9 "$pid" 2>/dev/null || true
            log "$name stopped"
        fi
        rm -f "$pid_file"
    fi
}

start_all() {
    log "Starting all services..."
    load_services
    for svc in "${SERVICES[@]}"; do
        IFS=':' read -r name cmd pid_file log_file <<< "$svc"
        start_service "$name" "$cmd" "$pid_file" "$log_file"
    done
    log "Supervisor active — monitoring ${#SERVICES[@]} services"
}

stop_all() {
    log "Stopping all services..."
    load_services
    for svc in "${SERVICES[@]}"; do
        IFS=':' read -r name cmd pid_file log_file <<< "$svc"
        stop_service "$name" "$pid_file"
    done
    log "All services stopped"
}

status_all() {
    load_services
    local running=0
    for svc in "${SERVICES[@]}"; do
        IFS=':' read -r name cmd pid_file log_file <<< "$svc"
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file")
            if kill -0 "$pid" 2>/dev/null; then
                log "$name is running (PID $pid)"
                running=$((running + 1))
            else
                warn "$name has crashed (stale PID $pid)"
                rm -f "$pid_file"
            fi
        else
            warn "$name is stopped"
        fi
    done
    echo "  Services: $running/${#SERVICES[@]} running"
}

watchdog_loop() {
    log "Watchdog started — monitoring every 30s"
    while true; do
        load_services
        for svc in "${SERVICES[@]}"; do
            IFS=':' read -r name cmd pid_file log_file <<< "$svc"
            if [ -f "$pid_file" ]; then
                local pid=$(cat "$pid_file")
                if ! kill -0 "$pid" 2>/dev/null; then
                    warn "$name crashed — restarting"
                    rm -f "$pid_file"
                    start_service "$name" "$cmd" "$pid_file" "$log_file"
                fi
            else
                start_service "$name" "$cmd" "$pid_file" "$log_file"
            fi
        done
        sleep 30
    done
}

case "${1:-}" in
    start)
        start_all
        if [ "${2:-}" = "--watchdog" ]; then
            watchdog_loop
        fi
        ;;
    stop)
        stop_all
        ;;
    restart)
        stop_all
        sleep 2
        start_all
        ;;
    status)
        status_all
        ;;
    watchdog)
        start_all
        watchdog_loop
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|watchdog} [--watchdog]"
        ;;
esac
