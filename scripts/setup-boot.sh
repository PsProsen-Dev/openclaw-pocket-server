#!/data/data/com.termux/files/usr/bin/bash
# setup-boot.sh — Generate Termux:Boot auto-start script for OCA
set -uo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log_ok()   { echo -e "${GREEN}[OK]${NC}   $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_info() { echo -e "${CYAN}[INFO]${NC} $1"; }

BOOT_DIR="$HOME/.termux/boot"
BOOT_SCRIPT="$BOOT_DIR/oca-boot.sh"

mkdir -p "$BOOT_DIR"

cat > "$BOOT_SCRIPT" << 'BOOTEOF'
#!/data/data/com.termux/files/usr/bin/bash
source ~/.bashrc 2>/dev/null ||# Start necessary services (add yours below)
sleep 10
if ! tmux has-session -t OpenClaw 2>/dev/null; then
  tmux new-session -d -s OpenClaw "source ~/.bashrc && openclaw gateway"
fi
BOOTEOF

chmod +x "$BOOT_SCRIPT"
log_ok "Boot script created: $BOOT_SCRIPT"
log_info "Install Termux:Boot from F-Droid to enable auto-start"
log_info "https://f-droid.org/en/packages/com.termux.boot/"
log_warn "Open Termux:Boot once after install to grant permissions"
