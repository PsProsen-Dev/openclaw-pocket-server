#!/usr/bin/env bash
# install-go.sh - Install Go toolchain (Official Linux Glibc Wrapper) (RTX⚡3 optional)
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

GO_VERSION="1.23.4"
OPENCLAW_DIR="$HOME/.oca"
GO_DIR="$OPENCLAW_DIR/go"

echo "=== RTX⚡3 — Installing Go Toolchain (glibc) ==="
echo ""

if [ -z "${PREFIX:-}" ]; then
    echo -e "${RED}[FAIL]${NC} Not running in Termux (\$PREFIX not set)"
    exit 1
fi

ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ]; then
    GO_TARBALL="go${GO_VERSION}.linux-arm64.tar.gz"
    GLIBC_LDSO="$PREFIX/glibc/lib/ld-linux-aarch64.so.1"
elif [ "$ARCH" = "x86_64" ]; then
    GO_TARBALL="go${GO_VERSION}.linux-amd64.tar.gz"
    GLIBC_LDSO="$PREFIX/glibc/lib/ld-linux-x86-64.so.2"
else
    echo -e "${RED}[FAIL]${NC} Unsupported architecture for Native Go: $ARCH"
    exit 1
fi

GO_URL="https://go.dev/dl/${GO_TARBALL}"

if [ ! -x "$GLIBC_LDSO" ]; then
    echo -e "${RED}[FAIL]${NC} glibc dynamic linker not found at $GLIBC_LDSO"
    echo -e "${YELLOW}[INFO]${NC} Please ensure glibc-runner is installed via RTX⚡2 runtime dependencies."
    exit 1
fi

# Check if already installed
if [ -x "$GO_DIR/bin/go" ]; then
    INSTALLED_VER=$("$GO_DIR/bin/go" version 2>/dev/null | awk '{print $3}' | sed 's/^go//' || echo "unknown")
    if [ "$INSTALLED_VER" = "$GO_VERSION" ]; then
        echo -e "${GREEN}[SKIP]${NC} Go already installed (v${INSTALLED_VER})"
        exit 0
    else
        echo -e "${YELLOW}[INFO]${NC} Go v${INSTALLED_VER} -> v${GO_VERSION} (upgrading)"
        rm -rf "$GO_DIR"
    fi
fi

# Download & Extract
echo "Downloading Go v${GO_VERSION} (${GO_TARBALL})..."
echo "  (File size ~70MB — may take a few minutes)"
mkdir -p "$OPENCLAW_DIR"

TMP_DIR=$(mktemp -d "$PREFIX/tmp/go-install.XXXXXX") || {
    echo -e "${RED}[FAIL]${NC} Failed to create temp directory"
    exit 1
}
trap 'rm -rf "$TMP_DIR"' EXIT

if ! curl -fL --max-time 600 "$GO_URL" -o "$TMP_DIR/$GO_TARBALL"; then
    echo -e "${RED}[FAIL]${NC} Failed to download Go v${GO_VERSION}"
    exit 1
fi
echo -e "${GREEN}[OK]${NC}   Downloaded $GO_TARBALL"

echo "Extracting Go... (this may take a moment)"
if ! tar -xzf "$TMP_DIR/$GO_TARBALL" -C "$OPENCLAW_DIR"; then
    echo -e "${RED}[FAIL]${NC} Failed to extract Go"
    exit 1
fi
echo -e "${GREEN}[OK]${NC}   Extracted to $GO_DIR"

# Termux cleanup collision prevention
if command -v pkg >/dev/null 2>&1; then
    if dpkg -s golang &>/dev/null; then
        echo -e "${YELLOW}[INFO]${NC} Removing Termux default golang package to avoid conflicts..."
        pkg uninstall -y golang 2>/dev/null || true
    fi
fi

# Create Wrapper Scripts
echo ""
echo "Creating wrapper scripts (glibc ld.so direct execution)..."

mkdir -p "$PREFIX/bin"

for cmd in go gofmt; do
    if [ -f "$GO_DIR/bin/$cmd" ] && [ ! -L "$GO_DIR/bin/$cmd" ] && [ "$cmd" != "go.real" ] && [ "$cmd" != "gofmt.real" ]; then
        mv "$GO_DIR/bin/$cmd" "$GO_DIR/bin/${cmd}.real"
    fi

    cat > "$GO_DIR/bin/$cmd" << WRAPPER
#!/$PREFIX/bin/bash
[ -n "\$LD_PRELOAD" ] && export _OA_ORIG_LD_PRELOAD="\$LD_PRELOAD"
unset LD_PRELOAD
exec "$GLIBC_LDSO" "\$(dirname "\$0")/${cmd}.real" "\$@"
WRAPPER
    chmod +x "$GO_DIR/bin/$cmd"
    
    # Symlink to global PATH
    ln -sf "$GO_DIR/bin/$cmd" "$PREFIX/bin/$cmd"
    echo -e "${GREEN}[OK]${NC}   $cmd wrapper created and linked to $PREFIX/bin/$cmd"
done

# Verification
echo ""
echo "Verifying glibc Go..."

if "$GO_DIR/bin/go" version >/dev/null 2>&1; then
    FINAL_VER=$("$PREFIX/bin/go" version)
    echo -e "${GREEN}[OK]${NC}   Successfully installed: $FINAL_VER"
    echo -e "${CYAN}[INFO]${NC} You can now use 'go install' natively for Linux skills!"
else
    echo -e "${RED}[FAIL]${NC} Go verification failed — wrapper script or glibc linker setup may be broken."
    exit 1
fi
