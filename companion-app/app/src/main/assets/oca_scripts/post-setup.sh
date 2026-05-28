#!/usr/bin/env bash
# OpenClaw Android — Post-Bootstrap Setup
# Runs in the terminal after Termux bootstrap extraction.
# Installs: git, glibc, Node.js, OpenClaw
#
# Strategy:
#   - Termux .deb packages: dpkg-deb -x + relocate (bypasses dpkg hardcoded paths)
#   - Pacman .pkg.tar.xz packages: tar -xJf + relocate (bypasses pacman entirely)
#   - Both have files under data/data/com.termux/files/usr/ which we relocate to $PREFIX
#
# Why not apt-get/dpkg/pacman?
#   All three have hardcoded /data/data/com.termux/... paths that libtermux-exec
#   cannot rewrite (it only intercepts execve, not open/opendir).

set -eo pipefail

# ─── Paths ────────────────────────────────────
: "${PREFIX:?PREFIX not set}"
: "${HOME:?HOME not set}"
: "${TMPDIR:=$(dirname "$PREFIX")/tmp}"

OCA_DIR="$HOME/.oca"
NODE_DIR="$OCA_DIR/node"
NODE_VERSION="24.14.1"
GLIBC_LDSO="$PREFIX/glibc/lib/ld-linux-aarch64.so.1"
MARKER="$OCA_DIR/.post-setup-done"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ─── GitHub mirror fallback (for restricted networks) ──
REPO_BASE_ORIGIN="https://raw.githubusercontent.com/PsProsen-Dev/OpenClaw-On-Android/main"
REPO_BASE="$REPO_BASE_ORIGIN"
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

# SSL cert for curl (bootstrap curl looks at hardcoded com.termux path)
export CURL_CA_BUNDLE="$PREFIX/etc/tls/cert.pem"
export SSL_CERT_FILE="$PREFIX/etc/tls/cert.pem"
export GIT_SSL_CAINFO="$PREFIX/etc/tls/cert.pem"

# Git system config has hardcoded com.termux path — skip it
export GIT_CONFIG_NOSYSTEM=1

# Git exec path (git looks for helpers like git-remote-https here)
export GIT_EXEC_PATH="$PREFIX/libexec/git-core"

# Git template dir (hardcoded /data/data/com.termux path workaround)
export GIT_TEMPLATE_DIR="$PREFIX/share/git-core/templates"

if [ -f "$MARKER" ]; then
    echo -e "${GREEN}Post-setup already completed.${NC}"
    exit 0
fi

echo ""
echo "══════════════════════════════════════════════"
echo "  OpenClaw on Android — Installing components"
echo "══════════════════════════════════════════════"
echo ""

mkdir -p "$OCA_DIR" "$OCA_DIR/patches" "$TMPDIR"

TERMUX_DEB_REPO="https://packages-cf.termux.dev/apt/termux-main"
PACMAN_PKG_REPO="https://service.termux-pacman.dev/gpkg/aarch64"
TERMUX_INNER="data/data/com.termux/files/usr"
DEB_DIR="$TMPDIR/debs"
PKG_DIR="$TMPDIR/pkgs"
EXTRACT_DIR="$TMPDIR/pkg-extract"

# ─── Helper: install_deb ──────────────────────
install_deb() {
    local filename="$1"
    local name
    name=$(basename "$filename" | sed 's/_[0-9].*//')
    local url="${TERMUX_DEB_REPO}/${filename}"
    local deb_file="${DEB_DIR}/$(basename "$filename")"

    if [ -f "$deb_file" ]; then
        echo "    (cached) $name"
    else
        echo "    downloading $name..."
        curl -fsSL --max-time 120 -o "$deb_file" "$url"
    fi

    rm -rf "$EXTRACT_DIR"
    mkdir -p "$EXTRACT_DIR"
    dpkg-deb -x "$deb_file" "$EXTRACT_DIR" 2>/dev/null

    if [ -d "$EXTRACT_DIR/$TERMUX_INNER" ]; then
        cp -a "$EXTRACT_DIR/$TERMUX_INNER/"* "$PREFIX/" 2>/dev/null || true
    fi
    rm -rf "$EXTRACT_DIR"
}

