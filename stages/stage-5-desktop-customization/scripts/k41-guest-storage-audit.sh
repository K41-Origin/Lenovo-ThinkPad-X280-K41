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

Collects storage/mount topology, swap/hibernate, volatile-memory limits,
systemd persistence and user-session lifecycle, account/privilege metadata,
login/session entry points, desktop/browser packages and system launchers.
It does NOT enumerate home-directory contents or read browser profiles,
credentials, history, or documents. It reads only selected desktop startup
directives, autostart metadata, and bounded configuration path names.

The report may contain host paths, package versions, session IDs, device identifiers,
and selected desktop/PAM configuration. Review and redact it before sharing.
No system configuration or service state is changed.
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
report_root="$repo_root/reports/stage-5-desktop-customization/03-guest-mode/guest-storage-audit"
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
  sed -E \
    -e 's/(UUID=)[^ ,]+/\1[REDACTED]/g' \
    -e 's/(PARTUUID=)[^ ,]+/\1[REDACTED]/g' \
    -e 's/(rd\.luks\.name=)[^ ]+/\1[REDACTED]/g' \
    -e 's/(cryptdevice=)[^ ]+/\1[REDACTED]/g' \
    -e 's/(nvme\.eui\.)[[:alnum:]]+/\1[REDACTED]/g' \
    -e 's/(SERIAL=)[^ ,]+/\1[REDACTED]/g' \
    -e 's#(/dev/disk/by-uuid/)[[:alnum:]-]+#\1[REDACTED]#g' \
    -e 's#(/dev/disk/by-partuuid/)[[:alnum:]-]+#\1[REDACTED]#g'
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
    pacman -Q 2>/dev/null | grep -Ei '^(hyprland|caelestia|quickshell|firefox|chromium|brave|google-chrome|floorp|librewolf|zen-browser|vivaldi|opera|xdg-desktop-portal|uwsm|seatd|polkit|pipewire|wireplumber|sddm|greetd|ly|gdm|lightdm)([[:space:]-]|$)' >>"$report" || true
  else note 'pacman unavailable'; fi
}
{
  printf 'K41 Guest Mode — Extended Read-only Audit\n'
  printf 'Timestamp UTC: %s\n' "$stamp"
  printf 'Repository: checkout path omitted (privacy)\n'
  printf 'Branch: %s\n' "$(git -C "$repo_root" branch --show-current)"
  printf 'Commit: %s\n' "$(git -C "$repo_root" rev-parse HEAD)"
  printf 'Kernel: %s\n' "$(uname -sr)"
  printf 'Collector UID: %s (username omitted)\n' "$EUID"
  printf 'Scope: read-only host, session, account, desktop and persistence inspection.\n'
  printf 'No home content, browser profiles, credentials, document contents, or user-specific config are read.\n'
  printf 'Review/redact host-specific information before sharing.\n'
} >>"$report"

section 'Systemd and package manager versions'
if have systemctl; then systemctl --version 2>&1 | head -n 1 >>"$report"; else note 'systemctl unavailable'; fi
if have pacman; then pacman --version 2>&1 | head -n 1 >>"$report"; else note 'pacman unavailable'; fi

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
section 'Filesystem table and crypttab metadata (comments and keyfile fields omitted)'
if [[ -r /etc/fstab ]]; then awk '$0 !~ /^[[:space:]]*#/ && NF>=4 {print $1, $2, $3, $4, $5, $6}' /etc/fstab | redact_ids >>"$report"; fi
if [[ -r /etc/crypttab ]]; then
  printf '\ncrypttab (name, source, options only; keyfile field omitted):\n' >>"$report"
  awk '$0 !~ /^[[:space:]]*#/ && NF>=3 {print $1, $2, $4}' /etc/crypttab | redact_ids >>"$report"
fi
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
  systemctl show systemd-coredump.socket -p LoadState -p ActiveState -p SubState --no-pager >>"$report" 2>&1 || true
fi
note 'Empty directive output is not equivalent to disabled coredumps; defaults apply.'

section 'Relevant mount destinations and directory metadata'
for path in /home /root /tmp /dev/shm /run /run/user /run/user/"$EUID" /var/tmp /var/log /var/log/journal /run/log/journal /var/lib /var/lib/systemd /var/lib/systemd/coredump /var/lib/AccountsService /var/lib/flatpak /var/cache /var/spool /var/mail /opt /usr/local /srv /mnt /media; do mount_for_path "$path"; done
section 'Complete mounted filesystem topology (identifiers redacted)'
if have findmnt; then findmnt -rn -o TARGET,SOURCE,FSTYPE,OPTIONS 2>&1 | redact_ids >>"$report" || true; fi
section 'Home directory metadata and ACLs (no contents or names)'
for path in /home /root; do
  if [[ -e $path ]]; then
    stat -c 'path=%n type=%F mode=%a owner_uid=%u group_gid=%g' "$path" >>"$report" 2>&1
    if have getfacl; then getfacl -cpn "$path" 2>/dev/null | grep -v '^#' >>"$report" || true; fi
  else note "$path: MISSING"; fi
