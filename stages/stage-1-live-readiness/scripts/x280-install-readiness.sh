#!/usr/bin/env bash
# Backward-compatible entry point; implementation lives in k41-live-validation.sh.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
exec bash "$ROOT/stages/stage-1-live-readiness/scripts/k41-live-validation.sh" --readiness "$@"
