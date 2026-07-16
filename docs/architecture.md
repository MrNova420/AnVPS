# AnVPS Architecture

Version 1.0.0

## Overview

AnVPS transforms any Android device into a **self-managed**, **auto-healing**, **privacy-hardened** virtual private server. It uses a 6-layer architecture with adaptive component selection based on available RAM.

## Design Principles

1. **Zero configuration** — Single command install, everything auto-detected
2. **Adaptive** — Auto-selects components based on RAM (32MB → 512MB+)
3. **Modular** — Every feature is a toggleable plugin
4. **Privacy by default** — Security layers built in, not bolted on
5. **Self-managing** — Updates, backups, healing happen automatically

## Layer Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    L6: Management Plane                      │
│  CLI (anvps) │ Web Dashboard │ Telegram Bot │ Discord Bot   │
│  18 commands  │ FastAPI/React │ Python/Shell  │ Python/Shell │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────┐
│                    L5: Security & Privacy                    │
│  Tor Gateway │ VPN Kill Switch │ Stealth Mode │ Obfuscation │
│  Encrypted FS │ Tamper Detection │ Auto-Wipe │ Port Knocking │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────┐
│                    L4: Core Engine                           │
│  Supervisor │ Health Checker │ Auto-Updater │ Log Rotator   │
│  Watchdog │ Security Scanner │ Backup Manager │ Tier Switch │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────┐
│                    L3: Services                              │
│  SSH │ HTTP │ Database │ VPN │ File Server │ Code Server    │
│  Dropbear │ Busybox │ SQLite │ WireGuard │ Python HTTP       │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────┐
│                    L2: Networking                            │
│  Cloudflare Tunnel │ ngrok │ bore │ DDNS │ DNS over HTTPS    │
│  Firewall (iptables) │ WireGuard │ Tor │ Port Forwarding    │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────┐
│                    L1: RAM Tier Layer                        │
│  Shadow (32MB) │ Lite (64MB) │ Standard (128MB) │ Full (512+) │
│  Auto-detects at install, components selected per tier      │
└─────────────────────────────────────────────────────────────┘
```

## Tier Architecture

### Shadow (32MB RAM)
```
Memory budget:
  Linux kernel + Android base  ~12MB
  Dropbear SSH                  ~1MB
  Shell HTTPD (busybox)         ~0.5MB
  Supervisor + healthcheck      ~1MB
  bore tunnel                   ~2MB
  WireGuard                     ~2MB
  Shell bots (curl+API)         ~0.5MB
  bash + core utils             ~4MB
  ─────────────────────────────────
  Total:                       ~23MB
  Free:                         ~9MB (headroom)
```

### Standard (128MB RAM)
Adds: Python FastAPI, full web dashboard, Python Telegram/Discord bots, SQL database, OpenSSH, cloudflared tunnel, monitoring suite.

### Full (512MB+ RAM)
Adds: Docker containers, Code Server (Node.js), MariaDB/PostgreSQL, full monitoring, all services concurrently.

## Component Selection Matrix

| Component | Shadow (32MB) | Lite (64MB) | Standard (128MB) | Full (512MB+) |
|-----------|:---:|:---:|:---:|:---:|
| SSH | Dropbear | Dropbear | OpenSSH | OpenSSH |
| HTTP | Shell | Busybox | Busybox | Python/FastAPI |
| Web UI | 5KB HTML | 5KB HTML | Full React | Full React |
| Database | SQLite CLI | SQLite CLI | SQLite+ | Full SQL |
| File Server | Shell | Shell | Python | Python |
| Docker | — | — | — | ✅ |
| Code Server | — | — | — | ✅ |
| VM Monitor | Minimal | Basic | Standard | Full |
| Bot | Shell+curl | Shell+curl | Python | Python |
| Tunnel | bore | bore | Cloudflare | Cloudflare |
| Tor | opt-in | opt-in | opt-in | opt-in |
| Encrypted FS | — | opt-in | ✅ | ✅ |
| Stealth | ✅ | ✅ | ✅ | ✅ |

## Data Flow

```
User Command (CLI/Web/Bot)
        │
        ▼
    ┌─────────┐
    │  anvps  │  CLI entry point, dispatches to modules
    └────┬────┘
         │
    ┌────▼────┐
    │  Core   │  supervisor.sh, healthcheck.sh, autoupdate.sh
    └────┬────┘
         │
    ┌────▼──────────────────────────────────────┐
    │  Service Scripts (src/core/*.sh)          │
    │  start/stop/restart individual services   │
    └────┬──────────────────────────────────────┘
         │
    ┌────▼──────────────────────────────────────┐
    │  Android/Linux Layer                      │
    │  Termux, Proot, Docker, iptables, systemd │
    └───────────────────────────────────────────┘
```

## File System Layout

```
~/.anvps/                           Runtime directory
├── etc/                            Configuration
│   ├── anvps.conf                  Main config (65 settings)
│   ├── services.conf               Custom service definitions
│   ├── profiles/                   8 profile presets
│   ├── torrc                       Tor configuration
│   └── .stealth_enabled            Stealth mode flag
├── data/                           Persistent data
│   ├── ssh/                        SSH host keys
│   ├── tor/                        Tor data
│   ├── encrypted/                  Encrypted storage backend
│   ├── private/                    Mount point for encrypted FS
│   ├── databases/                  SQLite/MySQL data
│   ├── sites/                      Web server files
│   ├── files/                      File server share
│   └── vpn/                        WireGuard configs
├── services/                       PID files for running services
├── logs/                           Service logs
├── backup/                         Compressed backups
├── tmp/                            Temporary files
├── ssl/                            SSL certificates
├── tunnels/                        Tunnel binaries
└── src/                            Source code mirror
    ├── cli/                        CLI tool
    ├── core/                       Core engine modules
    ├── web/                        Web dashboard
    ├── bots/                       Chat bots
    └── setup/                      Service installers
```
