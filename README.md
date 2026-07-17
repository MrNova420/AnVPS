<p align="center">
  <br>
  <b>AnVPS</b><br>
  <i>Android Virtual Private Server</i><br><br>
  <a href="https://github.com/MrNova420/AnVPS"><img src="https://img.shields.io/badge/version-1.0.0-blue.svg" alt="Version"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License"></a>
  <br>
  <a href="#-one-command-install">Quick Start</a> •
  <a href="#-features">Features</a> •
  <a href="#-how-to-connect-remotely">Connect</a> •
  <a href="#-architecture">Architecture</a> •
  <a href="#-security">Security</a>
</p>

---

**AnVPS** transforms any Android device into a self-managed, auto-healing, privacy-hardened virtual private server. One command install. Zero configuration. Runs on **32MB to 512MB+** RAM. Rooted and unrooted.

## ⚡ One-Command Install

Copy-paste this into Termux:

```bash
curl -sL https://raw.githubusercontent.com/MrNova420/AnVPS/master/setup/install.sh | bash
```

That's it. The installer detects your RAM, sets up everything, and gives you SSH access on port **7022**.

After install, you get the `anvps` command:

```bash
anvps status          # See your system
anvps service setup   # Install all default services
```

## 🔌 How to Connect Remotely

### From another device on the same WiFi

```bash
ssh -p 7022 u0_aXXX@192.168.1.X
```

Find your IP with `anvps status` or `ip addr show`.

### From anywhere in the world (no public IP needed)

**bore tunnel (simplest, no account):**

```bash
anvps tunnel start bore
# Output: bore tunnel started (public at bore.pub:XXXXX)
# Then connect:
ssh -p XXXXX bore.pub
```

**Cloudflare Tunnel (faster, needs account):**

```bash
anvps tunnel start cloudflare
# Uses your Cloudflare token from config
```

**ngrok (easy, needs free account):**

```bash
anvps tunnel start ngrok
# Gives you a URL like https://xxxx.ngrok.io
```

### Make it survive phone reboots

1. Install [Termux:Boot](https://f-droid.org/packages/com.termux.boot/) from F-Droid
2. AnVPS already installed the boot script — it auto-starts after reboot

For Android 12+ phantom process killing, run once:

```bash
termux-wake-lock
```

## 📋 Commands at a Glance

| Command | What it does |
|---------|-------------|
| `anvps status` | System overview |
| `anvps service list` | See running services |
| `anvps tunnel start bore` | Public tunnel (connect from anywhere) |
| `anvps monitor` | Live dashboard |
| `anvps security scan` | Security check |
| `anvps stealth on` | Hide your VPS |
| `anvps config load ghost` | Ultra-stealth mode |
| `anvps logs ssh` | View SSH logs |
| `anvps doctor` | Diagnose issues |

## 📱 What You Get

| Service | Port | What |
|---------|------|------|
| SSH | 7022 | Remote shell (Dropbear or OpenSSH) |
| Web UI | 7080 | Dashboard in browser |
| File Server | 7444 | Upload/download files |
| Database | 7306 | SQLite/MySQL/PostgreSQL |
| Tunnels | — | Public URL (bore/ngrok/cloudflare) |
| Tor | 9050 | Anonymous routing |
| VPN | 7518 | WireGuard |

## 🔒 Security

Just run this after install:

```bash
anvps security harden     # Lock it down
anvps stealth on          # Hide from scanners
anvps obfuscate all       # Mask device identity
```

## Project Structure

```
anserver/
├── setup/            # Installers
├── src/
│   ├── cli/          # anvps command
│   ├── core/         # Engine (supervisor, health, security, stealth, etc.)
│   ├── web/          # Dashboard backend + frontend
│   ├── bots/         # Telegram + Discord bots
│   └── tunnels/      # bore/ngrok/cloudflare
├── config/           # Settings + profiles
├── docs/             # Documentation
└── tests/            # Unit tests
```

## License

MIT — See [LICENSE](LICENSE) for full text.