# ─── Helper: install_pacman_pkg ───────────────
install_pacman_pkg() {
    local filename="$1"
    local target="$2"  # e.g., $PREFIX/glibc
    local name
    name=${filename%%-[0-9]*}
    local url="${PACMAN_PKG_REPO}/${filename}"
    local pkg_file="${PKG_DIR}/${filename}"

    if [ -f "$pkg_file" ]; then
        echo "    (cached) $name"
    else
        echo "    downloading $name..."
        curl -fsSL --max-time 300 -o "$pkg_file" "$url"
    fi

    rm -rf "$EXTRACT_DIR"
    mkdir -p "$EXTRACT_DIR"
    tar -xJf "$pkg_file" -C "$EXTRACT_DIR" 2>/dev/null

    local inner="$EXTRACT_DIR/$TERMUX_INNER"
    if [ -d "$inner/glibc" ]; then
        cp -a "$inner/glibc/"* "$target/" 2>/dev/null || true
    elif [ -d "$inner" ]; then
        cp -a "$inner/"* "$target/" 2>/dev/null || true
    fi
    rm -rf "$EXTRACT_DIR"
}

# ─── [1/7] Install essential packages ─────────
echo -e "▸ ${YELLOW}[1/7]${NC} Installing essential packages..."
mkdir -p "$DEB_DIR" "$PKG_DIR"

echo "  Fetching package index..."
PACKAGES_FILE="$TMPDIR/Packages"
curl -fsSL --max-time 60 \
    "${TERMUX_DEB_REPO}/dists/stable/main/binary-aarch64/Packages" \
    -o "$PACKAGES_FILE"

get_deb_filename() {
    local pkg="$1"
    awk -v pkg="$pkg" '
        /^Package: / { found = ($2 == pkg) }
        found && /^Filename:/ { print $2; exit }
    ' "$PACKAGES_FILE"
}

DEB_PACKAGES=(
    libexpat
    pcre2
    git
)

TOTAL=${#DEB_PACKAGES[@]}
COUNT=0
for pkg in "${DEB_PACKAGES[@]}"; do
    COUNT=$((COUNT + 1))
    filename=$(get_deb_filename "$pkg")
    if [ -z "$filename" ]; then
        echo -e "  ${RED}✗${NC} Package '$pkg' not found in index"
        continue
    fi
    echo "  [$COUNT/$TOTAL] $pkg"
    install_deb "$filename"
done

chmod +x "$PREFIX/bin/"* 2>/dev/null || true

if [ -f "$PREFIX/bin/git" ]; then
    echo -e "  ${GREEN}✓${NC} git $(git --version 2>/dev/null | head -1)"
else
    echo -e "  ${RED}✗${NC} git not found after extraction"
    exit 1
fi

# ─── [2/7] glibc runtime ─────────────────────
echo -e "▸ ${YELLOW}[2/7]${NC} Installing glibc runtime..."

if [ -x "$GLIBC_LDSO" ]; then
    echo -e "  ${GREEN}[SKIP]${NC} glibc already installed"
else
    mkdir -p "$PREFIX/glibc"

    echo "  Downloading glibc (~10MB)..."
    install_pacman_pkg "glibc-2.42-0-aarch64.pkg.tar.xz" "$PREFIX/glibc"

    echo "  Downloading gcc-libs (~24MB)..."
    install_pacman_pkg "gcc-libs-glibc-14.2.1-1-aarch64.pkg.tar.xz" "$PREFIX/glibc"

    if [ ! -f "$GLIBC_LDSO" ]; then
        echo -e "  ${RED}✗${NC} glibc linker not found at $GLIBC_LDSO"
        exit 1
    fi
    chmod +x "$GLIBC_LDSO"
    mkdir -p "$OCA_DIR"
    touch "$OCA_DIR/.glibc-arch"
    echo -e "  ${GREEN}✓${NC} glibc installed"
fi
echo -e "  Linker: $GLIBC_LDSO"

# ─── [3/7] Node.js ──────────────────────────
echo -e "▸ ${YELLOW}[3/7]${NC} Installing Node.js v${NODE_VERSION}..."
mkdir -p "$NODE_DIR/bin"

if [ -f "$NODE_DIR/bin/node.real" ] && "$NODE_DIR/bin/node" --version &>/dev/null; then
    INSTALLED_VER=$("$NODE_DIR/bin/node" --version 2>/dev/null || echo "")
    echo -e "  ${GREEN}[SKIP]${NC} Node.js already installed ($INSTALLED_VER)"
    if [ -f "$NODE_DIR/lib/node_modules/npm/bin/npm-cli.js" ]; then
        rm -f "$NODE_DIR/bin/npm"
        cat > "$NODE_DIR/bin/npm" << NPMWRAP
#!$PREFIX/bin/bash
exec "$NODE_DIR/bin/node" "$NODE_DIR/lib/node_modules/npm/bin/npm-cli.js" "\$@"
NPMWRAP
        chmod +x "$NODE_DIR/bin/npm"
    fi
    if [ -f "$NODE_DIR/lib/node_modules/npm/bin/npx-cli.js" ]; then
        rm -f "$NODE_DIR/bin/npx"
        cat > "$NODE_DIR/bin/npx" << NPXWRAP
#!$PREFIX/bin/bash
exec "$NODE_DIR/bin/node" "$NODE_DIR/lib/node_modules/npm/bin/npx-cli.js" "\$@"
NPXWRAP
        chmod +x "$NODE_DIR/bin/npx"
    fi
    if [ -f "$NODE_DIR/bin/corepack" ] && head -1 "$NODE_DIR/bin/corepack" 2>/dev/null | grep -q '#!/usr/bin/env node'; then
        sed -i "1s|#!/usr/bin/env node|#!$NODE_DIR/bin/node|" "$NODE_DIR/bin/corepack"
    fi
else
    NODE_TAR="node-v${NODE_VERSION}-linux-arm64"
    echo "  Downloading Node.js v${NODE_VERSION} (~25MB)..."
    curl -fSL --max-time 300 \
        "https://nodejs.org/dist/v${NODE_VERSION}/${NODE_TAR}.tar.xz" \
        -o "$TMPDIR/${NODE_TAR}.tar.xz"

    echo "  Extracting..."
    tar -xJf "$TMPDIR/${NODE_TAR}.tar.xz" -C "$NODE_DIR" --strip-components=1

    if [ -f "$NODE_DIR/bin/node" ] && [ ! -L "$NODE_DIR/bin/node" ]; then
        mv "$NODE_DIR/bin/node" "$NODE_DIR/bin/node.real"
    fi

    rm -f "$TMPDIR/${NODE_TAR}.tar.xz"

    cat > "$NODE_DIR/bin/node" << WRAPPER
#!${PREFIX}/bin/bash
[ -n "\$LD_PRELOAD" ] && export _OA_ORIG_LD_PRELOAD="\$LD_PRELOAD"
unset LD_PRELOAD
_OA_COMPAT="\$HOME/.oca/patches/glibc-compat.js"
if [ -f "\$_OA_COMPAT" ]; then
    case "\${NODE_OPTIONS:-}" in
        *"\$_OA_COMPAT"*) ;;
        *) export NODE_OPTIONS="\${NODE_OPTIONS:+\$NODE_OPTIONS }-r \$_OA_COMPAT" ;;
    esac
