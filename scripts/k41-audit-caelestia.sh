#!/usr/bin/env bash
# Compatibility entry point; canonical implementation lives in Stage 5.
set -Eeuo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel)"
exec bash "$repo_root/stages/stage-5-desktop-customization/scripts/k41-audit-caelestia.sh" "$@"
