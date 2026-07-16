# AnVPS Command Reference

## CLI Commands

### `anvps status`

Display system overview — CPU, memory, disk usage, running services, network status, and security state.

```
$ anvps status

  AnVPS v1.0.0 — System Status
  ────────────────────────────────────────

  SYSTEM
  Uptime:    up 3 days, 2 hours
  Memory:    185M/982M
  Storage:   45M/128G
  CPU Load:  0.12 0.08 0.05

  SERVICES
  ssh: running (PID 3124)
  web: running (PID 3156)
  tor: running (PID 3201)

  NETWORK
  SSH:       port 7022 (active)
  Web:       port 7080 (active)

  SECURITY
  Stealth:   ACTIVE
  Obfuscate: ACTIVE
```

### `anvps service`

Manage services — install, start, stop, restart, list.

```
Usage: anvps service {list|install|start|stop|restart|setup} [name]

Commands:
  list                          Show available and running services
  install <name>                Install a service
  start <name>                  Start a service
  stop <name>                   Stop a service
  restart <name>                Restart a service
  setup                         Install and configure default services

Services:
  ssh           SSH server (Dropbear or OpenSSH)
  web           HTTP server (shell/busybox/Python)
  database      SQLite / MariaDB / PostgreSQL
  code-server   VS Code in browser
  files         HTTP file server
  docker        Container support (rooted) / Proot (unrooted)
  vpn           WireGuard VPN
  tunnel        Cloudflare/ngrok/bore
  tor           Tor gateway
  encrypt       Encrypted storage (encfs/gocryptfs)
  telegram-bot  Telegram bot
  discord-bot   Discord bot
```

### `anvps monitor [interval]`

Live resource monitor with configurable refresh interval (default: 2 seconds).

```
$ anvps monitor 1

  AnVPS Monitor — 2024-07-16 14:30:00
  ────────────────────────────────────────

  CPU:    0.15 0.10 0.06
  Memory: 185M/982M
  Disk:   45M/128G (0%)

  Services:
  * ssh (PID 3124, 2.1M)
  * web (PID 3156, 4.3M)
  * tor (PID 3201, 8.7M)

  Network:
  LISTEN 0.0.0.0:7022
  LISTEN 0.0.0.0:7080
  LISTEN 127.0.0.1:9050
```

### `anvps update`

Run the auto-update cycle — checks for package updates, updates AnVPS itself, rotates logs, cleans temp files, and creates a backup (if enabled).

### `anvps backup`

Backup management — create, list, and restore compressed snapshots.

```
Usage: anvps backup {create|list|restore} [file]

Commands:
  create          Create a new backup
  list            List available backups
  restore [file]  Restore from backup (default: latest)

$ anvps backup create
[-] Backup: 4.2M

$ anvps backup list
  /home/user/.anvps/backup/anvps_backup_20240716_143000.tar.gz (4.2M)
```

### `anvps tunnel`

Tunnel management — start/stop Cloudflare Tunnel, ngrok, or bore for public access.

```
Usage: anvps tunnel {start|stop|restart|status} [cloudflare|ngrok|bore|all]

Commands:
  start [type]    Start tunnel(s)
  stop [type]     Stop tunnel(s)
  restart         Restart all tunnels
  status          Show tunnel status
```

### `anvps security`

Security tools — scan, harden, and wipe the system.

```
Usage: anvps security {status|scan|harden|wipe}

Commands:
  status          Show security posture overview
  scan            Run full security audit
  harden          Apply security hardening
  wipe [reason]   Securely destroy all AnVPS data

$ anvps security scan
=== Security Scan: 2024-07-16 14:30:00 ===
INFO: SSH on non-default port 7022
INFO: Password authentication disabled
WARN: 15 failed SSH login attempts
INFO: 3 package updates available
---
Issues found: 1
```

### `anvps stealth`

Stealth mode — enable/disable anonymity features.

```
Usage: anvps stealth {enable|disable|status|knock <host>}

Commands:
  enable|on       Enable stealth mode (port knocking, decoy services, traffic shaping)
  disable|off     Disable stealth mode
  status          Show stealth mode status
  knock <host>    Send port knock sequence to open service

$ anvps stealth on
Stealth mode active
  Active window: 0:00 - 24:00
  Decoy ports: 22, 80, 443
  Knock sequence: 7000,8000,9000 (open) / 9000,8000,7000 (close)
```

### `anvps obfuscate`

Device obfuscation — randomize identifiers that could identify the device.

```
Usage: anvps obfuscate {all|hostname|ssh|mac|http|status}

Commands:
  all             Run full device obfuscation
  hostname        Randomize device hostname
  ssh             Rotate SSH host keys
  mac             Randomize MAC addresses (requires root)
  http            Randomize HTTP User-Agent
  status          Show obfuscation status
```

