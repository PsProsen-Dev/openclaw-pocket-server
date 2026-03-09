#!/usr/bin/env bash
# install-opencode.sh - Install OpenCode on Termux
# Uses proot + ld.so concatenation for Bun standalone binaries.
#
# This script is NON-CRITICAL: failure does not affect OpenClaw.
#
# Why proot + ld.so concatenation?
#   1. Bun uses raw syscalls (LD_PRELOAD shims don't work)
#   2. patchelf causes SIGSEGV on Android (seccomp)
#   3. Bun standalone reads embedded JS via /proc/self/exe offset
#      → grun makes /proc/self/exe point to ld.so, breaking this
#      → concatenating ld.so + binary data fixes the offset math
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

OPENCLAW_DIR="$HOME/.oca"
GLIBC_LDSO="$PREFIX/glibc/lib/ld-linux-aarch64.so.1"
PROOT_ROOT="$OPENCLAW_DIR/proot-root"

fail_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    exit 0
}

echo "=== RTX⚡3 — Installing OpenCode ==="
echo ""

# ── Pre-checks ───────────────────────────────

if [ ! -f "$OPENCLAW_DIR/.glibc-arch" ]; then
    fail_warn "glibc environment not installed — skipping OpenCode install"
fi

if [ ! -x "$GLIBC_LDSO" ]; then
    fail_warn "glibc dynamic linker not found — skipping OpenCode install"
fi

if ! command -v proot &>/dev/null; then
    echo "Installing proot..."
    if ! pkg install -y proot; then
        fail_warn "Failed to install proot — skipping OpenCode install"
    fi
fi

# ── Helper: Create ld.so concatenation ───────

# Bun standalone binaries store embedded JS at the end of the file.
# The last 8 bytes contain the original file size as a LE u64.
# Bun calculates: embedded_offset = current_file_size - stored_size
# By prepending ld.so, current_file_size increases, and the offset
# shifts correctly to find the embedded data after ld.so.
create_ldso_concat() {
    local bin_path="$1"
    local output_path="$2"
    local name="$3"

    if [ ! -f "$bin_path" ]; then
        echo -e "${RED}[FAIL]${NC} $name binary not found at $bin_path"
        return 1
    fi

echo "  Creating ld.so concatenation for $name..."
echo "    (Copying large binary files — this may take a minute)"
cp "$GLIBC_LDSO" "$output_path"
cat "$bin_path" >> "$output_path"
chmod +x "$output_path"

    # Verify the Bun magic marker exists at the end
    local marker
    marker=$(tail -c 32 "$output_path" | strings 2>/dev/null | grep -o "Bun" || true)
    if [ -n "$marker" ]; then
        echo -e "${GREEN}[OK]${NC}   $name ld.so concatenation created ($(du -h "$output_path" | cut -f1))"
    else
        echo -e "${YELLOW}[WARN]${NC} $name ld.so concatenation created but Bun marker not found"
    fi
}

# ── Helper: Create proot wrapper script ──────

create_proot_wrapper() {
    local wrapper_path="$1"
    local ldso_path="$2"
    local bin_path="$3"
    local name="$4"

    cat > "$wrapper_path" << WRAPPER
#!/data/data/com.termux/files/usr/bin/bash
# $name wrapper — proot + ld.so concatenation
# proot: intercepts raw syscalls (Bun uses inline asm, not glibc calls)
# ld.so concat: fixes /proc/self/exe offset for embedded JS
# unset LD_PRELOAD: prevents Bionic libtermux-exec.so version mismatch
unset LD_PRELOAD
exec proot \\
  -R "$PROOT_ROOT" \\
  -b "\$PREFIX:\$PREFIX" \\
  -b /system:/system \\
  -b /apex:/apex \\
  -w "\$(pwd)" \\
  "$ldso_path" "$bin_path" "\$@"
WRAPPER
    chmod +x "$wrapper_path"
    echo -e "${GREEN}[OK]${NC}   $name wrapper script created"
}

# ── Step 1: Create minimal proot rootfs ──────

echo "Setting up proot minimal rootfs..."
mkdir -p "$PROOT_ROOT/data/data/com.termux/files"
echo -e "${GREEN}[OK]${NC}   proot rootfs created at $PROOT_ROOT"

# ── Step 2: Install Bun (package manager) ────

echo ""
echo "Installing Bun..."
echo "  (Downloading and installing Bun runtime — this may take a few minutes)"
BUN_BIN="$HOME/.bun/bin/bun"
if [ -x "$BUN_BIN" ]; then
    echo -e "${GREEN}[OK]${NC}   Bun already installed"
