#!/usr/bin/env bash
# build-sharp.sh - Build sharp native module for image processing support
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=== Building sharp (image processing) ==="
echo ""

# Ensure required environment variables are set (for standalone use)
export TMPDIR="${TMPDIR:-$PREFIX/tmp}"
export TMP="$TMPDIR"
export TEMP="$TMPDIR"
export CONTAINER="${CONTAINER:-1}"

# Locate openclaw install directory
OPENCLAW_DIR="$(npm root -g)/openclaw"

if [ ! -d "$OPENCLAW_DIR" ]; then
    echo -e "${RED}[FAIL]${NC} OpenClaw directory not found: $OPENCLAW_DIR"
    exit 0
fi

# Skip rebuild if sharp is already working (e.g. compiled during npm install)
if [ -d "$OPENCLAW_DIR/node_modules/sharp" ]; then
    if node -e "require('$OPENCLAW_DIR/node_modules/sharp')" 2>/dev/null; then
        echo -e "${GREEN}[OK]${NC}   sharp is already working — skipping rebuild"
        exit 0
    fi
fi

# Install required packages
echo "Installing build dependencies..."
if ! pkg install -y libvips binutils; then
    echo -e "${YELLOW}[WARN]${NC} Failed to install build dependencies"
    echo "       Image processing will not be available, but OpenClaw will work normally."
    exit 0
fi
echo -e "${GREEN}[OK]${NC}   libvips and binutils installed"

# Create ar symlink if missing (Termux provides llvm-ar but not ar)
if [ ! -e "$PREFIX/bin/ar" ] && [ -x "$PREFIX/bin/llvm-ar" ]; then
    ln -s "$PREFIX/bin/llvm-ar" "$PREFIX/bin/ar"
    echo -e "${GREEN}[OK]${NC}   Created ar → llvm-ar symlink"
fi

# Install node-gyp globally
echo "Installing node-gyp..."
if ! npm install -g node-gyp; then
    echo -e "${YELLOW}[WARN]${NC} Failed to install node-gyp"
    echo "       Image processing will not be available, but OpenClaw will work normally."
    exit 0
fi
echo -e "${GREEN}[OK]${NC}   node-gyp installed"

# Set build environment variables
# On glibc architecture, these are handled by glibc's standard headers.
# On Bionic (legacy), we need explicit compatibility flags.
if [ ! -f "$HOME/.oca/.glibc-arch" ]; then
    export CFLAGS="-Wno-error=implicit-function-declaration"
    export CXXFLAGS="-include $HOME/.oca/patches/termux-compat.h"
    export GYP_DEFINES="OS=linux android_ndk_path=$PREFIX"
fi
export CPATH="$PREFIX/include/glib-2.0:$PREFIX/lib/glib-2.0/include"

echo "Rebuilding sharp in $OPENCLAW_DIR..."
echo "This may take several minutes..."
echo ""

if (cd "$OPENCLAW_DIR" && npm rebuild sharp); then
    echo ""
    echo -e "${GREEN}[OK]${NC}   sharp built successfully — image processing enabled"
else
    echo ""
    echo -e "${YELLOW}[WARN]${NC} sharp build failed (non-critical)"
    echo "       Image processing will not be available, but OpenClaw will work normally."
    echo "       You can retry later: bash ~/.oca/scripts/build-sharp.sh"
fi
