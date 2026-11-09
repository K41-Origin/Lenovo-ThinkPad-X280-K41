#!/usr/bin/env bash
# Read-only failure collector for K41 lock-screen deployment.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
have() { command -v "$1" >/dev/null 2>&1; }

(( EUID != 0 )) || die 'Jalankan sebagai user desktop biasa, tanpa sudo.'
for cmd in git stat date mkdir find sort tail sed id uname; do
    have "$cmd" || die "Command tidak tersedia: $cmd"
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)" ||
    die 'Jalankan dari checkout repository.'
repo_root="$(cd -- "$repo_root" && pwd -P)"
[[ "$(git -C "$repo_root" branch --show-current)" == main ]] ||
    die 'Checkout bukan branch main.'
[[ "$(stat -c %u "$repo_root")" == "$EUID" ]] ||
    die 'Repository bukan milik user aktif; jangan jalankan dengan sudo.'

report_dir="$repo_root/reports/lockscreen-apply"
[[ ! -L "$repo_root/reports" && ! -L "$report_dir" ]] ||
    die 'Symlink pada direktori report ditolak.'
mkdir -p -- "$report_dir"
[[ -d "$report_dir" && -w "$report_dir" ]] || die 'Direktori report tidak writable.'

stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
report="$report_dir/${stamp}-failure-diagnostic.log"
n=0
while [[ -e "$report" || -L "$report" ]]; do
    n=$((n + 1))
    report="$report_dir/${stamp}-${n}-failure-diagnostic.log"
done
( set -o noclobber; : > "$report" ) 2>/dev/null || die 'Gagal membuat report.'

section() { printf '\n========== %s ==========\n' "$1" >> "$report"; }
record_path() {
    local p=$1
    if [[ -L "$p" ]]; then
        stat -c 'SYMLINK mode=%A owner=%U:%G uid=%u gid=%g path=%n target=%N' -- "$p" >> "$report" 2>&1 || true
    elif [[ -e "$p" ]]; then
        stat -c 'mode=%A owner=%U:%G uid=%u gid=%g path=%n' -- "$p" >> "$report" 2>&1 || true
    else
        printf 'MISSING path=%s\n' "$p" >> "$report"
    fi
}
{
    printf 'K41 LOCKSCREEN FAILURE DIAGNOSTIC\n'
    printf 'Timestamp UTC: %s\n' "$stamp"
    printf 'User: %s uid=%s gid=%s\n' "$(id -un)" "$EUID" "$(id -g)"
    printf 'HOME: %s\n' "$HOME"
    printf 'Repo: %s\n' "$repo_root"
    printf 'Branch: %s\n' "$(git -C "$repo_root" branch --show-current)"
    printf 'HEAD: %s\n' "$(git -C "$repo_root" rev-parse HEAD)"
    printf 'Kernel: %s\n' "$(uname -sr)"
    printf 'Working tree status:\n'
    git -C "$repo_root" status --short
} >> "$report"

config="$HOME/.config"
quick="$config/quickshell"
target="$quick/caelestia"
state="$HOME/.local/state"
backup="$state/k41/lockscreen/backups"
section 'Ownership and permissions'
for p in "$HOME" "$config" "$quick" "$target" "$target/modules" "$target/modules/lock" "$target/modules/lock/Content.qml" "$target/modules/lock/Center.qml" "$target/shell.qml" "$state" "$state/k41" "$state/k41/lockscreen" "$backup" "$repo_root" "$report_dir"; do
    record_path "$p"
done

section 'Path traversal'
if have namei; then
    for p in "$config" "$quick" "$target" "$backup"; do
        printf '\n-- namei -l %s --\n' "$p" >> "$report"
        namei -l -- "$p" >> "$report" 2>&1 || true
    done
else
    printf 'namei unavailable\n' >> "$report"
fi