done
if [[ -d /home ]]; then
  for path in /home/*; do
    [[ -d $path ]] || continue
    stat -c 'home_entry type=%F mode=%a owner_uid=%u group_gid=%g' "$path" >>"$report" 2>&1 || true
    if have getfacl; then getfacl -cpn "$path" 2>/dev/null | grep -v '^#' >>"$report" || true; fi
  done
fi

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
for path in /etc/sudoers /etc/sudoers.d; do
  if [[ -e $path ]]; then stat -c 'sudo_policy_path=%n type=%F mode=%a owner_uid=%u group_gid=%g' "$path" >>"$report" 2>&1
  else note "$path: MISSING"; fi
done
note 'Sudo policy contents are intentionally not read; group membership is only an indicator, not a complete sudo authorization check.'

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
  printf '\\n-- Running system service unit names only --\\n' >>"$report"
  systemctl list-units --type=service --state=running --no-legend --no-pager 2>&1 |
    awk '{print $1}' | sort -u >>"$report" || true
else note 'systemctl unavailable'; fi

section 'Filesystem topology, capacity and volatile mount limits'
if have lsblk; then lsblk -o NAME,TYPE,FSTYPE,SIZE,MOUNTPOINTS 2>&1 | redact_ids >>"$report" || true; else note 'lsblk unavailable'; fi
if have df; then df -B1 -P / /home /tmp /dev/shm /var /var/tmp /var/log /var/lib /run /run/user/"$EUID" >>"$report" 2>&1 || true; fi
for path in /dev/shm /run/user/"$EUID" /var/lib /var/lib/AccountsService /var/lib/flatpak /opt /usr/local; do
  printf '\n-- %s --\n' "$path" >>"$report"
  if [[ -e $path ]]; then
    findmnt -T "$path" -n -o TARGET,SOURCE,FSTYPE,OPTIONS 2>&1 | redact_ids >>"$report" || true
    stat -c 'object_type=%F mode=%a owner_uid=%u group_gid=%g' "$path" >>"$report" 2>&1 || true
    if have getfacl; then getfacl -cpn "$path" 2>/dev/null | grep -v '^#' >>"$report" || true; fi
  else note 'PATH MISSING'; fi
done

section 'Memory and cgroup limits relevant to session storage'
for file in /sys/fs/cgroup/memory.max /sys/fs/cgroup/memory.current /sys/fs/cgroup/memory.swap.max; do
  [[ -r $file ]] && printf '%s: %s\n' "$file" "$(cat "$file")" >>"$report"
done
if have systemctl; then
  systemctl show "user-$EUID.slice" "user@$EUID.service" -p Id -p ActiveState -p MemoryMax -p MemoryHigh -p TasksMax -p ControlGroup --no-pager >>"$report" 2>&1 || true
  for unit in "user-$EUID.slice" "user@$EUID.service"; do
    cg="$(systemctl show "$unit" -p ControlGroup --value 2>/dev/null || true)"
    [[ -n $cg && $cg == /* ]] || continue
    for key in memory.max memory.high memory.current memory.swap.max pids.max; do
      file="/sys/fs/cgroup${cg%/}/$key"
      [[ -r $file ]] && printf '%s %s: %s\n' "$unit" "$key" "$(cat "$file")" >>"$report"
    done
  done
fi

section 'Current user manager, lingering and session lifecycle'
if have loginctl; then
  loginctl show-user "$EUID" -p UID -p GID -p State -p Sessions -p Linger -p RuntimePath --no-pager >>"$report" 2>&1 || true
  loginctl show-user guest -p UID -p GID -p State -p Sessions -p Linger -p RuntimePath --no-pager >>"$report" 2>&1 || true
fi
if have systemctl; then
  systemctl show "user@$EUID.service" "user-$EUID.slice" -p Id -p LoadState -p ActiveState -p SubState -p ControlGroup --no-pager >>"$report" 2>&1 || true
  printf '\n-- User manager service/socket/target names and states only --\n' >>"$report"
  systemctl --user list-units --type=service,socket,target --all --no-legend --no-pager 2>&1 | awk '{print $1 " " $2 " " $3}' >>"$report" || true
  printf '\n-- User manager service/socket unit-file names and states --\n' >>"$report"
  systemctl --user list-unit-files --type=service,socket --no-legend --no-pager 2>&1 | awk '{print $1 " " $2}' >>"$report" || true
fi
if [[ -e /var/lib/systemd/linger/"$EUID" ]]; then note "collector_user_linger=yes uid=$EUID"; else note "collector_user_linger=no uid=$EUID"; fi
if have ps; then
  printf 'collector_user_process_names:\n' >>"$report"
  ps -u "$EUID" -o comm= 2>/dev/null | sort -u >>"$report" || true
fi

section 'Login manager and PAM entry-point metadata'
if have systemctl; then
  systemctl show display-manager.service -p LoadState -p ActiveState -p SubState -p FragmentPath --no-pager >>"$report" 2>&1 || true
  systemctl list-unit-files --no-legend --no-pager 2>/dev/null | grep -Ei '(^|/)(sddm|greetd|ly|gdm|lightdm|systemd-logind)(\.service|@\.service)' >>"$report" || true
fi
if [[ -L /etc/systemd/system/display-manager.service ]]; then
  printf 'display_manager_link=%s\n' "$(readlink /etc/systemd/system/display-manager.service)" >>"$report"
fi
if [[ -d /etc/pam.d ]]; then
  printf 'pam_stack_files (names only):\n' >>"$report"
  find /etc/pam.d -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | sort >>"$report" || true
  printf '\nSelected PAM auth/account/session module chains (no password database or secrets):\n' >>"$report"
  for file in /etc/pam.d/login /etc/pam.d/system-local-login /etc/pam.d/system-login /etc/pam.d/system-auth /etc/pam.d/sudo /etc/pam.d/hyprlock /etc/pam.d/other; do
    [[ -r $file ]] || continue
    printf '[%s]\n' "${file##*/}" >>"$report"
    awk '$1 ~ /^(auth|account|session)$/ {print}' "$file" |
      sed -E 's/(password|token|secret|api[_-]?key)=[^[:space:]]+/\1=[REDACTED]/Ig' >>"$report"
  done
