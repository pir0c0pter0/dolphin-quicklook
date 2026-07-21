#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Pir0c0pter0
# SPDX-License-Identifier: GPL-2.0-or-later
#
# install-bazzite.sh
#
# Dolphin Quick Look -- installer / updater for atomic Fedora desktops
# (Bazzite, Silverblue, Kinoite -- any rpm-ostree / ostree-booted host).
#
# The repo-root install.sh assumes a mutable system: it builds against
# host-installed -devel packages and `sudo cmake --install`s into /usr.
# On an atomic host /usr is read-only and the build toolchain is not in
# the base image, so that approach cannot work. This script does the
# atomic-native workflow instead:
#
#   1. builds inside a Toolbx container, where dnf works normally;
#   2. installs into ~/.local -- no sudo, no system modification;
#   3. repoints the .desktop launcher and the systemd user unit at the
#      ~/.local build, so the dock and D-Bus/systemd activation use the
#      patched Dolphin instead of the system one.
#
# Idempotent: re-run it after editing the patch to rebuild and update.
# For a normal (mutable) distribution, use ../install.sh instead.
#
set -euo pipefail

# ── Paths & constants ───────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
PATCH_FILE="$REPO_DIR/patches/dolphin-quicklook.patch"
GENERIC_INSTALLER="$REPO_DIR/install.sh"
BUILD_DIR="$REPO_DIR/build"
DOLPHIN_SRC="$BUILD_DIR/dolphin"

PREFIX="$HOME/.local"
TOOLBOX="dolphin-quicklook"   # dedicated Toolbx build container
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dolphin-quicklook"
MANIFEST="$STATE_DIR/install-manifest.txt"
LOCK_FILE="$STATE_DIR/build.lock"

# ── Logging ─────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
    CYAN=$'\033[0;36m'; NC=$'\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; NC=''
fi
info()  { printf '%s[INFO]%s %s\n'  "$CYAN"   "$NC" "$1"; }
ok()    { printf '%s[OK]%s %s\n'    "$GREEN"  "$NC" "$1"; }
warn()  { printf '%s[WARN]%s %s\n'  "$YELLOW" "$NC" "$1"; }
error() { printf '%s[ERROR]%s %s\n' "$RED"    "$NC" "$1" >&2; exit 1; }

