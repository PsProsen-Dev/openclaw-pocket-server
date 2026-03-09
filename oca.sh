#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$HOME/.oca"
SCRIPT_DIR="$PROJECT_DIR/scripts"

if [ -f "$SCRIPT_DIR/lib.sh" ]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/lib.sh"
    # shellcheck source=/dev/null
    if [ -f "$SCRIPT_DIR/backup.sh" ]; then
        source "$SCRIPT_DIR/backup.sh"
    fi
else
    OCA_VERSION="1.0.14"
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
    REPO_BASE_ORIGIN="https://raw.githubusercontent.com/PsProsen-Dev/OpenClaw-On-Android/main"
    REPO_BASE="$REPO_BASE_ORIGIN"
    PLATFORM_MARKER="$PROJECT_DIR/.platform"

    detect_platform() {
        if [ -f "$PLATFORM_MARKER" ]; then
            cat "$PLATFORM_MARKER"
            return 0
        fi
        return 1
    }

    resolve_repo_base() {
        if curl -sI --connect-timeout 3 "$REPO_BASE_ORIGIN/oca.sh" >/dev/null 2>&1; then
            REPO_BASE="$REPO_BASE_ORIGIN"; return 0
        fi
        local mirrors=(
            "https://ghfast.top/$REPO_BASE_ORIGIN"
            "https://ghproxy.net/$REPO_BASE_ORIGIN"
            "https://mirror.ghproxy.com/$REPO_BASE_ORIGIN"
        )
        for m in "${mirrors[@]}"; do
            if curl -sI --connect-timeout 3 "$m/oca.sh" >/dev/null 2>&1; then
                echo -e "  ${YELLOW}[MIRROR]${NC} Using mirror for GitHub downloads"
                REPO_BASE="$m"; return 0
            fi
        done
        return 1
    }
fi

show_help() {
    echo ""
    echo -e "${BOLD}oca${NC} — OpenClaw on Android Master CLI v${OCA_VERSION:-1.0.14}"
    echo ""
    echo "Usage: oca <command> [args]"
    echo ""
    echo "Core Engine:"
    echo "  shell               Drop into the Dual-Engine Linux RootFS (Debian) natively!"
    echo "  install [tool]      Install specific FHS module (e.g. oca install code-server, playwright, homebrew)"
    echo "  start [service]     Start a background service natively (e.g. oca start code-server)"
    echo ""
    echo "Management:"
    echo "  status              Show system status and FHS container specs"
    echo "  update              Update OpenClaw and Android patches"
    echo "  backup              Create a full backup of OpenClaw data"
    echo "  restore             Restore from a backup"
    echo "  uninstall           Remove OpenClaw on Android completely"
    echo ""
    echo "  version, -v         Show version"
    echo "  help, -h            Show this help message"
    echo ""
}

show_version() {
    echo "oca v${OCA_VERSION:-1.0.14} (OpenClaw on Android)"

    local latest
    latest=$(curl -sfL --max-time 3 "${REPO_BASE:-https://raw.githubusercontent.com/PsProsen-Dev/OpenClaw-On-Android/main}/scripts/lib.sh" 2>/dev/null \
        | grep -m1 '^OCA_VERSION=' | cut -d'"' -f2) || true

    if [ -n "${latest:-}" ]; then
        if [ "$latest" = "${OCA_VERSION:-1.0.14}" ]; then
            echo -e "  ${GREEN}Up to date${NC}"
        else
            echo -e "  ${YELLOW}v${latest} available${NC} - run: oca update"
        fi
    fi
}

