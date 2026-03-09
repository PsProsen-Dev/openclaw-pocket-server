#!/usr/bin/env bash
# install-nodejs.sh - Install Node.js linux-arm64 with grun wrapper (RTX⚡2 conditional)
# Extracted from install-glibc-env.sh — Node.js only, assumes glibc already installed.
# Called by orchestrator when config.env PLATFORM_NEEDS_NODEJS=true.
#
# What it does:
#   1. Download Node.js linux-arm64 LTS
#   2. Create grun-style wrapper scripts (ld.so direct execution)
#   3. Configure npm
#   4. Verify everything works
#
# patchelf is NOT used — Android seccomp causes SIGSEGV on patchelf'd binaries.
# All glibc binaries are executed via: exec ld.so binary "$@"
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

OPENCLAW_DIR="$HOME/.oca"
NODE_DIR="$OPENCLAW_DIR/node"
GLIBC_LDSO="$PREFIX/glibc/lib/ld-linux-aarch64.so.1"

# Node.js LTS version to install
NODE_VERSION="22.22.0"
NODE_TARBALL="node-v${NODE_VERSION}-linux-arm64.tar.xz"
NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/${NODE_TARBALL}"

echo "=== RTX⚡2 — Installing Node.js (glibc) ==="
echo ""

# ── Pre-checks ───────────────────────────────

if [ -z "${PREFIX:-}" ]; then
    echo -e "${RED}[FAIL]${NC} Not running in Termux (\$PREFIX not set)"
    exit 1
fi

if [ ! -x "$GLIBC_LDSO" ]; then
    echo -e "${RED}[FAIL]${NC} glibc dynamic linker not found — run install-glibc.sh first"
    exit 1
fi

# Check if already installed
if [ -x "$NODE_DIR/bin/node" ]; then
    if "$NODE_DIR/bin/node" --version &>/dev/null; then
        INSTALLED_VER=$("$NODE_DIR/bin/node" --version 2>/dev/null | sed 's/^v//')
        if [ "$INSTALLED_VER" = "$NODE_VERSION" ]; then
            echo -e "${GREEN}[SKIP]${NC} Node.js already installed (v${INSTALLED_VER})"
            # Repair npm/npx wrappers — older installs may have shebang-only patch
            # which fails because bin/npm's relative require('../lib/cli.js') doesn't resolve
            _any_fixed=false
            if [ -f "$NODE_DIR/lib/node_modules/npm/bin/npm-cli.js" ]; then
                rm -f "$NODE_DIR/bin/npm"
                cat > "$NODE_DIR/bin/npm" << NPMWRAP
#!$PREFIX/bin/bash
exec "$NODE_DIR/bin/node" "$NODE_DIR/lib/node_modules/npm/bin/npm-cli.js" "\$@"
NPMWRAP
                chmod +x "$NODE_DIR/bin/npm"
                _any_fixed=true
            fi
            if [ -f "$NODE_DIR/lib/node_modules/npm/bin/npx-cli.js" ]; then
                rm -f "$NODE_DIR/bin/npx"
                cat > "$NODE_DIR/bin/npx" << NPXWRAP
#!$PREFIX/bin/bash
exec "$NODE_DIR/bin/node" "$NODE_DIR/lib/node_modules/npm/bin/npx-cli.js" "\$@"
NPXWRAP
                chmod +x "$NODE_DIR/bin/npx"
                _any_fixed=true
            fi
            if [ -f "$NODE_DIR/bin/corepack" ] && head -1 "$NODE_DIR/bin/corepack" 2>/dev/null | grep -q '#!/usr/bin/env node'; then
                sed -i "1s|#!/usr/bin/env node|#!$NODE_DIR/bin/node|" "$NODE_DIR/bin/corepack"
                _any_fixed=true
            fi
            if [ "$_any_fixed" = true ]; then
                echo -e "${YELLOW}[FIX]${NC}  npm/npx wrappers repaired"
            fi
            exit 0
        fi
        LOWEST=$(printf '%s\n%s\n' "$INSTALLED_VER" "$NODE_VERSION" | sort -V | head -1)
        if [ "$LOWEST" = "$INSTALLED_VER" ] && [ "$INSTALLED_VER" != "$NODE_VERSION" ]; then
            echo -e "${YELLOW}[INFO]${NC} Node.js v${INSTALLED_VER} -> v${NODE_VERSION} (upgrading)"
        else
            echo -e "${GREEN}[SKIP]${NC} Node.js v${INSTALLED_VER} is newer than target v${NODE_VERSION}"
            exit 0
        fi
    else
        echo -e "${YELLOW}[INFO]${NC} Node.js exists but broken — reinstalling"
    fi
