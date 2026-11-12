#!/usr/bin/env bash
# Install the standalone K41 Quickshell configuration without touching Caelestia.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\\n' "$*"; }
owned() { [[ $(stat -c %u -- "$1") == "$EUID" ]]; }

[[ $# -eq 0 ]] || die 'Script ini tidak menerima opsi.'
(( EUID != 0 )) || die 'Jalankan sebagai user desktop biasa, tanpa sudo.'
[[ -n ${HOME:-} && $HOME == /* && -d $HOME ]] || die 'HOME tidak valid.'
for cmd in git dirname install cp cmp sha256sum stat mkdir chmod mktemp mv rm date grep cut; do
    command -v "$cmd" >/dev/null 2>&1 || die "Command wajib tidak tersedia: $cmd"
done

script_dir="$(cd -- "$(dirname -- "$0")" && pwd -P)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)" || die 'Git checkout tidak ditemukan.'
repo_root="$(cd -- "$repo_root" && pwd -P)"
source_root="$repo_root/stages/stage-5-desktop-customization/workstreams/04-topbar"
source_shell="$source_root/shell.qml"
source_topbar="$source_root/modules/topbar/Topbar.qml"
for file in "$source_shell" "$source_topbar"; do
    [[ -f $file && ! -L $file ]] || die "Source canonical tidak tersedia/regular file: $file"
    owned "$file" || die "Source canonical bukan milik user aktif: $file"
done

# Standalone contract: refuse all known Caelestia runtime/service dependencies.
for file in "$source_shell" "$source_topbar"; do
    if grep -En 'Caelestia|qs\.services|ShellState|Notifs|Time\.format|ServiceRef|import[[:space:]]+qs\.' "$file"; then
        die "Dependency internal Caelestia/qs.* terdeteksi pada source: $file"
    fi
done
grep -Fq 'K41StandaloneTopbar' "$source_shell" || die 'Entry point tidak memiliki root marker K41StandaloneTopbar.'
grep -Fq 'K41StandaloneTopbar' "$source_topbar" || die 'Topbar tidak memiliki marker standalone K41.'

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
[[ $config_home == /* && -d $config_home && ! -L $config_home ]] || die 'XDG_CONFIG_HOME tidak aman atau tidak tersedia.'
owned "$config_home" || die 'XDG_CONFIG_HOME bukan milik user aktif.'
qs_root="$config_home/quickshell"
runtime_root="$qs_root/k41"
module_root="$runtime_root/modules/topbar"
target_shell="$runtime_root/shell.qml"
target_topbar="$module_root/Topbar.qml"

for path in "$qs_root" "$runtime_root" "$runtime_root/modules" "$module_root"; do
    [[ ! -L $path ]] || die "Symlink runtime ditolak: $path"
    if [[ -e $path ]]; then
        [[ -d $path ]] || die "Path runtime bukan direktori: $path"
        owned "$path" || die "Direktori runtime bukan milik user aktif: $path"
    fi
done
for file in "$target_shell" "$target_topbar"; do
    if [[ -e $file || -L $file ]]; then
        [[ -f $file && ! -L $file ]] || die "Target bukan regular file: $file"
        owned "$file" || die "Target bukan milik user aktif: $file"
    fi
done

state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
[[ $state_home == /* ]] || die 'XDG_STATE_HOME harus absolut.'
backup_parent="$state_home/k41/backups/topbar"
for path in "$state_home" "$state_home/k41" "$state_home/k41/backups" "$backup_parent"; do
    [[ ! -L $path ]] || die "Symlink backup ditolak: $path"
    if [[ -e $path ]]; then
        [[ -d $path ]] || die "Path backup bukan direktori: $path"
        owned "$path" || die "Path backup bukan milik user aktif: $path"
    fi
done

if [[ -f $target_shell && -f $target_topbar ]] &&
   cmp -s -- "$source_shell" "$target_shell" && cmp -s -- "$source_topbar" "$target_topbar"; then
    info 'Standalone K41 Topbar sudah sesuai; tidak ada perubahan.'
    exit 0
fi

mkdir -p -- "$module_root" "$backup_parent"
chmod 0700 "$backup_parent"
stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
backup_root="$backup_parent/$stamp"
n=0
while ! mkdir -- "$backup_root" 2>/dev/null; do
    [[ -e $backup_root || -L $backup_root ]] || die 'Gagal membuat direktori backup.'
    n=$((n + 1)); backup_root="$backup_parent/$stamp-$n"
done
chmod 0700 "$backup_root"

had_shell=0; had_topbar=0
if [[ -f $target_shell ]]; then had_shell=1; cp -a -- "$target_shell" "$backup_root/shell.qml"; fi
if [[ -f $target_topbar ]]; then had_topbar=1; cp -a -- "$target_topbar" "$backup_root/Topbar.qml"; fi
{
    printf 'target_shell=%s\\nsource_shell_sha256=%s\\n' "$target_shell" "$(sha256sum "$source_shell" | cut -d' ' -f1)"
    printf 'target_topbar=%s\\nsource_topbar_sha256=%s\\n' "$target_topbar" "$(sha256sum "$source_topbar" | cut -d' ' -f1)"
    printf 'previous_shell=%s\\nprevious_topbar=%s\\n' "$had_shell" "$had_topbar"
} >"$backup_root/manifest.txt"
chmod 0600 "$backup_root/manifest.txt"

shell_tmp=''; topbar_tmp=''; shell_replaced=0; topbar_replaced=0
rollback() {
    local rc=$1 restore
    trap - EXIT
    if (( rc != 0 )); then
        if (( topbar_replaced )); then
            if (( had_topbar )); then
                restore="$(mktemp "$module_root/.Topbar.restore.XXXXXX")"
                if cp -a "$backup_root/Topbar.qml" "$restore" && mv -fT "$restore" "$target_topbar"; then
                    printf 'ROLLBACK: Topbar.qml dipulihkan.\\n' >&2
                else rm -f "$restore"; printf 'CRITICAL: rollback Topbar.qml gagal; backup %s\\n' "$backup_root" >&2; fi
            else rm -f "$target_topbar"; fi
        fi
        if (( shell_replaced )); then
            if (( had_shell )); then
                restore="$(mktemp "$runtime_root/.shell.restore.XXXXXX")"
                if cp -a "$backup_root/shell.qml" "$restore" && mv -fT "$restore" "$target_shell"; then
                    printf 'ROLLBACK: shell.qml dipulihkan.\\n' >&2
                else rm -f "$restore"; printf 'CRITICAL: rollback shell.qml gagal; backup %s\\n' "$backup_root" >&2; fi
            else rm -f "$target_shell"; fi
        fi
    fi
    [[ -z $shell_tmp ]] || rm -f "$shell_tmp"
    [[ -z $topbar_tmp ]] || rm -f "$topbar_tmp"
    exit "$rc"
}
trap 'rollback $?' EXIT

shell_tmp="$(mktemp "$runtime_root/.shell.install.XXXXXX")"
topbar_tmp="$(mktemp "$module_root/.Topbar.install.XXXXXX")"
install -m 0644 -- "$source_shell" "$shell_tmp"
install -m 0644 -- "$source_topbar" "$topbar_tmp"
cmp -s "$source_shell" "$shell_tmp" || die 'Verifikasi staging shell.qml gagal.'
cmp -s "$source_topbar" "$topbar_tmp" || die 'Verifikasi staging Topbar.qml gagal.'

shell_replaced=1
mv -fT -- "$shell_tmp" "$target_shell"; shell_tmp=''
cmp -s "$source_shell" "$target_shell" || die 'Verifikasi shell.qml setelah install gagal.'
topbar_replaced=1
mv -fT -- "$topbar_tmp" "$target_topbar"; topbar_tmp=''
cmp -s "$source_topbar" "$target_topbar" || die 'Verifikasi Topbar.qml setelah install gagal.'
[[ $(stat -c %a "$target_shell") == 644 && $(stat -c %a "$target_topbar") == 644 ]] || die 'Permission file runtime bukan 0644.'

shell_replaced=0; topbar_replaced=0
trap - EXIT
info "Entry point mandiri: $target_shell"
info "Module K41: $target_topbar"
info "Backup privat: $backup_root"
info 'Tidak ada file di direktori Caelestia yang dibaca atau diubah.'
info 'Tidak melakukan reload/restart Quickshell atau mengubah autostart.'
info 'Jalankan manual setelah dependency dan kepemilikan NotificationServer diverifikasi: qs -c k41'