usage() {
    cat <<USAGE
Usage: $(basename "$0") [--uninstall]

Build the Dolphin Quick Look patch in a Toolbx container and install it
into ~/.local on an atomic Fedora desktop. Re-run to update.

Use --uninstall to remove only files installed by this build and its user units.
For a normal (mutable) distribution use ../install.sh.
USAGE
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { usage; exit 0; }
[[ $# -le 1 ]] || { usage >&2; exit 2; }

# ── Preflight ───────────────────────────────────────────────────────
preflight() {
    [[ -f "$PATCH_FILE" ]] || error "patch not found: $PATCH_FILE"

    # Whitespace in $HOME would need Desktop Entry / systemd / Toolbx
    # quoting throughout; reject it rather than half-support it.
    case "$HOME" in
        *[[:space:]]*) error "\$HOME contains whitespace ($HOME) -- unsupported." ;;
    esac
    [[ ! -L "$PREFIX" ]] || error "$PREFIX must not be a symbolic link."

    # The Toolbx container shares the host home; the repo must live under
    # $HOME so the same absolute paths resolve inside the container.
    # Canonicalise first so the /home -> /var/home symlink (standard on
    # atomic Fedora) does not produce a false mismatch.
    local canon_home canon_repo
    canon_home="$(realpath "$HOME")"
    canon_repo="$(realpath "$REPO_DIR")"
    case "$canon_repo/" in
        "$canon_home"/*) : ;;
        *) error "repo must live under \$HOME ($canon_home) for the Toolbx build" ;;
    esac

    if [[ ! -f /run/ostree-booted ]]; then
        warn "This host is not ostree/atomic."
        warn "On a normal distribution use the standard installer:"
        warn "    $GENERIC_INSTALLER"
        error "Aborting -- install-bazzite.sh is for atomic Fedora only."
    fi

    command -v toolbox >/dev/null 2>&1 \
        || error "'toolbox' not found (it ships with atomic Fedora)."
    command -v git >/dev/null 2>&1 \
        || error "'git' not found on the host."
    command -v realpath >/dev/null 2>&1 \
        || error "'realpath' not found on the host."
    command -v flock >/dev/null 2>&1 \
        || error "'flock' not found on the host."

    JOBS="${JOBS:-$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"
    [[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || error "JOBS must be a positive integer."

    # Read the pinned Dolphin commit/repo from install.sh so the two
    # installers share a single source of truth and never drift apart.
    DOLPHIN_REPO="$(sed -n 's/^DOLPHIN_REPO="\(.*\)"$/\1/p'    "$GENERIC_INSTALLER" 2>/dev/null || true)"
    DOLPHIN_COMMIT="$(sed -n 's/^DOLPHIN_COMMIT="\(.*\)"$/\1/p' "$GENERIC_INSTALLER" 2>/dev/null || true)"
    [[ -n "$DOLPHIN_REPO" && -n "$DOLPHIN_COMMIT" ]] \
        || error "could not read DOLPHIN_REPO/DOLPHIN_COMMIT from $GENERIC_INSTALLER"

    ok "Atomic host detected -- build in Toolbx '$TOOLBOX', install to $PREFIX"
}

# ── Toolbx build container ──────────────────────────────────────────
ensure_toolbox() {
    # Match the container by name in `toolbox list` so a plain (non-Toolbx)
    # podman container of the same name is not mistaken for ours.
    # A named Toolbx survives host upgrades. Recreate this dedicated build
    # container when its Fedora release no longer matches the host.
    local host_release container_release=''
    # shellcheck disable=SC1091
    . /etc/os-release
    host_release="${VERSION_ID:-}"
    [[ -n "$host_release" ]] || error "Host VERSION_ID is missing from /etc/os-release."
    if toolbox list --containers 2>/dev/null | grep -qw "$TOOLBOX"; then
        # VERSION_ID must expand inside Toolbx.
        # shellcheck disable=SC2016
        container_release="$(toolbox run -c "$TOOLBOX" sh -c '. /etc/os-release; printf %s "${VERSION_ID:-}"' 2>/dev/null || true)"
        if [[ "$container_release" != "$host_release" ]]; then
            warn "Recreating Toolbx '$TOOLBOX' ($container_release -> $host_release)."
            toolbox rm -f "$TOOLBOX" || error "could not remove stale Toolbx"
        else
            info "Toolbx container '$TOOLBOX' matches Fedora $host_release"
        fi
    fi
    if [[ "$container_release" != "$host_release" ]]; then
        info "Creating Fedora $host_release Toolbx '$TOOLBOX'..."
        toolbox create -y --distro fedora --release "$host_release" "$TOOLBOX" || error "toolbox create failed"
    fi

    # Always (re)provision deps: dnf is idempotent, so this completes a
    # partially provisioned container instead of trusting a single probe.
    info "Ensuring build dependencies in '$TOOLBOX' (one-time download, idempotent)..."
    toolbox run -c "$TOOLBOX" bash -s <<'DEPS' || error "dependency installation failed"
set -euo pipefail
sudo dnf -y install 'dnf-command(builddep)' git cmake gcc-c++ extra-cmake-modules
sudo dnf -y builddep dolphin
sudo dnf -y install qt6-qtpdf-devel qt6-qtmultimedia-devel
DEPS
    ok "Build dependencies ready"
}

# ── Build & install (inside the container) ──────────────────────────
build_and_install() {
    info "Preparing a clean Dolphin checkout under $BUILD_DIR ..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$DOLPHIN_SRC"

    info "Building Dolphin + Quick Look inside '$TOOLBOX' -- this takes a while..."
    if ! toolbox run -c "$TOOLBOX" \
            env DOLPHIN_SRC="$DOLPHIN_SRC" \
                DOLPHIN_REPO="$DOLPHIN_REPO" \
                DOLPHIN_COMMIT="$DOLPHIN_COMMIT" \
                PATCH_FILE="$PATCH_FILE" \
                PREFIX="$PREFIX" \
                JOBS="$JOBS" \
            bash -s <<'BUILD'
set -euo pipefail

cd "$DOLPHIN_SRC"
git init -q
git remote add origin "$DOLPHIN_REPO"
echo "[INFO] fetching Dolphin @ $DOLPHIN_COMMIT (shallow)..."
git fetch --depth 1 origin "$DOLPHIN_COMMIT"
git checkout -q --detach FETCH_HEAD

echo "[INFO] applying Quick Look patch..."
git apply --check "$PATCH_FILE"
git apply "$PATCH_FILE"

mkdir -p "$DOLPHIN_SRC/build"
cd "$DOLPHIN_SRC/build"
echo "[INFO] configuring (cmake)..."
cmake .. -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF

echo "[INFO] compiling with JOBS=$JOBS..."
cmake --build . -j"$JOBS"

echo "[INFO] installing to $PREFIX ..."
cmake --install .
BUILD
    then
        error "build/install failed inside the container"
    fi
    mkdir -p "$STATE_DIR"
    install -m 600 "$DOLPHIN_SRC/build/install_manifest.txt" "$MANIFEST"
    ok "Dolphin Quick Look built and installed to $PREFIX"
}

uninstall_atomic() {
    [[ -r "$MANIFEST" ]] || error "Install manifest not found: $MANIFEST"
    local prefix_real dir_real path
    local -a files=()
    prefix_real="$(realpath -m "$PREFIX")"
    while IFS= read -r path || [[ -n "$path" ]]; do
        [[ -n "$path" && "$path" == /* ]] || error "Unsafe path in install manifest: '$path'"
        dir_real="$(realpath -m "$(dirname "$path")")"
        case "$dir_real/" in
            "$prefix_real"/*) files+=("$path") ;;
            *) error "Manifest path escapes $PREFIX: $path" ;;
        esac
    done < "$MANIFEST"
    ((${#files[@]})) || error "Install manifest is empty: $MANIFEST"
    rm -vf -- "${files[@]}"

    local daemon_unit="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/plasma-dolphin.service"
    if [[ -f "$daemon_unit" ]] && grep -Fqx 'ExecStart=%h/.local/bin/dolphin --daemon' "$daemon_unit"; then
        rm -v -- "$daemon_unit"
    fi
    local update_unit="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/dolphin-quicklook-update.service"
    systemctl --user disable --now dolphin-quicklook-update.service 2>/dev/null || true
    rm -f -- "$update_unit" "$HOME/.local/bin/dolphin-quicklook-update"
    rm -rf -- "${XDG_DATA_HOME:-$HOME/.local/share}/dolphin-quicklook"
    systemctl --user daemon-reload 2>/dev/null || true
    ok "Removed the manifest-tracked user install and Quick Look user units."
}

# ── Repoint launchers at the ~/.local build ─────────────────────────
#
# `cmake --install` to a ~/.local prefix leaves two things pointing at
# the system Dolphin (which has no Quick Look):
#   * org.kde.dolphin.desktop gets a relative `Exec=dolphin`;
#   * the systemd user unit lands under ~/.local/lib/systemd/user/,
#     a directory systemd does not search, so plasma-dolphin.service
#     keeps activating /usr/bin/dolphin --daemon.
# This repoints both at the patched binary.
fix_launchers() {
    local bin="$PREFIX/bin/dolphin"
    [[ -x "$bin" ]] || error "expected binary missing after install: $bin"

    local tmp='' tmpu=''
    trap '[[ -n "$tmp" ]] && rm -f "$tmp"; [[ -n "$tmpu" ]] && rm -f "$tmpu"' RETURN

    # 1. Desktop launcher. Rewrite every Exec= whose command basename is
    #    `dolphin` to the absolute patched path, and pin one TryExec=
    #    right after the [Desktop Entry] header.
    local desktop="$PREFIX/share/applications/org.kde.dolphin.desktop"
    [[ -f "$desktop" ]] || error "launcher missing after install: $desktop"

    tmp="$(mktemp "${desktop}.XXXXXX")"
    local line rest cmd args saw_dolphin_exec=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        case "$line" in
            "[Desktop Entry]")
                printf '%s\n' "$line"
                printf 'TryExec=%s\n' "$bin"
                continue ;;
            TryExec=*)
                continue ;;            # drop stray TryExec; ours is canonical
            Exec=*)
                rest="${line#Exec=}"
                cmd="${rest%% *}"
                args="${rest#"$cmd"}"
                if [[ "${cmd##*/}" == "dolphin" ]]; then
                    line="Exec=${bin}${args}"
                    saw_dolphin_exec=1
                fi ;;
        esac
        printf '%s\n' "$line"
    done < "$desktop" > "$tmp"

    [[ "$saw_dolphin_exec" == 1 ]] \
        || error "no 'Exec=...dolphin' line in $desktop -- unexpected format"

    if cmp -s "$tmp" "$desktop"; then
        rm -f "$tmp"; tmp=''
        ok "Desktop launcher already points at $bin"
    else
        chmod --reference="$desktop" "$tmp" 2>/dev/null || chmod 644 "$tmp"
        mv "$tmp" "$desktop"; tmp=''
        command -v update-desktop-database >/dev/null 2>&1 \
            && update-desktop-database "$PREFIX/share/applications" 2>/dev/null || true
        ok "Desktop launcher repointed at $bin"
    fi

    # 2. systemd user unit -- install where systemd actually looks.
    local unit_dir="$HOME/.config/systemd/user"
    local unit="$unit_dir/plasma-dolphin.service"
    mkdir -p "$unit_dir"
    tmpu="$(mktemp "${unit}.XXXXXX")"
    cat > "$tmpu" <<'UNIT'
[Unit]
Description=Dolphin file manager
PartOf=graphical-session.target

[Service]
ExecStart=%h/.local/bin/dolphin --daemon
BusName=org.freedesktop.FileManager1
Slice=background.slice
UNIT
    chmod 644 "$tmpu"
    if [[ -f "$unit" ]] && cmp -s "$tmpu" "$unit"; then
        rm -f "$tmpu"; tmpu=''
        ok "systemd user unit already points at $bin"
    else
        mv "$tmpu" "$unit"; tmpu=''
        ok "systemd user unit repointed at $bin"
    fi

    # 3. Reload + restart the headless daemon so it runs the new build.
    #    User-opened Dolphin windows are separate processes, untouched.
    if command -v systemctl >/dev/null 2>&1 && [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
        if systemctl --user daemon-reload \
           && systemctl --user restart plasma-dolphin.service; then
            ok "systemd reloaded, plasma-dolphin daemon restarted"
        else
            warn "could not restart plasma-dolphin.service -- reopen Dolphin manually"
        fi
    else
        warn "systemctl --user unavailable -- reopen Dolphin to pick up the update"
    fi

    trap - RETURN
}

# ── Main ────────────────────────────────────────────────────────────
main() {
    mkdir -p "$STATE_DIR"
    chmod 700 "$STATE_DIR"
    if [[ "${DQL_LOCK_HELD:-0}" != 1 ]]; then
        exec 9>"$LOCK_FILE"
        flock 9
    fi
    preflight
    if [[ "${1:-}" == --uninstall ]]; then
        uninstall_atomic
        return
    elif [[ -n "${1:-}" ]]; then
        usage >&2
        exit 2
    fi
    ensure_toolbox
    build_and_install
    fix_launchers

    echo
    ok "Done. Dolphin Quick Look is installed at $PREFIX/bin/dolphin"
    info "Close every open Dolphin window and reopen it to pick up the update."
    info "Select a supported local file and press Space to open Quick Look."
    info "Uninstall with: $SCRIPT_DIR/install-bazzite.sh --uninstall"
}

main "$@"
