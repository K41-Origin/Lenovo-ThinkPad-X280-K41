#!/usr/bin/env bash
# Canonical Stage 3 entry point. Run with sudo from an installed Arch TTY.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
exec bash "$ROOT/scripts/setup-desktop-x280.sh" "$@"
