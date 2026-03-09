#!/usr/bin/env bash
# install-playwright.sh - Install Playwright (FHS/Dual-Engine Chromium Automation)
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "${PREFIX:-}" ]; then
    echo -e "${YELLOW}[WARN]${NC} Not running in Termux (\$PREFIX not set)"
    exit 0
fi

ROOTFS="$PREFIX/var/lib/proot-distro/installed-rootfs/debian"
if [ ! -d "$ROOTFS" ]; then
    echo -e "${YELLOW}[INFO]${NC} Base Debian container not found. Initializing..."
    bash "$SCRIPT_DIR/install-homebrew.sh" || { echo "Failed to init container"; exit 0; }
fi

echo "=== RTX⚡3 — Installing Full Playwright Suite (FHS Debian) ==="
echo ""
echo "This will install native Linux browsers and xvfb inside the FHS container."
echo "It enables 100% compatible Headless Scraping on Android!"

export PROOT_NO_SECCOMP=1
proot-distro login debian --shared-tmp --bind "$PREFIX:/termux" --user root -- bash -c "
    apt-get update -yq
    # Install Node.js natively in Debian if not present
    if ! command -v node &> /dev/null; then
        apt-get install -yq curl ca-certificates
        curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
        apt-get install -yq nodejs
    fi
    # Install system dependencies for Playwright
    apt-get install -yq libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libgbm1 libasound2 xvfb
    
    # Install playwright and its browsers
    npm install -g playwright
    npx playwright install --with-deps chromium
" || { echo -e "${YELLOW}[WARN]${NC} Core playwright setup failed"; exit 0; }

# Create Dual Engine Wrapper for Playwright scripts
WRAPPER="$PREFIX/bin/playwright-node"

cat > "$WRAPPER" << 'EOF'
#!/usr/bin/env bash
# OpenClaw Transparent FHS playbook-node Wrapper (Dual-Engine)
# Use this to run Puppeteer/Playwright scripts on Android with full Xvfb support

ROOTFS="$PREFIX/var/lib/proot-distro/installed-rootfs/debian"
IS_ROOTED=false
if command -v su >/dev/null 2>&1 && su -c true >/dev/null 2>&1; then
    IS_ROOTED=true
fi

args_escaped=()
for arg in "$@"; do
    args_escaped+=("$(printf '%q' "$arg")")
done

SCRIPT_CMD="xvfb-run -a node ${args_escaped[*]}"

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

    su -c "chroot \"$ROOTFS\" /bin/su - debian -c \"export HOME=$HOME; export PATH=/usr/local/bin:/usr/bin:/bin; cd \\\"$(pwd)\\\"; $SCRIPT_CMD\""
    EXIT_CODE=$?
else
    # --- Safe Proot Engine ---
    export PROOT_NO_SECCOMP=1
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
            $SCRIPT_CMD \
        "
    EXIT_CODE=$?
fi
exit $EXIT_CODE
EOF

chmod +x "$WRAPPER"

echo -e "${GREEN}[OK]${NC}   Playwright native FHS suite installed!"
echo ""
echo -e "${CYAN}[INFO]${NC} To run a scraper script natively on Android:"
echo "       Run:  playwright-node my-scraper.js"
echo "       This invisibly uses xvfb to provide a virtual display and executes via Dual-Engine!"
