#!/usr/bin/env bash
# Install or repair only the K41 Bottombar QML module.
set -Eeuo pipefail
umask 077

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

info() {
    printf 'INFO: %s\n' "$*"
}

[[ $# -eq 0 ]] || die 'Script ini hanya menjalankan install/repair; tidak menerima opsi.'
(( EUID != 0 )) || die 'Jalankan sebagai user desktop biasa, tanpa sudo.'
[[ -n ${HOME:-} && $HOME == /* && -d $HOME ]] || die 'HOME tidak valid.'

for cmd in git install cp cmp sha256sum stat mkdir chmod mktemp mv date grep awk; do
    command -v "$cmd" >/dev/null 2>&1 || die "Command wajib tidak tersedia: $cmd"
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)" ||
    die 'Tidak dapat menemukan Git repository.'
repo_root="$(cd -- "$repo_root" && pwd -P)"

source_file="$repo_root/stages/stage-5-desktop-customization/workstreams/03-bottombar/modules/bottombar/Dock.Qml"
[[ -f $source_file && ! -L $source_file ]] || die "Source Bottombar tidak tersedia atau symlink: $source_file"
[[ $(stat -c %u -- "$source_file") == "$EUID" ]] || die 'Source QML bukan milik user aktif.'

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
[[ $config_home == /* && -d $config_home && ! -L $config_home ]] ||
    die 'XDG_CONFIG_HOME harus berupa direktori absolut yang sudah ada dan bukan symlink.'
[[ $(stat -c %u -- "$config_home") == "$EUID" ]] ||
    die 'XDG_CONFIG_HOME bukan milik user aktif.'

quickshell_dir="$config_home/quickshell"
[[ -d $quickshell_dir && ! -L $quickshell_dir ]] || die "Quickshell user config directory tidak ditemukan atau tidak aman: $quickshell_dir"
[[ $(stat -c %u -- "$quickshell_dir") == "$EUID" ]] || die "Quickshell user config directory bukan milik user aktif."
runtime_root="$quickshell_dir/caelestia"
shell_file="$runtime_root/shell.qml"
[[ -d $runtime_root && ! -L $runtime_root ]] ||
    die "Caelestia user runtime tidak ditemukan atau tidak aman: $runtime_root"
[[ $(stat -c %u -- "$runtime_root") == "$EUID" ]] ||
    die 'Caelestia user runtime bukan milik user aktif.'
[[ -f $shell_file && ! -L $shell_file ]] ||
    die 'shell.qml tidak ditemukan atau berupa symlink; deployment dibatalkan.'

# The audited host already imports modules/k41dock and instantiates
# K41Dock.K41Dock. Preserve that contract; do not edit shell.qml or shell.json.
grep -Fq 'import "modules/k41dock" as K41Dock' "$shell_file" ||
    die 'Host import K41Dock tidak cocok dengan hasil audit; tidak mengubah integrasi host.'
grep -Fq 'K41Dock.K41Dock {' "$shell_file" ||
    die 'Host component K41Dock tidak ditemukan; tidak mengubah integrasi host.'

modules_dir="$runtime_root/modules"
module_dir="$modules_dir/k41dock"
target_file="$module_dir/K41Dock.qml"

for path in "$modules_dir" "$module_dir"; do
    if [[ -L $path ]]; then
        die "Symlink pada direktori runtime ditolak: $path"
    fi
    if [[ -e $path ]]; then
        [[ -d $path ]] || die "Path runtime bukan direktori: $path"
        [[ $(stat -c %u -- "$path") == "$EUID" ]] ||
            die "Direktori runtime bukan milik user aktif: $path"
    fi
done

if [[ -e $target_file || -L $target_file ]]; then
    [[ -f $target_file && ! -L $target_file ]] ||
        die "Target runtime bukan regular file atau berupa symlink: $target_file"
    [[ $(stat -c %u -- "$target_file") == "$EUID" ]] ||
        die 'Target runtime bukan milik user aktif.'
fi

source_sha="$(sha256sum -- "$source_file" | awk '{print $1}')"
[[ $source_sha =~ ^[0-9a-f]{64}$ ]] || die 'Tidak dapat menghitung checksum source.'

if [[ -f $target_file ]] && cmp -s -- "$source_file" "$target_file"; then
    info 'Bottombar sudah terpasang dan sesuai source; tidak ada perubahan.'
    exit 0
fi

state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
[[ $state_home == /* ]] || die 'XDG_STATE_HOME harus berupa path absolut.'
for path in "$HOME/.local" "$state_home" "$state_home/k41" "$state_home/k41/backups" "$state_home/k41/backups/bottombar"; do
    [[ ! -L $path ]] || die "Symlink pada backup path ditolak: $path"
    if [[ -e $path ]]; then
        [[ -d $path ]] || die "Backup path bukan direktori: $path"
        [[ $(stat -c %u -- "$path") == "$EUID" ]] ||
            die "Backup path bukan milik user aktif: $path"
    fi
done

mkdir -p -- "$module_dir" "$state_home/k41/backups/bottombar"
chmod 0700 "$state_home/k41" "$state_home/k41/backups" "$state_home/k41/backups/bottombar"

stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
backup_root="$state_home/k41/backups/bottombar/$stamp"
suffix=0
while ! mkdir -- "$backup_root" 2>/dev/null; do
    suffix=$((suffix + 1))
    backup_root="$state_home/k41/backups/bottombar/$stamp-$suffix"
done
chmod 0700 "$backup_root"

had_target=0
if [[ -f $target_file ]]; then
    had_target=1
    cp -a -- "$target_file" "$backup_root/K41Dock.qml"
    previous_sha="$(sha256sum -- "$target_file" | awk '{print $1}')"
else
    previous_sha='ABSENT'
fi

{
    printf 'target=%s\n' "$target_file"
    printf 'previous_sha256=%s\n' "$previous_sha"
    printf 'source_sha256=%s\n' "$source_sha"
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
            restore_tmp="$(mktemp "$module_dir/.K41Dock.restore.XXXXXX")" || {
                printf 'CRITICAL: gagal membuat file restore; backup tersedia di %s\n' "$backup_root" >&2
                exit "$rc"
            }
            if cp -a -- "$backup_root/K41Dock.qml" "$restore_tmp" &&
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

temp_file="$(mktemp "$module_dir/.K41Dock.install.XXXXXX")"
install -m 0644 -- "$source_file" "$temp_file"
cmp -s -- "$source_file" "$temp_file" || die 'Verifikasi staging gagal.'
mutation_started=1
mv -fT -- "$temp_file" "$target_file"
temp_file=''

[[ -f $target_file && ! -L $target_file ]] || die 'Target tidak valid setelah deployment.'
cmp -s -- "$source_file" "$target_file" || die 'Checksum/content target tidak cocok setelah deployment.'
[[ $(stat -c %a -- "$target_file") == 644 ]] || die 'Mode permission target tidak sesuai.'
mutation_started=0
trap - EXIT

info "Bottombar berhasil dipasang/diperbaiki: $target_file"
info "Source kanonis: $source_file"
info "Backup privat: $backup_root"
info 'shell.qml, shell.json, paket, service, dan konfigurasi system-wide tidak diubah.'
info 'Quickshell tidak di-reload atau di-restart.'
