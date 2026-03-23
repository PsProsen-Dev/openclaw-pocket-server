#!/usr/bin/env bash
# install-homebrew.sh - Install Homebrew (Linuxbrew) inside the glibc-enabled OCA environment
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

BREW_PREFIX="${HOME}/.linuxbrew"
BREW_BIN="${BREW_PREFIX}/bin/brew"
SHELLENV_LINE='eval "$($HOME/.linuxbrew/bin/brew shellenv)"'

echo "=== OCA — Installing Homebrew (experimental) ==="
echo ""

if [ "$(uname -m)" != "aarch64" ]; then
    echo -e "${RED}[FAIL]${NC} Homebrew support is currently documented for aarch64 only"
    exit 1
fi

if [ ! -x "$PREFIX/bin/grun" ]; then
    echo -e "${RED}[FAIL]${NC} grun not found — install glibc runtime first"
    exit 1
fi

if [ -x "$BREW_BIN" ]; then
    echo -e "${GREEN}[SKIP]${NC} Homebrew already installed at $BREW_BIN"
else
    echo -e "${CYAN}[INFO]${NC} Installing Homebrew into ${BREW_PREFIX}"
    export NONINTERACTIVE=1
    export CI=1
    export HOME="$HOME"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

mkdir -p "$BREW_PREFIX/bin"

if ! grep -Fq "$SHELLENV_LINE" "$HOME/.bashrc" 2>/dev/null; then
    {
        echo ""
        echo "# Homebrew (managed by OCA)"
        echo "$SHELLENV_LINE"
    } >> "$HOME/.bashrc"
    echo -e "${GREEN}[OK]${NC}   Added Homebrew shellenv to ~/.bashrc"
fi

eval "$("$BREW_BIN" shellenv)"

echo -e "${YELLOW}[INFO]${NC} Homebrew depends on the glibc-enabled OCA environment; some formulae may still require manual tweaks on Android."
echo -e "${GREEN}[OK]${NC}   Homebrew ready: $("$BREW_BIN" --version | head -n 1)"
