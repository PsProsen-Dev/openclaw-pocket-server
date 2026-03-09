#!/usr/bin/env bash
# =============================================================================
# install-tools.sh — Optional tools installer for OpenClaw on Android
#
# Run via `oca --install`. Allows installing tools that were skipped
# during the initial bootstrap.
# Already installed tools are marked as [INSTALLED] and skipped.
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

PROJECT_DIR="$HOME/.oca"
PLATFORM_MARKER="$PROJECT_DIR/.platform"
OCA_VERSION="1.0.14"
REPO_TARBALL="https://github.com/PsProsen-Dev/OpenClaw-On-Android/archive/refs/heads/main.tar.gz"

echo ""
echo -e "${BOLD}========================================${NC}"
echo -e "${BOLD}  OpenClaw on Android - Install Tools${NC}"
echo -e "${BOLD}========================================${NC}"
echo ""

# --- Pre-checks ---
if [ -z "${PREFIX:-}" ]; then
    echo -e "${RED}[FAIL]${NC} Not running in Termux (\$PREFIX not set)"
    exit 1
fi

if ! command -v curl &>/dev/null; then
    echo -e "${RED}[FAIL]${NC} curl not found. Install it with: pkg install curl"
    exit 1
fi

if [ -f "$PROJECT_DIR/scripts/lib.sh" ]; then
    source "$PROJECT_DIR/scripts/lib.sh"
fi

if ! declare -f ask_yn &>/dev/null; then
    ask_yn() {
        local prompt="$1"
        local reply
        read -rp "$prompt [Y/n] " reply < /dev/tty
        [[ "${reply:-}" =~ ^[Nn]$ ]] && return 1
        return 0
    }
fi

IS_GLIBC=false
if [ -f "$PROJECT_DIR/.glibc-arch" ]; then
    IS_GLIBC=true
fi

# --- Detect installed tools ---
echo -e "${BOLD}Checking installed tools...${NC}"
echo ""

declare -A TOOL_STATUS

check_tool() {
    local name="$1"
    local cmd="$2"
    if command -v "$cmd" &>/dev/null; then
        TOOL_STATUS["$name"]="installed"
        echo -e "  ${GREEN}[INSTALLED]${NC} $name"
    else
        TOOL_STATUS["$name"]="not_installed"
        echo -e "  ${YELLOW}[NOT INSTALLED]${NC} $name"
    fi
}

check_tool "tmux" "tmux"
check_tool "ttyd" "ttyd"
check_tool "dufs" "dufs"
check_tool "android-tools" "adb"
check_tool "Chromium" "chromium-browser"
if command -v npm &>/dev/null && npm list -g playwright-core &>/dev/null 2>&1; then
    TOOL_STATUS["Playwright"]="installed"
    echo -e "  ${GREEN}[INSTALLED]${NC} Playwright"
else
    TOOL_STATUS["Playwright"]="not_installed"
    echo -e "  ${YELLOW}[NOT INSTALLED]${NC} Playwright"
fi
check_tool "code-server" "code-server"
if [ "$IS_GLIBC" = true ]; then
    check_tool "OpenCode" "opencode"
    if [ -x "$PROJECT_DIR/go/bin/go" ]; then
        TOOL_STATUS["Go"]="installed"
        echo -e "  ${GREEN}[INSTALLED]${NC} Go (Native Glibc)"
    else
        TOOL_STATUS["Go"]="not_installed"
        echo -e "  ${YELLOW}[NOT INSTALLED]${NC} Go (Native Glibc)"
    fi
fi
check_tool "QWEN Code CLI" "qwen"
check_tool "Gemini CLI" "gemini"
check_tool "Homebrew" "brew"

echo ""

# --- Check if anything to install ---
HAS_UNINSTALLED=false
for status in "${TOOL_STATUS[@]}"; do
    if [ "$status" = "not_installed" ]; then
        HAS_UNINSTALLED=true
        break
    fi
done

if [ "$HAS_UNINSTALLED" = false ]; then
    echo -e "${GREEN}All available tools are already installed.${NC}"
    echo ""
    exit 0
fi

