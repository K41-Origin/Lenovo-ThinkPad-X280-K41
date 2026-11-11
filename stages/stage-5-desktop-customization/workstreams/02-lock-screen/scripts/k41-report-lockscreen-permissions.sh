#!/usr/bin/env bash
# Read-only ownership/path audit for the user-local Caelestia lock runtime.
# The only writes are a new private report under reports/lockscreen-apply/.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
have() { command -v "$1" >/dev/null 2>&1; }

(( EUID != 0 )) || die 'Jalankan sebagai user desktop biasa, tanpa sudo.'
[[ -n ${HOME:-} && $HOME == /* && -d $HOME ]] || die 'HOME tidak valid.'
for cmd in git stat date mkdir find id uname; do
    have "$cmd" || die "Command tidak tersedia: $cmd"
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
report_root="$report_parent/lockscreen-apply"
for path in "$report_parent" "$report_root"; do
    [[ ! -L $path ]] || die "Symlink report path ditolak: $path"
    [[ ! -e $path || -d $path ]] || die "Report path bukan direktori: $path"
done
mkdir -p -- "$report_root"
stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
report="$report_root/$stamp-permission-audit.log"
suffix=0
while [[ -e $report || -L $report ]]; do
    suffix=$((suffix + 1))
    report="$report_root/$stamp-$suffix-permission-audit.log"
done
( set -o noclobber; : > "$report" ) 2>/dev/null || die 'Tidak dapat membuat report baru.'
chmod 0600 "$report"

section() { printf '\n========== %s ==========\n' "$*" >>"$report"; }
path_info() {
    local path=$1
    if [[ -L $path ]]; then
        stat -c 'SYMLINK %A owner=%U:%G uid=%u gid=%g path=%n -> %N' -- "$path" 2>&1
    elif [[ -e $path ]]; then
        stat -c 'PATH %A owner=%U:%G uid=%u gid=%g path=%n' -- "$path" 2>&1
    else
        printf 'MISSING path=%s\n' "$path"
    fi
}
tree_info() {
    local base=$1
    if [[ -d $base && ! -L $base ]]; then
        printf '%s\n' "-- tree: $base --"
        find "$base" -maxdepth 5 -printf '%y %M uid=%U gid=%G %p\n' 2>&1 || true
    else
        printf '%s\n' "-- tree unavailable: $base --"
    fi
}

config="$HOME/.config"
quickshell="$config/quickshell"
target="$quickshell/caelestia"
state="$HOME/.local/state"
k41state="$state/k41"
lockstate="$k41state/lockscreen"
backups="$lockstate/backups"

{
    printf 'K41 Lock Screen Deployment Permission Audit\n'
    printf 'Timestamp UTC: %s\n' "$stamp"
    printf 'User UID/GID: %s/%s\n' "$EUID" "$(id -g)"
    printf 'HOME: %s\n' "$HOME"
    printf 'Repository: %s\n' "$repo_root"
    printf 'Branch: %s\n' "$(git -C "$repo_root" branch --show-current)"
    printf 'HEAD: %s\n' "$(git -C "$repo_root" rev-parse HEAD)"
    printf 'Kernel: %s\n' "$(uname -sr)"
    printf 'Read-only contract: no permission, ownership, configuration, package, service, PAM, or Git state changes.\n'
} >>"$report"

section 'Expected managed path metadata'
for path in "$HOME" "$config" "$quickshell" "$target" "$state" "$k41state" "$lockstate" "$backups" "$repo_root" "$report_root"; do
    path_info "$path" >>"$report"
done

section 'Path traversal and symlink inspection'
if have namei; then
    for path in "$config" "$quickshell" "$target" "$state" "$k41state" "$lockstate" "$backups"; do
        printf '\n-- namei -l %s --\n' "$path" >>"$report"
        namei -l -- "$path" >>"$report" 2>&1 || true
    done
else
    printf 'namei unavailable.\n' >>"$report"
fi

section 'ACL metadata (read-only)'
if have getfacl; then
    for path in "$config" "$quickshell" "$target" "$state" "$k41state" "$lockstate" "$backups"; do
        [[ -e $path ]] || continue
        printf '\n-- getfacl %s --\n' "$path" >>"$report"
        getfacl -cp -- "$path" >>"$report" 2>&1 || true
    done
else
    printf 'getfacl unavailable; ACL entries were not inspected.\n' >>"$report"
fi

section 'Existing user Caelestia tree (metadata and paths only)'
tree_info "$target" >>"$report"
printf 'Expected user entry point: %s/shell.qml\n' "$target" >>"$report"
[[ -f $target/shell.qml && ! -L $target/shell.qml ]] &&
    printf 'User shell.qml: PRESENT\n' >>"$report" ||
    printf 'User shell.qml: MISSING\n' >>"$report"
[[ -f /etc/xdg/quickshell/caelestia/shell.qml ]] &&
    printf 'Package shell.qml: PRESENT\n' >>"$report" ||
    printf 'Package shell.qml: MISSING\n' >>"$report"

section 'Backup tree (metadata and paths only)'
tree_info "$backups" >>"$report"

section 'Relevant package and deployment versions'
if have pacman; then
    pacman -Q caelestia-shell caelestia-cli quickshell-git >>"$report" 2>&1 || true
else
    printf 'pacman unavailable.\n' >>"$report"
fi
if [[ -d $target/.git && ! -L $target/.git ]]; then
    printf 'User source HEAD: %s\n' "$(git -C "$target" rev-parse HEAD 2>&1 || true)" >>"$report"
    printf 'User source origin: %s\n' "$(git -C "$target" remote get-url origin 2>&1 || true)" >>"$report"
    if git -C "$target" diff --quiet; then
        printf 'User source tracked changes: none\n' >>"$report"
    else
        printf 'User source tracked changes: present\n' >>"$report"
    fi
else
    printf 'User source Git checkout: absent\n' >>"$report"
fi

section 'Recent deployment reports (newest 10 summaries)'
if [[ -d $report_root ]]; then
    mapfile -t logs < <(find "$report_root" -maxdepth 1 -type f -name '*-apply.log' -printf '%T@ %f\n' 2>/dev/null |
        sort -nr | head -n 10 | cut -d' ' -f2-)
    if (("${#logs[@]}" == 0)); then
        printf 'No deployment apply logs found.\n' >>"$report"
    else
        for log in "${logs[@]}"; do
            printf '\n-- %s --\n' "$log" >>"$report"
            grep -E '^(ERROR:|INFO:|Exit code:|Result[[:space:]]*:|Log file[[:space:]]*:)' "$report_root/$log" 2>/dev/null |
                tail -n 25 >>"$report" || true
        done
    fi
fi

section 'Diagnosis hints (no automatic repair performed)'
cat >>"$report" <<'EOF'
- Compare UID/GID and mode for ~/.config, ~/.config/quickshell, and ~/.config/quickshell/caelestia.
- Check namei output for a non-traversable parent or symlink.
- Check ACL output if owner/mode appear correct but access still fails.
- Do not run recursive chown/chmod. Repair must target only a confirmed managed path after review.
- The local shell entry point must exist before Quickshell can select the K41 user source tree.
EOF

printf 'Audit selesai: %s\n' "$report"
printf 'Audit hanya membaca metadata; tidak mengubah permission/ownership atau konfigurasi.\n'
printf '\nTinjau report sebelum commit karena dapat memuat path lokal dan nama user.\n'
printf 'git -C %q add -- %q\n' "$repo_root" "${report#"$repo_root"/}"
printf 'git -C %q diff --cached --check\n' "$repo_root"
printf 'git -C %q commit --only -m %q -- %q\n' "$repo_root" 'audit(lockscreen): add deployment permission report' "${report#"$repo_root"/}"
printf 'git -C %q push origin main\n' "$repo_root"