fi

# ── Step 1: Download Node.js linux-arm64 ──────

echo "Downloading Node.js v${NODE_VERSION} (linux-arm64)..."
echo "  (File size ~25MB — may take a few minutes depending on network speed)"
mkdir -p "$NODE_DIR"

TMP_DIR=$(mktemp -d "$PREFIX/tmp/node-install.XXXXXX") || {
    echo -e "${RED}[FAIL]${NC} Failed to create temp directory"
    exit 1
}
trap 'rm -rf "$TMP_DIR"' EXIT

if ! curl -fL --max-time 300 "$NODE_URL" -o "$TMP_DIR/$NODE_TARBALL"; then
    echo -e "${RED}[FAIL]${NC} Failed to download Node.js v${NODE_VERSION}"
    exit 1
fi
echo -e "${GREEN}[OK]${NC}   Downloaded $NODE_TARBALL"

# Extract
echo "Extracting Node.js... (this may take a moment)"
if ! tar -xJf "$TMP_DIR/$NODE_TARBALL" -C "$NODE_DIR" --strip-components=1; then
    echo -e "${RED}[FAIL]${NC} Failed to extract Node.js"
    exit 1
fi
echo -e "${GREEN}[OK]${NC}   Extracted to $NODE_DIR"

# ── Step 2: Create wrapper scripts ────────────

echo ""
echo "Creating wrapper scripts (grun-style, no patchelf)..."

# Move original node binary to node.real
if [ -f "$NODE_DIR/bin/node" ] && [ ! -L "$NODE_DIR/bin/node" ]; then
    mv "$NODE_DIR/bin/node" "$NODE_DIR/bin/node.real"
fi

# Create node wrapper script
# This uses grun-style execution: ld.so directly loads the binary
# LD_PRELOAD must be unset to prevent Bionic libtermux-exec.so from
# being loaded into the glibc process (causes version mismatch crash)
# glibc-compat.js is auto-loaded to fix Android kernel quirks (os.cpus() returns 0,
# os.networkInterfaces() throws EACCES) that affect native module builds and runtime.
printf '#!%s/bin/bash\n' "$PREFIX" > "$NODE_DIR/bin/node"
cat >> "$NODE_DIR/bin/node" << 'WRAPPER'
[ -n "$LD_PRELOAD" ] && export _OA_ORIG_LD_PRELOAD="$LD_PRELOAD"
unset LD_PRELOAD
_OA_COMPAT="$HOME/.oca/patches/glibc-compat.js"
if [ -f "$_OA_COMPAT" ]; then
    case "${NODE_OPTIONS:-}" in
        *"$_OA_COMPAT"*) ;;
        *) export NODE_OPTIONS="${NODE_OPTIONS:+$NODE_OPTIONS }-r $_OA_COMPAT" ;;
    esac
fi
# glibc ld.so misparses leading --options as its own flags.
# Move them to NODE_OPTIONS ONLY when a script path follows
# (preserves direct invocations like 'node --version').
_LEADING_OPTS=""
_COUNT=0
for _arg in "$@"; do
    case "$_arg" in --*) _COUNT=$((_COUNT + 1)) ;; *) break ;; esac
done
if [ $_COUNT -gt 0 ] && [ $_COUNT -lt $# ]; then
    while [ $# -gt 0 ]; do
        case "$1" in
            --*) _LEADING_OPTS="${_LEADING_OPTS:+$_LEADING_OPTS }$1"; shift ;;
            *) break ;;
        esac
    done
    export NODE_OPTIONS="${NODE_OPTIONS:+$NODE_OPTIONS }$_LEADING_OPTS"
fi
exec "$PREFIX/glibc/lib/ld-linux-aarch64.so.1" "$(dirname "$0")/node.real" "$@"
WRAPPER
chmod +x "$NODE_DIR/bin/node"
echo -e "${GREEN}[OK]${NC}   node wrapper created"

