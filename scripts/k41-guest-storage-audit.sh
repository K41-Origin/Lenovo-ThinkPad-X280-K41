#!/usr/bin/env bash
# Read-only Guest Mode host/storage audit. Run as the regular desktop user.
set -Eeuo pipefail

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
have() { command -v "$1" >/dev/null 2>&1; }
usage() {
  cat <<'USAGE'
Usage: bash scripts/k41-guest-storage-audit.sh

Creates a read-only Guest Mode audit report under reports/guest-mode-audit/.
Run from the repository clone as the regular desktop user, without sudo.

Collects memory/swap/hibernate, mounts and permissions, journald/coredump,
logind/session/linger state, the guest account and privilege indicators,
installed desktop/browser packages, and system-level desktop launchers.
It does NOT enumerate home-directory contents, read browser profiles,
credentials, document contents, or user-specific configuration files.

The report may contain host paths, package versions, session IDs, and
configuration values. Review and redact it before sharing. No system
configuration or service state is changed.
USAGE
}
case "${1-}" in "" ) ;; -h|--help) usage; exit 0 ;; *) usage >&2; exit 2 ;; esac
(( EUID != 0 )) || die 'Jalankan sebagai user desktop biasa, tanpa sudo.'
for dependency in git stat date mkdir findmnt awk sed grep; do
  have "$dependency" || die "Dependensi tidak tersedia: $dependency"
done
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)" || die 'Script harus dijalankan dari Git checkout.'
repo_root="$(cd -- "$repo_root" && pwd -P)"
[[ "$(git -C "$repo_root" branch --show-current)" == main ]] || die 'Collector hanya berjalan pada branch main.'
[[ "$(stat -c %u "$repo_root")" == "$EUID" ]] || die 'Repository bukan milik user aktif; jangan gunakan sudo/chown.'
report_parent="$repo_root/reports"
report_root="$report_parent/guest-mode-audit"
[[ ! -L $report_parent && ! -L $report_root ]] || die 'Symlink pada jalur report ditolak.'
[[ ! -e $report_parent || -d $report_parent ]] || die 'reports bukan direktori.'
[[ ! -e $report_root || -d $report_root ]] || die 'guest-mode-audit bukan direktori.'
mkdir -p -- "$report_root"
stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
report="$report_root/$stamp-audit.txt"
suffix=0
while [[ -e $report || -L $report ]]; do suffix=$((suffix + 1)); report="$report_root/$stamp-$suffix-audit.txt"; done
( set -o noclobber; : > "$report" ) 2>/dev/null || die 'Tidak dapat membuat report baru.'