else
    # Install bun via the official installer
    # Bun is needed to download the opencode package
    if curl -fsSL https://bun.sh/install | bash 2>/dev/null; then
        echo -e "${GREEN}[OK]${NC}   Bun installed"
    else
        fail_warn "Failed to install Bun — cannot install OpenCode"
    fi
    BUN_BIN="$HOME/.bun/bin/bun"
fi

# Bun itself needs grun to run (it's a glibc binary)
# Create a temporary wrapper for bun
BUN_WRAPPER=$(mktemp "$PREFIX/tmp/bun-wrapper.XXXXXX")
cat > "$BUN_WRAPPER" << WRAPPER
#!/data/data/com.termux/files/usr/bin/bash
unset LD_PRELOAD
exec "$GLIBC_LDSO" "$BUN_BIN" "\$@"
WRAPPER
chmod +x "$BUN_WRAPPER"

# Verify bun works
BUN_VER=$("$BUN_WRAPPER" --version 2>/dev/null) || {
    rm -f "$BUN_WRAPPER"
    fail_warn "Bun verification failed"
}
echo -e "${GREEN}[OK]${NC}   Bun $BUN_VER verified"

# ── Step 3: Install OpenCode ────────────────

echo ""
echo "Installing OpenCode..."
echo "  (Downloading package — this may take a few minutes)"
# Use bun to install opencode-ai package
# Note: bun may exit non-zero due to optional platform packages (windows, darwin)
# failing to install, but the linux-arm64 binary is still installed successfully.
"$BUN_WRAPPER" install -g opencode-ai 2>&1 || true
echo -e "${GREEN}[OK]${NC}   opencode-ai package install attempted"

# Remove bun's global shim — it tries to spawnSync the native binary directly,
# which fails on Termux (missing /lib/ld-linux-aarch64.so.1).
# Our proot wrapper at $PREFIX/bin/opencode will be used instead.
rm -f "$HOME/.bun/bin/opencode"

# Find the OpenCode binary
OPENCODE_BIN=""
for pattern in \
    "$HOME/.bun/install/cache/opencode-linux-arm64@*/bin/opencode" \
    "$HOME/.bun/install/global/node_modules/opencode-linux-arm64/bin/opencode"; do
    # shellcheck disable=SC2012,SC2086
    FOUND=$(ls $pattern 2>/dev/null | sort -V | tail -1 || true)
    if [ -n "$FOUND" ] && [ -f "$FOUND" ]; then
        OPENCODE_BIN="$FOUND"
        break
    fi
done

if [ -z "$OPENCODE_BIN" ]; then
    rm -f "$BUN_WRAPPER"
    fail_warn "OpenCode binary not found after installation"
fi
echo -e "${GREEN}[OK]${NC}   OpenCode binary found: $OPENCODE_BIN"

# Create ld.so concatenation
mkdir -p "$OPENCLAW_DIR/bin"
LDSO_OPENCODE="$OPENCLAW_DIR/bin/ld.so.opencode"
create_ldso_concat "$OPENCODE_BIN" "$LDSO_OPENCODE" "OpenCode" || {
    rm -f "$BUN_WRAPPER"
    fail_warn "Failed to create OpenCode ld.so concatenation"
}

# Create wrapper script
create_proot_wrapper "$PREFIX/bin/opencode" "$LDSO_OPENCODE" "$OPENCODE_BIN" "OpenCode"

# Verify
echo ""
echo "Verifying OpenCode..."
OC_VER=$("$PREFIX/bin/opencode" --version 2>/dev/null) || true
if [ -n "$OC_VER" ]; then
    echo -e "${GREEN}[OK]${NC}   OpenCode v$OC_VER verified"
else
    echo -e "${YELLOW}[WARN]${NC} OpenCode --version check failed (may work in interactive mode)"
fi


# ── Step 4: Create OpenCode config ───────────

echo ""
echo "Setting up OpenCode configuration..."

OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
OPENCODE_CONFIG="$OPENCODE_CONFIG_DIR/opencode.json"
mkdir -p "$OPENCODE_CONFIG_DIR"

if [ ! -f "$OPENCODE_CONFIG" ]; then
    cat > "$OPENCODE_CONFIG" << 'CONFIG'
{
  "$schema": "https://opencode.ai/config.json"
}
CONFIG
    echo -e "${GREEN}[OK]${NC}   OpenCode config created"
else
    echo -e "${GREEN}[OK]${NC}   OpenCode config already exists"
fi

# ── Cleanup ──────────────────────────────────

rm -f "$BUN_WRAPPER"

echo ""
echo -e "${GREEN}OpenCode installation complete.${NC}"
if [ -n "${OC_VER:-}" ]; then
    echo "  OpenCode:         v$OC_VER"
fi
echo "  Run: opencode"
