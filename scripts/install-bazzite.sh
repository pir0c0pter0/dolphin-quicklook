#!/usr/bin/env bash
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
Usage: $(basename "$0")

Build the Dolphin Quick Look patch in a Toolbx container and install it
into ~/.local on an atomic Fedora desktop. Re-run to update.

No options. For a normal (mutable) distribution use ../install.sh.
USAGE
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { usage; exit 0; }

# ── Preflight ───────────────────────────────────────────────────────
preflight() {
    [[ -f "$PATCH_FILE" ]] || error "patch not found: $PATCH_FILE"

    # Whitespace in $HOME would need Desktop Entry / systemd / Toolbx
    # quoting throughout; reject it rather than half-support it.
    case "$HOME" in
        *[[:space:]]*) error "\$HOME contains whitespace ($HOME) -- unsupported." ;;
    esac

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
    if toolbox list --containers 2>/dev/null | grep -qw "$TOOLBOX"; then
        info "Toolbx container '$TOOLBOX' already exists"
    else
        info "Creating Toolbx container '$TOOLBOX'..."
        toolbox create -y "$TOOLBOX" || error "toolbox create failed"
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
cmake .. -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_BUILD_TYPE=Release

echo "[INFO] compiling with $(nproc) threads..."
cmake --build . -j"$(nproc)"

echo "[INFO] installing to $PREFIX ..."
cmake --install .
BUILD
    then
        error "build/install failed inside the container"
    fi
    ok "Dolphin Quick Look built and installed to $PREFIX"
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
    preflight
    ensure_toolbox
    build_and_install
    fix_launchers

    echo
    ok "Done. Dolphin Quick Look is installed at $PREFIX/bin/dolphin"
    info "Close every open Dolphin window and reopen it to pick up the update."
    info "Quick Look opens on double-click by default; change the mode with"
    info "  QuickLookActivation=PrimeThenDoubleClick   under [General] in ~/.config/dolphinrc"
}

main "$@"
