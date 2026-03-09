#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/lib.sh"

echo ""
echo -e "${BOLD}========================================${NC}"
echo -e "${BOLD}  OpenClaw on Android - Installer v${OCA_VERSION}${NC}"
echo -e "${BOLD}========================================${NC}"
echo ""
echo "This script installs OpenClaw on Termux with platform-aware architecture."
echo ""

step() {
    echo ""
    echo -e "${BOLD}[$1/8] $2${NC}"
    echo "----------------------------------------"
}

step 1 "Environment Check"
if command -v termux-wake-lock &>/dev/null; then
    termux-wake-lock 2>/dev/null || true
    echo -e "${GREEN}[OK]${NC}   Termux wake lock enabled"
fi
bash "$SCRIPT_DIR/scripts/check-env.sh"

step 2 "Platform Selection"
SELECTED_PLATFORM="openclaw"
echo -e "${GREEN}[OK]${NC}   Platform: OpenClaw"
load_platform_config "$SELECTED_PLATFORM" "$SCRIPT_DIR"

step 3 "Total Auto-Install Selection (RTX⚡3)"
# CORE TOOLS & AI CLI: AUTO INSTALL
INSTALL_TMUX=true
INSTALL_TTYD=true
INSTALL_DUFS=true
INSTALL_ANDROID_TOOLS=true
INSTALL_CODE_SERVER=true
INSTALL_OPENCODE=true
INSTALL_GO=true
INSTALL_CHROMIUM=true
INSTALL_HOMEBREW=true
INSTALL_PLAYWRIGHT=true
INSTALL_QWEN_CODE_CLI=true
INSTALL_GEMINI_CLI=true

echo -e "${CYAN}All Tools including QWEN & Gemini CLI will be Auto-Installed!${NC}"
echo ""

step 4 "Core Infrastructure (RTX⚡1)"
bash "$SCRIPT_DIR/scripts/install-infra-deps.sh"
bash "$SCRIPT_DIR/scripts/setup-paths.sh"

step 5 "Platform Runtime Dependencies (RTX⚡2)"
if [ "${PLATFORM_NEEDS_GLIBC:-false}" = true ]; then bash "$SCRIPT_DIR/scripts/install-glibc.sh"; fi
if [ "${PLATFORM_NEEDS_NODEJS:-false}" = true ]; then bash "$SCRIPT_DIR/scripts/install-nodejs.sh"; fi
if [ "${PLATFORM_NEEDS_BUILD_TOOLS:-false}" = true ]; then bash "$SCRIPT_DIR/scripts/install-build-tools.sh"; fi
if [ "${PLATFORM_NEEDS_PROOT:-false}" = true ]; then pkg install -y proot; fi

# Source environment for current session (needed by platform install)
GLIBC_NODE_DIR="$PROJECT_DIR/node"
export PATH="$GLIBC_NODE_DIR/bin:$HOME/.local/bin:$PATH"
export TMPDIR="$PREFIX/tmp"
export TMP="$TMPDIR"
export TEMP="$TMPDIR"
export OA_GLIBC=1

step 6 "Platform Package Install (RTX⚡2)"
bash "$SCRIPT_DIR/platforms/$SELECTED_PLATFORM/install.sh"

echo ""
echo -e "${BOLD}[6.5] Environment Variables + CLI + Marker${NC}"
echo "----------------------------------------"
bash "$SCRIPT_DIR/scripts/setup-env.sh"

PLATFORM_ENV_SCRIPT="$SCRIPT_DIR/platforms/$SELECTED_PLATFORM/env.sh"
if [ -f "$PLATFORM_ENV_SCRIPT" ]; then
    eval "$(bash "$PLATFORM_ENV_SCRIPT")"
fi

mkdir -p "$PROJECT_DIR"
echo "$SELECTED_PLATFORM" > "$PLATFORM_MARKER"

cp "$SCRIPT_DIR/oca.sh" "$PREFIX/bin/oca"
chmod +x "$PREFIX/bin/oca"
cp "$SCRIPT_DIR/update.sh" "$PREFIX/bin/ocaupdate"
chmod +x "$PREFIX/bin/ocaupdate"

cp "$SCRIPT_DIR/uninstall.sh" "$PROJECT_DIR/uninstall.sh"
chmod +x "$PROJECT_DIR/uninstall.sh"

mkdir -p "$PROJECT_DIR/scripts"
mkdir -p "$PROJECT_DIR/platforms"
cp "$SCRIPT_DIR/scripts/lib.sh" "$PROJECT_DIR/scripts/lib.sh"
cp "$SCRIPT_DIR/scripts/setup-env.sh" "$PROJECT_DIR/scripts/setup-env.sh"
cp "$SCRIPT_DIR/scripts/backup.sh" "$PROJECT_DIR/scripts/backup.sh"
rm -rf "$PROJECT_DIR/platforms/$SELECTED_PLATFORM"
cp -R "$SCRIPT_DIR/platforms/$SELECTED_PLATFORM" "$PROJECT_DIR/platforms/$SELECTED_PLATFORM"

step 7 "Install Optional Tools (RTX⚡3)"
if [ "$INSTALL_TMUX" = true ]; then pkg install -y tmux; fi
if [ "$INSTALL_TTYD" = true ]; then pkg install -y ttyd; fi
if [ "$INSTALL_DUFS" = true ]; then pkg install -y dufs; fi
if [ "$INSTALL_ANDROID_TOOLS" = true ]; then pkg install -y android-tools; fi

if [ "$INSTALL_CHROMIUM" = true ]; then bash "$SCRIPT_DIR/scripts/install-chromium.sh" install; fi

if [ "$INSTALL_CODE_SERVER" = true ]; then mkdir -p "$PROJECT_DIR/patches" && cp "$SCRIPT_DIR/patches/argon2-stub.js" "$PROJECT_DIR/patches/argon2-stub.js" && bash "$SCRIPT_DIR/scripts/install-code-server.sh" install; fi

if [ "$INSTALL_OPENCODE" = true ]; then bash "$SCRIPT_DIR/scripts/install-opencode.sh" install; fi
if [ "$INSTALL_GO" = true ]; then bash "$SCRIPT_DIR/scripts/install-go.sh"; fi
if [ "$INSTALL_HOMEBREW" = true ]; then bash "$SCRIPT_DIR/scripts/install-homebrew.sh"; fi

if [ "$INSTALL_QWEN_CODE_CLI" = true ]; then npm install -g @qwen-code/qwen-code@latest; fi
if [ "$INSTALL_GEMINI_CLI" = true ]; then npm install -g @google/gemini-cli; fi

step 8 "Verification"
bash "$SCRIPT_DIR/tests/verify-install.sh"

echo ""
echo -e "${BOLD}========================================${NC}"
echo -e "${GREEN}${BOLD}  Installation Complete!${NC}"
echo -e "${BOLD}========================================${NC}"
echo ""
echo -e "  $PLATFORM_NAME $($PLATFORM_VERSION_CMD 2>/dev/null || echo '')"
echo ""
echo "Next step:"
echo "  $PLATFORM_POST_INSTALL_MSG"
echo ""