cmd_update() {
    if ! command -v curl &>/dev/null; then
        echo -e "${RED}[FAIL]${NC} curl not found. Install it with: pkg install curl"
        exit 1
    fi

    mkdir -p "$PROJECT_DIR"
    local LOGFILE="$PROJECT_DIR/update.log"

    local TMPFILE
    TMPFILE=$(mktemp "${TMPDIR:-${PREFIX:-/tmp}/tmp}/update-core.XXXXXX.sh" 2>/dev/null) \
        || TMPFILE=$(mktemp "/tmp/update-core.XXXXXX.sh")

    if ! curl -sfL "${REPO_BASE:-https://raw.githubusercontent.com/PsProsen-Dev/OpenClaw-On-Android/main}/update-core.sh" -o "$TMPFILE"; then
        rm -f "$TMPFILE"
        echo -e "${RED}[FAIL]${NC} Failed to download update-core.sh"
        exit 1
    fi

    bash "$TMPFILE" 2>&1 | tee "$LOGFILE"
    rm -f "$TMPFILE"

    echo ""
    echo -e "${YELLOW}Log saved to $LOGFILE${NC}"
}

cmd_uninstall() {
    local UNINSTALL_SCRIPT="$PROJECT_DIR/uninstall.sh"

    if [ ! -f "$UNINSTALL_SCRIPT" ]; then
        echo -e "${RED}[FAIL]${NC} Uninstall script not found at $UNINSTALL_SCRIPT"
        echo ""
        echo "You can download it manually:"
        echo "  curl -sL ${REPO_BASE:-https://raw.githubusercontent.com/PsProsen-Dev/OpenClaw-On-Android/main}/uninstall.sh -o $UNINSTALL_SCRIPT && chmod +x $UNINSTALL_SCRIPT"
        exit 1
    fi

    bash "$UNINSTALL_SCRIPT"
}

cmd_status() {
    echo ""
    echo -e "${BOLD}========================================${NC}"
    echo -e "${BOLD}  OpenClaw on Android — Status${NC}"
    echo -e "${BOLD}========================================${NC}"

    echo ""
    echo -e "${BOLD}Version${NC}"
    echo "  oca:         v${OCA_VERSION:-1.0.14}"

    local PLATFORM
    if declare -f detect_platform > /dev/null; then
        PLATFORM=$(detect_platform 2>/dev/null) || PLATFORM=""
    else
        PLATFORM=""
    fi
    if [ -n "$PLATFORM" ]; then
        echo "  Platform:    $PLATFORM"
    else
        echo -e "  Platform:    ${RED}not detected${NC}"
    fi

    echo ""
    echo -e "${BOLD}Environment${NC}"
    echo "  PREFIX:            ${PREFIX:-not set}"
    echo "  TMPDIR:            ${TMPDIR:-not set}"

    echo ""
    echo -e "${BOLD}Paths${NC}"
    local CHECK_DIRS=("$PROJECT_DIR" "${PREFIX:-}/tmp")
    for dir in "${CHECK_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            echo -e "  ${GREEN}[OK]${NC}   $dir"
        else
            echo -e "  ${RED}[MISS]${NC} $dir"
        fi
    done

    echo ""
    echo -e "${BOLD}Dual-Engine FHS Container${NC}"
    local ROOTFS="${PREFIX:-}/var/lib/proot-distro/installed-rootfs/debian"
    if [ -d "$ROOTFS" ]; then
        echo -e "  ${GREEN}[OK]${NC}   Debian rootfs is installed and ready"
    else
        echo -e "  ${RED}[MISS]${NC} Debian rootfs not found"
    fi

    echo ""
    echo -e "${BOLD}Configuration${NC}"
    if grep -qF "OpenClaw on Android" "$HOME/.bashrc" 2>/dev/null; then
        echo -e "  ${GREEN}[OK]${NC}   .bashrc environment block present"
    else
        echo -e "  ${RED}[MISS]${NC} .bashrc environment block not found"
    fi

    local STATUS_SCRIPT="$PROJECT_DIR/platforms/$PLATFORM/status.sh"
    if [ -n "$PLATFORM" ] && [ -f "$STATUS_SCRIPT" ]; then
        bash "$STATUS_SCRIPT"
    fi

    # Resource usage (Debian)
    if [ -d "$ROOTFS" ]; then
        echo -e "${BOLD}Disk Usage (Debian)${NC}"
        du -sh "$ROOTFS" 2>/dev/null | sed 's/^/  /' || echo "  Unable to calculate"
    fi

    echo ""
}

