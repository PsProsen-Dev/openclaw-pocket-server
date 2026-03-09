#!/usr/bin/env bash
# install-homebrew.sh - Containerized FHS Homebrew installation using proot-distro
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "=== RTX⚡3 — Installing Homebrew (Debian Proot-Distro) ==="
echo ""

if [ -z "${PREFIX:-}" ]; then
    echo -e "${RED}[FAIL]${NC} Not running in Termux (\$PREFIX not set)"
    exit 1
fi

if ! command -v proot-distro >/dev/null 2>&1; then
    echo -e "${YELLOW}[INFO]${NC} Installing proot-distro..."
    pkg install -y proot-distro || {
        echo -e "${RED}[FAIL]${NC} Could not install proot-distro"
        exit 1
    }
fi

echo -e "${CYAN}[INFO]${NC} Checking Debian rootfs..."
if ! proot-distro list | grep -q 'debian' 2>/dev/null; then
    echo -e "${YELLOW}[INFO]${NC} Downloading Debian base (~50MB download, ~150MB extracted)..."
    proot-distro install debian || {
        echo -e "${RED}[FAIL]${NC} Failed to install Debian guest via proot-distro"
        exit 1
    }
else
    echo -e "${GREEN}[OK]${NC}   Debian minimal rootfs already present."
fi

# Write the guest initialization script
INIT_SCRIPT=$(mktemp "$PREFIX/tmp/brew-init.XXXXXX")
cat > "$INIT_SCRIPT" << 'EOF'
#!/usr/bin/env bash
set -e
export DEBIAN_FRONTEND=noninteractive

# Update system and install Homebrew prerequisites
apt-get update -qq
apt-get install -yq build-essential procps curl file git bash gcc sudo locales

# Generate en_US.UTF-8 locale (Required by Homebrew Ruby)
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8

# Homebrew cannot be run as root. We must create a debian user.
if ! id "debian" &>/dev/null; then
    useradd -m -s /bin/bash debian
    usermod -aG sudo debian
    echo "debian ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/debian
fi

# Switch to the debian user to run the official install code
echo "Setting up Brew for user debian..."
mkdir -p /home/linuxbrew
chown debian:debian /home/linuxbrew
su - debian -c "
    git clone --depth=1 https://github.com/Homebrew/brew ~/.linuxbrew/Homebrew
    mkdir -p ~/.linuxbrew/bin
    ln -s ~/.linuxbrew/Homebrew/bin/brew ~/.linuxbrew/bin/brew
    eval \"\$(~/.linuxbrew/bin/brew shellenv)\"
    brew update --force --quiet
    echo \"eval \\\"\$(~/.linuxbrew/bin/brew shellenv)\\\"\" >> ~/.bashrc
"
echo "Brew installation succeeded inside container."
EOF

# Move script into accessible space for proot
chmod +x "$INIT_SCRIPT"
GUEST_SCRIPT="/tmp/brew_init.sh"
cp "$INIT_SCRIPT" "$PREFIX/var/lib/proot-distro/installed-rootfs/debian/tmp/brew_init.sh"

echo -e "${CYAN}[INFO]${NC} Jumping into Debian guest to configure Linuxbrew..."
proot-distro login debian --shared-tmp --bind "$PREFIX:/termux" -- /bin/bash "$GUEST_SCRIPT" || {
    echo -e "${RED}[FAIL]${NC} Guest provisioning crashed."
    rm -f "$INIT_SCRIPT"
    exit 1
}

rm -f "$PREFIX/var/lib/proot-distro/installed-rootfs/debian/tmp/brew_init.sh"
rm -f "$INIT_SCRIPT"

# Now we construct the transparent wrapper!
WRAPPER="$PREFIX/bin/brew"
cat > "$WRAPPER" << 'EOF'
#!/usr/bin/env bash
# OpenClaw Transparent Homebrew Wrapper (Dual-Engine)
# Auto-detects Root (su) to bypass proot overhead via Native Chroot, else safely uses proot-distro.