fi
_LEADING_OPTS=""
_COUNT=0
for _arg in "\$@"; do
    case "\$_arg" in --*) _COUNT=\$((_COUNT + 1)) ;; *) break ;; esac
done
if [ \$_COUNT -gt 0 ] && [ \$_COUNT -lt \$# ]; then
    while [ \$# -gt 0 ]; do
        case "\$1" in
            --*) _LEADING_OPTS="\${_LEADING_OPTS:+\$_LEADING_OPTS }\$1"; shift ;;
            *) break ;;
        esac
    done
    export NODE_OPTIONS="\${NODE_OPTIONS:+\$NODE_OPTIONS }\$_LEADING_OPTS"
fi
exec "$GLIBC_LDSO" --library-path "$PREFIX/glibc/lib" "\$(dirname "\$0")/node.real" "\$@"
WRAPPER
    chmod +x "$NODE_DIR/bin/node"

    if [ -f "$NODE_DIR/lib/node_modules/npm/bin/npm-cli.js" ]; then
        rm -f "$NODE_DIR/bin/npm"
        cat > "$NODE_DIR/bin/npm" << NPMWRAP
#!$PREFIX/bin/bash
exec "$NODE_DIR/bin/node" "$NODE_DIR/lib/node_modules/npm/bin/npm-cli.js" "\$@"
NPMWRAP
        chmod +x "$NODE_DIR/bin/npm"
    fi
    if [ -f "$NODE_DIR/lib/node_modules/npm/bin/npx-cli.js" ]; then
        rm -f "$NODE_DIR/bin/npx"
        cat > "$NODE_DIR/bin/npx" << NPXWRAP