cmd_clean() {
    echo -e "${YELLOW}[CLEAN]${NC} Purging temporary files and caches..."
    
    # Termux caches
    rm -rf "$HOME/.cache"/* 2>/dev/null || true
    rm -rf "${PREFIX:-}/tmp"/* 2>/dev/null || true
    
    # Debian FHS caches (if possible)
    local ROOTFS="${PREFIX:-}/var/lib/proot-distro/installed-rootfs/debian"
    if [ -d "$ROOTFS" ]; then
        echo "  Cleaning Debian caches..."
        # We run apt clean inside the container if it exists
        if [ "$(id -u)" -eq 0 ] || command -v su >/dev/null; then
             # Try root clean
             (proot-distro login debian --user root -- apt-get clean 2>/dev/null || true)
        fi
    fi

    echo -e "${GREEN}[DONE]${NC} System optimized.\n"
}

cmd_install() {
    local TARGET_TOOL="${1:-}"
    
    if [ -z "$TARGET_TOOL" ]; then
        if ! command -v curl &>/dev/null; then
            echo -e "${RED}[FAIL]${NC} curl not found. Install it with: pkg install curl"
            exit 1
        fi
        local TMPFILE
        TMPFILE=$(mktemp "${TMPDIR:-${PREFIX:-/tmp}/tmp}/install-tools.XXXXXX.sh" 2>/dev/null) \
            || TMPFILE=$(mktemp "/tmp/install-tools.XXXXXX.sh")
        if ! curl -sfL "${REPO_BASE:-https://raw.githubusercontent.com/PsProsen-Dev/OpenClaw-On-Android/main}/install-tools.sh" -o "$TMPFILE"; then
            echo -e "${RED}[FAIL]${NC} Failed to download install-tools.sh"
            exit 1
        fi
        bash "$TMPFILE"
        rm -f "$TMPFILE"
        return
    fi

    # Local Arsenal Install Route
    local FALLBACK_SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts"
    local INSTALL_SCRIPT="$SCRIPT_DIR/install-${TARGET_TOOL}.sh"
    
    if [ ! -f "$INSTALL_SCRIPT" ] && [ -f "$FALLBACK_SCRIPTS/install-${TARGET_TOOL}.sh" ]; then
        INSTALL_SCRIPT="$FALLBACK_SCRIPTS/install-${TARGET_TOOL}.sh"
    fi

    if [ -f "$INSTALL_SCRIPT" ]; then
        echo -e "${CYAN}Executing: oca install ${TARGET_TOOL}${NC}"
        bash "$INSTALL_SCRIPT"
    else
        echo -e "${RED}[FAIL]${NC} Unknown tool '$TARGET_TOOL'. Could not find installer script."
    fi
}

cmd_shell() {
    local ROOTFS="${PREFIX:-}/var/lib/proot-distro/installed-rootfs/debian"
    if [ ! -d "$ROOTFS" ]; then
        echo -e "${RED}[FAIL]${NC} The Dual-Engine FHS container (Debian) is not installed."
        echo "Please run 'oca install homebrew' first."
        exit 1
    fi

    local IS_ROOTED=false
    if command -v su >/dev/null 2>&1; then
        if su -c "id" >/dev/null 2>&1; then
            IS_ROOTED=true
        fi
    fi

    # Standard Environment for the Shell
    export LANG=${LANG:-C.UTF-8}
    export LC_ALL=${LC_ALL:-C.UTF-8}

    echo -e "${GREEN}========================================${NC}"
    echo -e "${BOLD}  OpenClaw FHS God Mode Shell  ${NC}"
    echo -e "${GREEN}========================================${NC}"
    
    if [ "$IS_ROOTED" = true ]; then
        echo -e "${CYAN}Engine:${NC} Native Chroot (Maximum Performance)"
        echo -e "${CYAN}User:${NC}   root\n"
        su -c "
            if ! mountpoint -q \"$ROOTFS/proc\"; then mount -t proc proc \"$ROOTFS/proc\"; fi
            if ! mountpoint -q \"$ROOTFS/sys\"; then mount -t sysfs sysfs \"$ROOTFS/sys\"; fi
            if ! mountpoint -q \"$ROOTFS/dev\"; then mount --bind /dev \"$ROOTFS/dev\"; fi
            if ! mountpoint -q \"$ROOTFS/data/data/com.termux\"; then
                mkdir -p \"$ROOTFS/data/data/com.termux\"
                mount --bind /data/data/com.termux \"$ROOTFS/data/data/com.termux\"
            fi
            if [ -d /sdcard ]; then
                if ! mountpoint -q \"$ROOTFS/sdcard\"; then
                    mkdir -p \"$ROOTFS/sdcard\"
                    mount --bind /sdcard \"$ROOTFS/sdcard\"
                fi
            fi
            mkdir -p \"$ROOTFS/tmp\"
            chmod 1777 \"$ROOTFS/tmp\"
        " >/dev/null 2>&1
        su -c "chroot \"$ROOTFS\" /bin/su - root" || true
    else
        echo -e "${CYAN}Engine:${NC} Safe Proot (Standard Compatibility)"
        echo -e "${CYAN}User:${NC}   root\n"
        export PROOT_NO_SECCOMP=1
        local SDCARD_BIND=""
        [ -d /sdcard ] && SDCARD_BIND="--bind /sdcard:/sdcard"
        proot-distro login debian --shared-tmp \
            --bind "${PREFIX:-}:/termux" \
            --bind "$HOME:$HOME" \
            $SDCARD_BIND \
            --bind "$(pwd)":"$(pwd)" \
            --user root || true
    fi

    echo -e "\n${YELLOW}Exited FHS Shell.${NC}"
}

cmd_start() {
    local SERVICE="${1:-}"
    if [ -z "$SERVICE" ]; then
        echo -e "${RED}[FAIL]${NC} Please specify a service to start. Available:"
        echo "  - code-server"
        echo "  - ttyd"
        exit 1
    fi

    if [ "$SERVICE" = "code-server" ] || [ "$SERVICE" = "opencode" ]; then
        if command -v code-server >/dev/null 2>&1 || [ -x "$HOME/.local/bin/code-server" ]; then
            echo -e "${GREEN}[START]${NC} Booting VS Code Server inside Dual-Engine..."
            echo -e "${CYAN}Access your IDE at: ${BOLD}http://127.0.0.1:8080${NC}"
            if command -v code-server >/dev/null 2>&1; then
                code-server
            else
                "$HOME/.local/bin/code-server"
            fi
        else
            echo -e "${RED}[FAIL]${NC} code-server is not installed. Run: oca install code-server"
        fi
    elif [ "$SERVICE" = "ttyd" ]; then
        if command -v ttyd >/dev/null 2>&1; then
            echo -e "${GREEN}[START]${NC} Booting TTYD Web Terminal..."
            echo -e "${CYAN}Access terminal at: ${BOLD}http://127.0.0.1:7681${NC}"
            ttyd bash
        else
            echo -e "${RED}[FAIL]${NC} ttyd is not installed. Run: pkg install ttyd"
        fi
    else
        echo -e "${RED}[FAIL]${NC} Unknown service '$SERVICE'"
    fi
}

# Resolve mirror before any network operation via original URL if needed
case "${1:-}" in --update|update) if declare -f resolve_repo_base >/dev/null; then resolve_repo_base || true; fi ;; esac

case "${1:-}" in
    --update|update) cmd_update ;;
    --install|install) cmd_install "${2:-}" ;;
    --uninstall|uninstall) cmd_uninstall ;;
    clean) cmd_clean ;;
    --backup|backup)
        if declare -f cmd_backup > /dev/null 2>&1; then cmd_backup "${2:-}"; else echo -e "${RED}[FAIL]${NC} backup.sh not found."; exit 1; fi
        ;;
    --restore|restore)
        if declare -f cmd_restore > /dev/null 2>&1; then cmd_restore; else echo -e "${RED}[FAIL]${NC} backup.sh not found."; exit 1; fi
        ;;
    --status|status) cmd_status ;;
    shell) cmd_shell ;;
    start) cmd_start "${2:-}" ;;
    --version|-v|version) show_version ;;
    --help|-h|"") show_help ;;
    *)
        echo -e "${RED}Unknown option: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac
