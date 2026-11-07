#!/usr/bin/env bash
# Shared, deterministic storage target fixture builders.
# Source from test scripts only; no production code should depend on this file.

storage_test::make_x280_target() {
  [[ $# -ge 1 && $# -le 3 && $1 =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || return 2
  local declaration
  declaration=$(declare -p "$1" 2>/dev/null) || return 2
  [[ $declaration == 'declare -A '* ]] || return 2
  local -n target_ref="$1"
  local stable_id=${2:-eui.0011223344556677}
  local serial=${3:-SN-X280}
  [[ -n $stable_id && -n $serial ]] || return 2
  target_ref=(
    [device_path]=/dev/nvme0n1
    [major_minor]=259:0
    [size_bytes]=274877906944
    [transport]=nvme
    [removable]=false
    [read_only]=false
    [stable_id_kind]=wwn
    [stable_id]="$stable_id"
    [wwn]="$stable_id"
    [serial]="$serial"
    [model]="WDC PC SN730"
  )
}