#!$PREFIX/bin/bash
exec "$NODE_DIR/bin/node" "$NODE_DIR/lib/node_modules/npm/bin/npx-cli.js" "\$@"
NPXWRAP
        chmod +x "$NODE_DIR/bin/npx"
    fi
    if [ -f "$NODE_DIR/bin/corepack" ] && head -1 "$NODE_DIR/bin/corepack" 2>/dev/null | grep -q '#!/usr/bin/env node'; then
        sed -i "1s|#!/usr/bin/env node|#!$NODE_DIR/bin/node|" "$NODE_DIR/bin/corepack"
    fi

    export PATH="$NODE_DIR/bin:$PATH"
    "$NODE_DIR/bin/npm" config set script-shell "$PREFIX/bin/sh" 2>/dev/null || true

    NODE_VER=$("$NODE_DIR/bin/node" --version 2>/dev/null) || {
        echo -e "  ${RED}✗${NC} Node.js verification failed"
        exit 1
    }
    echo -e "  ${GREEN}✓${NC} Node.js $NODE_VER (glibc)"
fi

# ─── [4/7] OpenClaw ─────────────────────────
echo -e "▸ ${YELLOW}[4/7]${NC} Installing OpenClaw..."
export PATH="$NODE_DIR/bin:$PATH"

resolve_repo_base

if ! curl -sI --connect-timeout 3 https://registry.npmjs.org >/dev/null 2>&1; then
    echo "  npm registry unreachable, switching to npmmirror.com..."
    npm config set registry https://registry.npmmirror.com
fi

cat > "$HOME/.gitconfig" << GITCFG
[http]
    sslCAInfo = $PREFIX/etc/tls/cert.pem
[url "https://github.com/"]
    insteadOf = ssh://git@github.com/
    insteadOf = git@github.com:
GITCFG

REAL_GIT="$PREFIX/libexec/git-core/git"
if [ -f "$REAL_GIT" ] && [ ! -f "$PREFIX/bin/git.wrapper-installed" ]; then
    echo "  Installing git wrapper (strips --recurse-submodules)..."
    rm -f "$PREFIX/bin/git"
    echo "#!${PREFIX}/bin/bash" > "$PREFIX/bin/git"
    cat >> "$PREFIX/bin/git" << 'ENDWRAP'
filtered=()
is_clone=false
for a in "$@"; do
  case "$a" in
    --recurse-submodules) ;;
    clone) is_clone=true; filtered+=("$a") ;;
    *) filtered+=("$a") ;;
  esac
done
if $is_clone; then
  for a in "${filtered[@]}"; do
    case "$a" in
      clone|--*|-*|http*|ssh*|git*|[0-9]) ;;
      *) [ -d "$a" ] && rm -rf "$a" ;;
    esac
  done
fi
ENDWRAP
    echo "exec \"$REAL_GIT\" \"\${filtered[@]}\"" >> "$PREFIX/bin/git"
    chmod +x "$PREFIX/bin/git"
    touch "$PREFIX/bin/git.wrapper-installed"
    echo -e "  ${GREEN}\u2713${NC} git wrapper installed"
else
    if [ -f "$PREFIX/bin/git.wrapper-installed" ]; then
        echo -e "  ${GREEN}[SKIP]${NC} git wrapper already installed"
    else
        echo -e "  ${RED}\u2717${NC} Real git not found at $REAL_GIT"
        exit 1
    fi
fi

if command -v openclaw &>/dev/null 2>&1; then
    OC_VER=$(openclaw --version 2>/dev/null || echo "unknown")
    echo -e "  ${GREEN}[SKIP]${NC} OpenClaw already installed ($OC_VER)"
else
    rm -rf "$HOME/.npm/_cacache/tmp" 2>/dev/null || true
    npm install -g openclaw@latest --ignore-scripts 2>&1
    OC_VER=$(openclaw --version 2>/dev/null || echo "installed")
    echo -e "  ${GREEN}✓${NC} OpenClaw $OC_VER"
fi

OPENCLAW_DIR="$(npm root -g)/openclaw"
if [ -d "$OPENCLAW_DIR/node_modules/@snazzah/davey" ]; then
    echo "  Installing native bindings for @snazzah/davey..."
    (cd "$OPENCLAW_DIR" && npm install @snazzah/davey --no-fund --no-audit --no-save 2>/dev/null) || true
fi

echo "  Installing clawdhub..."
if npm install -g clawdhub --no-fund --no-audit; then
    echo -e "  ${GREEN}✓${NC} clawdhub installed"
    CLAWHUB_DIR="$(npm root -g)/clawdhub"
    if [ -d "$CLAWHUB_DIR" ] && ! (cd "$CLAWHUB_DIR" && node -e "require('undici')" 2>/dev/null); then
        echo "  Installing undici dependency for clawdhub..."
        (cd "$CLAWHUB_DIR" && npm install undici --no-fund --no-audit) || true
    fi
