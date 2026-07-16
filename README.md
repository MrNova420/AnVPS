<p align="center">
  <br>
  <b>AnVPS</b><br>
  <i>Android Virtual Private Server</i><br><br>
  <a href="https://github.com/anvps/anserver"><img src="https://img.shields.io/badge/version-1.0.0-blue.svg" alt="Version"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License"></a>
  <a href="https://github.com/anvps/anserver/security/policy"><img src="https://img.shields.io/badge/security-policy-red.svg" alt="Security"></a>
  <br>
  <a href="#-quick-start">Quick Start</a> •
  <a href="#-features">Features</a> •
  <a href="#-installation">Installation</a> •
  <a href="#-architecture">Architecture</a> •
  <a href="#-security">Security</a> •
  <a href="#-profiles">Profiles</a>
</p>

---

**AnVPS** transforms any Android device into a self-managed, auto-healing, privacy-hardened virtual private server. One command install. Zero configuration. Runs on **32MB to 512MB+** RAM. Rooted and unrooted.

```bash
curl -sL https://raw.githubusercontent.com/anvps/anserver/main/setup/install.sh | bash
```

## Quick Start

```bash
anvps status             # System overview
anvps service setup      # Install default services
anvps monitor            # Live resource monitor
anvps security status    # Check security posture
```

## Features

### Core Platform
| | Feature | Detail |
|---|---|---|
| 🚀 | **Auto-tier detection** | RAM-detected: shadow (32MB) → lite → standard → full (512MB+) |
| 📦 | **Zero-dependency install** | One `curl \| bash` command, everything auto-configures |
| 🔄 | **Self-managing** | Auto-updates, auto-backup, auto-heal, log rotation, disk cleanup |
| 📱 | **Universal** | Unrooted (Termux+Proot) and rooted (Docker+chroot) support |

### Services
| Service | Port | Description | 32MB | 512MB |
|---------|------|-------------|------|-------|
| SSH | 7022 | Dropbear or OpenSSH | ✅ | ✅ |
| HTTP | 7080 | Shell/busybox/Python/FastAPI | ✅ | ✅ |
| Database | 7306 | SQLite/MariaDB/PostgreSQL | ✅ | ✅ |
| File Server | 7444 | HTTP upload/download | ✅ | ✅ |
| Containers | — | Docker (rooted) / Proot (unrooted) | ❌ | ✅ |
| Code Server | 7443 | VS Code in browser | ❌ | ✅ |
| VPN | 7518 | WireGuard auto-config | ✅ | ✅ |
| Tunnels | — | Cloudflare/ngrok/bore | ✅ | ✅ |

### Management Interfaces
- **CLI**: 18 commands via `anvps` command
- **Web Dashboard**: FastAPI + React (128MB+) or 5KB static HTML (32MB)
- **Telegram Bot**: Full Python or zero-dep shell version
- **Discord Bot**: Full Python or zero-dep shell version

### Security & Privacy
| Level | Features |
|-------|----------|
| 🔒 **Normal** | SSH on non-standard port, firewall, auto-updates, fail2ban, TLS |
| 🛡️ **Hardened** | Encrypted storage, DNS over HTTPS, MAC randomization, key rotation |
| 👻 **Stealth** | Tor routing, VPN kill switch, port knocking, traffic shaping, decoy services |
| 💀 **Ghost** | Tamper detection, auto-wipe, dead man switch, remote wipe, process hiding |

## Installation

### Requirements
- Android 7+ (unrooted) or any Android (rooted)
- **32MB** RAM minimum (shadow tier)
- 200MB+ free storage
- Internet connection

### One Command
```bash
curl -sL https://raw.githubusercontent.com/anvps/anserver/main/setup/install.sh | bash
```

The installer automatically detects your RAM, root status, and Android version — selecting the optimal tier and defaults.

### Manual
```bash
git clone https://github.com/anvps/anserver.git
cd anserver
bash setup/install.sh        # Main install
bash setup/root-enable.sh    # Run separately on rooted devices
```

