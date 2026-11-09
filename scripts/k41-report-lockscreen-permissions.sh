#!/usr/bin/env bash
# Read-only ownership/path audit for the K41 Caelestia lock-screen deployment.
# Only writes a new report under reports/lockscreen-apply/.
set -Eeuo pipefail

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
have() { command -v "$1" >/dev/null 2>&1; }

(( EUID != 0 )) || die 'Jalankan sebagai user desktop biasa, tanpa sudo.'
have git || die 'Git tidak tersedia.'
have stat || die 'stat tidak tersedia.'
have date || die 'date tidak tersedia.'
have mkdir || die 'mkdir tidak tersedia.'
have find || die 'find tidak tersedia.'
have id || die 'id tidak tersedia.'

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)" ||
    die 'Script harus berada di dalam Git checkout.'
repo_root="$(cd -- "$repo_root" && pwd -P)"
[[ "$(git -C "$repo_root" branch --show-current)" == main ]] ||
    die 'Audit hanya berjalan pada branch main.'
[[ "$(stat -c %u "$repo_root")" == "$EUID" ]] ||
    die 'Repository bukan milik user aktif; jangan gunakan sudo/chown.'

report_parent="$repo_root/reports"
report_root="$report_parent/lockscreen-apply"
[[ ! -L $report_parent && ! -L $report_root ]] || die 'Symlink pada jalur report ditolak.'
[[ ! -e $report_parent || -d $report_parent ]] || die 'reports bukan direktori.'
[[ ! -e $report_root || -d $report_root ]] || die 'lockscreen-apply bukan direktori.'
mkdir -p -- "$report_root"
stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
report="$report_root/$stamp-permission-audit.log"
suffix=0
while [[ -e $report || -L $report ]]; do
    suffix=$((suffix + 1))
    report="$report_root/$stamp-$suffix-permission-audit.log"
done
( set -o noclobber; : > "$report" ) 2>/dev/null || die 'Tidak dapat membuat report baru.'

section() { printf '\n========== %s ==========\n' "$1" >> "$report"; }
path_info() {
    local p=$1
    if [[ -L $p ]]; then
        printf 'SYMLINK '
        stat -c '%A owner=%U:%G uid=%u gid=%g path=%n -> %N' -- "$p" 2>&1
    elif [[ -e $p ]]; then
        stat -c '%A owner=%U:%G uid=%u gid=%g path=%n' -- "$p" 2>&1
    else
        printf 'MISSING path=%s\n' "$p"
    fi
}
tree_info() {
    local base=$1
    if [[ -d $base && ! -L $base ]]; then
        printf '\n-- tree: %s --\n' "$base"
        find "$base" -maxdepth 5 -printf '%y %M uid=%U gid=%G %p\n' 2>&1 | head -n 250
    else
        printf '\n-- tree unavailable: %s --\n' "$base"
    fi
}

{
    printf 'K41 Lock Screen Deployment Permission Audit\n'
    printf 'Timestamp UTC: %s\n' "$stamp"
    printf 'User: %s UID=%s GID=%s\n' "$(id -un)" "$EUID" "$(id -g)"
    printf 'HOME: %s\n' "$HOME"
    printf 'Repository: %s\n' "$repo_root"
    printf 'Branch: %s\n' "$(git -C "$repo_root" branch --show-current)"
    printf 'HEAD: %s\n' "$(git -C "$repo_root" rev-parse HEAD)"
    printf 'Kernel: %s\n' "$(uname -sr)"
    printf 'This collector does not change permissions, ownership, configuration, packages, services, PAM, Git index, branch, or HEAD.\n'
} >> "$report"

config="$HOME/.config"
quickshell="$config/quickshell"
target="$quickshell/caelestia"
state="$HOME/.local/state"
k41state="$state/k41"
lockstate="$k41state/lockscreen"
backups="$lockstate/backups"

section 'Expected managed path metadata'
for p in "$HOME" "$config" "$quickshell" "$target" "$state" "$k41state" "$lockstate" "$backups" "$repo_root" "$report_root"; do
    path_info "$p" >> "$report"
done

section 'Path traversal and symlink inspection'
for p in "$config" "$quickshell" "$target" "$state" "$k41state" "$lockstate" "$backups"; do
    if have namei; then
        printf '\n-- namei -l %s --\n' "$p" >> "$report"
        namei -l -- "$p" >> "$report" 2>&1 || true
    fi