# --- Collect selections ---
echo -e "${BOLD}Select tools to install:${NC}"
echo ""

echo -e "${CYAN}Core Tools (Playwright, Homebrew, VS Code, Go, Chromium) will be Auto-Installed if missing!${NC}"
echo ""

INSTALL_TMUX=false
INSTALL_TTYD=false
INSTALL_DUFS=false
INSTALL_ANDROID_TOOLS=false
INSTALL_CODE_SERVER=false
INSTALL_OPENCODE=false
INSTALL_GO=false
INSTALL_HOMEBREW=false
INSTALL_CHROMIUM=false
INSTALL_PLAYWRIGHT=false

if [ "${TOOL_STATUS[tmux]}" = "not_installed" ]; then INSTALL_TMUX=true; fi
if [ "${TOOL_STATUS[ttyd]}" = "not_installed" ]; then INSTALL_TTYD=true; fi
if [ "${TOOL_STATUS[dufs]}" = "not_installed" ]; then INSTALL_DUFS=true; fi
if [ "${TOOL_STATUS[android-tools]}" = "not_installed" ]; then INSTALL_ANDROID_TOOLS=true; fi
if [ "${TOOL_STATUS[Chromium]}" = "not_installed" ]; then INSTALL_CHROMIUM=true; fi
if [ "${TOOL_STATUS[Playwright]}" = "not_installed" ]; then INSTALL_PLAYWRIGHT=true; fi
if [ "${TOOL_STATUS[code-server]}" = "not_installed" ]; then INSTALL_CODE_SERVER=true; fi
if [ "$IS_GLIBC" = true ] && [ "${TOOL_STATUS[OpenCode]}" = "not_installed" ]; then INSTALL_OPENCODE=true; fi
if [ "$IS_GLIBC" = true ] && [ "${TOOL_STATUS[Go]}" = "not_installed" ]; then INSTALL_GO=true; fi
if [ "${TOOL_STATUS[Homebrew]}" = "not_installed" ]; then INSTALL_HOMEBREW=true; fi
if [ "${TOOL_STATUS[QWEN Code CLI]}" = "not_installed" ]; then INSTALL_QWEN_CODE_CLI=true; fi
if [ "${TOOL_STATUS[Gemini CLI]}" = "not_installed" ]; then INSTALL_GEMINI_CLI=true; fi

# --- Check if anything selected ---
ANYTHING_SELECTED=false
for var in INSTALL_TMUX INSTALL_TTYD INSTALL_DUFS INSTALL_ANDROID_TOOLS \
           INSTALL_CHROMIUM INSTALL_PLAYWRIGHT INSTALL_CODE_SERVER INSTALL_OPENCODE \
           INSTALL_GO INSTALL_QWEN_CODE_CLI INSTALL_GEMINI_CLI INSTALL_HOMEBREW; do
    if [ "${!var}" = true ]; then
        ANYTHING_SELECTED=true
        break
    fi
done

if [ "$ANYTHING_SELECTED" = false ]; then
    echo ""
    echo "No tools selected."
    exit 0
fi

# --- Download scripts (needed for code-server and OpenCode) ---
NEEDS_TARBALL=false
if [ "$INSTALL_CODE_SERVER" = true ] || [ "$INSTALL_OPENCODE" = true ] || [ "$INSTALL_GO" = true ] || [ "$INSTALL_CHROMIUM" = true ] || [ "$INSTALL_PLAYWRIGHT" = true ] || [ "$INSTALL_HOMEBREW" = true ]; then
    NEEDS_TARBALL=true
fi

if [ "$NEEDS_TARBALL" = true ]; then
    echo ""
    echo "Downloading install scripts..."
    mkdir -p "$PREFIX/tmp"
    RELEASE_TMP=$(mktemp -d "$PREFIX/tmp/oca-install.XXXXXX") || {
        echo -e "${RED}[FAIL]${NC} Failed to create temp directory"
        exit 1
    }
    trap 'rm -rf "$RELEASE_TMP"' EXIT

    if curl -sfL "$REPO_TARBALL" | tar xz -C "$RELEASE_TMP" --strip-components=1; then
        echo -e "${GREEN}[OK]${NC}   Downloaded install scripts"
    else
        echo -e "${RED}[FAIL]${NC} Failed to download scripts"
        exit 1
    fi
