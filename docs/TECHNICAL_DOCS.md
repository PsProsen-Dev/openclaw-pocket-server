# Technical Documentation for Developers (RTX⚡ Edition)

## Installed Components
The OpenClaw-On-Android installer sets up infrastructure, platform packages, and the complete tool arsenal across multiple package managers. **All components, including core infrastructure and the extensive tool suite, are now installed automatically** for a seamless "Zero-Interaction" experience.

### Core Infrastructure (RTX⚡1)
| Component | Role | Install Method |
| :--- | :--- | :--- |
| **git** | Version control, repo management | `pkg install` |
| **curl** | Network operations | `pkg install` |

### Agent Platform Runtime Dependencies (RTX⚡2)
These are controlled by the platform's `config.env` flags. For the OpenClaw platform, the following are auto-deployed:

| Component | Role | Install Method |
| :--- | :--- | :--- |
| **pacman** | Package manager for glibc (v2) | `pkg install` |
| **glibc-runner** | glibc dynamic linker for Android | `pacman -Sy` |
| **Node.js v22+** | Glibc-native JavaScript runtime | Direct download / Wrapped |
| **Python/Make/Clang/Binutils** | Native module build toolchain | `pkg install` |

### OpenClaw Platform
| Component | Role | Install Method |
| :--- | :--- | :--- |
| **OpenClaw** | AI agent platform (core) | `npm install -g` |
| **clawdhub** | Skill manager for OpenClaw | `npm install -g` |
| **PyYAML** | YAML parser for .skill packaging | `pip install` |
| **libvips** | Image processing (sharp) headers | `pkg install` |

### Master Arsenal (RTX⚡3 - Auto-Installed Tools)
All tools below are now installed automatically if missing, removing the need for manual Y/n prompts.

| Component | Role | Install Method |
| :--- | :--- | :--- |
| **QWEN Code CLI** | Primary AI Coding Companion | `@qwen-code/qwen-code@latest` |
| **Gemini CLI** | Google's AI Interface | `@google/gemini-cli` |
| **code-server** | FHS-Integrated VS Code IDE | Direct FHS Deployment |
| **Playwright** | Glibc-Native Browser Automation | Internal FHS Install |
| **Chromium** | Headless Engine for AI Agents | Bundled with Playwright |
| **Homebrew** | Containerized Linux Package Manager | `proot-distro` integration |
| **tmux / ttyd** | Terminal multiplexing & Web UI | `pkg install` |
| **dufs** | High-performance File Server | `pkg install` |
| **android-tools** | ADB for System Optimizations | `pkg install` |

> [!IMPORTANT]
> `Claude Code` and `Codex CLI` have been REMOVED to streamline the framework and focus on the superior QWEN/Gemini/FHS integration.

---

## Project Structure
`OpenClaw-On-Android/`
├── **bootstrap.sh**                # One-liner downloader/installer
├── **install.sh**                  # "Zero-Interaction" entry point
├── **oca.sh**                      # **Master CLI** (Unified controller)
├── **update-core.sh**              # Lightweight core engine updater
├── **uninstall.sh**                # Clean removal orchestrator
├── **patches/**
│   ├── **glibc-compat.js**         # Node.js runtime/OS compatibility layer
│   ├── **argon2-stub.js**          # code-server native module patch
│   └── **systemctl**               # systemd stub for service simulation
├── **scripts/**
│   ├── **lib.sh**                  # Shared RTX-grade logic & mirrors
│   ├── **install-glibc.sh**        # RTX⚡2: glibc initialization
│   ├── **install-nodejs.sh**       # RTX⚡2: Node.js wrapper deployment
│   ├── **install-chromium.sh**     # RTX⚡3: Browser engine deployment
│   ├── **install-playwright.sh**   # RTX⚡3: Playwright FHS integration
│   ├── **install-code-server.sh**  # RTX⚡3: VS Code FHS setup
│   └── **setup-env.sh**            # Environment & Locale configuration
├── **platforms/openclaw/**
│   ├── **config.env**              # Precision dependency flags
│   ├── **install.sh**              # Platform-specific injection
│   └── **status.sh**               # Local status reporter
└── **docs/**
    └── **TECHNICAL_DOCS.md**       # This document

---

## Architecture: The RTX Dual-Engine
The project uses a **Platform-Plugin Architecture** coupled with a **Dual-Engine FHS Container**:

┌─────────────────────────────────────────────────────────────┐
│             **oca** Master CLI (Command & Control)              │
│  ── Orchestrates Shell, Services, Installs, and Maintenance │
├─────────────────────────────────────────────────────────────┤
│  **FHS Dual-Engine (Debian Container)**                         │
│  ── Provides a standard Glibc environment inside Termux.   │
│  ── Powers Code-Server, Playwright, and Go natively.       │
├─────────────────────────────────────────────────────────────┤
│  **Dependency Layers**                                          │
│  ── RTX⚡1: Core Infrastructure (Immutable)                │
│  ── RTX⚡2: Platform Runtime (Glibc, Node, Build Tools)     │
│  ── RTX⚡3: The Master Arsenal (Automated Tool Deployment)   │
└─────────────────────────────────────────────────────────────┘

### Dependency Control
Each platform declares its requirements in `config.env`. The framework then automatically injects these into either the Termux layer or the FHS layer based on compatibility.

```bash
# platforms/openclaw/config.env
PLATFORM_NEEDS_GLIBC=true
PLATFORM_NEEDS_NODEJS=true
PLATFORM_NEEDS_BUILD_TOOLS=true
```

## Detailed Installation Flow (8-Step Auto-Flow)

1.  **Environment Check:** Verifies CPU, space, and root status (via `su -c "id"`).
2.  **Total Auto-Install Selection:** Configures the arsenal to `TRUE` by default for a ready-to-use setup.
3.  **Core Infrastructure (RTX⚡1):** Prepares git and mirror sources.
4.  **FHS Runtime Initializing (RTX⚡2):** Deploys the Debian container and glibc-runner.
5.  **Platform Injection:** Installs OpenClaw package and applies compatibility patches.
6.  **Arsenal Deployment (RTX⚡3):** FHS-level installation of Code-Server, Playwright, QWEN, and Gemini.
7.  **Environment Finalization:** Configures locales (`C.UTF-8`) and path symlinks.
8.  **Verification:** Runs the high-fidelity test suite to ensure 100% operational status.

---
**RTX⚡ Protocol:** *Build fast. Stay clean. Evolve instantly.*
