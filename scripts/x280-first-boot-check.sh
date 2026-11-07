#!/usr/bin/env bash
# Read-only first-boot evidence collector for the installed ThinkPad X280.
set -Eeuo pipefail
umask 077

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

sys_root="${K41_FIRST_BOOT_SYS_ROOT:-/sys}"
etc_root="${K41_FIRST_BOOT_ETC_ROOT:-/etc}"
proc_root="${K41_FIRST_BOOT_PROC_ROOT:-/proc}"
report_root="${K41_FIRST_BOOT_REPORT_ROOT:-$ROOT/reports/first-boot}"
timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
started="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
branch="$(git branch --show-current 2>/dev/null || printf unknown)"
commit="$(git rev-parse HEAD 2>/dev/null || printf unknown)"

mkdir -p -- "$report_root"
report_dir="$report_root/$timestamp"
suffix=0
while ! mkdir -- "$report_dir" 2>/dev/null; do
  suffix=$((suffix + 1))
  report_dir="$report_root/$timestamp-$suffix"
done
chmod 700 "$report_dir"

summary="$report_dir/summary.md"
diagnostics="$report_dir/diagnostics.log"
boot_status="$report_dir/boot-status.txt"
system_status="$report_dir/system-status.txt"
hardware="$report_dir/hardware.txt"
: >"$summary"
: >"$diagnostics"
: >"$boot_status"
: >"$system_status"
: >"$hardware"
chmod 600 "$summary" "$diagnostics" "$boot_status" "$system_status" "$hardware"

passed=0
failed=0
skipped=0
finalized=0
check_rows="$report_dir/.check-rows"
: >"$check_rows"

redact_stream() {
  sed -E \
    -e 's/(pass(word|phrase)?|token|secret|psk|private[_ -]?key)([=:][[:space:]]*|[[:space:]]+)[^[:space:]]+/\1\3[REDACTED]/Ig' \
    -e 's/(serial([[:space:]_-]*number)?[=:[:space:]]*)[^[:space:]]+/\1[REDACTED]/Ig' \
    -e 's/([[:space:]]|^)([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}([[:space:]]|$)/\1[MAC-REDACTED]\3/g' \
    -e 's#(/home/)[^/[:space:]]+#\1[REDACTED]#g'
}

record_check() {
  local name="$1" status="$2" rc="$3" detail="$4"
  printf '| %s | **%s** | %s | %s |\n' "$name" "$status" "$rc" "$detail" >>"$check_rows"
  case "$status" in
    PASS) passed=$((passed + 1)) ;;
    FAIL) failed=$((failed + 1)) ;;
    SKIP) skipped=$((skipped + 1)) ;;
  esac
}

run_check() {
  local name="$1" destination="$2"
  shift 2
  local raw="$report_dir/.check-output" rc status detail
  : >"$raw"
  if "$@" >"$raw" 2>&1; then
    rc=0; status=PASS; detail="Check completed."
  else
    rc=$?
    if (( rc == 2 )); then
      status=SKIP; detail="Required capability or evidence unavailable."
    else
      status=FAIL; detail="Check failed; inspect diagnostics.log."
    fi
  fi
  {
    printf '\n===== %s [%s, exit %s] =====\n' "$name" "$status" "$rc"
    redact_stream <"$raw"
  } >>"$destination"
  redact_stream <"$raw" >>"$diagnostics"
  rm -f -- "$raw"
  record_check "$name" "$status" "$rc" "$detail"
  printf '%s: %s\n' "$status" "$name"
}

