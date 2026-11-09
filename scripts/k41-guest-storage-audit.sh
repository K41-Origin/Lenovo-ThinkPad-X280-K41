#!/usr/bin/env bash
# Read-only Guest Mode persistence-path audit for the installed ThinkPad X280.
set -Eeuo pipefail

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
have() { command -v "$1" >/dev/null 2>&1; }

usage() {
  cat <<'USAGE'
Usage: bash scripts/k41-guest-storage-audit.sh

Collects a focused, read-only snapshot of swap/resume, root and relevant
mounts, journald, coredump, and volatile-storage paths. Run as the regular
desktop user from the repository clone, without sudo.

The script writes one new report under reports/guest-mode-audit/.
It does not read file contents from user homes, install packages, change
configuration/services, or perform storage operations. Review the report
before sharing it. No Guest Mode configuration is applied.
USAGE
}

case "${1-}" in
  "") ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

(( EUID != 0 )) || die 'Jalankan sebagai user desktop biasa, tanpa sudo.'
for dependency in git stat date mkdir findmnt awk sed grep; do
  have "$dependency" || die "Dependensi tidak tersedia: $dependency"
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)" ||
  die 'Script harus dijalankan dari Git checkout.'
repo_root="$(cd -- "$repo_root" && pwd -P)"
[[ "$(git -C "$repo_root" branch --show-current)" == main ]] ||
  die 'Collector hanya berjalan pada branch main.'
[[ "$(stat -c %u "$repo_root")" == "$EUID" ]] ||
  die 'Repository bukan milik user aktif; jangan gunakan sudo/chown.'

report_parent="$repo_root/reports"
report_root="$report_parent/guest-mode-audit"
[[ ! -L $report_parent && ! -L $report_root ]] ||
  die 'Symlink pada jalur report ditolak.'
[[ ! -e $report_parent || -d $report_parent ]] ||
  die 'reports bukan direktori.'
[[ ! -e $report_root || -d $report_root ]] ||
  die 'guest-mode-audit bukan direktori.'
mkdir -p -- "$report_root"

stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
report="$report_root/$stamp-audit.txt"
suffix=0
while [[ -e $report || -L $report ]]; do
  suffix=$((suffix + 1))
  report="$report_root/$stamp-$suffix-audit.txt"
done
( set -o noclobber; : > "$report" ) 2>/dev/null ||
  die 'Tidak dapat membuat report baru.'

section() { printf '\n========== %s ==========\n' "$1" >>"$report"; }
run_capture() {
  local label="$1" binary="$2" rc
  shift 2
  section "$label"
  printf 'COMMAND:' >>"$report"
  printf ' %q' "$binary" "$@" >>"$report"
  printf '\n' >>"$report"
  if ! have "$binary"; then
    printf 'SKIPPED: command unavailable (%s)\n' "$binary" >>"$report"
  elif "$binary" "$@" >>"$report" 2>&1; then
    printf 'COMMAND EXIT: 0\n' >>"$report"
  else
    rc=$?
    printf 'COMMAND EXIT: %s (collection continues)\n' "$rc" >>"$report"
  fi
}
redact_storage_ids() {
  sed -E \
    -e 's/(UUID=)[^ ,]+/\1[REDACTED]/g' \
    -e 's/(PARTUUID=)[^ ,]+/\1[REDACTED]/g' \
    -e 's/(rd\.luks\.name=)[^ ]+/\1[REDACTED]/g' \
    -e 's/(cryptdevice=)[^ ]+/\1[REDACTED]/g'
}
mount_for_path() {
  local path="$1"
  printf '\n-- %s --\n' "$path" >>"$report"
  if [[ -e $path ]]; then
    findmnt -T "$path" -n -o TARGET,SOURCE,FSTYPE,OPTIONS 2>&1 |
      redact_storage_ids >>"$report" || true
  else
    printf 'PATH MISSING\n' >>"$report"
  fi
}
selected_config() {
  local file="$1" keys="$2"
  if [[ -r $file ]]; then
    awk -v keys="$keys" '
      BEGIN { n=split(keys, wanted, "|") }
      /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
      {
        line=$0
        sub(/^[[:space:]]*/, "", line)
        key=line
        sub(/[[:space:]]*=.*/, "", key)
        for (i=1; i<=n; i++) if (key == wanted[i]) print FILENAME ":" $0
      }
    ' "$file"
  fi
}

