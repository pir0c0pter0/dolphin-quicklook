#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Pir0c0pter0
# SPDX-License-Identifier: GPL-2.0-or-later

# Build the vetted Quick Look patch against its pinned Dolphin revision.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="$SCRIPT_DIR/patches/dolphin-quicklook.patch"
BUILD_DIR="$SCRIPT_DIR/build"
DOLPHIN_DIR="$BUILD_DIR/dolphin"
DOLPHIN_REPO="https://invent.kde.org/system/dolphin.git"
DOLPHIN_COMMIT="b12eada7126627c43e463b1c1fff191233485d00"
ALLOWED_PREFIXES=("/usr" "/usr/local" "$HOME/.local")

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { printf '%b[INFO]%b %s\n' "$CYAN" "$NC" "$1"; }
ok()    { printf '%b[OK]%b %s\n' "$GREEN" "$NC" "$1"; }
warn()  { printf '%b[WARN]%b %s\n' "$YELLOW" "$NC" "$1"; }
error() { printf '%b[ERROR]%b %s\n' "$RED" "$NC" "$1" >&2; exit 1; }

DISTRO_ID=unknown
if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    DISTRO_ID="${ID:-unknown}"
fi

usage() {
    printf 'Usage: %s [--uninstall]\n' "$(basename "$0")"
}

install_hint() {
    warn "The pinned Dolphin checkout needs a C++ toolchain, ECM, Qt 6 and KDE Frameworks 6 development files."
    case "$DISTRO_ID" in
        arch|cachyos|endeavouros|manjaro|garuda)
            echo "  sudo pacman -S base-devel git cmake extra-cmake-modules qt6-base kio" ;;
        fedora|nobara)
            echo "  sudo dnf builddep dolphin" ;;
        ubuntu|debian|linuxmint|pop)
            echo "  sudo apt build-dep dolphin" ;;
        opensuse*|suse*)
            echo "  sudo zypper source-install -d dolphin" ;;
        *)
            echo "  Install the build dependencies for your distribution's Dolphin package." ;;
    esac
    warn "Qt PDF and Qt Multimedia development packages enable the optional PDF and media backends."
}

resolve_prefix() {
    if [[ -n "${CMAKE_INSTALL_PREFIX:-}" ]]; then
        INSTALL_PREFIX="$CMAKE_INSTALL_PREFIX"
    else
        local dolphin_bin
        dolphin_bin="$(command -v dolphin 2>/dev/null || true)"
        if [[ -n "$dolphin_bin" ]]; then
            dolphin_bin="$(readlink -f "$dolphin_bin" 2>/dev/null || printf '%s' "$dolphin_bin")"
            INSTALL_PREFIX="$(dirname "$(dirname "$dolphin_bin")")"
        else
            INSTALL_PREFIX=/usr
        fi
    fi

    local allowed found=0
    for allowed in "${ALLOWED_PREFIXES[@]}"; do
        [[ "$INSTALL_PREFIX" == "$allowed" ]] && found=1
    done
    (( found )) || error "Refusing install prefix '$INSTALL_PREFIX'; allowed: ${ALLOWED_PREFIXES[*]}"

    if [[ "$INSTALL_PREFIX" == "$HOME/.local" ]]; then
        [[ ! -L "$INSTALL_PREFIX" ]] || error "$INSTALL_PREFIX must not be a symbolic link."
        local real_home real_prefix
        real_home="$(realpath "$HOME")"
        real_prefix="$(realpath -m "$INSTALL_PREFIX")"
        [[ "$real_prefix" == "$real_home/.local" ]] || error "$INSTALL_PREFIX resolves outside your home directory."
    fi
}