check_arch() {
  [[ -f "$etc_root/arch-release" ]] || { printf 'Installed Arch release marker not found.\n'; return 1; }
  printf 'Arch release: '; head -n 1 "$etc_root/arch-release"
}
check_uefi() {
  [[ -d "$sys_root/firmware/efi" ]] || { printf 'System was not booted in UEFI mode.\n'; return 1; }
  printf 'UEFI sysfs interface is present.\n'
}
check_root_mount() {
  command -v findmnt >/dev/null 2>&1 || { printf 'findmnt is unavailable.\n'; return 2; }
  local info source fstype
  info="$(findmnt -nro SOURCE,FSTYPE /)" || { printf 'Cannot resolve root mount.\n'; return 1; }
  read -r source fstype <<<"$info"
  printf 'Root source: %s\nRoot filesystem: %s\n' "$source" "$fstype"
  [[ $fstype == ext4 && $source == /dev/mapper/cryptroot* ]] || {
    printf 'Expected ext4 root on /dev/mapper/cryptroot.\n'; return 1;
  }
}
check_luks() {
  command -v cryptsetup >/dev/null 2>&1 || { printf 'cryptsetup is unavailable.\n'; return 2; }
  cryptsetup status cryptroot || { printf 'Expected active mapper cryptroot was not found.\n'; return 1; }
  printf 'cryptroot mapping is active.\n'
}
check_efi_mount() {
  command -v findmnt >/dev/null 2>&1 || { printf 'findmnt is unavailable.\n'; return 2; }
  local info target fstype
  info="$(findmnt -nro TARGET,FSTYPE /efi)" || { printf '/efi is not mounted.\n'; return 1; }
  read -r target fstype <<<"$info"
  printf 'EFI mount: %s (%s)\n' "$target" "$fstype"
  [[ $target == /efi && $fstype == vfat ]] || return 1
}
check_systemd_boot() {
  command -v bootctl >/dev/null 2>&1 || { printf 'bootctl is unavailable.\n'; return 2; }
  bootctl status --no-pager || { printf 'systemd-boot status query failed.\n'; return 1; }
  printf 'systemd-boot status query succeeded.\n'
}
check_uki() {
  local dir file count=0
  for dir in /efi/EFI/Linux /boot/EFI/Linux; do
    [[ -d $dir ]] || continue
    for file in "$dir"/*.efi; do
      [[ -f $file ]] || continue
      printf 'UKI candidate: %s\n' "${file##*/}"
      count=$((count + 1))
    done
  done
  (( count > 0 )) || { printf 'No EFI Unified Kernel Image found in expected ESP paths.\n'; return 1; }
}
check_system_running() {
  command -v systemctl >/dev/null 2>&1 || { printf 'systemctl is unavailable.\n'; return 2; }
  local state
  state="$(systemctl is-system-running 2>&1)" || {
    printf 'systemd state: %s\n' "$state"
    return 1
  }
  printf 'systemd state: %s\n' "$state"
  [[ $state == running ]]
}
check_failed_units() {
  command -v systemctl >/dev/null 2>&1 || { printf 'systemctl is unavailable.\n'; return 2; }
  local units
  units="$(systemctl --failed --no-legend --plain)" || { printf 'Cannot query failed units.\n'; return 1; }
  if [[ -n $units ]]; then
    printf 'Failed units:\n%s\n' "$units"
    return 1
  fi
  printf 'No failed systemd units reported.\n'
}
check_default_target() {
  command -v systemctl >/dev/null 2>&1 || { printf 'systemctl is unavailable.\n'; return 2; }
  local target state
  target="$(systemctl get-default)" || { printf 'Cannot determine default target.\n'; return 1; }
  state="$(systemctl is-active "$target")" || { printf 'Default target %s is not active.\n' "$target"; return 1; }
  printf 'Default target: %s (%s)\n' "$target" "$state"
}
check_networkmanager() {
  command -v systemctl >/dev/null 2>&1 || { printf 'systemctl is unavailable.\n'; return 2; }
  systemctl is-active --quiet NetworkManager || { printf 'NetworkManager is not active.\n'; return 1; }
  printf 'NetworkManager is active.\n'
}
check_network_connection() {
  command -v nmcli >/dev/null 2>&1 || { printf 'nmcli is unavailable.\n'; return 2; }
  local state
  state="$(nmcli -t -f STATE general)" || { printf 'Cannot query NetworkManager connectivity.\n'; return 1; }
  printf 'NetworkManager state: %s\n' "$state"
  [[ $state == connected* ]]
}
check_login_context() {
  if [[ ${SUDO_UID:-} =~ ^[0-9]+$ ]] && (( SUDO_UID >= 1000 )); then
    printf 'Invoking desktop/console account UID: %s (name intentionally omitted).\n' "$SUDO_UID"
    return 0
  fi
  printf 'Run this check through sudo from the regular user session to record its UID.\n'
  return 2
}

capture_optional() {
  local label="$1" destination="$2"
  shift 2
  {
    printf '\n===== %s =====\n' "$label"
    if command -v "$1" >/dev/null 2>&1; then
      "$@" 2>&1 || printf 'Command exited non-zero: %s\n' "$1"
    else
      printf 'SKIP: command unavailable: %s\n' "$1"
    fi
  } | redact_stream >>"$destination"
}