{
  printf 'K41 Guest Mode — Storage/Persistence Audit\n'
  printf 'Timestamp UTC: %s\n' "$stamp"
  printf 'Repository: %s\n' "$repo_root"
  printf 'Branch: %s\n' "$(git -C "$repo_root" branch --show-current)"
  printf 'Commit: %s\n' "$(git -C "$repo_root" rev-parse HEAD)"
  printf 'Kernel: %s\n' "$(uname -sr)"
  printf 'User: UID=%s (username omitted)\n' "$EUID"
  printf '\nScope: read-only persistence-path inspection; not a Guest Mode test.\n'
  printf 'No home-directory contents, credentials, browser profiles, or file listings are collected.\n'
  printf 'Report may still contain host-specific paths and package/service state; review before sharing.\n'
} >>"$report"

run_capture 'Memory capacity and pressure snapshot' free -b
section 'Selected memory counters'
grep -E '^(MemTotal|MemAvailable|SwapTotal|SwapFree|Shmem|Cached|SwapCached):' /proc/meminfo >>"$report" || true

run_capture 'Root filesystem' findmnt -n -o TARGET,SOURCE,FSTYPE,OPTIONS /
run_capture 'Active swap devices (path/type/size/usage only)' swapon --show --noheadings --raw --output NAME,TYPE,SIZE,USED,PRIO
section 'Swapfile metadata (no file contents read)'
if [[ -e /swapfile ]]; then
  stat -c 'type=%F size_bytes=%s mode=%a owner_uid=%u group_gid=%g path=%n' /swapfile >>"$report"
else
  printf '/swapfile: MISSING\n' >>"$report"
fi
section 'Relevant fstab entries'
if [[ -r /etc/fstab ]]; then
  awk '$0 !~ /^[[:space:]]*#/ && NF >= 3 && ($3 == "swap" || $2 == "swap") {print}' /etc/fstab |
    redact_storage_ids >>"$report"
else
  printf '/etc/fstab unavailable\n' >>"$report"
fi

section 'Kernel resume/hibernate parameters'
if [[ -r /proc/cmdline ]]; then
  tr ' ' '\n' </proc/cmdline |
    grep -E '^(resume=|resume_offset=|noresume$|hibernate=)' |
    redact_storage_ids >>"$report" || true
else
  printf '/proc/cmdline unavailable\n' >>"$report"
fi
for file in /etc/kernel/cmdline /etc/default/grub; do
  if [[ -r $file ]]; then
    printf '\n-- selected resume tokens: %s --\n' "$file" >>"$report"
    grep -Eo '(^|[[:space:]])(resume=[^[:space:]"]+|resume_offset=[^[:space:]"]+|noresume|hibernate=[^[:space:]"]+)' "$file" |
      redact_storage_ids >>"$report" || true
  fi
done
section 'Initramfs resume hook indicators'
for file in /etc/mkinitcpio.conf /etc/mkinitcpio.conf.d/*.conf; do
  [[ -r $file ]] || continue
  selected_config "$file" 'HOOKS|MODULES' >>"$report"
done
section 'Kernel hibernation interface'
for file in /sys/power/state /sys/power/disk; do
  if [[ -r $file ]]; then
    printf '%s: %s\n' "$file" "$(cat "$file")" >>"$report"
  else
    printf '%s: unavailable\n' "$file" >>"$report"
  fi
done

section 'ZRAM inventory'
found_zram=0
for device in /sys/block/zram*; do
  [[ -d $device ]] || continue
  found_zram=1
  printf '[%s]\n' "${device##*/}" >>"$report"
  for field in disksize comp_algorithm mm_stat; do
    if [[ -r $device/$field ]]; then
      printf '%s: %s\n' "$field" "$(cat "$device/$field")" >>"$report"
    fi
  done
