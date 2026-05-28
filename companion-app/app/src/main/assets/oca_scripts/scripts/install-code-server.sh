#!/usr/bin/env bash
# install-code-server.sh - Install code-server (browser IDE) inside FHS Dual-Engine Container
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

MODE="${1:-install}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== RTX⚡3 — Installing code-server (Browser IDE) ==="
echo ""

# ── Helper ────────────────────────────────────
fail_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    exit 0
}

# ── Pre-checks ────────────────────────────────
if [ -z "${PREFIX:-}" ]; then
    fail_warn "Not running in Termux (\$PREFIX not set)"
fi

ROOTFS="$PREFIX/var/lib/proot-distro/installed-rootfs/debian"
if [ ! -d "$ROOTFS" ]; then
    echo -e "${YELLOW}[INFO]${NC} Base Debian container not found. Initializing..."
    bash "$SCRIPT_DIR/install-homebrew.sh" || fail_warn "Container initialization failed."
fi

# ── Install Code-Server natively in Container ─
echo "Installing Official Linux code-server inside FHS Container..."
export PROOT_NO_SECCOMP=1
proot-distro login debian --shared-tmp --bind "$PREFIX:/termux" --user root -- bash -c "
    apt-get update -yq
    apt-get install -yq curl
    curl -fsSL https://code-server.dev/install.sh | sh
" || fail_warn "code-server installation failed"

echo -e "${GREEN}[OK]${NC}   code-server installed into Debian FHS container."

# ── Create Dual-Engine Smart Wrapper ──────────
WRAPPER="$PREFIX/bin/code-server"

cat > "$WRAPPER" << 'EOF'
#!/usr/bin/env bash
# OpenClaw Transparent FHS code-server Wrapper (Dual-Engine)

ROOTFS="$PREFIX/var/lib/proot-distro/installed-rootfs/debian"
IS_ROOTED=false
if command -v su >/dev/null 2>&1 && su -c true >/dev/null 2>&1; then
    IS_ROOTED=true
fi

args_escaped=()
for arg in "$@"; do
    args_escaped+=("$(printf '%q' "$arg")")
done

if [ "$IS_ROOTED" = true ]; then
    # --- Native Chroot Engine ---
    su -c "
        if ! mountpoint -q \"$ROOTFS/proc\"; then mount -t proc proc \"$ROOTFS/proc\"; fi
        if ! mountpoint -q \"$ROOTFS/sys\"; then mount -t sysfs sysfs \"$ROOTFS/sys\"; fi
        if ! mountpoint -q \"$ROOTFS/dev\"; then mount --bind /dev \"$ROOTFS/dev\"; fi
        if ! mountpoint -q \"$ROOTFS/data/data/com.termux\"; then
            mkdir -p \"$ROOTFS/data/data/com.termux\"
            mount --bind /data/data/com.termux \"$ROOTFS/data/data/com.termux\"
        fi
        if [ -d /sdcard ]; then
            if ! mountpoint -q \"$ROOTFS/sdcard\"; then
                mkdir -p \"$ROOTFS/sdcard\"
                mount --bind /sdcard \"$ROOTFS/sdcard\"
            fi
        fi
        mkdir -p \"$ROOTFS/tmp\"
        chmod 1777 \"$ROOTFS/tmp\"
    " >/dev/null 2>&1

    su -c "chroot \"$ROOTFS\" /bin/su - debian -c \"export HOME=$HOME; export PATH=/usr/local/bin:/usr/bin:/bin; cd \\\"$(pwd)\\\"; /usr/bin/code-server --bind-addr 127.0.0.1:8080 --auth none ${args_escaped[*]}\""
    EXIT_CODE=$?
else
    # --- Safe Proot Engine ---
    export PROOT_NO_SECCOMP=1
    # Bind paths safely. Ignore /sdcard if not exist.
    SDCARD_BIND=""
    [ -d /sdcard ] && SDCARD_BIND="--bind /sdcard:/sdcard"
    
    proot-distro login debian --shared-tmp \
        --bind "$PREFIX:/termux" \
        --bind "$HOME:$HOME" \
        $SDCARD_BIND \
        --bind "$(pwd)":"$(pwd)" \
        --user debian -- bash -c "\
            export HOME=$HOME; \
            cd \"$(pwd)\"; \
            /usr/bin/code-server --bind-addr 127.0.0.1:8080 --auth none ${args_escaped[*]} \
        "
    EXIT_CODE=$?
fi
exit $EXIT_CODE
EOF

chmod +x "$WRAPPER"
echo -e "${GREEN}[OK]${NC}   Dual-Engine wrapper created at $WRAPPER"
echo ""
echo -e "${CYAN}[INFO]${NC} You can now start 'code-server' seamlessly from Termux."
echo "       It will run fully native Ubuntu/Debian extensions!"
