#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/lib.sh"

PASS=0
FAIL=0
WARN=0

check_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    PASS=$((PASS + 1))
}

check_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    FAIL=$((FAIL + 1))
}

check_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    WARN=$((WARN + 1))
}

echo "=== RTX⚡ — Installation Verification ==="
echo ""

# --- RTX⚡1: Infrastructure & Runtime Check ---
if command -v node &>/dev/null; then
    NODE_VER=$(node -v)
    NODE_MAJOR="${NODE_VER%%.*}"
    NODE_MAJOR="${NODE_MAJOR#v}"
    if [ "$NODE_MAJOR" -ge 24 ] 2>/dev/null; then
        check_pass "Node.js $NODE_VER (>= 24)"
    else
        check_fail "Node.js $NODE_VER (need >= 24)"
    fi
else
    check_fail "Node.js not found"
fi

if command -v npm &>/dev/null; then
    check_pass "npm $(npm -v)"
else
    check_fail "npm not found"
fi

if [ -n "${TMPDIR:-}" ]; then
    check_pass "TMPDIR=$TMPDIR"
else
    check_fail "TMPDIR not set"
fi

if [ "${OCA_GLIBC:-}" = "1" ]; then
    check_pass "RTX⚡2 Protocol Active (glibc architecture)"
else
    check_fail "OCA_GLIBC not set"
fi

COMPAT_FILE="$PROJECT_DIR/patches/glibc-compat.js"
if [ -f "$COMPAT_FILE" ]; then
    check_pass "glibc-compat.js exists"
else
    check_fail "glibc-compat.js not found at $COMPAT_FILE"
fi

GLIBC_MARKER="$PROJECT_DIR/.glibc-arch"
if [ -f "$GLIBC_MARKER" ]; then
    check_pass "glibc architecture marker (.glibc-arch)"
else
    check_fail "glibc architecture marker not found"
fi

GLIBC_LDSO="${PREFIX:-}/glibc/lib/ld-linux-aarch64.so.1"
if [ -f "$GLIBC_LDSO" ]; then
    check_pass "glibc dynamic linker (ld-linux-aarch64.so.1)"
else
    check_fail "glibc dynamic linker not found at $GLIBC_LDSO"
fi

NODE_WRAPPER="$PROJECT_DIR/node/bin/node"
if [ -f "$NODE_WRAPPER" ] && head -1 "$NODE_WRAPPER" 2>/dev/null | grep -q "bash"; then
    check_pass "glibc node wrapper script"
else
    check_fail "glibc node wrapper not found or not a wrapper script"
fi

for DIR in "$PROJECT_DIR" "$PREFIX/tmp"; do
    if [ -d "$DIR" ]; then
        check_pass "Directory $DIR exists"
    else
        check_fail "Directory $DIR missing"
    fi
done

# --- RTX⚡3: Master Arsenal (Optional Tools) ---
if command -v code-server &>/dev/null; then
    CS_VER=$(code-server --version 2>/dev/null | head -1 || true)
    if [ -n "$CS_VER" ]; then
        check_pass "code-server $CS_VER"
    else
        check_warn "code-server found but --version failed"
    fi
fi

command -v opencode &>/dev/null && check_pass "opencode command available"
command -v qwen &>/dev/null && check_pass "qwen command available"

# Bashrc check
if grep -qF "OCA" "$HOME/.bashrc" 2>/dev/null; then
    check_pass ".bashrc contains environment block"
else
    check_fail ".bashrc missing environment block"
fi

# Root check (info only)
if [ -f "$PROJECT_DIR/.rooted" ]; then
    check_pass "Root access configured"
fi

# Termux:Boot check (info only)
if [ -f "$HOME/.termux/boot/oca-boot.sh" ]; then
    check_pass "Termux:Boot auto-start configured"
fi

# Termux:API check (info only)
if command -v termux-battery-status &>/dev/null; then
    check_pass "Termux:API installed"
fi

# Platform verification
PLATFORM=$(detect_platform) || true
PLATFORM_VERIFY="$PROJECT_DIR/platforms/$PLATFORM/verify.sh"
if [ -n "$PLATFORM" ] && [ -f "$PLATFORM_VERIFY" ]; then
    if bash "$PLATFORM_VERIFY"; then
        check_pass "Platform verifier passed ($PLATFORM)"
    else
        check_fail "Platform verifier failed ($PLATFORM)"
    fi
else
    check_warn "Platform verifier not found (platform=${PLATFORM:-none})"
fi

echo ""
echo "==============================="
echo -e "  Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}, ${YELLOW}$WARN warnings${NC}"
echo "==============================="
echo ""

if [ "$FAIL" -gt 0 ]; then
    echo -e "${RED}Installation verification FAILED.${NC}"
    echo "Please check the errors above and re-run install.sh"
    exit 1
else
    echo -e "${GREEN}Installation verification PASSED!${NC}"
fi