section 'ACL'
if have getfacl; then
    for p in "$config" "$quick" "$target" "$target/modules" "$target/modules/lock" "$state" "$state/k41" "$state/k41/lockscreen" "$backup"; do
        [[ -e "$p" ]] || continue
        printf '\n-- getfacl %s --\n' "$p" >> "$report"
        getfacl -cp -- "$p" >> "$report" 2>&1 || true
    done
else
    printf 'getfacl unavailable\n' >> "$report"
fi

section 'Existing target tree (paths and metadata only)'
if [[ -d "$target" && ! -L "$target" ]]; then
    find "$target" -maxdepth 5 -printf '%y %M uid=%U gid=%G %p\n' >> "$report" 2>&1 || true
else
    printf 'Target directory missing or not a real directory\n' >> "$report"
fi
printf '\nUser shell.qml: ' >> "$report"
[[ -f "$target/shell.qml" ]] && printf 'PRESENT\n' >> "$report" || printf 'MISSING\n' >> "$report"
printf 'System shell.qml: ' >> "$report"
[[ -f /etc/xdg/quickshell/caelestia/shell.qml ]] && printf 'PRESENT\n' >> "$report" || printf 'MISSING\n' >> "$report"

section 'Installer and test source fingerprints'
for f in scripts/k41-apply-lockscreen-design.sh scripts/k41-report-lockscreen-session.sh scripts/k41-report-lockscreen-failure.sh tests/test-lockscreen-design.sh; do
    if [[ -f "$repo_root/$f" ]]; then
        printf '%s\n' "$f" >> "$report"
        git -C "$repo_root" hash-object "$repo_root/$f" >> "$report" 2>&1 || true
    else
        printf 'MISSING %s\n' "$f" >> "$report"
    fi
done

section 'Package versions and tools'
if have pacman; then
    pacman -Q caelestia-shell caelestia-cli quickshell-git >> "$report" 2>&1 || true
else
    printf 'pacman unavailable\n' >> "$report"
fi
for cmd in sudo runuser chown install git pacman caelestia; do
    if have "$cmd"; then printf '%s: %s\n' "$cmd" "$(command -v "$cmd")" >> "$report"
    else printf '%s: MISSING\n' "$cmd" >> "$report"; fi
done

section 'Latest deployment logs (full last 500 lines each, newest 3)'
mapfile -t logs < <(find "$report_dir" -maxdepth 1 -type f -name '*-apply.log' -printf '%T@ %p\n' 2>/dev/null | sort -nr | sed -n '1,3p')
if (("${#logs[@]}" == 0)); then
    printf 'No *-apply.log files found.\n' >> "$report"
else
    for item in "${logs[@]}"; do
        log="${item#* }"
        printf '\n----- %s -----\n' "$log" >> "$report"
        tail -n 500 -- "$log" >> "$report" 2>&1 || true
    done
fi

section 'Latest session restart logs (full last 300 lines each, newest 2)'
mapfile -t sessions < <(find "$report_dir" -maxdepth 1 -type f -name '*-session-restart.log' -printf '%T@ %p\n' 2>/dev/null | sort -nr | sed -n '1,2p')
if (("${#sessions[@]}" == 0)); then
    printf 'No session restart logs found.\n' >> "$report"
else
    for item in "${sessions[@]}"; do
        log="${item#* }"
        printf '\n----- %s -----\n' "$log" >> "$report"
        tail -n 300 -- "$log" >> "$report" 2>&1 || true
    done
fi

section 'End of diagnostic'
printf 'Collector is read-only: no ownership, permission, package, service, PAM, or configuration changes were made.\n' >> "$report"
printf 'Report created: %s\n' "$report"
printf '\nPush report with these commands:\n'
printf 'git -C %q add -- %q\n' "$repo_root" "${report#"$repo_root"/}"
printf 'git -C %q diff --cached --check\n' "$repo_root"
printf 'git -C %q commit --only -m %q -- %q\n' "$repo_root" 'diagnostic(lockscreen): capture latest deployment failure' "${report#"$repo_root"/}"
printf 'git -C %q push origin main\n' "$repo_root"
