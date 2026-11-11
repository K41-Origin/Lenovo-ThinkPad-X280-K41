#!/usr/bin/env bash
# Canonical entry point for installing the K41 Plymouth-only boot screen.
# This script intentionally does not configure LUKS, TPM, bootloader, getty,
# autologin, desktop startup, or custom systemd lifecycle units.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
INSTALLER="$SCRIPT_DIR/k41-install-plymouth-theme.sh"

[[ -f $INSTALLER ]] || {
    printf 'ERROR: Plymouth theme installer is missing: %s\n' "$INSTALLER" >&2
    exit 1
}

exec bash "$INSTALLER" "$@"
