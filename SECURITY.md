# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| Latest (`master`) | ✅ Yes |
| Older releases | ❌ No — please update |

---

## Reporting a Vulnerability

If you discover a security vulnerability in OCA, **please do NOT open a public GitHub issue.**

Instead, report it privately via:

- **GitHub Security Advisories:** [Report a vulnerability](https://github.com/PsProsen-Dev/OpenClaw-On-Android/security/advisories/new)
- **Email:** Contact the maintainer via GitHub profile

Please include:
1. Description of the vulnerability
2. Steps to reproduce
3. Potential impact
4. Suggested fix (if any)

We aim to respond within **72 hours** and will credit you in the fix.

---

## Security Considerations

OCA runs with elevated privileges on Android (Termux + optional root). Key security notes:

- **SSH:** OCA sets up an SSH server on port 8022. Use strong passwords and consider key-based auth.
- **Root (`oca-root`):** The root wrapper limits which commands can be run as root. Never run untrusted scripts with `tsu`.
- **AI CLIs:** API keys are stored in environment variables. Keep your `.bashrc` private.
- **Network:** OCA binds services to `0.0.0.0` by default. Use a firewall or limit to local network.

---

## Scope

In scope:
- Installation scripts (`install.sh`, `bootstrap.sh`, `oca.sh`)
- Platform patches (`patches/`)
- Root access wrapper (`scripts/setup-root.sh`)

Out of scope:
- Upstream OpenClaw vulnerabilities → report to [openclaw](https://github.com/openclaw/openclaw)
- Third-party AI CLI tools (Claude, Gemini, Codex, Qwen)