capture_hardware() {
  printf 'Collection time (UTC): %s\n' "$started"
  printf 'Kernel: %s\nArchitecture: %s\n' "$(uname -sr)" "$(uname -m)"
  for item in sys_vendor product_name bios_version; do
    path="$sys_root/class/dmi/id/$item"
    if [[ -r $path ]]; then
      printf '%s: %s\n' "$item" "$(tr -d '\n' <"$path")"
    fi
  done
  capture_optional 'CPU details' "$hardware" lscpu
  capture_optional 'Memory summary' "$hardware" free -h
  capture_optional 'Block topology (serials and UUIDs excluded)' "$hardware" lsblk -e7 -o NAME,TYPE,SIZE,FSTYPE,MOUNTPOINTS,MODEL,TRAN
  capture_optional 'PCI devices' "$hardware" lspci -nn
  capture_optional 'Battery inventory' "$hardware" bash -c 'for f in /sys/class/power_supply/BAT*/{status,capacity,energy_full,energy_full_design}; do [[ -r $f ]] && printf "%s: %s\n" "${f##*/}" "$(cat "$f")"; done'
}
capture_boot_status() {
  capture_optional 'systemd-boot status' "$boot_status" bootctl status --no-pager
  capture_optional 'EFI boot entries' "$boot_status" bootctl list --no-pager
  capture_optional 'EFI UKI filenames' "$boot_status" bash -c 'for f in /efi/EFI/Linux/*.efi /boot/EFI/Linux/*.efi; do [[ -f $f ]] && basename "$f"; done'
  capture_optional 'Kernel command line (sensitive identifiers redacted)' "$boot_status" cat "$proc_root/cmdline"
}
capture_system_status() {
  capture_optional 'systemd state' "$system_status" systemctl is-system-running
  capture_optional 'Default target' "$system_status" systemctl get-default
  capture_optional 'Failed units' "$system_status" systemctl --failed --no-legend --plain
  capture_optional 'Root mount' "$system_status" findmnt -nro TARGET,SOURCE,FSTYPE /
  capture_optional 'EFI mount' "$system_status" findmnt -nro TARGET,SOURCE,FSTYPE /efi
  capture_optional 'NetworkManager state' "$system_status" nmcli -t -f STATE general
  capture_optional 'Active cryptroot mapping' "$system_status" cryptsetup status cryptroot
}

finalize_report() {
  local rc="$1" finished result
  (( finalized == 0 )) || return 0
  finalized=1
  finished="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  if (( rc == 0 && failed == 0 )); then result=PASS; else result=FAIL; fi
  {
    printf '# ThinkPad X280 first-boot report\n\n'
    printf -- '- Result: **%s**\n' "$result"
    printf -- '- Started (UTC): %s\n- Finished (UTC): %s\n' "$started" "$finished"
    printf -- '- Repository: Lenovo-ThinkPad-X280-K41\n- Branch: %s\n- Commit: %s\n' "$branch" "$commit"
    printf -- '- Kernel: %s\n- Architecture: %s\n' "$(uname -sr 2>/dev/null || printf unknown)" "$(uname -m 2>/dev/null || printf unknown)"
    printf -- '- Checks: %s PASS, %s FAIL, %s SKIP\n' "$passed" "$failed" "$skipped"
    printf -- '- Script exit code: %s\n' "$rc"
    printf '\n## Acceptance checks\n\n| Check | Result | Exit | Detail |\n|---|---:|---:|---|\n'
    cat "$check_rows"
    printf '\n## Evidence files\n\n'
    printf -- '- `boot-status.txt`: bootloader, UKI, and kernel command-line evidence\n'
    printf -- '- `system-status.txt`: systemd, mounts, network, and encryption state\n'
    printf -- '- `hardware.txt`: hardware inventory without disk serials or filesystem UUIDs\n'
    printf -- '- `diagnostics.log`: captured check output and errors\n'
    printf '\n## Interpretation and safety\n\n'
    printf 'This is a read-only snapshot of the running installed system. PASS applies only to the listed check and this boot. SKIP means evidence could not be collected; it is not a pass. A report containing FAIL must be reviewed before any repair. The collector does not change boot configuration, services, networking, encryption, partitions, or files outside its report directory. Review every report file before committing; automated redaction is best-effort and is not a substitute for human review.\n'
    printf '\nRun with `sudo bash scripts/x280-first-boot-check.sh` from the installed system. Reports are local and are never committed or pushed automatically.\n'
  } >"$summary"
  rm -f -- "$check_rows" "$report_dir/.check-output"
  chmod 600 "$summary" "$diagnostics" "$boot_status" "$system_status" "$hardware"
  printf '\nFirst-boot report: %s\nResult: %s (%s PASS, %s FAIL, %s SKIP)\n' "$summary" "$result" "$passed" "$failed" "$skipped"
}
on_exit() { local rc=$?; finalize_report "$rc"; }
trap on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

printf 'Collecting read-only first-boot evidence...\n'
run_check 'Installed Arch Linux' "$diagnostics" check_arch
run_check 'UEFI boot' "$boot_status" check_uefi
run_check 'Encrypted root mount (ext4 on cryptroot)' "$system_status" check_root_mount
run_check 'Active LUKS cryptroot mapping' "$system_status" check_luks
run_check 'EFI system partition mount' "$system_status" check_efi_mount
run_check 'systemd-boot status' "$boot_status" check_systemd_boot
run_check 'Unified Kernel Image present' "$boot_status" check_uki
run_check 'systemd reached running state' "$system_status" check_system_running
run_check 'No failed systemd units' "$system_status" check_failed_units
run_check 'Default systemd target active' "$system_status" check_default_target
run_check 'NetworkManager active' "$system_status" check_networkmanager
run_check 'Network connected' "$system_status" check_network_connection
run_check 'Regular user session context' "$diagnostics" check_login_context

capture_boot_status
capture_system_status
capture_hardware
printf '\nEvidence collection complete. Review all files before pushing.\n'
