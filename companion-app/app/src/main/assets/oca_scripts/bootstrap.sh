#!/usr/bin/env bash
# bootstrap.sh - Download and run OpenClaw on Android installer
# Usage: curl -sL https://raw.githubusercontent.com/PsProsen-Dev/OpenClaw-On-Android/main/bootstrap.sh | bash
set -euo pipefail

REPO_TARBALL="https://github.com/PsProsen-Dev/OpenClaw-On-Android/archive/refs/heads/master.tar.gz"
INSTALL_DIR="$HOME/.oca/installer"

RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}OpenClaw on Android - Bootstrap${NC}"
echo ""

if ! command -v curl &>/dev/null; then
    echo -e "${RED}[FAIL]${NC} curl not found. Install it with: pkg install curl"
    exit 1
fi

echo "Downloading installer..."
mkdir -p "$INSTALL_DIR"
curl -sfL "$REPO_TARBALL" | tar xz -C "$INSTALL_DIR" --strip-components=1

bash "$INSTALL_DIR/install.sh"

cp "$INSTALL_DIR/uninstall.sh" "$HOME/.oca/uninstall.sh"
chmod +x "$HOME/.oca/uninstall.sh"
rm -rf "$INSTALL_DIR"
