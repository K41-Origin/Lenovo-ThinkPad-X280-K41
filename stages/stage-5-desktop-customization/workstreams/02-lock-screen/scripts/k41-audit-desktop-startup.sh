#!/usr/bin/env bash
# Read-only X280 desktop startup diagnostic for tty fallback / stuck Hyprland launch.
# Can be run from tty2 or a normal user shell; does not require a Wayland session.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
have() { command -v "$1" >/dev/null 2>&1; }

(( EUID != 0 )) || die 'Jalankan sebagai user desktop biasa, tanpa sudo.'
[[ -n ${HOME:-} && $HOME == /* && -d $HOME ]] || die 'HOME tidak valid.'
for cmd in git stat date mkdir chmod uname id who tty ps awk grep sed tail find python3 cp rm mktemp rmdir tr; do
    have "$cmd" || die "Command wajib tidak tersedia: $cmd"
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)" ||
    die 'Script harus dijalankan dari Git checkout.'
repo_root="$(cd -- "$repo_root" && pwd -P)"
[[ $(git -C "$repo_root" branch --show-current) == main ]] ||
    die 'Audit hanya berjalan pada branch main.'
[[ $(stat -c %u -- "$repo_root") == "$EUID" ]] ||
    die 'Repository bukan milik user aktif; jangan gunakan sudo/chown.'

report_parent="$repo_root/reports"
report_root="$report_parent/stage-5-desktop-customization/02-lock-screen/startup-audits"
for path in "$report_parent" "$report_parent/stage-5-desktop-customization" "$report_parent/stage-5-desktop-customization/02-lock-screen" "$report_root"; do
    [[ ! -L $path ]] || die "Symlink report path ditolak: $path"
    [[ ! -e $path || -d $path ]] || die "Report path bukan direktori: $path"
done
mkdir -p -- "$report_root"
stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
run_dir="$report_root/$stamp"
suffix=0
while ! mkdir -- "$run_dir" 2>/dev/null; do
    [[ -e $run_dir ]] || die 'Tidak dapat membuat direktori report.'
    suffix=$((suffix + 1))
    run_dir="$report_root/$stamp-$suffix"
done
chmod 0700 "$run_dir"
report="$run_dir/report.txt"
( set -o noclobber; : > "$report" ) 2>/dev/null || die 'Tidak dapat membuat report.'
chmod 0600 "$report"

# Redact common identifiers and credential-like values before writing logs.
redact() {
    python3 -c '
import os, pwd, re, sys
s = sys.stdin.read()
home = os.environ.get("HOME", "")
try: user = pwd.getpwuid(os.getuid()).pw_name
except KeyError: user = os.environ.get("USER", "")
if home and home != "/": s = s.replace(home, "<HOME>")
if user: s = re.sub(r"(?<![A-Za-z0-9_.-])" + re.escape(user) + r"(?![A-Za-z0-9_.-])", "<USER>", s)
s = re.sub(r"(?i)\b(password|passwd|token|secret|authorization|cookie|api[_-]?key)\b([=: ]+)[^\s,;]+", r"\1\2<REDACTED>", s)
s = re.sub(r"\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b", "<IP-REDACTED>", s)
s = re.sub(r"\b(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}\b", "<MAC-REDACTED>", s)
sys.stdout.write(s)
'
}

section() { printf '\n\n========== %s ==========\n' "$*" >>"$report"; }
note() { printf '%s\n' "$*" >>"$report"; }
run() {
    local title=$1 rc=0
    shift
    section "$title"
    if ! have "$1"; then
        note "[unavailable: $1]"
        return 0
    fi
    if have timeout; then
        timeout 20s "$@" 2>&1 | redact >>"$report" || rc=${PIPESTATUS[0]}
    else
        "$@" 2>&1 | redact >>"$report" || rc=${PIPESTATUS[0]}
    fi
    (( rc == 0 )) || note "[command exit: $rc]"
    return 0
}
unit_state() {
    local unit=$1
    section "SYSTEMD UNIT: $unit"
    if ! have systemctl; then note '[systemctl unavailable]'; return; fi
    systemctl show "$unit" --no-pager \
        -p LoadState -p ActiveState -p SubState -p Result \
        -p ExecMainCode -p ExecMainStatus -p NRestarts \
        -p FragmentPath -p DropInPaths 2>&1 | redact >>"$report" || true
}

{
    printf 'K41 DESKTOP STARTUP DIAGNOSTIC\n'
    printf 'Captured UTC: %s\n' "$stamp"
    printf 'Scope: tty fallback, start-hyprland/Hyprland startup, user session and Caelestia handoff.\n'
    printf 'Mode: read-only; no service, package, boot, authentication, permission or configuration changes.\n'
    printf 'Host: <REDACTED>\n'
    printf 'Kernel: %s\n' "$(uname -sr)"
    printf 'User UID/GID: %s/%s\n' "$EUID" "$(id -g)"
    printf 'Current TTY: %s\n' "$(tty 2>/dev/null || printf unknown)"
    printf 'Shell: %s\n' "${SHELL:-unknown}"
    printf 'Repository HEAD: %s\n' "$(git -C "$repo_root" rev-parse HEAD)"
    printf 'Repository status: %s\n' "$(git -C "$repo_root" status --short | tr '\n' ' ' | redact)"
    for name in XDG_SESSION_ID XDG_SESSION_TYPE XDG_CURRENT_DESKTOP WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS; do
        if [[ -n ${!name:-} ]]; then printf '%s: present\n' "$name"; else printf '%s: absent\n' "$name"; fi
    done
} >>"$report"

section 'LOGIN AND TTY INVENTORY'
run 'WHO' who -a
run 'LOGINCTL SESSIONS' loginctl list-sessions --no-legend
run 'LOGINCTL CURRENT USER' loginctl show-user "$EUID" -p State -p Sessions -p Display -p RuntimePath -p Linger
run 'FOREGROUND CONSOLE' fgconsole
run 'TTY GETTY UNITS' systemctl status getty@tty1.service getty@tty2.service --no-pager
run 'FAILED SYSTEM UNITS' systemctl --failed --no-pager
run 'DEFAULT AND ACTIVE TARGETS' systemctl get-default
run 'ACTIVE TARGET CHECKS' systemctl is-active multi-user.target graphical.target systemd-user-sessions.service

unit_state getty@tty1.service
unit_state getty@tty2.service
unit_state plymouth-quit.service
unit_state k41-plymouth-release.service
unit_state "user@$EUID.service"

section 'USER SYSTEMD SESSION'
run 'USER FAILED UNITS' systemctl --user --failed --no-pager
run 'USER ACTIVE SERVICES' systemctl --user list-units --type=service --all --no-pager
for unit in default.target graphical-session.target hyprland-session.target caelestia.service quickshell.service; do
    section "USER UNIT STATE: $unit"
    systemctl --user show "$unit" --no-pager -p LoadState -p ActiveState -p SubState -p Result -p ExecMainCode -p ExecMainStatus -p NRestarts 2>&1 | redact >>"$report" || true
done

section 'PROCESS INVENTORY (names only; no arguments or environment)'
ps -eo pid,ppid,tty,stat,comm --sort=pid 2>/dev/null |
    awk 'NR==1 || tolower($0) ~ /hyprland|start-hyprland|quickshell|(^|[[:space:]])qs([[:space:]]|$)|caelestia|hyprlock|agetty|bash|systemd/' |
    redact >>"$report" || true

section 'EXECUTABLE AND PACKAGE VERSIONS'
for bin in start-hyprland Hyprland hyprland hyprctl caelestia qs quickshell hyprlock; do
    if have "$bin"; then
        printf '%s: %s\n' "$bin" "$(command -v "$bin")" >>"$report"
        case "$bin" in
            start-hyprland|Hyprland|hyprland|hyprctl|caelestia|qs|quickshell|hyprlock)
                if have timeout; then timeout 5s "$bin" --version 2>&1 | redact >>"$report" || true; fi
                ;;
        esac
    else
        printf '%s: NOT FOUND in PATH\n' "$bin" >>"$report"
    fi
done
run 'INSTALLED RELEVANT PACKAGES' pacman -Q hyprland hyprland-git quickshell quickshell-git caelestia-shell caelestia-cli xorg-xwayland mesa qt6-wayland

section 'K41 STARTUP AND LOCKSCREEN FILE METADATA'
for path in \
    "$HOME/.bash_profile" \
    "$HOME/.local/bin/k41-start-hyprland" \
    "$HOME/.local/bin/k41-lock-caelestia-after-start" \
    "$HOME/.local/state/k41/hyprland-startup.log" \
    "$HOME/.config/hypr/hyprland.lua" \
    "$HOME/.config/caelestia/shell.json" \
    "$HOME/.config/quickshell/caelestia/shell.qml" \
    "$HOME/.config/quickshell/caelestia/modules/lock/Lock.qml" \
    "$HOME/.config/quickshell/caelestia/modules/lock/LockSurface.qml" \
    "$HOME/.config/quickshell/caelestia/modules/lock/Content.qml" \
    "$HOME/.config/quickshell/caelestia/modules/lock/Center.qml"; do
    if [[ -L $path ]]; then stat -c 'SYMLINK %A uid=%u gid=%g %n -> %N' "$path" 2>&1 | redact >>"$report" || true
    elif [[ -e $path ]]; then stat -c 'FILE %A uid=%u gid=%g size=%s %n' "$path" 2>&1 | redact >>"$report" || true
    else printf 'MISSING %s\n' "$path" | redact >>"$report"; fi
done

section 'BASH PROFILE K41 AUTOLOGIN BLOCK'
if [[ -r $HOME/.bash_profile ]]; then
    awk '/# K41 HYPRLAND AUTOLOGIN START/{show=1} show{print} /# K41 HYPRLAND AUTOLOGIN END/{show=0}' "$HOME/.bash_profile" | redact >>"$report" || true
else note '[~/.bash_profile unavailable]'; fi

section 'HYPRLAND CONFIG STARTUP INTEGRATION'
for config_file in "$HOME/.config/hypr/hyprland.conf" "$HOME/.config/hypr/hyprland.lua"; do
    [[ -r $config_file && ! -L $config_file ]] || continue
    printf '\\n-- %s --\\n' "${config_file#"$HOME"/}" | redact >>"$report"
    grep -nEi -C 4 'exec-once|exec[[:space:]]*=|caelestia|quickshell|(^|[[:space:]])qs([[:space:]]|$)|k41-boot-splash|hyprland\\.start|lock-caelestia' "$config_file" |
        redact >>"$report" || note "[no matching startup directives in ${config_file#"$HOME"/}]"
done

section 'HYPRLAND LUA STARTUP / LOCK INTEGRATION LINES'
if [[ -r $HOME/.config/hypr/hyprland.lua ]]; then
    grep -nEi -C 3 'K41|hyprland\.start|start-hyprland|caelestia|hyprlock|lock|exec_cmd|exec-once' "$HOME/.config/hypr/hyprland.lua" |
        redact >>"$report" || note '[no matching startup/lock lines]'
else note '[~/.config/hypr/hyprland.lua unavailable]'; fi

section 'INSTALLED LOCK HELPER CONTENT AND SOURCE COMPARISON'
installed_helper="$HOME/.local/bin/k41-lock-caelestia-after-start"
source_helper="$repo_root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-lock-caelestia-after-start.sh"
if [[ -f $installed_helper && ! -L $installed_helper ]]; then
    printf 'Installed helper: ' | redact >>"$report"
    stat -c 'mode=%A uid=%u gid=%g size=%s' "$installed_helper" 2>&1 | redact >>"$report" || true
    if have sha256sum; then sha256sum "$installed_helper" "$source_helper" 2>&1 | redact >>"$report" || true; fi
    if [[ -f $source_helper ]] && cmp -s "$installed_helper" "$source_helper"; then
        note 'Installed helper byte comparison: MATCHES repository source.'
    else
        note 'Installed helper byte comparison: DIFFERS from repository source or source is missing.'
    fi
    if bash -n "$installed_helper" 2>&1; then note 'Installed helper Bash syntax: PASS'; else note 'Installed helper Bash syntax: FAIL'; fi
    section 'INSTALLED LOCK HELPER SOURCE (redacted)'
    sed -n '1,320p' "$installed_helper" | redact >>"$report" || true
else
    note 'Installed helper is missing, unreadable, or a symlink.'
fi

section 'PREVIOUS INSTALLED LOCK HELPER BACKUPS'
helper_backup_root="$HOME/.local/state/k41/lockscreen/helper-backups"
if [[ -d $helper_backup_root && ! -L $helper_backup_root ]]; then
    while IFS= read -r backup_name; do
        [[ -n $backup_name ]] || continue
        backup_file="$helper_backup_root/$backup_name"
        [[ -f $backup_file && ! -L $backup_file ]] || continue
        printf '\n-- BACKUP %s --\n' "${backup_file#"$HOME"/}" | redact >>"$report"
        stat -c 'mode=%A uid=%u gid=%g size=%s' "$backup_file" 2>&1 | redact >>"$report" || true
        if have sha256sum; then sha256sum "$backup_file" 2>&1 | redact >>"$report" || true; fi
        sed -n '1,320p' "$backup_file" | redact >>"$report" || true
    done < <(find "$helper_backup_root" -maxdepth 1 -type f -name 'k41-lock-caelestia-after-start-*.sh' -printf '%T@ %f\n' 2>/dev/null | sort -nr | head -n 3 | cut -d' ' -f2-)
else
    note 'No previous installed lock helper backups found.'
fi

section 'INSTALLED K41 LOCK VISUAL SOURCE COMPARISON'
source_module="$repo_root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/modules/lockscreen"
runtime_module="$HOME/.config/quickshell/caelestia/modules/lock"
for relative in LockSurface.qml Content.qml Center.qml center/PasswordInput.qml; do
    source_file="$source_module/$relative"
    runtime_file="$runtime_module/$relative"
    if [[ -f $source_file && ! -L $source_file && -f $runtime_file && ! -L $runtime_file ]]; then
        if cmp -s "$source_file" "$runtime_file"; then
            printf 'MATCH %s\n' "$relative" >>"$report"
        else
            printf 'DIFFERS %s\n' "$relative" >>"$report"
        fi
        if have sha256sum; then sha256sum "$source_file" "$runtime_file" 2>&1 | redact >>"$report" || true; fi
    else
        printf 'MISSING source/runtime file: %s\n' "$relative" | redact >>"$report"
    fi
done

section 'HYPRLAND CONFIG FILE INVENTORY'
for base in "$HOME/.config/hypr" "$HOME/.config/quickshell/caelestia" "$HOME/.config/caelestia"; do
    [[ -d $base && ! -L $base ]] || continue
    printf '\n[%s]\n' "$base" | redact >>"$report"
    find "$base" -maxdepth 4 -type f \( -name '*.conf' -o -name '*.lua' -o -name '*.qml' -o -name '*.json' -o -name '*.jsonc' \) -printf '%P (%s bytes)\n' 2>/dev/null |
        sort | head -n 200 | redact >>"$report" || true
done

section 'BOOT HANDOFF UNIT CONFIGURATION (selected directives only)'
for unit_file in \
    /etc/systemd/system/plymouth-quit.service.d/k41-lock-handoff.conf \
    /etc/systemd/system/k41-plymouth-release.service \
    /etc/systemd/system/k41-plymouth-release.service.d/*.conf \
    /etc/systemd/system/getty@tty1.service.d/k41-autologin.conf; do
    [[ -f $unit_file && ! -L $unit_file ]] || continue
    printf '\\n-- %s --\\n' "$unit_file" | redact >>"$report"
    grep -nE '^[[:space:]]*(Description|Type|User|Group|ExecStart|ExecStartPre|ExecStartPost|ExecStop|After|Before|Wants|Requires|WantedBy|PartOf|TimeoutStartSec|Restart|RestartSec)[[:space:]]*=' "$unit_file" |
        redact >>"$report" || true
done

section 'HYPRLAND STARTUP LOG'
startup_log="$HOME/.local/state/k41/hyprland-startup.log"
if [[ -f $startup_log && ! -L $startup_log ]]; then
    tail -n 500 -- "$startup_log" | redact >>"$report" || true
else note '[K41 Hyprland startup log missing]'; fi

section 'RECENT USER LOG FILES'
for base in "$HOME/.local/state/k41" "$HOME/.local/state/caelestia" "$HOME/.local/state/quickshell" "$HOME/.local/share/hyprland" "$HOME/.local/share/caelestia" "$HOME/.cache/hyprland" "$HOME/.cache/caelestia" "$HOME/.cache/qs" "$HOME/.cache/quickshell"; do
    [[ -d $base && ! -L $base ]] || continue
    while IFS= read -r -d '' file; do
        [[ -f $file && ! -L $file ]] || continue
        size=$(stat -c %s "$file" 2>/dev/null || printf 0)
        (( size <= 2097152 )) || continue
        case "$file" in
            *.log|*.txt)
                section "LOG FILE: ${file#"$HOME"/}"
                tail -n 300 -- "$file" | redact >>"$report" || true
                ;;
        esac
    done < <(find "$base" -maxdepth 4 -type f \( -name '*.log' -o -name '*.txt' \) -printf '%p\0' 2>/dev/null)
done

section 'HYPRLAND IPC (only succeeds if compositor is running)'
run 'HYPRLAND INSTANCES' hyprctl instances
run 'HYPRLAND VERSION VIA IPC' hyprctl version
run 'HYPRLAND MONITORS' hyprctl monitors

run 'START-HYPRLAND COREDUMP SUMMARY' coredumpctl info start-hyprland

section 'GRAPHICS DEVICE INVENTORY'
run 'DRM DEVICE NODES' ls -l /dev/dri
if have lspci; then
    lspci -nnk 2>/dev/null | grep -iE -A4 'VGA compatible|3D controller|Display controller' | redact >>"$report" || true
fi

section 'CURRENT BOOT JOURNAL — STARTUP / SESSION EVENTS'
if have journalctl; then
    journalctl -b --no-pager -o short-monotonic 2>&1 |
        grep -Ei 'hyprland|start-hyprland|k41|plymouth|caelestia|quickshell|(^|[[:space:]])qs([[:space:][:punct:]]|$)|getty@tty[12]|tty[12]|systemd-logind|pam_|session (opened|closed)|failed to start|dependency failed|failed with result|segfault|core dumped|drm|gpu|i915|wayland' |
        tail -n 600 | redact >>"$report" || true
else note '[journalctl unavailable]'; fi

section 'PREVIOUS BOOT JOURNAL — STARTUP / SESSION EVENTS'
if have journalctl; then
    journalctl -b -1 --no-pager -o short-monotonic 2>&1 |
        grep -Ei 'hyprland|start-hyprland|k41|plymouth|caelestia|quickshell|(^|[[:space:]])qs([[:space:][:punct:]]|$)|getty@tty[12]|tty[12]|systemd-logind|pam_|session (opened|closed)|failed to start|dependency failed|failed with result|segfault|core dumped|drm|gpu|i915|wayland' |
        tail -n 600 | redact >>"$report" || true
else note '[journalctl unavailable]'; fi

section 'CURRENT USER JOURNAL — STARTUP / SESSION EVENTS'
if have journalctl; then
    journalctl --user -b --no-pager -o short-monotonic 2>&1 |
        grep -Ei 'hyprland|start-hyprland|k41|caelestia|quickshell|(^|[[:space:]])qs([[:space:][:punct:]]|$)|failed|error|segfault|core dumped|wayland' |
        tail -n 500 | redact >>"$report" || true
else note '[journalctl unavailable]'; fi


# Explicit lock lifecycle evidence. All commands below are observational and bounded.
section 'LOCK LIFECYCLE: LOGIN SESSION STATE'
if have loginctl; then
    while read -r session_id _; do
        [[ -n ${session_id:-} ]] || continue
        section "LOGIN SESSION DETAILS: $session_id"
        loginctl show-session "$session_id" --no-pager \
            -p Id -p Name -p User -p State -p Active -p Remote -p Type \
            -p Class -p Seat -p TTY -p Display -p Leader -p Scope -p Service \
            2>&1 | redact >>"$report" || true
    done < <(loginctl list-sessions --no-legend 2>/dev/null)
else
    note '[loginctl unavailable; per-session lifecycle state not collected]'
fi

section 'LOCK LIFECYCLE: HELPER INVOCATIONS AND PHASE TRANSITIONS'
helper_log_root="$HOME/.local/state/k41/lockscreen"
if [[ -d $helper_log_root && ! -L $helper_log_root ]]; then
    mapfile -t helper_logs < <(
        find "$helper_log_root" -maxdepth 1 -type f -name 'startup-*.log' \
            -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 8 | cut -d' ' -f2-
    )
    if (("${#helper_logs[@]}" > 0)); then
        for helper_log in "${helper_logs[@]}"; do
            [[ -f $helper_log && ! -L $helper_log ]] || continue
            printf '\n-- %s --\n' "${helper_log#"$HOME"/}" | redact >>"$report"
            stat -c 'size=%s modified=%y mode=%A' "$helper_log" 2>&1 | redact >>"$report" || true
            if have sha256sum; then sha256sum "$helper_log" 2>&1 | redact >>"$report" || true; fi
            # Helper logs are bounded by the helper's own timeout; retain the full
            # latest log so IPC errors and the exact terminal phase are not truncated.
            tail -n 400 -- "$helper_log" | redact >>"$report" || true
        done
    else
        note '[No startup-*.log helper invocation records found]'
    fi
else
    note '[K41 lock helper log directory missing or unsafe]'
fi

section 'LOCK LIFECYCLE: CURRENT CAELESTIA IPC STATE (READ-ONLY)'
if have caelestia; then
    run 'CAELESTIA EXPORTED SHELL IPC TARGETS' caelestia shell -s
    run 'CAELESTIA LOCK isLocked QUERY' caelestia shell lock isLocked
else
    note '[caelestia CLI unavailable; IPC state cannot be queried]'
fi
if have qs; then
    run 'QUICKSHELL VERSION' qs --version
else
    note '[qs executable unavailable]'
fi

section 'LOCK LIFECYCLE: LOCKER AND COMPOSITOR PROCESS STATE'
if have ps; then
    ps -eo etimes,stat,comm --sort=comm 2>/dev/null |
        awk 'NR==1 || tolower($0) ~ /hyprland|quickshell|(^|[[:space:]])qs([[:space:]]|$)|caelestia|hyprlock|swaylock/' |
        redact >>"$report" || true
fi
run 'HYPRLAND IPC INSTANCE INVENTORY' hyprctl instances
run 'HYPRLAND IPC MONITOR STATE' hyprctl -j monitors
if have hyprctl; then
    section 'HYPRLAND LOCK-RELATED BINDINGS'
    hyprctl -j binds 2>&1 |
        grep -iE -C 2 'lock|hyprlock|swaylock|SUPER[[:space:]]*\+[[:space:]]*M' |
        redact >>"$report" || note '[No matching lock/recovery binding or IPC unavailable]'
fi

section 'LOCK LIFECYCLE: AUTHENTICATION AND UNLOCK JOURNAL EVENTS'
if have journalctl; then
    journalctl -b --no-pager -o short-iso-precise 2>&1 |
        grep -Ei 'hyprlock|caelestia.*lock|lock.*caelestia|pam_.*(auth|account|session)|authentication|authenticated|authenticat|unlock|unlocked|session (opened|closed)|session scope|stopped target.*(hyprland|graphical)|reached target.*(hyprland|graphical)' |
        tail -n 500 | redact >>"$report" || true
else
    note '[journalctl unavailable; authentication/unlock lifecycle cannot be reconstructed]'
fi

section 'LOCK LIFECYCLE: DEPLOYMENT AND VISUAL SOURCE PROVENANCE'
deployment_log_root="$HOME/.local/state/k41/lockscreen/deployment-logs"
if [[ -d $deployment_log_root && ! -L $deployment_log_root ]]; then
    while IFS= read -r -d '' deployment_log; do
        [[ -f $deployment_log && ! -L $deployment_log ]] || continue
        printf '\n-- %s --\n' "${deployment_log#"$HOME"/}" | redact >>"$report"
        tail -n 250 -- "$deployment_log" | redact >>"$report" || true
    done < <(find "$deployment_log_root" -maxdepth 3 -type f \( -name 'latest.log' -o -name 'deploy-*.log' \) -printf '%T@ %p\0' 2>/dev/null |
        sort -z -nr | head -z -n 5 | cut -z -d' ' -f2-)
else
    note '[No local lockscreen visual deployment log directory found]'
fi

section 'DIAGNOSTIC LIMITATIONS'
note '- Collector tidak menjalankan start-hyprland, Hyprland, Caelestia reload, atau lock command.'
note '- Collector tidak mengubah service, package, bootloader, initramfs, TPM/LUKS, PAM, permission, ownership, maupun konfigurasi.'
note '- Journal mungkin tidak dapat dibaca lengkap oleh user biasa; permission-denied dicatat sebagai keterbatasan.'
note '- Report menyimpan potongan log yang relevan dan metadata konfigurasi. Redaksi otomatis tidak menjamin seluruh data pribadi terhapus.'
note '- Salinan report tersanitasi dipublikasikan otomatis; redaksi tidak menjamin seluruh data privat terhapus, jadi tinjau report di GitHub dan hapus data sensitif bila ditemukan.'
note '- TTY2 fallback dapat merupakan konsekuensi eksplisit dari k41-plymouth-quit-after-lock.sh setelah timeout 75 detik; bukti journal menentukan apakah mekanisme itu yang berjalan.'
note "Report: ${report#"$repo_root"/}"

cat >"$run_dir/README.txt" <<EOF
K41 desktop startup diagnostic
===============================
Run this script as the regular desktop user from tty2 or a normal shell:

  bash stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-audit-desktop-startup.sh

Report: report.txt

The collector does not modify host system state and does not attempt to launch or repair Hyprland. It writes a private local report and publishes a sanitized copy.
The script publishes a sanitized copy of this run directory to GitHub main using existing Git credentials. The local report remains private (0600); if publication fails, the report stays local and the script exits non-zero. Review the published report for any residual private information.
EOF
chmod 0600 "$run_dir/README.txt"

publish_report() {
    local remote_url publish_dir relative_dir publish_target
    remote_url="$(git -C "$repo_root" remote get-url origin 2>/dev/null)" ||
        { printf 'ERROR: tidak dapat membaca Git origin; report tetap lokal.\n' >&2; return 1; }
    case "$remote_url" in
        https://github.com/K41-Origin/Lenovo-ThinkPad-X280-K41|https://github.com/K41-Origin/Lenovo-ThinkPad-X280-K41.git|git@github.com:K41-Origin/Lenovo-ThinkPad-X280-K41.git|ssh://git@github.com/K41-Origin/Lenovo-ThinkPad-X280-K41.git) ;;
        *) printf 'ERROR: Git origin bukan repository K41 yang diizinkan; report tetap lokal.\n' >&2; return 1 ;;
    esac
    git -C "$repo_root" fetch --no-tags origin main ||
        { printf 'ERROR: fetch origin/main gagal; report tetap lokal.\n' >&2; return 1; }
    publish_dir="$(mktemp -d "${TMPDIR:-/tmp}/k41-startup-audit-publish.XXXXXX")" || return 1
    rmdir -- "$publish_dir" || { rm -rf -- "$publish_dir"; return 1; }
    if ! git -C "$repo_root" worktree add --detach "$publish_dir" FETCH_HEAD; then
        rm -rf -- "$publish_dir"
        printf 'ERROR: isolated worktree gagal dibuat; report tetap lokal.\n' >&2
        return 1
    fi
    relative_dir="${run_dir#"$repo_root"/}"
    publish_target="$publish_dir/$relative_dir"
    mkdir -p -- "$publish_target"
    cp -- "$report" "$publish_target/report.txt"
    cp -- "$run_dir/README.txt" "$publish_target/README.txt"
    chmod 0644 "$publish_target/report.txt" "$publish_target/README.txt"
    chmod 0755 "$publish_target"
    git -C "$publish_dir" config user.name "K41 Startup Audit"
    git -C "$publish_dir" config user.email "k41-startup-audit@users.noreply.github.com"
    if ! git -C "$publish_dir" add -- "$relative_dir" ||
       ! git -C "$publish_dir" commit -m "Add X280 desktop startup diagnostic"; then
        git -C "$repo_root" worktree remove --force "$publish_dir" >/dev/null 2>&1 || true
        printf 'ERROR: commit report gagal; report tetap lokal.\n' >&2
        return 1
    fi
    if ! git -C "$publish_dir" push origin HEAD:main; then
        printf 'INFO: push tertahan update main; mencoba rebase satu kali.\n'
        if ! git -C "$publish_dir" fetch --no-tags origin main ||
           ! git -C "$publish_dir" rebase FETCH_HEAD ||
           ! git -C "$publish_dir" push origin HEAD:main; then
            git -C "$repo_root" worktree remove --force "$publish_dir" >/dev/null 2>&1 || true
            printf 'ERROR: publikasi report gagal; report tetap lokal: %s\n' "$report" >&2
            return 1
        fi
    fi
    git -C "$repo_root" worktree remove --force "$publish_dir" >/dev/null 2>&1 || true
    printf 'INFO: report tersanitasi dipublikasikan ke GitHub main: %s\n' "$relative_dir"
}

printf 'Audit report created: %s\n' "$report"
printf 'README created: %s\n' "$run_dir/README.txt"
if publish_report; then
    printf 'Report tersanitasi berhasil dipublikasikan menggunakan Git credentials yang sudah tersedia.\n'
else
    printf 'WARNING: report tetap tersedia lokal; publikasi otomatis gagal.\n' >&2
    exit 1
fi
printf 'No system state was changed.\n'