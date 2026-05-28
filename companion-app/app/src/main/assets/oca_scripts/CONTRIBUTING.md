# Contributing to OpenClaw on Android (OCA)

Thank you for your interest in contributing! 🎉

OCA is a community-driven project to turn Android phones into powerful 24/7 AI servers. Every contribution — bug reports, feature requests, code, docs — is welcome.

---

## 🐛 Reporting Bugs

1. Check [existing issues](https://github.com/PsProsen-Dev/OpenClaw-On-Android/issues) first
2. Open a new issue with:
   - Your Android version and device model
   - Termux version (`termux-info`)
   - Full error output (paste in code block)
   - Steps to reproduce

---

## 💡 Feature Requests

Open a [GitHub Discussion](https://github.com/PsProsen-Dev/OpenClaw-On-Android/discussions) with:
- What you want to do
- Why it would help others
- Any ideas on implementation

---

## 🛠 Code Contributions

### Prerequisites

- Android device with Termux (for testing)
- Basic knowledge of bash scripting
- Git

### Setup

```bash
# Fork and clone
git clone https://github.com/YOUR_USERNAME/OpenClaw-On-Android.git
cd OpenClaw-On-Android

# Create a feature branch
git checkout -b feature/your-feature-name
```

### Guidelines

- **Shell scripts:** Follow existing code style. Use `set -euo pipefail`. Use `scripts/lib.sh` helpers.
- **Docs:** Use Mintlify `.mdx` format for documentation files in `docs/`
- **Testing:** Test on a real Termux device before submitting
- **Commits:** Use clear, descriptive commit messages

### Submitting a PR

1. Push your branch to your fork
2. Open a pull request against `master`
3. Describe what your PR does and why
4. Link any related issues

---

## 📁 Project Structure

```
OpenClaw-On-Android/
├── install.sh          # Main installer (8-step process)
├── bootstrap.sh        # One-liner entry point
├── oca.sh              # OCA CLI (update/status/install/uninstall)
├── scripts/            # Shared install scripts
├── platforms/openclaw/ # OpenClaw platform plugin
├── patches/            # glibc/bionic compatibility patches
├── tests/              # Install verification
└── docs/               # Mintlify documentation
```

---

## 🙏 Credits

Built with ⚡ by [PsProsen-Dev](https://github.com/PsProsen-Dev).
