# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.0.x   | ✅ Active |

## Reporting a Vulnerability

AnVPS takes security seriously. If you discover a vulnerability:

1. **Do not** open a public issue
2. Email: security@anvps.dev (placeholder — replace with real contact)
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Affected versions
   - Potential impact

You should receive a response within 48 hours. We will keep you informed of the fix progress.

## Security Features

AnVPS includes defense-in-depth:

| Layer | Protection |
|-------|-----------|
| Network | Tor, VPN kill switch, DNS over HTTPS, port knocking |
| Device | Hostname/MAC/SSH key randomization, HTTP header spoofing |
| Data | Encrypted storage at rest (encfs/gocryptfs), encrypted backups |
| Runtime | Tamper detection, integrity verification, auto-wipe |
| Monitoring | Failed auth limits, dead man switch, remote wipe |

## Best Practices

1. **Always use SSH keys** — password auth is disabled by default
2. **Enable stealth mode** in untrusted environments
3. **Use encrypted storage** for sensitive data
4. **Set a dead man timer** if unattended
5. **Keep AnVPS updated** — `anvps update` runs automatically
6. **Run `anvps security scan`** regularly
7. **Use Tor** when anonymity is critical

## Disclosure Policy

- Vulnerabilities are disclosed after a fix is released
- We credit reporters (with permission) in release notes
- Embargo period: 90 days for critical issues
