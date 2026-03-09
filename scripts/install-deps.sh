#!/data/data/com.termux/files/usr/bin/bash
# Install required Termux packages
set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log_ok()   { echo -e "${GREEN}[OK]${NC}   $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_info() { echo -e "${CYAN}[INFO]${NC} $1"; }

log_info "Updating package repositories..."
pkg update -y 2>/dev/null || { echo "Retrying..."; yes | pkg update; }
pkg upgrade -y 2>/dev/null || true

PACKAGES=(
  nodejs-lts    # Node.js LTS runtime (>= 22) + npm
  git           # Git (some npm packages need it)
  python=3.13.12        # Python (node-gyp build scripts)
  make          # Build automation (node-gyp)
  cmake         # Cross-platform builds (koffi, argon2)
  clang         # C/C++ compiler
  tmux          # Terminal multiplexer (persistent sessions)
  binutils      # Essential build tools (ar, nm, etc)
  curl          # HTTP client
  wget          # File downloader
)

log_info "Installing ${#PACKAGES[@]} packages..."
for pkg_name in "${PACKAGES[@]}"; do
  if dpkg -s "$pkg_name" &>/dev/null; then
    log_ok "$pkg_name (already installed)"
  else
    if pkg install -y "$pkg_name" 2>/dev/null; then
      log_ok "$pkg_name installed"
    else
      log_fail "$pkg_name failed to install"
    fi
  fi
done

# Install PyYAML (needed for .skill packaging)
# Termux uses pip3, not pip. Skip gracefully if unavailable.
if command -v pip3 >/dev/null 2>&1; then
  if pip3 install pyyaml 2>/dev/null; then
    log_ok "PyYAML installed"
  else
    log_warn "PyYAML install failed (non-critical, skipping)"
  fi
elif command -v python3 >/dev/null 2>&1; then
  if python3 -m pip install pyyaml 2>/dev/null; then
    log_ok "PyYAML installed via python3 -m pip"
  else
    log_warn "PyYAML install failed (non-critical, skipping)"
  fi
elif command -v python >/dev/null 2>&1; then
  if python -m pip install pyyaml 2>/dev/null; then
    log_ok "PyYAML installed via python -m pip"
  else
    log_warn "PyYAML install failed (non-critical, skipping)"
  fi
else
  log_warn "pip not found — PyYAML skipped (non-critical)"
fi

# Verify Node.js
if command -v node >/dev/null 2>&1; then
  NODE_VER=$(node -v | tr -d 'v')
  MAJOR=$(echo "$NODE_VER" | cut -d. -f1)
  if [ "${MAJOR:-0}" -ge 22 ] 2>/dev/null; then
    log_ok "Node.js v${NODE_VER} verified (>= 22)"
  else
    log_fail "Node.js v${NODE_VER} is too old. Need >= 22."
    exit 1
  fi
else
  log_fail "Node.js not found after installation"
  exit 1
fi

# Upgrade npm to specific version
if command -v npm >/dev/null 2>&1; then
  log_info "Upgrading npm to v11.12.0..."
  npm install -g npm@11.12.0 2>/dev/null || log_warn "Failed to upgrade npm"
fi

# Verify npm
if command -v npm >/dev/null 2>&1; then
  log_ok "npm $(npm -v) verified"
else
  log_fail "npm not found"
  exit 1
fi

# Acquire wakelock
if command -v termux-wake-lock >/dev/null 2>&1; then
  termux-wake-lock 2>/dev/null || true
  log_ok "Wakelock acquired (prevents sleep)"
fi

echo ""
log_ok "All dependencies installed successfully"
