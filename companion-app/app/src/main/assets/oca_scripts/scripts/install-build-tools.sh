#!/usr/bin/env bash
# install-build-tools.sh - Install build tools for native module compilation (RTX⚡2 conditional)
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== RTX⚡2 — Installing Build Tools ==="
echo ""

PACKAGES=(
    python
    make
    cmake
    clang
    binutils
    build-essential
)

echo "Installing packages: ${PACKAGES[*]}"
echo "  (This may take a few minutes depending on network speed)"
pkg install -y "${PACKAGES[@]}"

# Create ar symlink if missing
if [ ! -e "$PREFIX/bin/ar" ] && [ -x "$PREFIX/bin/llvm-ar" ]; then
    ln -s "$PREFIX/bin/llvm-ar" "$PREFIX/bin/ar"
    echo -e "${GREEN}[OK]${NC}   Created ar → llvm-ar symlink"
fi

echo ""
echo -e "${GREEN}Build tools installed.${NC}"