else
    echo -e "  ${YELLOW}[WARN]${NC} clawdhub installation failed (non-critical)"
fi

command -v python &>/dev/null && { python -c "import yaml" 2>/dev/null || pip install pyyaml -q || true; }

echo "  Running: openclaw update (this may take 5-10 minutes)..."
openclaw update || true

openclaw config set discovery.mdns.mode off 2>/dev/null || true

# ─── [5/7] Patches ──────────────────────────
echo -e "▸ ${YELLOW}[5/7]${NC} Applying patches..."

COMPAT_SRC="$(dirname "$0")/glibc-compat.js"
if [ -f "$COMPAT_SRC" ]; then
    cp "$COMPAT_SRC" "$OCA_DIR/patches/glibc-compat.js"
else
    curl -fsSL "$REPO_BASE/patches/glibc-compat.js" \
        -o "$OCA_DIR/patches/glibc-compat.js" 2>/dev/null || true
fi

printf '#!%s/bin/bash\nexit 0\n' "$PREFIX" > "$PREFIX/bin/systemctl"
chmod +x "$PREFIX/bin/systemctl"

if [ -d "$OPENCLAW_DIR/node_modules/sharp" ]; then
    if ! node -e "require('$OPENCLAW_DIR/node_modules/sharp')" 2>/dev/null; then
        echo "  Installing sharp WebAssembly runtime..."
        (cd "$OPENCLAW_DIR" && npm install @img/sharp-wasm32 --force --no-audit --no-fund 2>&1 | tail -3) || true
    fi
fi

echo -e "  ${GREEN}✓${NC} Patches applied"

# ─── [6/7] Environment ──────────────────────
echo -e "▸ ${YELLOW}[6/7]${NC} Configuring environment..."

cat > "$HOME/.bashrc" << BASHRC
# OpenClaw on Android environment
export PREFIX="$PREFIX"
export HOME="$HOME"
export TMPDIR="$TMPDIR"
export PATH="$NODE_DIR/bin:\$PREFIX/bin:\$PATH"
export LD_LIBRARY_PATH="$PREFIX/lib"
export LD_PRELOAD="$PREFIX/lib/libtermux-exec.so"
export TERMUX__PREFIX="$PREFIX"
export TERMUX_PREFIX="$PREFIX"
export LANG=en_US.UTF-8
export TERM=xterm-256color
export OA_GLIBC=1
export CONTAINER=1
export SSL_CERT_FILE="$PREFIX/etc/tls/cert.pem"
export CURL_CA_BUNDLE="$PREFIX/etc/tls/cert.pem"
export GIT_SSL_CAINFO="$PREFIX/etc/tls/cert.pem"
export GIT_CONFIG_NOSYSTEM=1
export GIT_EXEC_PATH="$PREFIX/libexec/git-core"
export GIT_TEMPLATE_DIR="$PREFIX/share/git-core/templates"
export CLAWDHUB_WORKDIR="$HOME/.openclaw/workspace"
export CPATH="$PREFIX/include/glib-2.0:$PREFIX/lib/glib-2.0/include"
BASHRC

echo -e "  ${GREEN}✓${NC} ~/.bashrc configured"

# oca CLI
if curl -fsSL "$REPO_BASE/oca.sh" \
        -o "$PREFIX/bin/oca" 2>/dev/null; then
    chmod +x "$PREFIX/bin/oca"
    echo -e "  ${GREEN}✓${NC} oca CLI installed"
else
    echo -e "  ${YELLOW}[WARN]${NC} oca CLI installation failed (non-critical)"
fi