section() { printf '\n========== %s ==========\n' "$1" >>"$report"; }
note() { printf '%s\n' "$*" >>"$report"; }
capture_shell() {
  local label="$1"; shift
  section "$label"
  if "$@" >>"$report" 2>&1; then note 'COLLECTION EXIT: 0'; else note "COLLECTION EXIT: $? (collection continues)"; fi
}
redact_ids() {
  sed -E -e 's/(UUID=)[^ ,]+/\1[REDACTED]/g' -e 's/(PARTUUID=)[^ ,]+/\1[REDACTED]/g' \
    -e 's/(rd\.luks\.name=)[^ ]+/\1[REDACTED]/g' -e 's/(cryptdevice=)[^ ]+/\1[REDACTED]/g'
}
mount_for_path() {
  local path="$1"
  printf '\n-- %s --\n' "$path" >>"$report"
  if [[ -e $path ]]; then
    findmnt -T "$path" -n -o TARGET,SOURCE,FSTYPE,OPTIONS 2>&1 | redact_ids >>"$report" || true
    stat -c 'object_type=%F mode=%a owner_uid=%u group_gid=%g' "$path" >>"$report" 2>&1 || true
  else note 'PATH MISSING'; fi
}
effective_config() {
  local unit="$1" keys="$2"
  if have systemd-analyze; then
    systemd-analyze cat-config "$unit" 2>/dev/null | awk -v keys="$keys" '
      /^[[:space:]]*\[/ { section=$0 }
      /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
      {
        line=$0; sub(/^[[:space:]]*/, "", line); key=line; sub(/[[:space:]]*=.*/, "", key)
        n=split(keys,wanted,"|"); for(i=1;i<=n;i++) if(key==wanted[i]) print section " " $0
      }' >>"$report" || true
  else note 'systemd-analyze unavailable; effective merged config not collected.'; fi
}
selected_file_config() {
  local file="$1" keys="$2"
  [[ -r $file ]] || return 0
  awk -v keys="$keys" '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    { line=$0; sub(/^[[:space:]]*/, "", line); key=line; sub(/[[:space:]]*=.*/, "", key)
      n=split(keys,wanted,"|"); for(i=1;i<=n;i++) if(key==wanted[i]) print FILENAME ":" $0
    }' "$file" >>"$report"
}
package_filter() {
  if have pacman; then
    pacman -Q 2>/dev/null | grep -Ei '^(hyprland|caelestia|quickshell|firefox|chromium|brave|google-chrome|floorp|librewolf|zen-browser|xdg-desktop-portal|uwsm|seatd|polkit|pipewire|wireplumber)([[:space:]-]|$)' >>"$report" || true
  else note 'pacman unavailable'; fi
}
{
  printf 'K41 Guest Mode — Extended Read-only Audit\n'
  printf 'Timestamp UTC: %s\n' "$stamp"
  printf 'Repository: %s\n' "$repo_root"
  printf 'Branch: %s\n' "$(git -C "$repo_root" branch --show-current)"
  printf 'Commit: %s\n' "$(git -C "$repo_root" rev-parse HEAD)"
  printf 'Kernel: %s\n' "$(uname -sr)"
  printf 'Collector UID: %s (username omitted)\n' "$EUID"
  printf 'Scope: read-only host, session, account, desktop and persistence inspection.\n'
  printf 'No home content, browser profiles, credentials, document contents, or user-specific config are read.\n'
  printf 'Review/redact host-specific information before sharing.\n'
} >>"$report"

section 'Memory capacity and pressure snapshot'
if have free; then free -b >>"$report" 2>&1; else note 'free unavailable'; fi
section 'Selected memory counters'
grep -E '^(MemTotal|MemAvailable|SwapTotal|SwapFree|Shmem|Cached|SwapCached|Dirty|Writeback|CommitLimit|Committed_AS):' /proc/meminfo >>"$report" || true
section 'Root filesystem'
findmnt -n -o TARGET,SOURCE,FSTYPE,OPTIONS / 2>&1 | redact_ids >>"$report" || true
section 'Active swap and swapfile metadata'
if have swapon; then swapon --show --noheadings --raw --output NAME,TYPE,SIZE,USED,PRIO 2>&1 | redact_ids >>"$report" || true; else note 'swapon unavailable'; fi
for path in /swapfile; do
  if [[ -e $path ]]; then stat -c 'type=%F size_bytes=%s mode=%a owner_uid=%u group_gid=%g path=%n' "$path" >>"$report"; else note "$path: MISSING"; fi
done
section 'Relevant fstab entries'
if [[ -r /etc/fstab ]]; then awk '$0 !~ /^[[:space:]]*#/ && NF>=3 && ($3=="swap" || $2=="swap") {print}' /etc/fstab | redact_ids >>"$report"; fi
section 'Resume/hibernate configuration indicators'
if [[ -r /proc/cmdline ]]; then tr ' ' '\n' </proc/cmdline | grep -E '^(resume=|resume_offset=|noresume$|hibernate=)' | redact_ids >>"$report" || true; fi
for file in /etc/kernel/cmdline /etc/default/grub; do
  if [[ -r $file ]]; then printf '\n-- %s --\n' "$file" >>"$report"; grep -Eo '(^|[[:space:]])(resume=[^[:space:]"]+|resume_offset=[^[:space:]"]+|noresume|hibernate=[^[:space:]"]+)' "$file" | redact_ids >>"$report" || true; fi
