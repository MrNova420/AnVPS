#!/usr/bin/env bash
install_database() {
    local ENV_TYPE="$1"
    local ANVPS_DIR="${2:-${HOME}/.anvps}"
    local DB_TYPE="${3:-sqlite}"
    local DB_DIR="${ANVPS_DIR}/data/databases"

    mkdir -p "$DB_DIR"

    log "Installing database: $DB_TYPE..."
    case "$DB_TYPE" in
        sqlite)
            case "$ENV_TYPE" in
                termux) pkg install -y sqlite 2>/dev/null || true ;;
                linux)
                    if command -v apt &>/dev/null; then apt install -y sqlite3 2>/dev/null || true
                    elif command -v apk &>/dev/null; then apk add sqlite 2>/dev/null || true; fi
                    ;;
            esac
            log "SQLite installed — configuration stored in $DB_DIR"
            ;;

        mariadb|mysql)
            case "$ENV_TYPE" in
                termux)
                    pkg install -y mariadb 2>/dev/null || {
                        warn "MariaDB not available in Termux repos"
                        return
                    }
                    mysql_install_db --datadir="$DB_DIR/mysql" 2>/dev/null || true
                    ;;
                linux)
                    if command -v apt &>/dev/null; then
                        apt install -y mariadb-server 2>/dev/null || apt install -y mysql-server 2>/dev/null || true
                    elif command -v apk &>/dev/null; then
                        apk add mariadb mariadb-client 2>/dev/null || true
                    fi
                    if command -v mysql_install_db &>/dev/null; then
                        mysql_install_db --datadir="$DB_DIR/mysql" 2>/dev/null || true
                    fi
                    ;;
            esac
            if command -v mysqld &>/dev/null; then
                mysqld --datadir="$DB_DIR/mysql" --port=7306 --skip-networking=0 &
                sleep 2
                mysqladmin -u root password "anvps_root" 2>/dev/null || true
                mysql -u root -p"anvps_root" -e "CREATE DATABASE IF NOT EXISTS anvps;" 2>/dev/null || true
                log "MariaDB/MySQL installed on port 7306"
            fi
            ;;

        postgresql)
            case "$ENV_TYPE" in
                termux)
                    pkg install -y postgresql 2>/dev/null || {
                        warn "PostgreSQL not available in Termux repos"
                        return
                    }
                    ;;
                linux)
                    if command -v apt &>/dev/null; then
                        apt install -y postgresql 2>/dev/null || true
                    elif command -v apk &>/dev/null; then
                        apk add postgresql postgresql-client 2>/dev/null || true
                    fi
                    ;;
            esac
            if command -v initdb &>/dev/null; then
                initdb -D "$DB_DIR/postgres" 2>/dev/null || true
                pg_ctl -D "$DB_DIR/postgres" -l "${ANVPS_DIR}/logs/postgres.log" start 2>/dev/null || true
                log "PostgreSQL installed on port 5432"
            fi
            ;;
    esac
    log "Database ($DB_TYPE) installation complete"
}