done
(( found_zram == 1 )) || printf 'No zram block devices detected.\n' >>"$report"

section 'Effective journald settings (selected keys only)'
if have systemd-analyze; then
  systemd-analyze cat-config systemd/journald.conf 2>/dev/null |
    awk '
      /^[[:space:]]*\[/ { section=$0 }
      /^[[:space:]]*(Storage|Compress|Seal|ForwardToSyslog|SystemMaxUse|SystemKeepFree|RuntimeMaxUse|RuntimeKeepFree|MaxRetentionSec|MaxFileSec)[[:space:]]*=/ {
        print section " " $0
      }
    ' >>"$report" || true
else
  printf 'systemd-analyze unavailable; checking primary config only.\n' >>"$report"
  selected_config /etc/systemd/journald.conf 'Storage|Compress|Seal|ForwardToSyslog|SystemMaxUse|SystemKeepFree|RuntimeMaxUse|RuntimeKeepFree|MaxRetentionSec|MaxFileSec' >>"$report"
fi

section 'Effective coredump settings (selected keys only)'
if have systemd-analyze; then
  systemd-analyze cat-config systemd/coredump.conf 2>/dev/null |
    awk '
      /^[[:space:]]*\[/ { section=$0 }
      /^[[:space:]]*(Storage|Compress|ProcessSizeMax|ExternalSizeMax|JournalSizeMax|MaxUse|KeepFree)[[:space:]]*=/ {
        print section " " $0
      }
    ' >>"$report" || true
else
  printf 'systemd-analyze unavailable; checking primary config only.\n' >>"$report"
  selected_config /etc/systemd/coredump.conf 'Storage|Compress|ProcessSizeMax|ExternalSizeMax|JournalSizeMax|MaxUse|KeepFree' >>"$report"
fi

section 'Relevant mount destinations'
for path in /home /tmp /var/tmp /var/log /var/log/journal /run/log/journal \
  /var/lib/systemd/coredump /var/cache /run; do
  mount_for_path "$path"
done

section 'Relevant systemd unit state'
if have systemctl; then
  for unit in systemd-journald.service systemd-coredump.socket systemd-tmpfiles-clean.timer \
    logrotate.timer swapfile.swap; do
    printf '\n[%s]\n' "$unit" >>"$report"
    systemctl show "$unit" -p LoadState -p ActiveState -p UnitFileState --no-pager 2>&1 >>"$report" || true
  done
  printf '\nActive swap units:\n' >>"$report"
  systemctl list-units --type=swap --all --no-legend --no-pager 2>&1 >>"$report" || true
else
  printf 'systemctl unavailable\n' >>"$report"
fi

section 'Assessment boundaries'
cat >>"$report" <<'BOUNDARIES'
- This report describes the system at collection time; it does not prove all application write paths.
- Active swap on a persistent filesystem is a Guest Mode design blocker until a safe policy is selected.
- A swapfile inside LUKS remains persistent across reboot; encryption is not ephemerality.
- Volatile journald/coredump settings do not by themselves make every log/cache volatile.
- This collector does not inspect browser profiles, user files, network/router logs, remote DNS, or server-side records.
- No settings, packages, services, mounts, swap devices, boot entries, or files were changed.
BOUNDARIES

printf '\nAudit report created: %s\n' "$report"
printf 'Review/redact the report before sharing it. No system configuration was changed.\n'
printf 'After review, push only this report using:\n'
printf 'git -C %q add -- %q\n' "$repo_root" "${report#"$repo_root"/}"
printf 'git -C %q diff --cached --check\n' "$repo_root"
printf 'git -C %q commit --only -m %q -- %q\n' "$repo_root" 'audit(guest-mode): add storage persistence report' "${report#"$repo_root"/}"
printf 'git -C %q push origin main\n' "$repo_root"
