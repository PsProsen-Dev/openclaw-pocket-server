#!/usr/bin/env bash
# install-infra-deps.sh - Install core infrastructure packages (RTX⚡1)
set -euo pipefail

GREEN='\033[0;32m'
NC='\033[0m'

echo "=== RTX⚡1 — Installing Infrastructure Dependencies ==="
echo ""

echo "Updating package repositories..."
echo "  (This may take a minute depending on mirror speed)"
pkg update -y
pkg upgrade -y

echo "Installing git..."
pkg install -y git

echo ""
echo -e "${GREEN}Infrastructure dependencies installed.${NC}"