### `anvps encrypt`

Encrypted storage management — encrypt AnVPS data at rest.

```
Usage: anvps encrypt {init|unmount|restart|status}

Commands:
  init|mount|start    Initialize and mount encrypted storage
  unmount|stop        Unmount encrypted storage
  restart             Remount encrypted storage
  status              Show encryption status

Requires: gocryptfs or encfs
Data directory: ~/.anvps/data/private
```

### `anvps tor`

Tor gateway — route traffic through the Tor network for anonymity.

```
Usage: anvps tor {start|stop|restart|status}

Commands:
  start|up        Start Tor SOCKS5 proxy
  stop|down       Stop Tor
  restart         Restart Tor
  status          Show Tor status (including connectivity check)

SOCKS5 proxy: 127.0.0.1:9050
```

### `anvps killswitch`

VPN kill switch — prevent traffic leaks if VPN disconnects.

```
Usage: anvps killswitch {enable|disable|status|test}

Commands:
  enable|on       Enable kill switch (blocks all non-VPN traffic)
  disable|off     Disable kill switch
  status          Show kill switch status
  test            Test for DNS/IP leaks

Requires: root + iptables
```

### `anvps tamper`

Tamper detection — integrity verification and automatic countermeasures.

```
Usage: anvps tamper {init|verify|check|wipe|reset|status}

Commands:
  init            Initialize integrity checksums
  verify          Verify file integrity against checksums
  check           Run scheduled check (failed auth + dead man timer)
  wipe [reason]   Trigger secure wipe
  reset           Reset tamper state
  status          Show tamper detection status
```

### `anvps config`

Configuration management — view and modify settings, load profiles.

```
Usage: anvps config {show|get|set|load} [key] [value]

Commands:
  show                    Display all configuration
  get <key>               Get a specific setting
  set <key> <value>       Set a configuration value
  load <profile>          Load a profile preset

Profiles:
  shadow      32MB ultra-light, maximum stealth
  minimal     SSH-only, low resource usage
  webhost     Web server + database hosting
  dev         Development environment
  full        Everything enabled
  hardened    Enterprise-grade security
  stealth     Maximum anonymity with Tor
  ghost       Extreme counter-forensics

$ anvps config set ANVPS_SSH_PORT 2222
[-] ANVPS_SSH_PORT=2222

$ anvps config load stealth
[-] Loaded profile: stealth
```

### `anvps tier`

RAM tier detection and component selection.

```
Usage: anvps tier {detect|tier|recommend|info}

Commands:
  detect          Print detected tier name (shadow/lite/standard/full)
  tier            Print human-readable tier name
  recommend       Recommend profile for current tier
  info            Show detailed tier information

$ anvps tier info

  Lightweight Auto-Detection
  ────────────────────────────────────────
  Detected RAM tier: Full (512MB+ everything)
  Recommended SSH:   openssh
  Recommended HTTPD: python
  Recommended Bots:  python
  Recommended Profile: full
```

### `anvps logs [service] [lines]`

View service logs (default: last 50 lines).

```
Usage: anvps logs [service] [lines]

$ anvps logs ssh 20
```

### `anvps doctor`

Run system diagnostics to verify installation integrity.

```
$ anvps doctor

  AnVPS Diagnostic
  ────────────────────────────────────────
  [PASS] test -d /home/user/.anvps
  [PASS] test -f /home/user/.anvps/etc/anvps.conf
  [PASS] command -v bash
  [PASS] command -v curl
  [PASS] kill -0 3124

  Results: 5/5 checks passed
```

### `anvps help`

Display this help text.

### `anvps --version`

Print version information.

## Telegram Bot Commands

Set environment variables:
```
ANVPS_TELEGRAM_BOT_TOKEN=your_token
ANVPS_TELEGRAM_CHAT_ID=your_chat_id
```

| Command | Description |
|---------|-------------|
| `/start` or `/help` | Welcome message and command list |
| `/status` | System status (uptime, CPU, memory) |
| `/services` | List running services |
| `/logs <name>` | View service logs |
| `/health` | Run health check |
| `/backup` | Create backup |
| `/update` | Run updates |

## Discord Bot Commands

Set environment variables:
```
ANVPS_DISCORD_BOT_TOKEN=your_token
ANVPS_DISCORD_CHANNEL_ID=your_channel_id
```

| Command | Description |
|---------|-------------|
| `an!help` | Command list |
| `an!status` | System status |
| `an!services` | List running services |
| `an!logs <name>` | View service logs |
| `an!health` | Run health check |
| `an!backup` | Create backup |
| `an!update` | Run updates |