validate_jobs() {
    JOBS="${JOBS:-$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"
    [[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || error "JOBS must be a positive integer."
}

remove_manifest() {
    local manifest="$1" prefix_real dir_real path
    [[ -r "$manifest" ]] || error "Install manifest not found: $manifest"
    prefix_real="$(realpath -m "$INSTALL_PREFIX")"
    local -a files=()
    while IFS= read -r path || [[ -n "$path" ]]; do
        [[ -n "$path" && "$path" == /* ]] || error "Unsafe path in install manifest: '$path'"
        dir_real="$(realpath -m "$(dirname "$path")")"
        case "$dir_real/" in
            "$prefix_real"/*) files+=("$path") ;;
            *) error "Manifest path escapes $INSTALL_PREFIX: $path" ;;
        esac
    done < "$manifest"
    ((${#files[@]})) || error "Install manifest is empty: $manifest"
    if [[ "$INSTALL_PREFIX" == "$HOME/.local" ]]; then
        rm -vf -- "${files[@]}"
    else
        sudo rm -vf -- "${files[@]}"
    fi
}

if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then usage; exit 0; fi
[[ $# -le 1 ]] || { usage >&2; exit 2; }
resolve_prefix

if [[ "${1:-}" == --uninstall ]]; then
    remove_manifest "$DOLPHIN_DIR/build/install_manifest.txt"
    if [[ "$INSTALL_PREFIX" != "$HOME/.local" ]]; then
        warn "Reinstall your distribution's Dolphin package to restore package-owned files."
    fi
    ok "Removed files recorded by the Quick Look build manifest."
    exit 0
elif [[ -n "${1:-}" ]]; then
    usage >&2
    exit 2
fi

[[ -f "$PATCH_FILE" ]] || error "Patch not found: $PATCH_FILE"
for cmd in git cmake realpath; do
    command -v "$cmd" >/dev/null 2>&1 || { install_hint; error "Required command not found: $cmd"; }
done
validate_jobs
info "Basic build tools found; CMake will verify the pinned source's exact library requirements."

mkdir -p "$BUILD_DIR"
if [[ -d "$DOLPHIN_DIR/.git" ]]; then
    cd "$DOLPHIN_DIR"
    if [[ "$(git rev-parse HEAD 2>/dev/null || true)" != "$DOLPHIN_COMMIT" ]]; then
        [[ -z "$(git status --porcelain)" ]] || error "Local changes in $DOLPHIN_DIR prevent switching revisions."
        git fetch --depth 1 origin "$DOLPHIN_COMMIT"
        git checkout -q --detach FETCH_HEAD
    fi
elif [[ -e "$DOLPHIN_DIR" ]]; then
    error "$DOLPHIN_DIR exists but is not a Git checkout."
else
    info "Fetching pinned Dolphin commit $DOLPHIN_COMMIT (shallow)..."
    mkdir -p "$DOLPHIN_DIR"
    cd "$DOLPHIN_DIR"
    git init -q
    git remote add origin "$DOLPHIN_REPO"
    git fetch --depth 1 origin "$DOLPHIN_COMMIT"
    git checkout -q --detach FETCH_HEAD
fi

cd "$DOLPHIN_DIR"
if git apply --check "$PATCH_FILE"; then
    git apply "$PATCH_FILE"
    ok "Patch applied."
elif git apply --reverse --check "$PATCH_FILE"; then
    ok "Patch was already applied; continuing the previous build."
else
    error "Patch is neither cleanly applicable nor already applied at the pinned commit."
fi

mkdir -p build
cd build
info "Configuring Release build for $INSTALL_PREFIX..."
if ! cmake .. -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" -DCMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}" -DBUILD_TESTING=OFF; then
    install_hint
    error "CMake configuration failed."
fi
info "Building with JOBS=$JOBS..."
cmake --build . -j"$JOBS"

printf '\nInstall the patched Dolphin to %s? [y/N] ' "$INSTALL_PREFIX"
read -r reply
if [[ "$reply" =~ ^[Yy]$ ]]; then
    if [[ "$INSTALL_PREFIX" == "$HOME/.local" ]]; then
        cmake --install .
    else
        sudo cmake --install .
    fi
    ok "Installed. Close all Dolphin processes, reopen Dolphin, select a supported local file and press Space."
    info "Uninstall with: $SCRIPT_DIR/install.sh --uninstall"
else
    info "Installation skipped. Test with: $DOLPHIN_DIR/build/bin/dolphin"
fi
