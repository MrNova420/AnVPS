# Changelog

## [1.0.0] — 2024-07-16

### Added
- **Core platform**: One-command installer, auto-detection of environment (Termux/Linux/root)
- **CLI**: 18 commands — status, service, monitor, update, backup, tunnel, security, stealth, obfuscate, encrypt, tor, tamper, killswitch, tier, config, logs, doctor, help
- **Service manager**: Supervisor with watchdog, auto-heal, health checks
- **Auto-update**: Self-updating system with scheduled backups and log rotation
- **Security scanner**: Port scan, SSH audit, permission check, brute force detection
- **4 RAM tiers**: Auto-detect from 32MB (shadow) to 512MB+ (full) with appropriate defaults

### Services
- SSH (Dropbear for 32MB, OpenSSH for 128MB+)
- HTTP server (shell/busybox/Python auto-select)
- Database (SQLite, MariaDB, PostgreSQL installers)
- Docker (rooted) / Proot (unrooted) container support
- Code Server (VS Code in browser)
- File Server (HTTP upload/download)
- WireGuard VPN with auto-config
- Tunnels (Cloudflare, ngrok, bore)

### Management
- Web Dashboard (FastAPI + React or 5KB lightweight HTML)
- Telegram Bot (Python or zero-dep shell version)
- Discord Bot (Python or zero-dep shell version)

### Security
- **Stealth**: Port knocking, decoy services, traffic shaping, scheduled availability
- **Obfuscation**: Hostname/MAC/SSH keys/HTTP headers randomization
- **Tor**: SOCKS5 gateway for anonymous routing
- **VPN kill switch**: iptables leak protection
- **Encrypted storage**: encfs/gocryptfs at rest
- **Tamper detection**: Integrity checksums, auto-wipe on violation
- **Dead man switch**: Configurable offline timeout → secure wipe
- **Remote wipe**: Telegram/Discord triggered data destruction

### Config
- 65 configuration options across 8 profiles
- Profiles: minimal, webhost, dev, full, shadow, hardened, stealth, ghost

### Profiles
| Profile | RAM | Security | Use Case |
|---------|-----|----------|----------|
| shadow | 32MB | High | Ultra-light, stealth |
| minimal | 64MB | Medium | SSH-only |
| webhost | 128MB | Medium | Web hosting |
| dev | 128MB | Medium | Development |
| full | 512MB | Medium | Everything |
| hardened | 128MB | High | Enterprise |
| stealth | 128MB | Maximum | Anonymity |
| ghost | 32MB | Extreme | Counter-forensics |

### Notes
- Android 7+ required (unrooted) or any Android (rooted)
- Minimum 32MB RAM for shadow tier
- All bash scripts pass `bash -n` syntax validation
- 56 source files, 37 shell scripts, 4 Python modules