## Architecture

```
                  ┌──────────────────────────────────┐
                  │        Management Plane           │
                  │  CLI · Web UI · Telegram · Discord │
                  └──────────────┬───────────────────┘
                                 │
                  ┌──────────────▼───────────────────┐
                  │         Core Engine               │
                  │  Supervisor · Health Check        │
                  │  Auto-Update · Security Scanner   │
                  │  Tamper Detection · Encrypt FS    │
                  └──────────────┬───────────────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                        │                        │
   ┌────▼────┐            ┌──────▼──────┐          ┌─────▼─────┐
   │ Services │            │  Security   │          │ Networking │
   │ SSH      │            │  Tor        │          │ Cloudflare │
   │ HTTP     │            │  Obfuscate  │          │ ngrok      │
   │ Database │            │  Stealth    │          │ WireGuard  │
   │ VPN      │            │  Killswitch │          │ DDNS       │
   └──────────┘            └─────────────┘          └────────────┘
                                 │
                  ┌──────────────▼───────────────────┐
                  │         RAM Tier Layer            │
                  │  Shadow · Lite · Standard · Full  │
                  └──────────────────────────────────┘
```

## Profiles

| Profile | RAM | Security | Use Case |
|---------|-----|----------|----------|
| `shadow` | 32MB | High | Ultra-light, stealth, SSH + shell only |
| `minimal` | 64MB | Medium | SSH-only, low resource |
| `webhost` | 128MB | Medium | Web server + database |
| `dev` | 128MB | Medium | Code server + containers |
| `full` | 512MB | Medium | Everything enabled |
| `hardened` | 128MB | High | Enterprise-grade security |
| `stealth` | 128MB | Maximum | Full anonymity + Tor |
| `ghost` | 32MB | Extreme | Counter-forensics, ephemeral |

```bash
anvps config load shadow    # Switch to 32MB shadow mode
anvps config load stealth   # Switch to stealth anonymity mode
```

## CLI Command Reference

| Command | Description |
|---------|-------------|
| `anvps status` | System overview |
| `anvps service list\|install\|start\|stop` | Service management |
| `anvps monitor [interval]` | Live resource monitor |
| `anvps update` | Run auto-updates |
| `anvps backup create\|list\|restore` | Backup management |
| `anvps tunnel start\|stop\|status` | Tunnel management |
| `anvps security status\|scan\|harden\|wipe` | Security tools |
| `anvps stealth on\|off\|status` | Stealth mode |
| `anvps obfuscate all\|hostname\|mac\|ssh\|http` | Device obfuscation |
| `anvps encrypt init\|unmount\|status` | Encrypted storage |
| `anvps tor start\|stop\|status` | Tor gateway |
| `anvps killswitch enable\|disable\|test` | VPN kill switch |
| `anvps tamper init\|verify\|check\|status` | Tamper detection |
| `anvps config show\|get\|set\|load` | Configuration |
| `anvps tier detect\|info\|select-ssh` | RAM tier tools |
| `anvps logs [service] [lines]` | View logs |
| `anvps doctor` | System diagnostics |

## Project Structure

```
anserver/
├── setup/            # Installers + service modules
├── src/
│   ├── cli/          # Unified CLI (anvps command)
│   ├── core/         # Supervisor, health, security, stealth, etc.
│   ├── web/          # FastAPI backend + frontend
│   ├── bots/         # Telegram + Discord (Python + shell)
│   └── tunnels/      # Cloudflare/ngrok/bore manager
├── config/           # Configuration + 8 profiles
├── docs/             # Documentation
└── tests/            # Unit tests
```

## Security

See [SECURITY.md](SECURITY.md) for:
- Reporting vulnerabilities
- Security feature documentation
- Best practices

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Bug reports and feature requests
- Pull request guidelines
- Code style and testing

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history.

## License

MIT — See [LICENSE](LICENSE) for full text.
