#!/usr/bin/env bash
set -euo pipefail
# Lightweight HTTP server using busybox httpd or netcat
# Serves static files + CGI API endpoints

ANVPS_DIR="${HOME}/.anvps"
WEB_PORT="${ANVPS_WEB_PORT:-7080}"
WWW_DIR="${ANVPS_DIR}/data/sites/default"
CGI_DIR="${ANVPS_DIR}/tmp/cgi"
PID_FILE="${ANVPS_DIR}/services/web.pid"
LOG_FILE="${ANVPS_DIR}/logs/web.log"

mkdir -p "$WWW_DIR" "$CGI_DIR"

start() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then echo "HTTPD running (PID $pid)"; return 0; fi
        rm -f "$PID_FILE"
    fi

    if command -v busybox &>/dev/null && busybox httpd --help 2>/dev/null | grep -q "Usage"; then
        echo "Starting busybox httpd on port $WEB_PORT..."
        busybox httpd -p "0.0.0.0:$WEB_PORT" -h "$WWW_DIR" -c "$CGI_DIR" >> "$LOG_FILE" 2>&1 &
        local pid=$!; echo $pid > "$PID_FILE"
        sleep 1
        if kill -0 "$pid" 2>/dev/null; then echo "busybox httpd started (PID $pid)"; return 0; fi
    fi

    if command -v python3 &>/dev/null; then
        echo "Starting Python HTTP server on port $WEB_PORT..."
        cd "$WWW_DIR" && python3 -m http.server "$WEB_PORT" >> "$LOG_FILE" 2>&1 &
        local pid=$!; echo $pid > "$PID_FILE"
        sleep 1
        if kill -0 "$pid" 2>/dev/null; then echo "Python HTTPD started (PID $pid)"; return 0; fi
    fi

    echo "Starting shell HTTPD on port $WEB_PORT using netcat..."
    start_shell_httpd &
    local pid=$!; echo $pid > "$PID_FILE"
    sleep 1
    if kill -0 "$pid" 2>/dev/null; then echo "Shell HTTPD started (PID $pid)"; fi
}

start_shell_httpd() {
    local nc_cmd="nc"
    if command -v nc &>/dev/null; then
        nc_cmd="nc"
    elif command -v netcat &>/dev/null; then
        nc_cmd="netcat"
    fi
    local nc_args=""
    if echo "" | "$nc_cmd" -l -p "$WEB_PORT" -q 1 2>/dev/null; then
        nc_args="-l -p $WEB_PORT -q 1"
    elif echo "" | "$nc_cmd" -l "$WEB_PORT" 2>/dev/null; then
        nc_args="-l $WEB_PORT"
    elif echo "" | "$nc_cmd" -l -p "$WEB_PORT" 2>/dev/null; then
        nc_args="-l -p $WEB_PORT"
    fi
    while true; do
        printf "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n%s" "$(cat "${WWW_DIR}/index.html" 2>/dev/null || echo '<h1>AnVPS</h1>')" \
            | "$nc_cmd" $nc_args >> "$LOG_FILE" 2>&1 || true
    done
}

stop() {
    if [ -f "$PID_FILE" ]; then kill "$(cat "$PID_FILE")" 2>/dev/null || true; rm -f "$PID_FILE"; fi
    pkill -f "httpd.*$WEB_PORT" 2>/dev/null || true
    pkill -f "python3 -m http.server.*$WEB_PORT" 2>/dev/null || true
    pkill -f "nc -l.*$WEB_PORT" 2>/dev/null || true
    echo "HTTPD stopped"
}

case "${1:-start}" in
    start) start ;;
    stop) stop ;;
    restart) stop; sleep 1; start ;;
    status)
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            echo "HTTPD running (PID $(cat "$PID_FILE"))"
        else echo "HTTPD stopped"; fi
        ;;
    *) echo "Usage: $0 {start|stop|restart|status}" ;;
esac
