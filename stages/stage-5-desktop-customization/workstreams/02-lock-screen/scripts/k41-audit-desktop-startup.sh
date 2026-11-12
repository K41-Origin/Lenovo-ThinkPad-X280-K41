#!/usr/bin/env bash
# Read-only X280 desktop startup diagnostic for tty fallback / stuck Hyprland launch.
# Can be run from tty2 or a normal user shell; does not require a Wayland session.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
have() { command -v "$1" >/dev/null 2>&1; }

(( EUID != 0 )) || die 'Jalankan sebagai user desktop biasa, tanpa sudo.'
[[ -n ${HOME:-} && $HOME == /* && -d $HOME ]] || die 'HOME tidak valid.'
for cmd in git stat date mkdir chmod uname id who tty ps awk grep sed tail find python3 cp rm mktemp rmdir tr timeout head; do
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
# Logs and user configuration may contain non-UTF-8 bytes. Decode
# lossily so one malformed byte cannot abort redaction or corrupt the report.
s = sys.stdin.buffer.read().decode("utf-8", errors="replace")
home = os.environ.get("HOME", "")
try: user = pwd.getpwuid(os.getuid()).pw_name
except KeyError: user = os.environ.get("USER", "")
if home and home != "/": s = s.replace(home, "<HOME>")
if user: s = re.sub(r"(?<![A-Za-z0-9_.-])" + re.escape(user) + r"(?![A-Za-z0-9_.-])", "<USER>", s)
s = re.sub(r"(?i)\b(password|passwd|token|secret|authorization|cookie|api[_-]?key)\b([=: ]+)[^\s,;]+", r"\1\2<REDACTED>", s)
s = re.sub(r"(?i)(\bSSID\s*[:=]\s*)(?:\x27[^\x27]*\x27|\x22[^\x22]*\x22|[^\s,;)]+)", r"\1<SSID-REDACTED>", s)
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
# start-hyprland is a session launcher, not a version-reporting utility.
# Executing it with an assumed --version flag can start a real Hyprland session.
# Record its path/package/hash only; never execute it from this read-only audit.
for bin in Hyprland hyprland hyprctl caelestia qs quickshell hyprlock; do
    if have "$bin"; then
        printf '%s: %s\n' "$bin" "$(command -v "$bin")" >>"$report"
        case "$bin" in
            Hyprland|hyprland|hyprctl|caelestia|qs|quickshell|hyprlock)
                if have timeout; then timeout 5s "$bin" --version 2>&1 | redact >>"$report" || true; fi
                ;;
        esac
    else
        printf '%s: NOT FOUND in PATH\n' "$bin" >>"$report"
    fi
done
run 'INSTALLED RELEVANT PACKAGES' pacman -Q hyprland hyprland-git quickshell quickshell-git caelestia-shell caelestia-cli xorg-xwayland mesa qt6-wayland

section 'START-HYPRLAND LAUNCHER — NON-EXECUTING INSPECTION'
launcher_binary="$(command -v start-hyprland 2>/dev/null || true)"
if [[ -n $launcher_binary && -x $launcher_binary ]]; then
    printf 'Launcher binary: %s\n' "$launcher_binary" | redact >>"$report"
    stat -Lc 'type=%F mode=%A uid=%u gid=%g size=%s modified=%y' -- "$launcher_binary" 2>&1 | redact >>"$report" || true
    if have sha256sum; then sha256sum "$launcher_binary" 2>&1 | redact >>"$report" || true; fi
    run 'START-HYPRLAND PACKAGE OWNER' pacman -Qo "$launcher_binary"
    note 'Launcher execution: NOT PERFORMED; start-hyprland is a session launcher and is never invoked by this audit.'
else
    note 'start-hyprland: NOT FOUND or not executable; launcher was not invoked.'
fi

launcher_source="$repo_root/stages/stage-5-desktop-customization/workstreams/01-boot-experience/scripts/k41-start-hyprland.sh"
launcher_installed="$HOME/.local/bin/k41-start-hyprland"
for pair in "REPOSITORY:$launcher_source" "INSTALLED:$launcher_installed"; do
    label="${pair%%:*}"
    file="${pair#*:}"
    section "K41 LAUNCHER SOURCE: $label"
    if [[ -f $file && ! -L $file && -r $file ]]; then
        stat -c 'size=%s mode=%A uid=%u gid=%g modified=%y' "$file" 2>&1 | redact >>"$report" || true
        if have sha256sum; then sha256sum "$file" 2>&1 | redact >>"$report" || true; fi
        sed -n '1,240p' "$file" | redact >>"$report" || true
    else
        note '[missing, unreadable, symlinked, or not a regular file]'
    fi
done
if [[ -f $launcher_source && ! -L $launcher_source && -f $launcher_installed && ! -L $launcher_installed ]]; then
    if cmp -s "$launcher_source" "$launcher_installed"; then
        note 'Installed K41 launcher byte comparison: MATCHES repository source.'
    else
        note 'Installed K41 launcher byte comparison: DIFFERS from repository source.'
    fi
else
    note 'Installed K41 launcher byte comparison: NOT POSSIBLE (source or installed file missing/unsafe).'
fi

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
    printf '\n-- %s --\n' "${config_file#"$HOME"/}" | redact >>"$report"
    grep -nEi -C 4 'exec-once|exec[[:space:]]*=|caelestia|quickshell|(^|[[:space:]])qs([[:space:]]|$)|k41-boot-splash|hyprland\\.start|lock-caelestia' "$config_file" |
        redact >>"$report" || note "[no matching startup directives in ${config_file#"$HOME"/}]"
done

section 'HYPRLAND LUA STARTUP / LOCK INTEGRATION LINES'
if [[ -r $HOME/.config/hypr/hyprland.lua ]]; then
    grep -nEi -C 3 'K41|hyprland\.start|start-hyprland|caelestia|hyprlock|lock|exec_cmd|exec-once' "$HOME/.config/hypr/hyprland.lua" |
        redact >>"$report" || note '[no matching startup/lock lines]'
else note '[~/.config/hypr/hyprland.lua unavailable]'; fi

section 'IMPLEMENTATION SOURCE REVISION AND INSTALLED CONFIG COMPARISON'
implementation_files=(
    "$repo_root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-update-lockscreen-startup-helper.sh"
    "$repo_root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-lock-caelestia-after-start.sh"
    "$repo_root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/config/hyprlock-fallback.conf"
    "$repo_root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-deploy-lockscreen-visual.sh"
    "$repo_root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-audit-lockscreen-visual.sh"
)
for implementation_file in "${implementation_files[@]}"; do
    relative="${implementation_file#"$repo_root"/}"
    if [[ -f $implementation_file && ! -L $implementation_file ]]; then
        printf 'REPOSITORY_SOURCE %s\n' "$relative" >>"$report"
        stat -c 'size=%s mode=%A modified=%y' "$implementation_file" 2>&1 | redact >>"$report" || true
        if have sha256sum; then sha256sum "$implementation_file" 2>&1 | redact >>"$report" || true; fi
    else
        printf 'REPOSITORY_SOURCE_MISSING %s\n' "$relative" >>"$report"
    fi
done
fallback_source="$repo_root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/config/hyprlock-fallback.conf"
fallback_installed="$HOME/.config/k41/hyprlock-fallback.conf"
if [[ -f $fallback_source && ! -L $fallback_source && -f $fallback_installed && ! -L $fallback_installed ]]; then
    if cmp -s "$fallback_source" "$fallback_installed"; then
        note 'Installed Hyprlock fallback config byte comparison: MATCHES repository source.'
    else
        note 'Installed Hyprlock fallback config byte comparison: DIFFERS from repository source.'
    fi
    if have sha256sum; then sha256sum "$fallback_source" "$fallback_installed" 2>&1 | redact >>"$report" || true; fi
else
    note 'Installed Hyprlock fallback config byte comparison: NOT POSSIBLE (source/runtime file missing or unsafe).'
fi
if have hyprctl; then
    run 'IMPLEMENTATION PROBE: HYPRLAND INSTANCE METADATA' hyprctl instances
fi

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

section 'LOCKSCREEN QML SOURCE: REPOSITORY AND INSTALLED RUNTIME'
# Capture the exact implementation inputs needed for a follow-up installer change.
# Only known lockscreen QML files are included; arbitrary config files are not dumped.
source_module="$repo_root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/modules/lockscreen"
runtime_module="$HOME/.config/quickshell/caelestia/modules/lock"
for relative in Lock.qml LockSurface.qml Content.qml Center.qml center/PasswordInput.qml; do
    for pair in "REPOSITORY:$source_module" "INSTALLED_RUNTIME:$runtime_module"; do
        label="${pair%%:*}"
        base="${pair#*:}"
        file="$base/$relative"
        section "LOCK QML $label: $relative"
        if [[ -f $file && ! -L $file && -r $file ]]; then
            printf 'path=%s\n' "${file#"$HOME"/}" | redact >>"$report"
            stat -c 'size=%s mode=%A uid=%u gid=%g modified=%y' "$file" 2>&1 | redact >>"$report" || true
            if have sha256sum; then sha256sum "$file" 2>&1 | redact >>"$report" || true; fi
            # Bound each source file to 600 lines / 48 KiB to keep reports reviewable.
            head -c 49152 "$file" | head -n 600 | redact >>"$report" || true
        else
            note '[missing, unreadable, symlinked, or not a regular file]'
        fi
    done
done

section 'LOCKSCREEN DEPLOYMENT STATE AND FILE HASHES'
for file in \
    "$HOME/.config/caelestia/shell.json" \
    "$HOME/.config/quickshell/caelestia/shell.qml" \
    "$HOME/.config/k41/hyprlock-fallback.conf" \
    "$HOME/.cache/k41/boot-lock-ready"; do
    if [[ -f $file && ! -L $file ]]; then
        printf '%s\n' "${file#"$HOME"/}" | redact >>"$report"
        stat -c 'size=%s mode=%A uid=%u gid=%g modified=%y' "$file" 2>&1 | redact >>"$report" || true
        if have sha256sum; then sha256sum "$file" 2>&1 | redact >>"$report" || true; fi
    else
        printf 'MISSING_OR_UNSAFE %s\n' "${file#"$HOME"/}" | redact >>"$report"
    fi
done

section 'IMPLEMENTATION INPUTS: ACTIVE SESSION AND PROCESS CONTEXT'
printf 'Audit context: tty=%s; XDG_SESSION_TYPE=%s; WAYLAND_DISPLAY=%s; HYPRLAND_INSTANCE_SIGNATURE=%s; XDG_RUNTIME_DIR=%s\n' \
    "$(tty 2>/dev/null || printf unknown)" "${XDG_SESSION_TYPE:-absent}" "${WAYLAND_DISPLAY:-absent}" \
    "${HYPRLAND_INSTANCE_SIGNATURE:+present}" "${XDG_RUNTIME_DIR:-absent}" | redact >>"$report"
if have loginctl; then
    loginctl list-sessions --no-legend 2>&1 | redact >>"$report" || true
fi
if have ps; then
    ps -eo pid,ppid,etimes,stat,comm,cgroup --sort=pid 2>/dev/null |
        awk 'NR==1 || tolower($0) ~ /hyprland|quickshell|caelestia|hyprlock|systemd --user/' |
        redact >>"$report" || true
fi
# Read-only probes deliberately use the same Caelestia CLI contract as the
# installed lock helper. Never send the mutating "lock" IPC request here.
if have caelestia; then
    run 'IMPLEMENTATION PROBE: CAELESTIA SHELL EXPORTS' caelestia shell -s
    run 'IMPLEMENTATION PROBE: CAELESTIA LOCK STATE' caelestia shell lock isLocked
else
    note '[caelestia executable unavailable; helper IPC contract cannot be probed]'
fi
if have systemctl; then
    section 'IMPLEMENTATION PROBE: USER SESSION ENVIRONMENT VARIABLE NAMES'
    systemctl --user show-environment 2>&1 | cut -d= -f1 | sort | redact >>"$report" || true
    for unit in caelestia.service quickshell.service hyprland-session.target graphical-session.target; do
        run "IMPLEMENTATION PROBE: USER UNIT CAT $unit" systemctl --user cat "$unit"
    done
fi

section 'IMPLEMENTATION INPUTS: ALLOWLISTED CONFIG CONTENT'
# Capture only files directly relevant to the lock lifecycle. Do not dump
# arbitrary user configuration, credentials, or the complete environment.
for file in \
    "$HOME/.config/caelestia/shell.json" \
    "$HOME/.config/quickshell/caelestia/shell.qml" \
    "$HOME/.config/hypr/hyprland.conf" \
    "$HOME/.config/hypr/hyprland.lua" \
    "$HOME/.config/k41/hyprlock-fallback.conf" \
    "$HOME/.local/bin/k41-lock-caelestia-after-start"; do
    section "IMPLEMENTATION CONFIG CONTENT: ${file#"$HOME"/}"
    if [[ -f $file && ! -L $file && -r $file ]]; then
        stat -c 'size=%s mode=%A uid=%u gid=%g modified=%y' "$file" 2>&1 | redact >>"$report" || true
        if have sha256sum; then sha256sum "$file" 2>&1 | redact >>"$report" || true; fi
        head -c 65536 "$file" | head -n 800 | redact >>"$report" || true
    else
        note '[missing, unreadable, symlinked, or not a regular file]'
    fi
done

section 'IMPLEMENTATION INPUTS: REPOSITORY LOCKSCREEN TREE'
repo_lock_root="$repo_root/stages/stage-5-desktop-customization/workstreams/02-lock-screen"
if [[ -d $repo_lock_root && ! -L $repo_lock_root ]]; then
    find "$repo_lock_root" -maxdepth 5 -type f \( -name '*.qml' -o -name '*.conf' -o -name '*.json' -o -name '*.lua' -o -name '*.sh' -o -name '*.service' -o -name '*.target' \) \
        -printf '%P (%s bytes)\n' 2>/dev/null | sort | head -n 300 | redact >>"$report" || true
else
    note '[repository lockscreen workstream directory missing or unsafe]'
fi

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
    printf '\n-- %s --\n' "$unit_file" | redact >>"$report"
    grep -nE '^[[:space:]]*(Description|Type|User|Group|ExecStart|ExecStartPre|ExecStartPost|ExecStop|After|Before|Wants|Requires|WantedBy|PartOf|TimeoutStartSec|Restart|RestartSec)[[:space:]]*=' "$unit_file" |
        redact >>"$report" || true
done

section 'HYPRLAND STARTUP LOG AND ROTATED PREVIOUS LOG'
startup_log="$HOME/.local/state/k41/hyprland-startup.log"
for file in "$startup_log" "$startup_log.1"; do
    if [[ -f $file && ! -L $file && -r $file ]]; then
        printf '\n-- %s --\n' "${file#"$HOME"/}" | redact >>"$report"
        stat -c 'size=%s mode=%A uid=%u gid=%g modified=%y' "$file" 2>&1 | redact >>"$report" || true
        if have sha256sum; then sha256sum "$file" 2>&1 | redact >>"$report" || true; fi
        tail -n 800 -- "$file" | redact >>"$report" || true
    else
        printf 'MISSING_OR_UNSAFE %s\n' "${file#"$HOME"/}" | redact >>"$report"
    fi
done

section 'RECENT USER LOG FILES'
for base in "$HOME/.local/state/k41" "$HOME/.local/state/caelestia" "$HOME/.local/state/quickshell" "$HOME/.local/share/hyprland" "$HOME/.local/share/caelestia" "$HOME/.cache/hyprland" "$HOME/.cache/caelestia" "$HOME/.cache/qs" "$HOME/.cache/quickshell" "${XDG_RUNTIME_DIR:-/run/user/$EUID}/quickshell"; do
    [[ -d $base && ! -L $base ]] || continue
    while IFS= read -r -d '' file; do
        [[ -f $file && ! -L $file ]] || continue
        size=$(stat -c %s "$file" 2>/dev/null || printf 0)
        (( size <= 2097152 )) || continue
        case "$file" in
            *.log|*.txt|*.qslog)
                section "LOG FILE: ${file#"$HOME"/}"
                tail -n 300 -- "$file" | redact >>"$report" || true
                ;;
        esac
    done < <(find "$base" -maxdepth 4 -type f \( -name '*.log' -o -name '*.txt' -o -name '*.qslog' \) -printf '%p\0' 2>/dev/null)
done

section 'HYPRLAND IPC (only succeeds if compositor is running)'
run 'HYPRLAND INSTANCES' hyprctl instances
run 'HYPRLAND VERSION VIA IPC' hyprctl version
run 'HYPRLAND MONITORS' hyprctl monitors

section 'START-HYPRLAND COREDUMP INVENTORY (READ-ONLY)'
if have coredumpctl; then
    coredumpctl list --no-pager 2>&1 |
        grep -iE -C 2 'start-hyprland|Hyprland|quickshell|caelestia|hyprlock' |
        redact >>"$report" || note '[No matching coredump entries or coredumpctl returned no data]'
else
    note '[coredumpctl unavailable]'
fi

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
    run 'QUICKSHELL INSTANCE INVENTORY' qs list --all
    run 'QUICKSHELL CAELESTIA LOG (LATEST 400 LINES)' qs log -c caelestia --tail 400 --no-color
else
    note '[qs executable unavailable]'
fi

section 'QUICKSHELL RUNTIME LOG FILES'
runtime_qs_root="${XDG_RUNTIME_DIR:-/run/user/$EUID}/quickshell"
if [[ -d $runtime_qs_root && ! -L $runtime_qs_root ]]; then
    while IFS= read -r -d '' qs_log_file; do
        [[ -f $qs_log_file && ! -L $qs_log_file ]] || continue
        printf '\n-- %s --\n' "${qs_log_file#"$HOME"/}" | redact >>"$report"
        stat -c 'size=%s modified=%y mode=%A' "$qs_log_file" 2>&1 | redact >>"$report" || true
        tail -n 500 -- "$qs_log_file" | redact >>"$report" || true
    done < <(find "$runtime_qs_root" -maxdepth 5 -type f -name 'log.qslog' -printf '%T@ %p\0' 2>/dev/null |
        sort -z -nr | head -z -n 8 | cut -z -d' ' -f2-)
else
    note '[Quickshell runtime log directory unavailable]'
fi

section 'OPTIONAL ACTIVE QUICKSHELL STARTUP PROBE'
if [[ ${K41_AUDIT_RUN_QS_PROBE:-0} == 1 ]]; then
    if ! have qs; then
        note '[probe skipped: qs executable unavailable]'
    elif [[ -z ${XDG_RUNTIME_DIR:-} || -z ${WAYLAND_DISPLAY:-} || -z ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
        note '[probe skipped: run from an active Hyprland/Wayland terminal; required session variables are absent]'
    else
        case "$WAYLAND_DISPLAY" in
            /*) wayland_socket="$WAYLAND_DISPLAY" ;;
            *) wayland_socket="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ;;
        esac
        if [[ ! -S $wayland_socket ]]; then
            note '[probe skipped: Wayland socket is not present]'
        elif ps -eo comm= 2>/dev/null | awk '$1 ~ /^(qs|quickshell|caelestia)$/ { found=1 } END { exit !found }'; then
            note '[probe skipped: a Quickshell/Caelestia process is already running; duplicate shell launch refused]'
        else
            probe_raw="$run_dir/quickshell-probe.raw.log"
            section 'QUICKSHELL FOREGROUND STARTUP PROBE (MAX 15 SECONDS)'
            note 'Command: qs -c caelestia (foreground; QT_DEBUG_PLUGINS=1; QML_IMPORT_TRACE=1)'
            note 'This opt-in probe starts the real shell briefly and then terminates it; it may display shell windows during the probe.'
            if QT_DEBUG_PLUGINS=1 QML_IMPORT_TRACE=1 timeout --signal=TERM --kill-after=3 15s qs -c caelestia >"$probe_raw" 2>&1; then
                probe_rc=0
            else
                probe_rc=$?
            fi
            printf 'Probe exit status: %s\n' "$probe_rc" >>"$report"
            case "$probe_rc" in
                124|137) note 'Probe reached its time limit; this alone does not prove successful QML loading.' ;;
                0) note 'Quickshell exited before the time limit; inspect output for the cause.' ;;
                *) note 'Quickshell exited with an error; inspect output for the first QML/plugin/import failure.' ;;
            esac
            if [[ -s $probe_raw ]]; then
                section 'QUICKSHELL FOREGROUND STARTUP OUTPUT (REDACTED; MAX 256 KiB)'
                head -c 262144 "$probe_raw" | redact >>"$report" || true
            else
                note '[probe produced no stdout/stderr]'
            fi
            rm -f -- "$probe_raw"
        fi
    fi
else
    note 'Probe not run. Set K41_AUDIT_RUN_QS_PROBE=1 only from an unlocked terminal inside the active Hyprland desktop.'
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

section 'LOCK LIFECYCLE: NORMALIZED EVIDENCE TIMELINE'
timeline_file="$run_dir/lifecycle-timeline.tsv"
python3 - "$helper_log_root" "$timeline_file" "$report" <<'PY'
import os
import pathlib
import pwd
import re
import subprocess
import sys

log_root = pathlib.Path(sys.argv[1])
timeline_path = pathlib.Path(sys.argv[2])
report_path = pathlib.Path(sys.argv[3])
events = {
    "HELPER_STARTED": re.compile(r"Lock startup helper started"),
    "CAELESTIA_IPC_READY": re.compile(r"Caelestia lock IPC is ready"),
    "LOCK_REQUEST_ACCEPTED": re.compile(r"Caelestia lock request accepted"),
    "LOCK_STATE_VERIFIED": re.compile(r"Caelestia lock state verified"),
    "LOCK_READINESS_MARKER_PUBLISHED": re.compile(r"Readiness marker published"),
    "CAELESTIA_IPC_TIMEOUT": re.compile(r"Caelestia lock IPC did not become ready"),
    "LOCK_STATE_TIMEOUT": re.compile(r"did not reach verified state"),
    "HYPRLOCK_FALLBACK_STARTED": re.compile(r"Starting Hyprlock fallback"),
    "LOCK_STATE_RETRY": re.compile(r"Caelestia lock state not yet verified"),
    "LOCK_REQUEST_REJECTED": re.compile(r"Caelestia lock IPC rejected or timed out on the lock request"),
    "HELPER_TERMINAL_ERROR": re.compile(r"K41 lock startup: ERROR:"),
    "HYPRLOCK_FALLBACK_EXITED": re.compile(r"Hyprlock fallback exited"),
    "HYPRLOCK_FALLBACK_RUNNING": re.compile(r"Hyprlock fallback is running"),
    # Hyprlock stdout/stderr is captured inside each helper log. These lines
    # are stronger evidence than PAM journal matching when upstream emits them.
    "HYPRLOCK_AUTH_SUCCESS": re.compile(r"auth: authenticated for hyprlock|authenticated for hyprlock", re.I),
    "HYPRLOCK_AUTH_FAILURE": re.compile(r"auth:.*(?:failed|failure)|authentication (?:failed|failure)", re.I),
    "HYPRLOCK_UNLOCK_CONFIRMED": re.compile(r"Unlocked, exiting!|unlock successful|session unlocked", re.I),
    "HYPRLOCK_CONFIG_ERROR": re.compile(r"Config path error|Could not find config|failed to load config", re.I),
}
observed = {name: [] for name in events}
sources = []
if log_root.is_dir() and not log_root.is_symlink():
    for path in sorted(log_root.glob("startup-*.log"), key=lambda p: p.stat().st_mtime, reverse=True)[:8]:
        if path.is_file() and not path.is_symlink():
            sources.append(path)
            try:
                lines = path.read_text(errors="replace").splitlines()
            except OSError:
                continue
            for line in lines:
                for name, pattern in events.items():
                    if pattern.search(line):
                        stamp = re.search(r"\[(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ)\]", line)
                        observed[name].append((stamp.group(1) if stamp else "UNKNOWN", path.name, line[:300]))

journal_patterns = {
    "AUTH_SUCCESS": re.compile(r"pam_[^: ]+.*(?:authentication|auth).*success|authentication succeeded", re.I),
    "AUTH_FAILURE": re.compile(r"pam_[^: ]+.*(?:authentication|auth).*failure|authentication failure|authenticator.*failed", re.I),
    "UNLOCK_EVENT": re.compile(r"\b(unlocked|unlock successful|session unlocked)\b", re.I),
    "HYPRLAND_SESSION_START": re.compile(r"Reached target.*(?:Hyprland|graphical)|Hyprland.*started", re.I),
    "HYPRLAND_SESSION_STOP": re.compile(r"Stopped target.*(?:Hyprland|graphical)|Hyprland.*(stopped|exited)", re.I),
    # No current upstream/runtime telemetry proves these visual events.
}
journal_events = {name: [] for name in journal_patterns}
try:
    result = subprocess.run(
        ["journalctl", "-b", "--no-pager", "-o", "short-iso-precise"],
        capture_output=True, text=True, timeout=15, check=False
    )
    if result.returncode == 0:
        for line in result.stdout.splitlines():
            for name, pattern in journal_patterns.items():
                if pattern.search(line):
                    stamp = line.split(maxsplit=1)[0] if line else "UNKNOWN"
                    journal_events[name].append((stamp, "journalctl -b", line[:300]))
except (OSError, subprocess.TimeoutExpired):
    pass

with timeline_path.open("w", encoding="utf-8") as out:
    out.write("event\tstatus\ttimestamp_with_timezone\tsource\tevidence\n")
    all_events = list(events) + list(journal_patterns) + ["LOCK_SURFACE_VISIBLE", "DESKTOP_RESTORED_AFTER_UNLOCK"]
    for name in all_events:
        matches = observed.get(name, journal_events.get(name, []))
        if name in ("LOCK_SURFACE_VISIBLE", "DESKTOP_RESTORED_AFTER_UNLOCK") and not matches:
            out.write(f"{name}\tNOT_INSTRUMENTED\tUNKNOWN\tUNKNOWN\tNo reliable event source currently emits this event\n")
        elif matches:
            for stamp, source, evidence in matches:
                safe = evidence.replace("\t", " ").replace("\n", " ")
                home = os.environ.get("HOME", "")
                if home and home != "/":
                    safe = safe.replace(home, "<HOME>")
                try:
                    username = pwd.getpwuid(os.getuid()).pw_name
                    safe = re.sub(r"(?<![A-Za-z0-9_.-])" + re.escape(username) + r"(?![A-Za-z0-9_.-])", "<USER>", safe)
                except KeyError:
                    pass
                safe = re.sub(r"(?i)\b(password|passwd|token|secret|authorization|cookie|api[_-]?key)\b([=: ]+)[^\s,;]+", r"\1\2<REDACTED>", safe)
                out.write(f"{name}\tOBSERVED\t{stamp}\t{source}\t{safe}\n")
        else:
            out.write(f"{name}\tNOT_OBSERVED\tUNKNOWN\tUNKNOWN\tNo matching evidence in collected sources\n")

with report_path.open("a", encoding="utf-8") as report:
    report.write("\n===== NORMALIZED LOCK LIFECYCLE TIMELINE =====\n")
    report.write("Evidence status is literal: NOT_OBSERVED does not mean the event did not happen.\n")
    report.write("HYPRLOCK_AUTH_SUCCESS/HYPRLOCK_AUTH_FAILURE/HYPRLOCK_UNLOCK_CONFIRMED are parsed from helper-captured Hyprlock stdout/stderr; timestamp is UNKNOWN when upstream output has no timestamp.\n")
    report.write("AUTH_SUCCESS/AUTH_FAILURE/UNLOCK_EVENT remain separate journal-derived signals and may be absent because PAM logging is implementation-dependent.\n")
    report.write("LOCK_SURFACE_VISIBLE and DESKTOP_RESTORED_AFTER_UNLOCK are NOT_INSTRUMENTED, not NOT_OBSERVED; no reliable correlated event source exists yet.\n")
    report.write("Timeline file: lifecycle-timeline.tsv\n")
    report.write("Helper logs inspected: " + (", ".join(p.name for p in sources) if sources else "none") + "\n")
    report.write("Journal query: " + ("available" if any(journal_events.values()) else "no matching/accessible evidence") + "\n")
    for name in all_events:
        matches = observed.get(name, journal_events.get(name, []))
        if name in ("LOCK_SURFACE_VISIBLE", "DESKTOP_RESTORED_AFTER_UNLOCK") and not matches:
            report.write(f"{name}: NOT_INSTRUMENTED\n")
            continue
        report.write(f"{name}: {'OBSERVED (' + str(len(matches)) + ')' if matches else 'NOT_OBSERVED'}\n")
PY
chmod 0600 "$timeline_file"
note "Normalized lifecycle timeline: $run_dir/lifecycle-timeline.tsv"

# GitHub's text/blob APIs require valid UTF-8. Normalize the completed report
# before publishing; upstream logs/config snippets can contain arbitrary bytes.
python3 - "$report" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
raw = path.read_bytes()
text = raw.decode("utf-8", errors="replace")
text = "".join(ch for ch in text if ch in "\n\r\t" or ord(ch) >= 32)
path.write_text(text, encoding="utf-8", errors="strict")
if path.stat().st_size == 0:
    raise SystemExit("ERROR: diagnostic report is empty; refusing publication")
print(f"Report UTF-8 normalization: PASS ({path.stat().st_size} bytes)")
PY
chmod 0600 "$report"
note 'Report encoding normalized to valid UTF-8; invalid bytes replaced and control characters removed.'
note 'Timeline statuses describe collected evidence only; NOT_OBSERVED is not proof that an event did not occur.'
note 'The collector cannot prove successful unlock or desktop restoration without correlated runtime telemetry.'

section 'DIAGNOSTIC LIMITATIONS'
note '- Collector tidak menjalankan start-hyprland, Hyprland, Caelestia reload, atau lock command secara default.'
note '- Opt-in K41_AUDIT_RUN_QS_PROBE=1 menjalankan qs -c caelestia secara foreground maksimal 15 detik untuk menangkap QML/plugin/import error; probe dilewati jika session Wayland tidak valid atau Quickshell sudah berjalan.'
note '- Collector tidak mengubah service, package, bootloader, initramfs, TPM/LUKS, PAM, permission, ownership, maupun konfigurasi.'
note '- Hyprlock auth/unlock lines are parsed from helper-captured stdout/stderr; if upstream emits no timestamp, the timeline records UNKNOWN rather than inventing one.'
note '- Journal-derived PAM/auth signals remain separate from Hyprlock helper-log signals; absence in one source does not negate evidence in the other.'
note '- Journal mungkin tidak dapat dibaca lengkap oleh user biasa; permission-denied dicatat sebagai keterbatasan.'
note '- Report memuat QML lockscreen repository/runtime yang dipilih, potongan log, metadata, dan hash. Redaksi otomatis tidak menjamin seluruh data pribadi terhapus.'
note '- Salinan report tersanitasi dipublikasikan otomatis; redaksi tidak menjamin seluruh data privat terhapus, jadi tinjau report di GitHub dan hapus data sensitif bila ditemukan.'
note '- TTY2 fallback dapat merupakan konsekuensi eksplisit dari k41-plymouth-quit-after-lock.sh setelah timeout 75 detik; bukti journal menentukan apakah mekanisme itu yang berjalan.'
note "Report: ${report#"$repo_root"/}"

cat >"$run_dir/README.txt" <<EOF
K41 desktop startup diagnostic
===============================
Run this script as the regular desktop user from tty2 or a normal shell:

  bash stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-audit-desktop-startup.sh

Report: report.txt

The collector does not modify configuration, packages, services, authentication, or boot state. By default it does not launch a shell. To run the optional 15-second foreground Quickshell diagnostic from an unlocked terminal inside the active Hyprland session, use:
  
  K41_AUDIT_RUN_QS_PROBE=1 bash stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-audit-desktop-startup.sh

The probe is skipped if Wayland session variables/socket are missing or a Quickshell/Caelestia process is already running. It may briefly display shell windows. The report is private locally and a redacted copy is published.
The script publishes a sanitized copy of this run directory (report.txt, README.txt, lifecycle-timeline.tsv) to GitHub main using existing Git credentials. The local report remains private (0600); if publication fails, the report stays local and the script exits non-zero. Review the published report for any residual private information.
EOF
chmod 0600 "$run_dir/README.txt"

publish_report() {
    local remote_url publish_tmp publish_dir relative_dir publish_target
    remote_url="$(git -C "$repo_root" remote get-url origin 2>/dev/null)" ||
        { printf 'ERROR: tidak dapat membaca Git origin; report tetap lokal.\n' >&2; return 1; }
    case "$remote_url" in
        https://github.com/K41-Origin/Lenovo-ThinkPad-X280-K41|https://github.com/K41-Origin/Lenovo-ThinkPad-X280-K41.git|git@github.com:K41-Origin/Lenovo-ThinkPad-X280-K41.git|ssh://git@github.com/K41-Origin/Lenovo-ThinkPad-X280-K41.git) ;;
        *) printf 'ERROR: Git origin bukan repository K41 yang diizinkan; report tetap lokal.\n' >&2; return 1 ;;
    esac

    # Publish through a completely independent clone. A linked worktree shares
    # the checkout's .git metadata; fetch/worktree registration/cleanup there
    # previously risked leaving the user's local repository in a broken state.
    # This clone has its own .git directory and cannot rewrite local refs,
    # FETCH_HEAD, index, branch, or worktree registration in the user's checkout.
    publish_tmp="$(mktemp -d "${TMPDIR:-/tmp}/k41-startup-audit-publish.XXXXXX")" || return 1
    publish_dir="$publish_tmp/repository"
    if ! git clone --quiet --no-tags --single-branch --branch main "$remote_url" "$publish_dir"; then
        rm -rf -- "$publish_tmp"
        printf 'ERROR: isolated clone failed; report remains local.\n' >&2
        return 1
    fi

    relative_dir="${run_dir#"$repo_root"/}"
    publish_target="$publish_dir/$relative_dir"
    if ! mkdir -p -- "$publish_target" ||
       ! cp -- "$report" "$publish_target/report.txt" ||
       ! cp -- "$run_dir/README.txt" "$publish_target/README.txt" ||
       ! cp -- "$timeline_file" "$publish_target/lifecycle-timeline.tsv"; then
        rm -rf -- "$publish_tmp"
        printf 'ERROR: could not stage sanitized report in isolated clone; report remains local.\n' >&2
        return 1
    fi
    chmod 0644 "$publish_target/report.txt" "$publish_target/README.txt" "$publish_target/lifecycle-timeline.tsv"
    chmod 0755 "$publish_target"
    git -C "$publish_dir" config user.name "K41 Startup Audit"
    git -C "$publish_dir" config user.email "k41-startup-audit@users.noreply.github.com"
    if ! git -C "$publish_dir" add -- "$relative_dir" ||
       ! git -C "$publish_dir" commit -m "Add X280 desktop startup diagnostic"; then
        rm -rf -- "$publish_tmp"
        printf 'ERROR: report commit failed in isolated clone; report remains local.\n' >&2
        return 1
    fi
    if ! git -C "$publish_dir" push origin HEAD:main; then
        printf 'INFO: push raced with an update to main; retrying once after rebase in isolated clone.\n'
        if ! git -C "$publish_dir" fetch --no-tags origin main ||
           ! git -C "$publish_dir" rebase FETCH_HEAD ||
           ! git -C "$publish_dir" push origin HEAD:main; then
            rm -rf -- "$publish_tmp"
            printf 'ERROR: report publication failed; local report remains at %s\n' "$report" >&2
            return 1
        fi
    fi

    rm -rf -- "$publish_tmp"
    printf 'INFO: report tersanitasi dipublikasikan ke GitHub main: %s\n' "$relative_dir"
    printf 'INFO: local checkout Git metadata was not used for publication and remains untouched.\n'
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