fi

section 'System session launch metadata (Name, Exec, TryExec only)'
for dir in /usr/share/wayland-sessions /usr/share/xsessions; do
  printf '\n-- %s --\n' "$dir" >>"$report"
  if [[ -d $dir ]]; then
    find "$dir" -maxdepth 1 -type f -name '*.desktop' -print0 2>/dev/null |
      while IFS= read -r -d '' file; do
        printf '[%s]\n' "$(basename "$file")"
        grep -E '^(Name|Exec|TryExec)=' "$file" 2>/dev/null || true
      done >>"$report"
  else note 'directory missing'; fi
done

section 'Installed browser desktop launchers (selected metadata only)'
if [[ -d /usr/share/applications ]]; then
  find /usr/share/applications -maxdepth 1 -type f \
    \( -iname '*firefox*.desktop' -o -iname '*chromium*.desktop' -o -iname '*brave*.desktop' -o -iname '*browser*.desktop' \) -print0 2>/dev/null |
    while IFS= read -r -d '' file; do
      printf '[%s]\n' "$(basename "$file")"
      grep -E '^(Name|Exec|TryExec|MimeType)=' "$file" 2>/dev/null || true
    done >>"$report"
fi
if have flatpak; then
  printf '\nFlatpak applications (IDs/branch/installation only):\n' >>"$report"
  flatpak list --app --columns=application,branch,installation >>"$report" 2>&1 || true
fi