ROOTFS="$PREFIX/var/lib/proot-distro/installed-rootfs/debian"
IS_ROOTED=false
if command -v su >/dev/null 2>&1 && su -c true >/dev/null 2>&1; then
    IS_ROOTED=true
fi

# Escape arguments correctly for inner shells
args_escaped=()
for arg in "$@"; do
    args_escaped+=("$(printf '%q' "$arg")")
done

if [ "$IS_ROOTED" = true ]; then
    # --- Native Chroot Engine ---
    su -c "
        if ! mountpoint -q \"$ROOTFS/proc\"; then mount -t proc proc \"$ROOTFS/proc\"; fi
        if ! mountpoint -q \"$ROOTFS/sys\"; then mount -t sysfs sysfs \"$ROOTFS/sys\"; fi
        if ! mountpoint -q \"$ROOTFS/dev\"; then mount --bind /dev \"$ROOTFS/dev\"; fi
        mkdir -p \"$ROOTFS/tmp\"
        chmod 1777 \"$ROOTFS/tmp\"
    " >/dev/null 2>&1

    su -c "chroot \"$ROOTFS\" /bin/su - debian -c \"export PATH=/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:/usr/bin:/bin; brew ${args_escaped[*]}\""
    EXIT_CODE=$?
else
    # --- Safe Proot Engine ---
    export PROOT_NO_SECCOMP=1
    proot-distro login debian --shared-tmp --bind "$PREFIX:/termux" --bind "$(pwd)":"$(pwd)" --user debian -- bash -c "eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\" && brew ${args_escaped[*]}"
    EXIT_CODE=$?
fi

# Auto-Shim Pipeline: Sync newly installed Homebrew binaries to Termux
if [[ " $* " == *" install "* ]] || [[ " $* " == *" upgrade "* ]] || [[ " $* " == *" link "* ]]; then
    SHIM_DIR="$HOME/.oca/brew-bin"
    mkdir -p "$SHIM_DIR"
    
    BREW_BIN="$ROOTFS/home/linuxbrew/.linuxbrew/bin"
    if [ -d "$BREW_BIN" ]; then
        for bin_path in "$BREW_BIN"/*; do
            if [ -f "$bin_path" ] && [ -x "$bin_path" ]; then
                base_name=$(basename "$bin_path")
                if [ "$base_name" = "brew" ]; then continue; fi
                
                # Create SMART wrapper shim that supports Dual-Engine seamlessly
                cat > "$SHIM_DIR/$base_name" << SHIM_EOF
#!/usr/bin/env bash
ROOTFS="\$PREFIX/var/lib/proot-distro/installed-rootfs/debian"
args_escaped=()
for arg in "\$@"; do
    args_escaped+=("\$(printf '%q' "\$arg")")
done

if command -v su >/dev/null 2>&1 && su -c true >/dev/null 2>&1; then
    # Fast Native Chroot
    su -c "chroot \\"\$ROOTFS\\" /bin/su - debian -c \\"export PATH=/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:/usr/bin:/bin; exec $base_name \${args_escaped[*]}\\""
else
    # Safe Proot
    export PROOT_NO_SECCOMP=1
    exec proot-distro login debian --shared-tmp --bind "\$PREFIX:/termux" --bind "\$(pwd)":"\$(pwd)" --user debian -- bash -c "eval \\\\"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\\\\" && exec \\"$base_name\\" \${args_escaped[*]}"
fi
SHIM_EOF
                chmod +x "$SHIM_DIR/$base_name"
            fi
        done
    fi
fi

exit $EXIT_CODE
EOF
chmod +x "$WRAPPER"

echo -e "${GREEN}[OK]${NC}   Homebrew successfully integrated via proot virtualization!"
echo -e "${CYAN}[INFO]${NC} You can now run 'brew' from anywhere in Termux. It will transparently execute inside the FHS container."
