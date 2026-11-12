#!/usr/bin/env bash
# Install or repair the canonical K41 Bottombar module in the K41 Quickshell namespace.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\n' "$*"; }
owner_is_user() { [[ $(stat -c %u -- "$1") == "$EUID" ]]; }

[[ $# -eq 0 ]] || die 'Script ini hanya menjalankan install/repair; tidak menerima opsi.'
(( EUID != 0 )) || die 'Jalankan sebagai user desktop biasa, tanpa sudo.'
[[ -n ${HOME:-} && $HOME == /* && -d $HOME ]] || die 'HOME tidak valid.'

for cmd in git install cp cmp sha256sum stat mkdir chmod mktemp mv rm date awk; do
    command -v "$cmd" >/dev/null 2>&1 || die "Command wajib tidak tersedia: $cmd"
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)" ||
    die 'Tidak dapat menemukan Git repository.'
repo_root="$(cd -- "$repo_root" && pwd -P)"

source_file="$repo_root/stages/stage-5-desktop-customization/workstreams/03-bottombar/modules/bottombar/Dock.Qml"
[[ -f $source_file && ! -L $source_file ]] || die "Source Bottombar tidak tersedia atau symlink: $source_file"
owner_is_user "$source_file" || die 'Source QML bukan milik user aktif.'

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
[[ $config_home == /* && -d $config_home && ! -L $config_home ]] ||
    die 'XDG_CONFIG_HOME harus berupa direktori absolut yang sudah ada dan bukan symlink.'
owner_is_user "$config_home" || die 'XDG_CONFIG_HOME bukan milik user aktif.'

quickshell_dir="$config_home/quickshell"
[[ -d $quickshell_dir && ! -L $quickshell_dir ]] ||
    die "Quickshell user config directory tidak ditemukan atau tidak aman: $quickshell_dir"
owner_is_user "$quickshell_dir" || die 'Quickshell user config directory bukan milik user aktif.'

# Architectural target: keep K41-owned modules separate from Caelestia.
runtime_root="$quickshell_dir/k41"
modules_dir="$runtime_root/modules"
module_dir="$modules_dir/bottombar"
target_file="$module_dir/Dock.Qml"

for path in "$runtime_root" "$modules_dir" "$module_dir"; do
    [[ ! -L $path ]] || die "Symlink pada direktori runtime ditolak: $path"
    if [[ -e $path ]]; then
        [[ -d $path ]] || die "Path runtime bukan direktori: $path"
        owner_is_user "$path" || die "Direktori runtime bukan milik user aktif: $path"
    fi
done

if [[ -e $target_file || -L $target_file ]]; then
    [[ -f $target_file && ! -L $target_file ]] ||
        die "Target runtime bukan regular file atau berupa symlink: $target_file"
    owner_is_user "$target_file" || die 'Target runtime bukan milik user aktif.'
fi

source_sha="$(sha256sum -- "$source_file" | awk '{print $1}')"
[[ $source_sha =~ ^[0-9a-f]{64}$ ]] || die 'Tidak dapat menghitung checksum source.'

if [[ -f $target_file ]] && cmp -s -- "$source_file" "$target_file"; then
    info 'Bottombar K41 sudah terpasang dan identik dengan source kanonis.'
    info "Runtime: $target_file"
    exit 0
fi

state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
[[ $state_home == /* ]] || die 'XDG_STATE_HOME harus berupa path absolut.'
for path in "$state_home" "$state_home/k41" "$state_home/k41/backups" "$state_home/k41/backups/bottombar"; do
    [[ ! -L $path ]] || die "Symlink pada backup path ditolak: $path"
    if [[ -e $path ]]; then
        [[ -d $path ]] || die "Backup path bukan direktori: $path"
        owner_is_user "$path" || die "Backup path bukan milik user aktif: $path"
    fi
done

mkdir -p -- "$module_dir" "$state_home/k41/backups/bottombar"
chmod 0700 "$state_home/k41/backups/bottombar"

stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
backup_root="$state_home/k41/backups/bottombar/$stamp"
suffix=0
while :; do
    if mkdir -- "$backup_root" 2>/dev/null; then break; fi
    [[ -e $backup_root || -L $backup_root ]] ||
        die "Tidak dapat membuat direktori backup: $backup_root"
    suffix=$((suffix + 1))
    backup_root="$state_home/k41/backups/bottombar/$stamp-$suffix"
done
chmod 0700 "$backup_root"

had_target=0
if [[ -f $target_file ]]; then
    had_target=1
    cp -a -- "$target_file" "$backup_root/Dock.Qml"
    previous_sha="$(sha256sum -- "$target_file" | awk '{print $1}')"
else
    previous_sha='ABSENT'
fi

{
    printf 'target=%s\n' "$target_file"
    printf 'previous_sha256=%s\n' "$previous_sha"
    printf 'source_sha256=%s\n' "$source_sha"
    printf 'deployment_namespace=k41\n'
} >"$backup_root/manifest.txt"
chmod 0600 "$backup_root/manifest.txt"

temp_file=''
mutation_started=0
rollback() {
    local rc=$1
    trap - EXIT
    if (( rc != 0 && mutation_started )); then
        if (( had_target )); then
            local restore_tmp
            restore_tmp="$(mktemp "$module_dir/.Dock.restore.XXXXXX")" || {
                printf 'CRITICAL: gagal membuat file restore; backup tersedia di %s\n' "$backup_root" >&2
                exit "$rc"
            }
            if cp -a -- "$backup_root/Dock.Qml" "$restore_tmp" &&
                mv -fT -- "$restore_tmp" "$target_file"; then
                printf 'ROLLBACK: target dipulihkan dari %s\n' "$backup_root" >&2
            else
                rm -f -- "$restore_tmp"
                printf 'CRITICAL: rollback gagal; backup tersedia di %s\n' "$backup_root" >&2
            fi
        else
            rm -f -- "$target_file"
            printf 'ROLLBACK: file baru dihapus setelah verifikasi gagal.\n' >&2
        fi
    fi
    [[ -z $temp_file ]] || rm -f -- "$temp_file"
    exit "$rc"
}
trap 'rollback $?' EXIT

temp_file="$(mktemp "$module_dir/.Dock.install.XXXXXX")"
install -m 0644 -- "$source_file" "$temp_file"
cmp -s -- "$source_file" "$temp_file" || die 'Verifikasi staging gagal.'
mutation_started=1
mv -fT -- "$temp_file" "$target_file"
temp_file=''

[[ -f $target_file && ! -L $target_file ]] || die 'Target tidak valid setelah deployment.'
cmp -s -- "$source_file" "$target_file" || die 'Content target tidak cocok setelah deployment.'
[[ $(stat -c %a -- "$target_file") == 644 ]] || die 'Mode permission target tidak sesuai.'

mutation_started=0
trap - EXIT
info "Bottombar berhasil dipasang/diperbaiki pada namespace K41: $target_file"
info "Source kanonis: $source_file"
info "Backup privat: $backup_root"
info 'Tidak ada perubahan pada Caelestia shell.qml/shell.json, paket, service, atau konfigurasi system-wide.'
info 'Quickshell tidak di-reload atau di-restart; host-loading contract tetap ditangani terpisah.'
