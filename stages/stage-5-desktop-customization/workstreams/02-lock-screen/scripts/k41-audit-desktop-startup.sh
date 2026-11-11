#!/usr/bin/env bash
# Read-only X280 desktop startup diagnostic for tty fallback / stuck Hyprland launch.
# Can be run from tty2 or a normal user shell; does not require a Wayland session.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
have() { command -v "$1" >/dev/null 2>&1; }

(( EUID != 0 )) || die 'Jalankan sebagai user desktop biasa, tanpa sudo.'
[[ -n ${HOME:-} && $HOME == /* && -d $HOME ]] || die 'HOME tidak valid.'
for cmd in git stat date mkdir chmod uname id who tty ps awk grep sed tail find python3; do
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
import os, re, sys
s = sys.stdin.read()
home = os.environ.get("HOME", "")
user = os.environ.get("USER", "")
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

section 'HYPRLAND LUA STARTUP / LOCK INTEGRATION LINES'
if [[ -r $HOME/.config/hypr/hyprland.lua ]]; then
    grep -nEi -C 3 'K41|hyprland\.start|start-hyprland|caelestia|hyprlock|lock|exec_cmd|exec-once' "$HOME/.config/hypr/hyprland.lua" |
        redact >>"$report" || note '[no matching startup/lock lines]'
else note '[~/.config/hypr/hyprland.lua unavailable]'; fi

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
for base in "$HOME/.local/state/k41" "$HOME/.local/share/hyprland" "$HOME/.cache/hyprland" "$HOME/.cache/qs" "$HOME/.cache/quickshell"; do
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

section 'DIAGNOSTIC LIMITATIONS'
note '- Collector tidak menjalankan start-hyprland, Hyprland, Caelestia reload, atau lock command.'
note '- Collector tidak mengubah service, package, bootloader, initramfs, TPM/LUKS, PAM, permission, ownership, maupun konfigurasi.'
note '- Journal mungkin tidak dapat dibaca lengkap oleh user biasa; permission-denied dicatat sebagai keterbatasan.'
note '- Report menyimpan potongan log yang relevan dan metadata konfigurasi. Redaksi otomatis tidak menjamin seluruh data pribadi terhapus.'
note '- Periksa report sebelum commit/push; jangan publikasikan token, hostname pribadi, alamat jaringan, atau informasi sensitif.'
note '- TTY2 fallback dapat merupakan konsekuensi eksplisit dari k41-plymouth-quit-after-lock.sh setelah timeout 75 detik; bukti journal menentukan apakah mekanisme itu yang berjalan.'
note "Report: ${report#"$repo_root"/}"

cat >"$run_dir/README.txt" <<EOF
K41 desktop startup diagnostic
===============================
Run this script as the regular desktop user from tty2 or a normal shell:

  bash stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-audit-desktop-startup.sh

Report: report.txt

The collector is read-only. It does not attempt to launch or repair Hyprland.
Review report.txt and remove private data before committing/pushing this directory.
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