# ─── [7/7] Optional Tools ──────────────────
TOOL_CONF="$OCA_DIR/tool-selections.conf"
if [ -f "$TOOL_CONF" ]; then
    source "$TOOL_CONF"

    HAS_TOOLS=false
    for var in INSTALL_TMUX INSTALL_TTYD INSTALL_DUFS INSTALL_CODE_SERVER INSTALL_PLAYWRIGHT INSTALL_CLAUDE_CODE INSTALL_GEMINI_CLI INSTALL_CODEX_CLI; do
        eval "val=\${$var:-false}"
        [ "$val" = "true" ] && HAS_TOOLS=true && break
    done

    if $HAS_TOOLS; then
        echo -e "▸ ${YELLOW}[7/7]${NC} Installing optional tools..."

        install_with_deps() {
            local pkg="$1"
            local deps
            deps=$(awk -v pkg="$pkg" '
                /^Package: / { found = ($2 == pkg) }
                found && /^Depends:/ {
                    gsub(/^Depends: /, "")
                    gsub(/ *\([^)]*\)/, "")
                    gsub(/, /, "\n")
                    print; exit
                }
            ' "$PACKAGES_FILE")
            while IFS= read -r dep; do
                dep=$(echo "$dep" | tr -d ' ')
                [ -z "$dep" ] && continue
                local dep_file
                dep_file=$(get_deb_filename "$dep")
                if [ -n "$dep_file" ]; then install_deb "$dep_file" 2>/dev/null || true; fi
            done <<< "$deps"
            local filename
            filename=$(get_deb_filename "$pkg")
            [ -n "$filename" ] && install_deb "$filename"
        }

        [ "${INSTALL_TMUX:-false}" = "true" ] && { echo "  Installing tmux..."; install_with_deps tmux; echo -e "  ${GREEN}✓${NC} tmux"; }
        [ "${INSTALL_TTYD:-false}" = "true" ] && { echo "  Installing ttyd..."; install_with_deps ttyd; echo -e "  ${GREEN}✓${NC} ttyd"; }
        [ "${INSTALL_DUFS:-false}" = "true" ] && { echo "  Installing dufs..."; install_with_deps dufs; echo -e "  ${GREEN}✓${NC} dufs"; }

        [ "${INSTALL_CODE_SERVER:-false}" = "true" ] && {
            echo "  Installing code-server (this may take a while)..."
            npm install -g code-server 2>&1 || true
            echo -e "  ${GREEN}✓${NC} code-server"
        }
        [ "${INSTALL_PLAYWRIGHT:-false}" = "true" ] && {
            echo "  Installing Playwright (playwright-core)..."
            npm install -g playwright-core 2>&1 || true
            CHROMIUM_BIN=""
            for bin in "$PREFIX/bin/chromium-browser" "$PREFIX/bin/chromium"; do
                [ -x "$bin" ] && CHROMIUM_BIN="$bin" && break
            done
            if [ -n "$CHROMIUM_BIN" ]; then
                PW_MARKER_START="# >>> Playwright >>>"
                PW_MARKER_END="# <<< Playwright <<<"
                if ! grep -qF "$PW_MARKER_START" "$HOME/.bashrc"; then
                    cat >> "$HOME/.bashrc" << PWENV

${PW_MARKER_START}
export PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH="$CHROMIUM_BIN"
export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
${PW_MARKER_END}
PWENV
                fi
                echo -e "  ${GREEN}✓${NC} Playwright (env: PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=$CHROMIUM_BIN)"
            else
                echo -e "  ${GREEN}✓${NC} Playwright (install Chromium later via 'oca --install' for full setup)"
            fi
        }
        [ "${INSTALL_CLAUDE_CODE:-false}" = "true" ] && { echo "  Installing Claude Code..."; npm install -g @anthropic-ai/claude-code 2>&1 || true; echo -e "  ${GREEN}✓${NC} Claude Code"; }
        [ "${INSTALL_GEMINI_CLI:-false}" = "true" ] && { echo "  Installing Gemini CLI..."; npm install -g @google/gemini-cli 2>&1 || true; echo -e "  ${GREEN}✓${NC} Gemini CLI"; }
        [ "${INSTALL_CODEX_CLI:-false}" = "true" ] && { echo "  Installing Codex CLI..."; npm install -g @openai/codex 2>&1 || true; echo -e "  ${GREEN}✓${NC} Codex CLI"; }
    else
        echo -e "▸ ${YELLOW}[7/7]${NC} No optional tools selected"
    fi
else
    echo -e "▸ ${YELLOW}[7/7]${NC} No optional tools selected"
fi

# ─── Cleanup ────────────────────────────────
rm -rf "$DEB_DIR" "$PKG_DIR" "$PACKAGES_FILE" "$TMPDIR/gpkg.db" 2>/dev/null || true

# ─── Done ────────────────────────────────────
touch "$MARKER"

echo ""
echo "══════════════════════════════════════════════"
echo -e "  ${GREEN}✓ Installation complete!${NC}"
echo "══════════════════════════════════════════════"
echo ""
echo "  Loading environment..."
source "$HOME/.bashrc"
echo ""
echo "  Starting OpenClaw onboard..."
echo ""
openclaw onboard
