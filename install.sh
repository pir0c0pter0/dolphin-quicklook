#!/bin/bash
#
# Dolphin Quick Look — Installation Script
#
# Clones KDE Dolphin, applies the Quick Look patch, builds, and installs.
#
# Requirements: git, cmake, Qt6, KDE Frameworks 6
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="$SCRIPT_DIR/patches/dolphin-quicklook.patch"
BUILD_DIR="$SCRIPT_DIR/build"
DOLPHIN_DIR="$BUILD_DIR/dolphin"

# Pin upstream Dolphin to a known-good commit. The patch targets Dolphin master;
# bump this when regenerating the patch for a newer upstream state.
DOLPHIN_REPO="https://invent.kde.org/system/dolphin.git"
DOLPHIN_COMMIT="b12eada7126627c43e463b1c1fff191233485d00"

# Prefixes we allow cmake --install to write into. Anything else would be
# refused so a tampered env cannot redirect a sudo install to arbitrary paths.
ALLOWED_PREFIXES=("/usr" "/usr/local" "${HOME}/.local")

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ── Detect distro ─────────────────────────────────────────────────
DISTRO_ID="unknown"
DISTRO_ID_LIKE=""
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_ID="${ID:-unknown}"
    DISTRO_ID_LIKE="${ID_LIKE:-}"
fi

print_install_hint() {
    local pkg_desc="$1"
    echo ""
    warn "Missing: $pkg_desc"
    case "$DISTRO_ID" in
        arch|cachyos|endeavouros|manjaro|garuda)
            echo "  sudo pacman -S base-devel git cmake extra-cmake-modules qt6-base qt6-multimedia qt6-pdf kio" ;;
        fedora|nobara)
            echo "  sudo dnf install git cmake extra-cmake-modules gcc-c++ qt6-qtbase-devel qt6-qtmultimedia-devel qt6-qtpdf-devel kf6-kio-devel" ;;
        ubuntu|debian|linuxmint|pop)
            echo "  sudo apt install git cmake build-essential extra-cmake-modules qt6-base-dev qt6-multimedia-dev libqt6pdf6-dev libkf6kio-dev" ;;
        opensuse*|suse*)
            echo "  sudo zypper install git cmake extra-cmake-modules qt6-base-devel qt6-multimedia-devel qt6-pdf-devel kf6-kio-devel" ;;
        void)
            echo "  sudo xbps-install git cmake extra-cmake-modules qt6-base-devel qt6-multimedia-devel qt6-pdf-devel kio-devel" ;;
        gentoo)
            echo "  sudo emerge dev-vcs/git dev-build/cmake kde-frameworks/extra-cmake-modules dev-qt/qtbase dev-qt/qtmultimedia dev-qt/qtpdf kde-frameworks/kio" ;;
        *)
            # Try ID_LIKE for derivatives
            if echo "$DISTRO_ID_LIKE" | grep -q "arch"; then
                echo "  sudo pacman -S base-devel git cmake extra-cmake-modules qt6-base qt6-multimedia qt6-pdf kio"
            elif echo "$DISTRO_ID_LIKE" | grep -q "debian\|ubuntu"; then
                echo "  sudo apt install git cmake build-essential extra-cmake-modules qt6-base-dev qt6-multimedia-dev libqt6pdf6-dev libkf6kio-dev"
            elif echo "$DISTRO_ID_LIKE" | grep -q "fedora\|rhel"; then
                echo "  sudo dnf install git cmake extra-cmake-modules gcc-c++ qt6-qtbase-devel qt6-qtmultimedia-devel qt6-qtpdf-devel kf6-kio-devel"
            else
                echo "  Please install: git, cmake, extra-cmake-modules, Qt6 (Base, Multimedia, Pdf), KDE Frameworks 6 (kio)"
            fi
            ;;
    esac
    echo ""
}

# ── Check dependencies ──────────────────────────────────────────────
info "Checking dependencies..."

MISSING_DEPS=0
for cmd in git cmake; do
    if ! command -v "$cmd" &>/dev/null; then
        warn "'$cmd' not found"
        MISSING_DEPS=1
    fi
done

# Check extra-cmake-modules (required by KDE)
if ! cmake --find-package -DNAME=ECM -DCOMPILER_ID=GNU -DLANGUAGE=CXX -DMODE=EXIST &>/dev/null; then
    if ! pkg-config --exists extra-cmake-modules 2>/dev/null; then
        warn "'extra-cmake-modules' not found (required by KDE)"
        MISSING_DEPS=1
    fi
fi

pkg-config --exists Qt6Core 2>/dev/null || warn "Qt6 pkg-config not found (may still work)"

if [ "$MISSING_DEPS" -eq 1 ]; then
    print_install_hint "build dependencies"
    error "Please install missing dependencies and try again."
fi

ok "Dependencies satisfied"

# ── Clone Dolphin ───────────────────────────────────────────────────
mkdir -p "$BUILD_DIR"

