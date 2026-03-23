#!/usr/bin/env bash
# install-go.sh - Install Go toolchain for OpenClaw skills and go install workflows
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "=== OCA — Installing Go Toolchain ==="
echo ""

if command -v go >/dev/null 2>&1; then
    echo -e "${GREEN}[SKIP]${NC} Go already installed: $(go version)"
    exit 0
fi

echo -e "${CYAN}[INFO]${NC} Installing golang from Termux packages"
pkg install -y golang

if command -v go >/dev/null 2>&1; then
    echo -e "${GREEN}[OK]${NC}   $(go version)"
    echo -e "${YELLOW}[INFO]${NC} You can now use 'go install ...' for OpenClaw skills and helper tools."
else
    echo -e "${YELLOW}[INFO]${NC} golang package installed, but 'go' is not in PATH yet. Restart Termux or source ~/.bashrc."
fi
