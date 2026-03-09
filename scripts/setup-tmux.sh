#!/data/data/com.termux/files/usr/bin/bash
# Setup tmux session info
set -euo pipefail

GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
log_ok() { echo -e "${GREEN}[OK]${NC}   $1"; }
log_info() { echo -e "${CYAN}[INFO]${NC} $1"; }

TMUX_SESSION="OpenClaw"

log_info "tmux session name will be: $TMUX_SESSION"
log_info "After 'openclaw onboard', create it with:"
echo -e "  ${CYAN}tmux new-session -s $TMUX_SESSION${NC}"
echo -e "  Then run: ${CYAN}openclaw gateway${NC}"
echo -e "  Detach: ${CYAN}Ctrl+B${NC} then ${CYAN}D${NC}"
echo -e "  Reattach: ${CYAN}tmux attach -t $TMUX_SESSION${NC}"

log_ok "tmux ready — session name: $TMUX_SESSION"
