#!/usr/bin/env bash
# Update Dolphin Quick Look once after the host Dolphin package changes.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dolphin-quicklook"
STATE_FILE="$STATE_DIR/dolphin-package-version"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
UNIT_NAME="dolphin-quicklook-update.service"
INSTALLED_HOOK="$HOME/.local/bin/dolphin-quicklook-update"
SOURCE_REPO="https://github.com/pir0c0pter0/dolphin-quicklook.git"

dolphin_version() {
    rpm -q --qf '%{EPOCHNUM}:%{VERSION}-%{RELEASE}.%{ARCH}\n' dolphin
}

install_hook() {
    [[ -f /run/ostree-booted ]] || { echo "This hook is only for atomic Fedora." >&2; exit 1; }
    [[ "$HOME" != *[[:space:]]* ]] || { echo "Home paths with whitespace are unsupported." >&2; exit 1; }
    [[ -x "$HOME/.local/bin/dolphin" ]] || { echo "Install Dolphin Quick Look before enabling the hook." >&2; exit 1; }

    mkdir -p "$STATE_DIR" "$UNIT_DIR" "$(dirname "$INSTALLED_HOOK")"
    install -m 755 "$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")" "$INSTALLED_HOOK"
    local tmp
    tmp="$(mktemp "$UNIT_DIR/${UNIT_NAME}.XXXXXX")"
    trap 'rm -f "$tmp"' EXIT
    cat > "$tmp" <<UNIT
[Unit]
Description=Update Dolphin Quick Look after a Dolphin package update

[Service]
Type=oneshot
ExecStart=$INSTALLED_HOOK

[Install]
WantedBy=default.target
UNIT
    chmod 644 "$tmp"
    mv "$tmp" "$UNIT_DIR/$UNIT_NAME"
    trap - EXIT

    # Quick Look is already current when this hook is installed.
    dolphin_version > "$STATE_FILE"
    systemctl --user daemon-reload
    systemctl --user enable --now "$UNIT_NAME"
    echo "Installed $UNIT_NAME"
}

check_update() {
    mkdir -p "$STATE_DIR"
    local current previous=''
    current="$(dolphin_version)"
    [[ -f "$STATE_FILE" ]] && previous="$(<"$STATE_FILE")"

    if [[ "$current" == "$previous" ]]; then
        echo "Dolphin $current already processed."
        return
    fi

    echo "Dolphin changed: ${previous:-not recorded} -> $current"
    local cache_dir checkout
    cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}"
    mkdir -p "$cache_dir"
    checkout="$(mktemp -d "$cache_dir/dolphin-quicklook-update.XXXXXX")"
    trap 'rm -rf -- "$checkout"' EXIT

    git clone --depth 1 "$SOURCE_REPO" "$checkout"
    # The environment assignments also avoid a RETURN-trap bug in older
    # installer revisions after an otherwise successful installation.
    tmp='' tmpu='' "$checkout/scripts/install-bazzite.sh"
    rm -rf -- "$checkout"
    trap - EXIT

    local tmp
    tmp="$(mktemp "$STATE_DIR/dolphin-package-version.XXXXXX")"
    printf '%s\n' "$current" > "$tmp"
    mv "$tmp" "$STATE_FILE"
    echo "Dolphin Quick Look updated for $current"
}

case "${1:-}" in
    "") check_update ;;
    --install) install_hook ;;
    *) echo "Usage: $(basename "$0") [--install]" >&2; exit 2 ;;
esac
