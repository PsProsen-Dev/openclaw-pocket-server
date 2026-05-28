#!/data/data/com.termux/files/usr/bin/bash
# setup-root.sh — Root access detection and safe wrapper for OCA
set -uo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"

log_ok()   { echo -e "${GREEN}[OK]${NC}   $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }

echo ""
echo "=== RTX⚡1 — Root Access Setup ==="
echo ""

# Detect root
if ! su -c "id" >/dev/null 2>&1; then
    log_info "Device is not rooted or root access denied"
    log_info "Root features will not be available"
    exit 0
fi

ROOT_UID=$(su -c "id -u" 2>/dev/null)
if [ "$ROOT_UID" = "0" ]; then
    log_ok "Root access confirmed (uid=0)"
else
    log_warn "su command exists but did not return uid=0"
    exit 0
fi

# Create safe root wrapper
WRAPPER="$PREFIX/bin/oca-root"
cat > "$WRAPPER" << 'ROOTWRAPPER'
#!/data/data/com.termux/files/usr/bin/bash
# oca-root — Safe root command wrapper for OCA
# Usage: oca-root <command> [args...]
#
# Only whitelisted commands are allowed.
# Add more commands to ALLOWED as needed.

set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

ALLOWED_COMMANDS=(
    ls cat head tail wc df du mount umount
    ps kill killall top
    getprop setprop
    ip ifconfig ping
    chmod chown
    cp mv mkdir rm
    logcat dmesg
    pm am settings
    svc dumpsys
    reboot
)

if [ $# -eq 0 ]; then
    echo -e "${YELLOW}Usage:${NC} oca-root <command> [args...]"
    echo ""
    echo "Whitelisted commands:"
    printf "  %s\n" "${ALLOWED_COMMANDS[@]}"
    exit 0
fi

CMD="$1"
ALLOWED=false

for allowed_cmd in "${ALLOWED_COMMANDS[@]}"; do
    if [ "$CMD" = "$allowed_cmd" ]; then
        ALLOWED=true
        break
    fi
done

if [ "$ALLOWED" = true ]; then
    su -c "$*"
else
    echo -e "${RED}[BLOCKED]${NC} Command '$CMD' is not whitelisted"
    echo ""
    echo "To add this command, edit: $PREFIX/bin/oca-root"
    echo "Add '$CMD' to the ALLOWED_COMMANDS array"
    exit 1
fi
ROOTWRAPPER

chmod +x "$WRAPPER"
log_ok "Root wrapper created: $WRAPPER"
log_info "Usage: oca-root <command> [args...]"
log_info "Example: oca-root getprop ro.build.version.release"
log_warn "Only whitelisted commands are allowed for safety"

# Create OCA root marker
mkdir -p "$HOME/.oca"
touch "$HOME/.oca/.rooted"
log_ok "Root marker created"
