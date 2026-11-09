#!/usr/bin/env bash
# Canonical Stage 2 entry point. Delegates to the reviewed legacy implementation.
# DESTRUCTIVE: the underlying installer erases the selected internal SSD.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
exec bash "$ROOT/scripts/install-arch-x280.sh" "$@"