if [ -d "$DOLPHIN_DIR" ]; then
    info "Dolphin source already exists, checking pinned commit..."
    cd "$DOLPHIN_DIR"
    if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
        error "Local changes detected in $DOLPHIN_DIR. Commit, stash, or remove them before rerunning."
    fi
    if [ "$(git rev-parse HEAD 2>/dev/null)" != "$DOLPHIN_COMMIT" ]; then
        info "Fetching and checking out pinned commit $DOLPHIN_COMMIT..."
        git fetch --depth 1 origin "$DOLPHIN_COMMIT"
        git checkout --detach "$DOLPHIN_COMMIT"
    fi
else
    info "Cloning KDE Dolphin at pinned commit $DOLPHIN_COMMIT..."
    git clone "$DOLPHIN_REPO" "$DOLPHIN_DIR"
    cd "$DOLPHIN_DIR"
    git checkout --detach "$DOLPHIN_COMMIT"
fi

ok "Dolphin source ready ($(git rev-parse --short HEAD))"

# ── Apply patch ─────────────────────────────────────────────────────
info "Applying Quick Look patch..."
cd "$DOLPHIN_DIR"

if git apply --check "$PATCH_FILE"; then
    git apply "$PATCH_FILE"
    ok "Patch applied successfully"
else
    error "Patch does not apply cleanly. The Dolphin pin may be stale or the tree is dirty."
fi

# ── Detect install prefix ──────────────────────────────────────────
if [ -z "${CMAKE_INSTALL_PREFIX:-}" ]; then
    # Try to match the existing Dolphin installation prefix
    INSTALL_PREFIX="$(pkg-config --variable=prefix dolphin 2>/dev/null || true)"
    if [ -z "$INSTALL_PREFIX" ]; then
        DOLPHIN_BIN="$(command -v dolphin 2>/dev/null || true)"
        if [ -n "$DOLPHIN_BIN" ]; then
            # Resolve symlinks so flatpak/snap wrappers don't produce a bogus prefix.
            DOLPHIN_BIN_REAL="$(readlink -f "$DOLPHIN_BIN" 2>/dev/null || echo "$DOLPHIN_BIN")"
            INSTALL_PREFIX="$(dirname "$(dirname "$DOLPHIN_BIN_REAL")")"
        else
            INSTALL_PREFIX="/usr"
        fi
    fi
else
    INSTALL_PREFIX="$CMAKE_INSTALL_PREFIX"
fi

# Whitelist the resolved prefix: a tampered env or snap/flatpak symlink must not
# be able to redirect `sudo cmake --install` to an arbitrary path.
prefix_allowed=0
for allowed in "${ALLOWED_PREFIXES[@]}"; do
    if [ "$INSTALL_PREFIX" = "$allowed" ]; then
        prefix_allowed=1
        break
    fi
done
if [ "$prefix_allowed" -ne 1 ]; then
    warn "Resolved install prefix '$INSTALL_PREFIX' is not in the allowed list:"
    printf '  %s\n' "${ALLOWED_PREFIXES[@]}"
    error "Refusing to install. Re-run with CMAKE_INSTALL_PREFIX=/usr (or another allowed path)."
fi
info "Install prefix: $INSTALL_PREFIX"

# ── Build ───────────────────────────────────────────────────────────
BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}"
info "Configuring build (type: $BUILD_TYPE)..."
mkdir -p "$DOLPHIN_DIR/build"
cd "$DOLPHIN_DIR/build"

cmake .. \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE"

NPROC=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)
info "Building with $NPROC threads..."
cmake --build . -j"$NPROC"

ok "Build completed"

# ── Install ─────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}Ready to install. This will replace your system Dolphin.${NC}"
echo -e "${YELLOW}You can always reinstall the original with your package manager.${NC}"
echo ""
read -p "Install now? [y/N] " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    info "Installing to $INSTALL_PREFIX (requires sudo)..."
    sudo cmake --install .
    ok "Dolphin Quick Look installed!"
    echo ""
    info "Restart Dolphin to use Quick Look:"
    echo "  1. Close all Dolphin windows"
    echo "  2. Open Dolphin"
    echo "  3. Double-click any image — enjoy the preview!"
    echo ""
    info "To uninstall:"
    echo "  1. Remove files tracked by cmake:"
    echo "     sudo xargs rm -v < $DOLPHIN_DIR/build/install_manifest.txt"
    echo "  2. Reinstall the upstream Dolphin package from your package manager:"
    case "$DISTRO_ID" in
        arch|cachyos|endeavouros|manjaro|garuda)
            echo "     sudo pacman -S dolphin" ;;
        fedora|nobara)
            echo "     sudo dnf reinstall dolphin" ;;
        ubuntu|debian|linuxmint|pop)
            echo "     sudo apt install --reinstall dolphin" ;;
        opensuse*|suse*)
            echo "     sudo zypper install -f dolphin" ;;
        *)
            echo "     Use your package manager to reinstall 'dolphin'" ;;
    esac
else
    info "Skipped installation."
    echo ""
    echo "You can test without installing:"
    echo "  $DOLPHIN_DIR/build/bin/dolphin"
    echo ""
    echo "Or install later with:"
    echo "  cd $DOLPHIN_DIR/build && sudo cmake --install ."
fi