done
section 'Initramfs resume hook indicators'
for file in /etc/mkinitcpio.conf /etc/mkinitcpio.conf.d/*.conf; do
  [[ -r $file ]] || continue
  selected_file_config "$file" 'HOOKS|MODULES'
done
for file in /sys/power/state /sys/power/disk; do
  if [[ -r $file ]]; then printf '%s: %s\n' "$file" "$(cat "$file")" >>"$report"; else note "$file: unavailable"; fi
done
section 'ZRAM and zswap indicators'
found_zram=0
for device in /sys/block/zram*; do
  [[ -d $device ]] || continue; found_zram=1; printf '[%s]\n' "${device##*/}" >>"$report"
  for field in disksize comp_algorithm mm_stat; do [[ -r $device/$field ]] && printf '%s: %s\n' "$field" "$(cat "$device/$field")" >>"$report"; done
done
(( found_zram )) || note 'No zram block devices detected.'
for file in /sys/module/zswap/parameters/enabled /sys/module/zswap/parameters/max_pool_percent /sys/module/zswap/parameters/compressor /sys/module/zswap/parameters/zpool; do
  [[ -r $file ]] && printf '%s: %s\n' "$file" "$(cat "$file")" >>"$report"
done

section 'Effective journald configuration (selected directives)'
effective_config systemd/journald.conf 'Storage|Compress|Seal|ForwardToSyslog|SystemMaxUse|SystemKeepFree|RuntimeMaxUse|RuntimeKeepFree|MaxRetentionSec|MaxFileSec'
section 'Journald storage directories and service state'
for path in /var/log/journal /run/log/journal; do mount_for_path "$path"; done
if have systemctl; then systemctl show systemd-journald.service -p LoadState -p ActiveState -p SubState --no-pager >>"$report" 2>&1 || true; fi
note 'Interpretation: empty directive output means defaults may apply; check journal directory existence and installed systemd version.'

section 'Effective coredump configuration (selected directives)'
effective_config systemd/coredump.conf 'Storage|Compress|ProcessSizeMax|ExternalSizeMax|JournalSizeMax|MaxUse|KeepFree'
section 'Coredump paths and unit state'
mount_for_path /var/lib/systemd/coredump
if have systemctl; then
  for unit in systemd-coredump.socket systemd-coredump@.service; do systemctl show "$unit" -p LoadState -p ActiveState -p SubState --no-pager >>"$report" 2>&1 || true; done
fi
note 'Empty directive output is not equivalent to disabled coredumps; defaults apply.'

section 'Relevant mount destinations and directory metadata'
for path in /home /root /tmp /var/tmp /var/log /var/log/journal /run/log/journal /var/lib/systemd/coredump /var/cache /run /run/user; do mount_for_path "$path"; done
section 'Home top-level metadata only (no contents)'
for path in /home /root; do
  if [[ -e $path ]]; then stat -c '%n type=%F mode=%a owner_uid=%u group_gid=%g' "$path" >>"$report" 2>&1; else note "$path: MISSING"; fi
done

section 'systemd-logind effective session policy'
effective_config systemd/logind.conf 'KillUserProcesses|KillOnlyUsers|KillExcludeUsers|UserStopDelaySec|RemoveIPC|NAutoVTs|ReserveVT|InhibitDelayMaxSec|RuntimeDirectorySize|UserTasksMax'
section 'Active login sessions (user names omitted)'
if have loginctl; then
  loginctl list-sessions --no-legend --no-pager 2>/dev/null | awk '{print "session_id=" $1 " uid=" $2 " seat=" $4 " tty=" $5}' >>"$report" || true
  loginctl show-user guest -p UID -p GID -p State -p Sessions -p Linger -p RuntimePath --no-pager >>"$report" 2>&1 || true
