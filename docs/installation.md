# Installation Guide

## Quick Start

```bash
curl -sL https://raw.githubusercontent.com/anvps/anserver/main/setup/install.sh | bash
```

The installer automatically:
- Detects Termux vs Linux environment
- Detects root availability
- Detects total RAM and selects optimal tier
- Installs tier-appropriate packages
- Generates SSH keys
- Creates configuration with tier-appropriate defaults
- Sets up auto-start (Termux boot or systemd)

## One-Line Install

### Unrooted Android (Termux)

```bash
# Install Termux from F-Droid first, then:
pkg update && pkg install -y curl git
curl -sL https://raw.githubusercontent.com/anvps/anserver/main/setup/install.sh | bash
```

### Rooted Android

```bash
curl -sL https://raw.githubusercontent.com/anvps/anserver/main/setup/install.sh | bash
sudo bash ~/.anvps/setup/root-enable.sh
```

### Linux (generic)

```bash
curl -sL https://raw.githubusercontent.com/anvps/anserver/main/setup/install.sh | bash
```

## Manual Installation

```bash
git clone https://github.com/anvps/anserver.git
cd anserver
bash setup/install.sh
```

## Installation Options

### Override RAM Tier

```bash
# Force a specific tier regardless of detected RAM
bash setup/install.sh --tier shadow     # 32MB ultra-light
bash setup/install.sh --tier standard   # 128MB balanced
bash setup/install.sh --tier full       # 512MB everything
```

### Custom Directory

```bash
ANVPS_DIR=/custom/path bash setup/install.sh
```

### Offline/From Repo

```bash
# Clone and run from local copy
git clone https://github.com/anvps/anserver.git
cd anserver
bash setup/install.sh

# Then for root-specific features:
bash setup/root-enable.sh
```

## Post-Installation

### Verify Installation

```bash
anvps doctor         # Run diagnostics
anvps status         # View system status
anvps --version      # Check version
```

### Install Services

```bash
anvps service setup              # Install all default services
anvps service list               # See available services
anvps service install database   # Install specific service
anvps service start ssh          # Start a service
```

### Switch Profile

```bash
anvps config load shadow    # 32MB ultra-light mode
anvps config load stealth   # Maximum anonymity
anvps config load full      # Everything enabled
```

## First-Time Setup

1. **Access the web dashboard**: Open `http://localhost:7080` in a browser
2. **Connect via SSH**: `ssh -p 7022 user@device-ip`
3. **Configure bots**: Set tokens in `~/.anvps/etc/anvps.conf`
4. **Enable tunnels**: `anvps tunnel start` (requires Cloudflare/ngrok token)
5. **Enable security**: `anvps stealth on && anvps obfuscate all`

## Updating

```bash
anvps update     # Auto-update (runs on schedule by default)
```

Or manually:
```bash
git pull && bash setup/install.sh
```

## Troubleshooting

### Check logs
```bash
anvps logs supervisor 50   # Last 50 lines of supervisor log
anvps logs ssh 100         # Last 100 lines of SSH log
```

### Run diagnostics
```bash
anvps doctor    # Full system check
```

### Common issues
- **"Command not found"**: Run `source ~/.bashrc` or restart Termux
- **SSH connection refused**: Check `anvps service start ssh`
- **Web UI not loading**: Check `anvps service start web`
- **Low memory warnings**: Switch to shadow profile: `anvps config load shadow`