done

section 'ACL metadata (read-only)'
if have getfacl; then
    for p in "$config" "$quickshell" "$target" "$state" "$k41state" "$lockstate" "$backups"; do
        [[ -e $p ]] || continue
        printf '\n-- getfacl %s --\n' "$p" >> "$report"
        getfacl -cp -- "$p" >> "$report" 2>&1 || true
    done
else
    printf 'getfacl unavailable; ACL entries were not inspected.\n' >> "$report"
fi

section 'Existing user Caelestia tree (metadata and paths only)'
tree_info "$target" >> "$report"
printf '\nExpected user entry point: %s/shell.qml\n' "$target" >> "$report"
[[ -f $target/shell.qml ]] && printf 'User shell.qml: PRESENT\n' >> "$report" || printf 'User shell.qml: MISSING\n' >> "$report"
[[ -f /etc/xdg/quickshell/caelestia/shell.qml ]] &&
    printf 'Package shell.qml: PRESENT (/etc/xdg/quickshell/caelestia/shell.qml)\n' >> "$report" ||
    printf 'Package shell.qml: MISSING\n' >> "$report"

section 'Backup tree (metadata and paths only)'
tree_info "$backups" >> "$report"

section 'Relevant package and deployment versions'
if have pacman; then
    pacman -Q caelestia-shell caelestia-cli quickshell-git 2>&1 >> "$report" || true
else
    printf 'pacman unavailable.\n' >> "$report"
fi
if have git && [[ -d $target/.git ]]; then
    printf '\nUser source HEAD: %s\n' "$(git -C "$target" rev-parse HEAD 2>&1 || true)" >> "$report"
    printf 'User source origin: %s\n' "$(git -C "$target" remote get-url origin 2>&1 || true)" >> "$report"
    printf 'User source tracked changes: ' >> "$report"
    if git -C "$target" diff --quiet; then printf 'none\n' >> "$report"; else printf 'present\n' >> "$report"; fi
else
    printf 'User source Git checkout: absent\n' >> "$report"
fi

section 'Recent deployment reports (last 10 filenames and summaries)'
if [[ -d $report_root ]]; then
    find "$report_root" -maxdepth 1 -type f -name '*-apply.log' -printf '%T@ %f\n' 2>/dev/null |
        sort -nr | head -n 10 | cut -d' ' -f2- >> "$report" || true
    while IFS= read -r f; do
        [[ -n $f ]] || continue
        printf '\n-- %s --\n' "$f" >> "$report"
        grep -E '^(ERROR:|INFO:|Exit code:|Result[[:space:]]*:|Log file[[:space:]]*:)' "$report_root/$f" 2>/dev/null |
            tail -n 25 >> "$report" || true
    done < <(find "$report_root" -maxdepth 1 -type f -name '*-apply.log' -printf '%T@ %f\n' 2>/dev/null |
        sort -nr | head -n 3 | cut -d' ' -f2-)
fi

section 'Diagnosis hints (no automatic repair performed)'
printf '%s\n' \
  '- Compare UID/GID and mode for ~/.config, ~/.config/quickshell, and ~/.config/quickshell/caelestia.' \
  '- Check namei output for a non-traversable parent or symlink.' \
  '- Check ACL output if owner/mode appear correct but access still fails.' \
  '- The previous installer deliberately stopped on unexpected owner; this audit does not change it.' \
  '- Do not run recursive chown/chmod. Repair must target only the confirmed managed path after review.' \
  '- The local shell entry point must exist before Quickshell can select the K41 user source tree.' >> "$report"

printf 'Audit selesai: %s\n' "$report"
printf 'Audit hanya membaca metadata; tidak mengubah permission/ownership atau konfigurasi.\n'
printf '\nTinjau report, lalu push dengan perintah berikut:\n'
printf 'git -C %q add -- %q\n' "$repo_root" "${report#"$repo_root"/}"
printf 'git -C %q diff --cached --check\n' "$repo_root"
printf 'git -C %q commit --only -m %q -- %q\n' "$repo_root" 'audit(lockscreen): add deployment permission report' "${report#"$repo_root"/}"
printf 'git -C %q push origin main\n' "$repo_root"