else note 'loginctl unavailable'; fi
section 'Guest account and privilege indicators'
if have getent && getent passwd guest >/dev/null 2>&1; then
  guest_entry="$(getent passwd guest)"
  IFS=: read -r gname _ guid ggid _ ghome gshell <<<"$guest_entry"
  printf 'guest_exists=yes uid=%s gid=%s home=%s shell=%s\n' "$guid" "$ggid" "$ghome" "$gshell" >>"$report"
  if have id; then id -G guest 2>/dev/null | awk '{print "guest_group_ids=" $0}' >>"$report" || true; fi
  if [[ -e /var/lib/systemd/linger/guest ]]; then note 'guest_linger=yes'; else note 'guest_linger=no'; fi
  if [[ $guid -lt 1000 || $guid -eq 0 ]]; then note 'WARNING: guest UID is outside ordinary unprivileged user range.'; fi
  if have getent; then
    for group in wheel sudo; do
      members="$(getent group "$group" 2>/dev/null | awk -F: '{print $4}')"
      [[ ",$members," == *",guest,"* ]] && note "WARNING: guest is explicitly listed in group $group."
    done
  fi
else note 'guest_exists=no'; fi
section 'Sudo policy indicators (no policy file contents)'
if have getent; then
  for group in wheel sudo; do getent group "$group" 2>/dev/null | awk -F: -v g="$group" '{print "group=" g " gid=" $3 " member_count=" (split($4,a,",") && $4!="" ? length(a) : 0)}' >>"$report" || true; done
fi
if [[ -d /etc/sudoers.d ]]; then
  find /etc/sudoers.d -maxdepth 1 -type f -printf 'sudoers_include_file=%f mode=%m owner=%U\n' 2>/dev/null | sort >>"$report"
else note '/etc/sudoers.d missing'; fi

section 'Installed desktop, portal, and browser packages'
package_filter
section 'System desktop session definitions and autostart filenames'
for dir in /usr/share/wayland-sessions /usr/share/xsessions /etc/xdg/autostart; do
  printf '\n-- %s --\n' "$dir" >>"$report"
  if [[ -d $dir ]]; then find "$dir" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | sort >>"$report"; else note 'directory missing'; fi
done
section 'Relevant running desktop processes (process names only)'
if have ps; then ps -eo comm= | grep -Ei '^(Hyprland|quickshell|caelestia|firefox|chromium|brave|xdg-desktop-portal.*|pipewire|wireplumber|polkitd)$' | sort -u >>"$report" || true; fi

section 'Relevant systemd units and active swap units'
if have systemctl; then
  for unit in systemd-journald.service systemd-coredump.socket systemd-tmpfiles-clean.timer logrotate.timer swapfile.swap; do
    printf '\n[%s]\n' "$unit" >>"$report"
    systemctl show "$unit" -p LoadState -p ActiveState -p UnitFileState --no-pager >>"$report" 2>&1 || true
  done
  systemctl list-units --type=swap --all --no-legend --no-pager 2>&1 | redact_ids >>"$report" || true
else note 'systemctl unavailable'; fi

section 'Audit boundaries and interpretation'
cat >>"$report" <<'BOUNDARIES'
- Snapshot only: this does not prove every application write path or filesystem permission boundary.
- No user home contents, browser profiles, cookies, credentials, documents, or personal configuration are read or listed.
- Session IDs and system paths may be identifying; review/redact before sharing.
- Empty systemd directive output means defaults may apply, not that a feature is disabled.
- Persistent swap, persistent logs/coredumps, lingering user services, and unisolated writable paths must be addressed in the Guest design.
- Browser package presence does not prove which browser is configured as the default or launched automatically.
- System-level launcher filenames do not reveal user-level autostart configuration.
- This collector does not inspect remote/server-side activity, network device logs, or removable media.
- No settings, packages, services, mounts, swap devices, boot entries, permissions, or existing files were changed.
BOUNDARIES
printf '\nAudit report created: %s\n' "$report"
printf 'Review/redact the report before sharing it. No system configuration was changed.\n'
printf 'After review, push only this report using:\n'
printf 'git -C %q add -- %q\n' "$repo_root" "${report#"$repo_root"/}"
printf 'git -C %q diff --cached --check\n' "$repo_root"
printf 'git -C %q commit --only -m %q -- %q\n' "$repo_root" 'audit(guest-mode): add extended read-only report' "${report#"$repo_root"/}"
printf 'git -C %q push origin main\n' "$repo_root"