section 'Browser private-mode policy indicators (selected policy keys only)'
for file in /etc/firefox/policies/policies.json /usr/lib/firefox/distribution/policies.json \
  /etc/chromium/policies/managed/*.json /etc/opt/chrome/policies/managed/*.json \
  /etc/brave/policies/managed/*.json; do
  [[ -r $file ]] || continue
  printf '[%s]\n' "${file#/}" >>"$report"
  grep -Ei 'DisablePrivateBrowsing|IncognitoModeAvailability|BrowserGuestModeEnabled|PrivateBrowsingMode' "$file" |
    sed -E 's/("?(password|token|secret|api[_-]?key)"?[[:space:]]*:[[:space:]]*)"[^"]*"/\1"[REDACTED]"/Ig' >>"$report" || true
done
section 'System and active-user default browser associations (selected MIME keys only)'
for file in /usr/share/applications/mimeapps.list /etc/xdg/mimeapps.list /usr/local/share/applications/mimeapps.list; do
  if [[ -r $file ]]; then
    printf '[%s]\n' "$file" >>"$report"
    awk '/^\[Default Applications\]/{p=1;next} /^\[/{p=0} p && /^(text\/html|x-scheme-handler\/http|x-scheme-handler\/https)=/{print}' "$file" >>"$report"
  fi
done
if have xdg-mime; then
  for mime in text/html x-scheme-handler/http x-scheme-handler/https; do
    printf 'active_user_default[%s]=' "$mime" >>"$report"
    xdg-mime query default "$mime" 2>/dev/null | head -n 1 >>"$report" || true
  done
else note 'xdg-mime unavailable; active-user MIME defaults not queried.'; fi
if have xdg-settings; then
  printf 'active_user_default_web_browser=' >>"$report"
  xdg-settings get default-web-browser 2>/dev/null | head -n 1 >>"$report" || true
fi
note 'Only selected browser association keys are queried; browser profiles, cookies, history and credentials are not inspected.'
if have journalctl; then journalctl --disk-usage --no-pager >>"$report" 2>&1 || true; fi

section 'User desktop autostart metadata (selected keys only)'
for dir in "$HOME/.config/autostart" /etc/xdg/autostart; do
  display_dir="${dir/#$HOME/~}"
  printf '\n-- %s --\n' "$display_dir" >>"$report"
  if [[ -d $dir ]]; then
    while IFS= read -r -d '' file; do
      printf '[%s]\n' "$(basename "$file")" >>"$report"
      grep -E '^(Name|Exec|TryExec|Hidden|OnlyShowIn|NotShowIn|X-GNOME-Autostart-enabled)=' "$file" 2>/dev/null |
        sed -E 's/([Tt][Oo][Kk][Ee][Nn]|[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]|[Ss][Ee][Cc][Rr][Ee][Tt]|[Aa][Pp][Ii][_-]?[Kk][Ee][Yy])=[^ ;]+/\1=[REDACTED]/g' | sed "s|$HOME|~|g" >>"$report" || true
    done < <(find "$dir" -maxdepth 1 -type f -name '*.desktop' -print0 2>/dev/null)
  else note 'directory missing'; fi
done
section 'Hyprland startup directives (selected directives only)'
hypr_config="$HOME/.config/hypr/hyprland.conf"
if [[ -r $hypr_config ]]; then
  grep -E '^[[:space:]]*(exec(-once)?|source|env)[[:space:]]*=' "$hypr_config" |
    sed -E 's/((TOKEN|PASSWORD|SECRET|API[_-]?KEY|ACCESS[_-]?KEY)[^=]*=)[^ ,;]+/\1[REDACTED]/Ig' | sed "s|$HOME|~|g" >>"$report" || true
else note 'Primary Hyprland config not found/readable at standard path.'; fi
section 'Quickshell/Caelestia config inventory (names and file types only)'
for dir in "$HOME/.config/quickshell" "$HOME/.config/caelestia" "$HOME/.config/hypr" "$HOME/.local/share/caelestia"; do
  display_dir="${dir/#$HOME/~}"
  printf '\n-- %s --\n' "$display_dir" >>"$report"
  if [[ -d $dir ]]; then find "$dir" -maxdepth 2 -mindepth 1 -printf '%y %P\n' 2>/dev/null | head -n 100 >>"$report"; else note 'directory missing'; fi
done

section 'Audit boundaries and interpretation'
cat >>"$report" <<'BOUNDARIES'
- Snapshot only: this does not prove every application write path or filesystem permission boundary.
- Home directories are not enumerated. Only selected desktop startup directives, autostart keys and bounded path names are read; browser profiles, cookies, credentials, history and documents are not read.
- Session IDs and system paths may be identifying; review/redact before sharing.
- Empty systemd directive output means defaults may apply, not that a feature is disabled.
- Persistent swap, persistent logs/coredumps, lingering user services, and unisolated writable paths must be addressed in the Guest design.
- Browser MIME defaults and desktop launchers are collected, but they do not prove which browser process will launch in every session.
- User-manager unit names/status, session IDs and mount paths may be identifying; review/redact before sharing.
- Selected Hyprland startup directives, desktop autostart entries, PAM module chains and browser MIME defaults are included for design analysis; review/redact before sharing.
- Browser profiles, cookies, history, credentials and general user documents are not inspected.
- Selected startup Exec directives may still reveal local paths or arguments; review/redact before publishing.
- Quickshell/Caelestia configuration contents are not dumped; only bounded file/directory names are inventoried.
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
