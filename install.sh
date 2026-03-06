#!/bin/bash
#
# Dolphin Quick Look — Installation Script
#
# Clones KDE Dolphin, applies the Quick Look patch, builds, and installs.
#
# Requirements: git, cmake, make, Qt6, KDE Frameworks 6
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="$SCRIPT_DIR/patches/dolphin-quicklook.patch"
BUILD_DIR="$SCRIPT_DIR/build"
DOLPHIN_DIR="$BUILD_DIR/dolphin"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ── Check dependencies ──────────────────────────────────────────────
info "Checking dependencies..."

for cmd in git cmake make; do
    command -v "$cmd" &>/dev/null || error "'$cmd' not found. Please install it first."
done

pkg-config --exists Qt6Core 2>/dev/null || warn "Qt6 pkg-config not found (may still work)"

ok "Dependencies satisfied"

# ── Clone Dolphin ───────────────────────────────────────────────────
mkdir -p "$BUILD_DIR"

if [ -d "$DOLPHIN_DIR" ]; then
    info "Dolphin source already exists, pulling latest..."
    cd "$DOLPHIN_DIR" && git checkout -- . && git pull --rebase 2>/dev/null || true
else
    info "Cloning KDE Dolphin..."
    git clone --depth 1 https://invent.kde.org/system/dolphin.git "$DOLPHIN_DIR"
fi

ok "Dolphin source ready"

# ── Apply patch ─────────────────────────────────────────────────────
info "Applying Quick Look patch..."
cd "$DOLPHIN_DIR"

if git apply --check "$PATCH_FILE" 2>/dev/null; then
    git apply "$PATCH_FILE"
    ok "Patch applied successfully"
else
    warn "Patch may already be applied or needs manual resolution"
    git apply "$PATCH_FILE" --3way 2>/dev/null || error "Failed to apply patch. See above for details."
fi

# ── Build ───────────────────────────────────────────────────────────
info "Configuring build..."
mkdir -p "$DOLPHIN_DIR/build"
cd "$DOLPHIN_DIR/build"

cmake .. \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_BUILD_TYPE=Release \
    2>&1 | tail -5

NPROC=$(nproc 2>/dev/null || echo 4)
info "Building with $NPROC threads..."
make -j"$NPROC" 2>&1 | tail -5

ok "Build completed"

# ── Install ─────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}Ready to install. This will replace your system Dolphin.${NC}"
echo -e "${YELLOW}You can always reinstall the original with your package manager.${NC}"
echo ""
read -p "Install now? [y/N] " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    info "Installing (requires sudo)..."
    sudo make install
    ok "Dolphin Quick Look installed!"
    echo ""
    info "Restart Dolphin to use Quick Look:"
    echo "  1. Close all Dolphin windows"
    echo "  2. Open Dolphin"
    echo "  3. Double-click any image — enjoy the preview!"
else
    info "Skipped installation."
    echo ""
    echo "You can test without installing:"
    echo "  $DOLPHIN_DIR/build/bin/dolphin"
    echo ""
    echo "Or install later with:"
    echo "  cd $DOLPHIN_DIR/build && sudo make install"
fi
