#!/data/data/com.termux/files/usr/bin/bash
# setup-termux-api.sh — Install and verify Termux:API integration
set -uo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'
log_ok()   { echo -e "${GREEN}[OK]${NC}   $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }

echo ""
echo "=== RTX⚡1 — Termux:API Setup ==="
echo ""

# Install termux-api package
if ! command -v termux-battery-status >/dev/null 2>&1; then
    echo "Installing termux-api package..."
    if pkg install -y termux-api 2>/dev/null; then
        log_ok "termux-api package installed"
    else
        log_fail "Failed to install termux-api package"
        exit 1
    fi
else
    log_ok "termux-api package already installed"
fi

# Test basic API calls
echo ""
echo "Testing Termux:API..."

if termux-battery-status >/dev/null 2>&1; then
    BATTERY=$(termux-battery-status 2>/dev/null | grep -o '"percentage":[0-9]*' | cut -d: -f2)
    log_ok "Battery API works (${BATTERY:-?}%)"
else
    log_warn "Battery API failed — make sure Termux:API app is installed from F-Droid"
    log_info "Download: https://f-droid.org/en/packages/com.termux.api/"
fi

if termux-wifi-connectioninfo >/dev/null 2>&1; then
    log_ok "WiFi API works"
else
    log_warn "WiFi API failed (may need Termux:API app)"
fi

echo ""
log_info "Available Termux:API features:"
echo "  termux-battery-status     — Battery level and status"
echo "  termux-camera-photo       — Take photos"
echo "  termux-clipboard-get/set  — Clipboard access"
echo "  termux-notification       — Send notifications"
echo "  termux-sensor             — Accelerometer, gyroscope, etc."
echo "  termux-toast              — Show toast messages"
echo "  termux-tts-speak          — Text-to-speech"
echo "  termux-vibrate            — Vibrate device"
echo "  termux-wifi-connectioninfo — WiFi info"
echo "  termux-wifi-scaninfo      — Scan nearby WiFi"
echo ""
log_info "Full list: pkg show termux-api | grep -A999 'Description'"