# ── Step 2.4: Upgrade npm ─────────────────────
echo ""
echo "Upgrading npm to v11.12.0..."
if "$NODE_DIR/bin/node" "$NODE_DIR/lib/node_modules/npm/bin/npm-cli.js" --prefix "$NODE_DIR" install -g npm@11.12.0; then
    echo -e "${GREEN}[OK]${NC}   npm updated to v11.12.0"
else
    echo -e "${YELLOW}[WARN]${NC} Failed to update npm"
fi

# ── Step 2.5: Create npm/npx wrapper scripts ──
#
# bin/npm and bin/npx from the Node.js tarball use relative requires
# (e.g. require('../lib/cli.js')) that don't resolve in Termux's install path.
# Replace them with explicit shell wrappers that invoke the correct entry points.
echo "Creating npm/npx wrapper scripts..."
if [ -f "$NODE_DIR/lib/node_modules/npm/bin/npm-cli.js" ]; then
    rm -f "$NODE_DIR/bin/npm"
    cat > "$NODE_DIR/bin/npm" << NPMWRAP
#!$PREFIX/bin/bash
exec "$NODE_DIR/bin/node" "$NODE_DIR/lib/node_modules/npm/bin/npm-cli.js" "\$@"
NPMWRAP
    chmod +x "$NODE_DIR/bin/npm"
    echo -e "${GREEN}[OK]${NC}   npm wrapper created"
fi
if [ -f "$NODE_DIR/lib/node_modules/npm/bin/npx-cli.js" ]; then
    rm -f "$NODE_DIR/bin/npx"
    cat > "$NODE_DIR/bin/npx" << NPXWRAP
#!$PREFIX/bin/bash
exec "$NODE_DIR/bin/node" "$NODE_DIR/lib/node_modules/npm/bin/npx-cli.js" "\$@"
NPXWRAP
    chmod +x "$NODE_DIR/bin/npx"
    echo -e "${GREEN}[OK]${NC}   npx wrapper created"
fi
# corepack uses a different structure — shebang patch is sufficient
if [ -f "$NODE_DIR/bin/corepack" ] && head -1 "$NODE_DIR/bin/corepack" 2>/dev/null | grep -q '#!/usr/bin/env node'; then
    sed -i "1s|#!/usr/bin/env node|#!$NODE_DIR/bin/node|" "$NODE_DIR/bin/corepack"
    echo -e "${GREEN}[OK]${NC}   corepack shebang patched"
fi

# ── Step 3: Configure npm ─────────────────────

echo ""
echo "Configuring npm..."

# Set script-shell to ensure npm lifecycle scripts use the correct shell
# On Android 9+, /bin/sh exists. On 7-8 it doesn't.
# Using $PREFIX/bin/sh is always safe.
export PATH="$NODE_DIR/bin:$PATH"
"$NODE_DIR/bin/npm" config set script-shell "$PREFIX/bin/sh" 2>/dev/null || true
echo -e "${GREEN}[OK]${NC}   npm script-shell set to $PREFIX/bin/sh"

# ── Step 4: Verify ────────────────────────────

echo ""
echo "Verifying glibc Node.js..."

NODE_VER=$("$NODE_DIR/bin/node" --version 2>/dev/null) || {
    echo -e "${RED}[FAIL]${NC} Node.js verification failed — wrapper script may be broken"
    exit 1
}
echo -e "${GREEN}[OK]${NC}   Node.js $NODE_VER (glibc, grun wrapper)"

NPM_VER=$("$NODE_DIR/bin/npm" --version 2>/dev/null) || {
    echo -e "${YELLOW}[WARN]${NC} npm verification failed"
}
if [ -n "${NPM_VER:-}" ]; then
    echo -e "${GREEN}[OK]${NC}   npm $NPM_VER"
fi

# Quick platform check
PLATFORM=$("$NODE_DIR/bin/node" -e "console.log(process.platform)" 2>/dev/null) || true
if [ "$PLATFORM" = "linux" ]; then
    echo -e "${GREEN}[OK]${NC}   platform: linux (correct)"
else
    echo -e "${YELLOW}[WARN]${NC} platform: ${PLATFORM:-unknown} (expected: linux)"
fi

echo ""
echo -e "${GREEN}Node.js installed successfully.${NC}"
echo "  Node.js: $NODE_VER ($NODE_DIR/bin/node)"
