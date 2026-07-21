#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Pir0c0pter0
# SPDX-License-Identifier: GPL-2.0-or-later

# Rebuild the installed, locally vetted snapshot after the host Dolphin RPM changes.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dolphin-quicklook"
STATE_FILE="$STATE_DIR/dolphin-package-version"
LOCK_FILE="$STATE_DIR/build.lock"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
UNIT_NAME="dolphin-quicklook-update.service"
INSTALLED_HOOK="$HOME/.local/bin/dolphin-quicklook-update"
SNAPSHOT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/dolphin-quicklook"

dolphin_version() {
    rpm -q --qf '%{EPOCHNUM}:%{VERSION}-%{RELEASE}.%{ARCH}\n' dolphin
}

install_hook() {
    [[ -f /run/ostree-booted ]] || { echo "This hook is only for atomic Fedora." >&2; exit 1; }
    [[ "$HOME" != *[[:space:]]* ]] || { echo "Home paths with whitespace are unsupported." >&2; exit 1; }
    [[ -x "$HOME/.local/bin/dolphin" ]] || { echo "Install Dolphin Quick Look before enabling the hook." >&2; exit 1; }
    [[ -f "$REPO_DIR/install.sh" && -f "$REPO_DIR/patches/dolphin-quicklook.patch" \
       && -f "$REPO_DIR/scripts/install-bazzite.sh" ]] \
        || { echo "Run --install from a complete local Dolphin Quick Look checkout." >&2; exit 1; }

    mkdir -p "$STATE_DIR" "$UNIT_DIR" "$(dirname "$INSTALLED_HOOK")" "$(dirname "$SNAPSHOT_DIR")"
    local staged
    staged="$(mktemp -d "$(dirname "$SNAPSHOT_DIR")/.dolphin-quicklook.XXXXXX")"
    trap 'rm -rf -- "$staged"' EXIT
    mkdir -p "$staged/patches" "$staged/scripts"
    install -m 755 "$REPO_DIR/install.sh" "$staged/install.sh"
    install -m 644 "$REPO_DIR/patches/dolphin-quicklook.patch" "$staged/patches/dolphin-quicklook.patch"
    install -m 755 "$REPO_DIR/scripts/install-bazzite.sh" "$staged/scripts/install-bazzite.sh"
    install -m 755 "$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")" "$staged/scripts/update-bazzite-hook.sh"
    rm -rf -- "$SNAPSHOT_DIR"
    mv "$staged" "$SNAPSHOT_DIR"
    trap - EXIT

    install -m 755 "$SNAPSHOT_DIR/scripts/update-bazzite-hook.sh" "$INSTALLED_HOOK"
    local tmp
    tmp="$(mktemp "$UNIT_DIR/${UNIT_NAME}.XXXXXX")"
    trap 'rm -f -- "$tmp"' EXIT
    cat > "$tmp" <<UNIT
[Unit]
Description=Update Dolphin Quick Look after a Dolphin package update

[Service]
Type=oneshot
ExecStart=%h/.local/bin/dolphin-quicklook-update
Nice=10
CPUWeight=20
IOWeight=20

[Install]
WantedBy=default.target
UNIT
    chmod 644 "$tmp"
    mv "$tmp" "$UNIT_DIR/$UNIT_NAME"
    trap - EXIT

    dolphin_version > "$STATE_FILE"
    systemctl --user daemon-reload
    systemctl --user enable --now "$UNIT_NAME"
    echo "Installed $UNIT_NAME with local snapshot $SNAPSHOT_DIR"
}

check_update() {
    local current previous=''
    current="$(dolphin_version)"
    [[ -f "$STATE_FILE" ]] && previous="$(<"$STATE_FILE")"
    if [[ "$current" == "$previous" ]]; then
        echo "Dolphin $current already processed."
        return
    fi

    [[ -x "$SNAPSHOT_DIR/scripts/install-bazzite.sh" ]] \
        || { echo "Local snapshot missing; rerun update-bazzite-hook.sh --install from the checkout." >&2; exit 1; }
    echo "Dolphin changed: ${previous:-not recorded} -> $current"
    DQL_LOCK_HELD=1 "$SNAPSHOT_DIR/scripts/install-bazzite.sh"

    local tmp
    tmp="$(mktemp "$STATE_DIR/dolphin-package-version.XXXXXX")"
    printf '%s\n' "$current" > "$tmp"
    mv "$tmp" "$STATE_FILE"
    echo "Dolphin Quick Look rebuilt from the installed local snapshot for $current"
}

mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"
command -v flock >/dev/null 2>&1 || { echo "flock is required." >&2; exit 1; }
exec 9>"$LOCK_FILE"
flock 9

case "${1:-}" in
    "") check_update ;;
    --install) install_hook ;;
    *) echo "Usage: $(basename "$0") [--install]" >&2; exit 2 ;;
esac