fi

# --- Install selected tools ---
echo ""
echo -e "${BOLD}Installing selected tools...${NC}"
echo ""

if [ "$INSTALL_TMUX" = true ]; then echo "Installing tmux..."; if pkg install -y tmux; then echo -e "${GREEN}[OK]${NC}   tmux installed"; fi; fi
if [ "$INSTALL_TTYD" = true ]; then echo "Installing ttyd..."; if pkg install -y ttyd; then echo -e "${GREEN}[OK]${NC}   ttyd installed"; fi; fi
if [ "$INSTALL_DUFS" = true ]; then echo "Installing dufs..."; if pkg install -y dufs; then echo -e "${GREEN}[OK]${NC}   dufs installed"; fi; fi
if [ "$INSTALL_ANDROID_TOOLS" = true ]; then echo "Installing android-tools..."; if pkg install -y android-tools; then echo -e "${GREEN}[OK]${NC}   android-tools installed"; fi; fi

if [ "$INSTALL_CODE_SERVER" = true ]; then
    mkdir -p "$PROJECT_DIR/patches"
    cp "$RELEASE_TMP/patches/argon2-stub.js" "$PROJECT_DIR/patches/argon2-stub.js" 2>/dev/null || true
    if bash "$RELEASE_TMP/scripts/install-code-server.sh" install; then
        echo -e "${GREEN}[OK]${NC}   code-server installed"
    else
        echo -e "${YELLOW}[WARN]${NC} code-server installation failed (non-critical)"
    fi
fi

if [ "$INSTALL_OPENCODE" = true ]; then
    if bash "$RELEASE_TMP/scripts/install-opencode.sh"; then
        echo -e "${GREEN}[OK]${NC}   OpenCode installed"
    else
        echo -e "${YELLOW}[WARN]${NC} OpenCode installation failed (non-critical)"
    fi
fi

if [ "$INSTALL_GO" = true ]; then
    if bash "$RELEASE_TMP/scripts/install-go.sh"; then
        echo -e "${GREEN}[OK]${NC}   Go (Native Glibc) installed"
    else
        echo -e "${YELLOW}[WARN]${NC} Go installation failed (non-critical)"
    fi
fi

if [ "$INSTALL_HOMEBREW" = true ]; then
    if bash "$RELEASE_TMP/scripts/install-homebrew.sh"; then
        echo -e "${GREEN}[OK]${NC}   Homebrew installed via proot-distro"
    else
        echo -e "${YELLOW}[WARN]${NC} Homebrew installation failed (non-critical)"
    fi
fi

if [ "$INSTALL_CHROMIUM" = true ]; then
    if bash "$RELEASE_TMP/scripts/install-chromium.sh" install; then
        echo -e "${GREEN}[OK]${NC}   Chromium installed"
    else
        echo -e "${YELLOW}[WARN]${NC} Chromium installation failed (non-critical)"
    fi
fi

if [ "$INSTALL_PLAYWRIGHT" = true ]; then
    if bash "$RELEASE_TMP/scripts/install-playwright.sh" install; then
        echo -e "${GREEN}[OK]${NC}   Playwright installed"
    else
        echo -e "${YELLOW}[WARN]${NC} Playwright installation failed (non-critical)"
    fi
fi

if [ "$INSTALL_QWEN_CODE_CLI" = true ]; then echo "Installing QWEN Code CLI..."; if npm install -g @qwen-code/qwen-code@latest; then echo -e "${GREEN}[OK]${NC}   QWEN Code CLI installed"; fi; fi
if [ "$INSTALL_GEMINI_CLI" = true ]; then echo "Installing Gemini CLI..."; if npm install -g @google/gemini-cli; then echo -e "${GREEN}[OK]${NC}   Gemini CLI installed"; fi; fi

echo ""
echo -e "${GREEN}${BOLD}  Installation Complete!${NC}"
echo ""
