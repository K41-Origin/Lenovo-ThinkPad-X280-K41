#!/usr/bin/env bash
# Deploy the K41-owned Bottombar module and point the existing Caelestia host to it.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\n' "$*"; }
owner_is_user() { [[ $(stat -c %u -- "$1") == "$EUID" ]]; }

[[ $# -eq 0 ]] || die 'Script ini hanya menjalankan install/repair; tidak menerima opsi.'
(( EUID != 0 )) || die 'Jalankan sebagai user desktop biasa, tanpa sudo.'
[[ -n ${HOME:-} && $HOME == /* && -d $HOME ]] || die 'HOME tidak valid.'

for cmd in git install cp cmp sha256sum stat mkdir chmod mktemp mv rm date awk grep; do
    command -v "$cmd" >/dev/null 2>&1 || die "Command wajib tidak tersedia: $cmd"
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)" ||
    die 'Tidak dapat menemukan Git repository.'
repo_root="$(cd -- "$repo_root" && pwd -P)"

source_file="$repo_root/stages/stage-5-desktop-customization/workstreams/03-bottombar/modules/bottombar/Dock.qml"
[[ -f $source_file && ! -L $source_file ]] || die "Source Bottombar tidak tersedia atau symlink: $source_file"
owner_is_user "$source_file" || die 'Source QML bukan milik user aktif.'

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
[[ $config_home == /* && -d $config_home && ! -L $config_home ]] ||
    die 'XDG_CONFIG_HOME harus berupa direktori absolut yang sudah ada dan bukan symlink.'
owner_is_user "$config_home" || die 'XDG_CONFIG_HOME bukan milik user aktif.'

quickshell_dir="$config_home/quickshell"
caelestia_dir="$quickshell_dir/caelestia"
shell_file="$caelestia_dir/shell.qml"
[[ -d $quickshell_dir && ! -L $quickshell_dir ]] ||
    die "Quickshell user config directory tidak ditemukan atau tidak aman: $quickshell_dir"
[[ -d $caelestia_dir && ! -L $caelestia_dir ]] ||
    die "Caelestia host directory tidak ditemukan atau tidak aman: $caelestia_dir"
[[ -f $shell_file && ! -L $shell_file ]] ||
    die "Caelestia shell.qml tidak ditemukan atau bukan regular file: $shell_file"
owner_is_user "$quickshell_dir" && owner_is_user "$caelestia_dir" && owner_is_user "$shell_file" ||
    die 'Quickshell/Caelestia host path bukan milik user aktif.'

runtime_root="$quickshell_dir/k41"
modules_dir="$runtime_root/modules"
module_dir="$modules_dir/bottombar"
target_file="$module_dir/Dock.qml"
for path in "$runtime_root" "$modules_dir" "$module_dir"; do
    [[ ! -L $path ]] || die "Symlink pada direktori runtime ditolak: $path"
    if [[ -e $path ]]; then
        [[ -d $path ]] || die "Path runtime bukan direktori: $path"
        owner_is_user "$path" || die "Direktori runtime bukan milik user aktif: $path"
    fi
done
if [[ -e $target_file || -L $target_file ]]; then
    [[ -f $target_file && ! -L $target_file ]] || die "Target runtime bukan regular file: $target_file"
    owner_is_user "$target_file" || die 'Target runtime bukan milik user aktif.'
fi

# Accept only the known legacy integration or the exact new integration.
legacy_import='import "modules/k41dock" as K41Dock'
new_import='import "../k41/modules/bottombar" as K41Bottombar'
legacy_instance='K41Dock.K41Dock {}'
new_instance='K41Bottombar.Dock {}'
import_legacy_count="$(grep -Ec '^[[:space:]]*import[[:space:]]+"modules/k41dock"[[:space:]]+as[[:space:]]+K41Dock[[:space:]]*$' "$shell_file" || true)"
instance_legacy_count="$(grep -Ec '^[[:space:]]*K41Dock\.K41Dock[[:space:]]*\{[[:space:]]*\}[[:space:]]*$' "$shell_file" || true)"
import_new_count="$(grep -Ec '^[[:space:]]*import[[:space:]]+"\.\./k41/modules/bottombar"[[:space:]]+as[[:space:]]+K41Bottombar[[:space:]]*$' "$shell_file" || true)"
instance_new_count="$(grep -Ec '^[[:space:]]*K41Bottombar\.Dock[[:space:]]*\{[[:space:]]*\}[[:space:]]*$' "$shell_file" || true)"

host_change=0
if [[ $import_legacy_count == 1 && $instance_legacy_count == 1 &&
      $import_new_count == 0 && $instance_new_count == 0 ]]; then
    host_change=1
elif [[ $import_new_count == 1 && $instance_new_count == 1 &&
        $import_legacy_count == 0 && $instance_legacy_count == 0 ]]; then
    host_change=0
else
    die 'Integrasi shell.qml tidak cocok dengan pola legacy K41Dock atau target K41; tidak ada perubahan dilakukan.'
fi

source_sha="$(sha256sum -- "$source_file" | awk '{print $1}')"
[[ $source_sha =~ ^[0-9a-f]{64}$ ]] || die 'Tidak dapat menghitung checksum source.'
module_matches=0
if [[ -f $target_file ]] && cmp -s -- "$source_file" "$target_file"; then module_matches=1; fi
if (( module_matches == 1 && host_change == 0 )); then
    info 'Bottombar K41 sudah terpasang dan Caelestia sudah mengimpor modul canonical K41.'
    info "Module: $target_file"
    info "Host: $shell_file"
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
    [[ -e $backup_root || -L $backup_root ]] || die "Tidak dapat membuat direktori backup: $backup_root"
    suffix=$((suffix + 1))
    backup_root="$state_home/k41/backups/bottombar/$stamp-$suffix"
done
chmod 0700 "$backup_root"

had_module=0
if [[ -f $target_file ]]; then
    had_module=1
    cp -a -- "$target_file" "$backup_root/Dock.qml"
    previous_module_sha="$(sha256sum -- "$target_file" | awk '{print $1}')"
else
    previous_module_sha='ABSENT'
fi
cp -a -- "$shell_file" "$backup_root/shell.qml"
previous_shell_sha="$(sha256sum -- "$shell_file" | awk '{print $1}')"

{
    printf 'module_target=%s\n' "$target_file"
    printf 'module_previous_sha256=%s\n' "$previous_module_sha"
    printf 'module_source_sha256=%s\n' "$source_sha"
    printf 'host_target=%s\n' "$shell_file"
    printf 'host_previous_sha256=%s\n' "$previous_shell_sha"
    printf 'host_integration=Caelestia imports ../k41/modules/bottombar as K41Bottombar; instantiates K41Bottombar.Dock\n'
} >"$backup_root/manifest.txt"
chmod 0600 "$backup_root/manifest.txt"

module_tmp=''
shell_tmp=''
module_mutated=0
shell_mutated=0
rollback() {
    local rc=$1
    trap - EXIT
    if (( rc != 0 )); then
        if (( shell_mutated )); then
            local restore_shell
            restore_shell="$(mktemp "$caelestia_dir/.shell.restore.XXXXXX")" || {
                printf 'CRITICAL: gagal menyiapkan restore shell.qml; backup: %s\n' "$backup_root" >&2
                exit "$rc"
            }
            if cp -a -- "$backup_root/shell.qml" "$restore_shell" &&
                mv -fT -- "$restore_shell" "$shell_file"; then
                printf 'ROLLBACK: shell.qml dipulihkan.\n' >&2
            else
                rm -f -- "$restore_shell"
                printf 'CRITICAL: rollback shell.qml gagal; backup: %s\n' "$backup_root" >&2
            fi
        fi
        if (( module_mutated )); then
            if (( had_module )); then
                local restore_module
                restore_module="$(mktemp "$module_dir/.Dock.restore.XXXXXX")" || {
                    printf 'CRITICAL: gagal menyiapkan restore Dock.qml; backup: %s\n' "$backup_root" >&2
                    exit "$rc"
                }
                if cp -a -- "$backup_root/Dock.qml" "$restore_module" &&
                    mv -fT -- "$restore_module" "$target_file"; then
                    printf 'ROLLBACK: Dock.qml dipulihkan.\n' >&2
                else
                    rm -f -- "$restore_module"
                    printf 'CRITICAL: rollback Dock.qml gagal; backup: %s\n' "$backup_root" >&2
                fi
            else
                rm -f -- "$target_file"
                printf 'ROLLBACK: Dock.qml baru dihapus.\n' >&2
            fi
        fi
    fi
    [[ -z $module_tmp ]] || rm -f -- "$module_tmp"
    [[ -z $shell_tmp ]] || rm -f -- "$shell_tmp"
    exit "$rc"
}
trap 'rollback $?' EXIT

module_tmp="$(mktemp "$module_dir/.Dock.install.XXXXXX")"
install -m 0644 -- "$source_file" "$module_tmp"
cmp -s -- "$source_file" "$module_tmp" || die 'Verifikasi staging Dock.qml gagal.'

if (( host_change )); then
    shell_tmp="$(mktemp "$caelestia_dir/.shell.install.XXXXXX")"
    awk -v old_import="$legacy_import" -v new_import="$new_import" \
        -v old_instance="$legacy_instance" -v new_instance="$new_instance" '
        $0 ~ /^[[:space:]]*import[[:space:]]+"modules\/k41dock"[[:space:]]+as[[:space:]]+K41Dock[[:space:]]*$/ { sub(/import "modules\/k41dock" as K41Dock/, new_import); }
        $0 ~ /^[[:space:]]*K41Dock\.K41Dock[[:space:]]*\{[[:space:]]*\}[[:space:]]*$/ { sub(/K41Dock\.K41Dock \{\}/, new_instance); }
        { print }
    ' "$shell_file" >"$shell_tmp"
    chmod --reference="$shell_file" "$shell_tmp"
    grep -Fqx "$new_import" "$shell_tmp" || die 'Staging shell.qml tidak memiliki import K41 baru.'
    grep -Eq '^[[:space:]]*K41Bottombar\.Dock[[:space:]]*\{[[:space:]]*\}[[:space:]]* || die 'Staging shell.qml tidak memiliki instance Dock baru.'
fi

# Commit module first, then host. Any failure restores every path already replaced.
module_mutated=1
mv -fT -- "$module_tmp" "$target_file"
module_tmp=''
[[ -f $target_file && ! -L $target_file ]] || die 'Target Dock.qml tidak valid setelah deployment.'
cmp -s -- "$source_file" "$target_file" || die 'Checksum/content Dock.qml tidak cocok setelah deployment.'
[[ $(stat -c %a -- "$target_file") == 644 ]] || die 'Mode permission Dock.qml tidak sesuai.'

if (( host_change )); then
    shell_mutated=1
    mv -fT -- "$shell_tmp" "$shell_file"
    shell_tmp=''
    grep -Fqx "$new_import" "$shell_file" || die 'Import K41 tidak ditemukan setelah update shell.qml.'
    grep -Eq '^[[:space:]]*K41Bottombar\.Dock[[:space:]]*\{[[:space:]]*\}[[:space:]]* || die 'Instance Dock tidak ditemukan setelah update shell.qml.'
fi

module_mutated=0
shell_mutated=0
trap - EXIT
info "Modul K41 terpasang: $target_file"
info "Caelestia host diarahkan ke modul K41: $shell_file"
info "Source kanonis: $source_file"
info "Backup privat: $backup_root"
info 'shell.qml tetap milik Caelestia; hanya import dan instance Bottombar K41 yang dimigrasikan.'
info 'File legacy k41dock tidak dihapus; cleanup harus dilakukan terpisah setelah runtime verification.'
info 'Quickshell tidak di-reload atau di-restart.'
 "$shell_tmp" || die 'Staging shell.qml tidak memiliki instance Dock baru.'
fi

# Commit module first, then host. Any failure restores every path already replaced.
module_mutated=1
mv -fT -- "$module_tmp" "$target_file"
module_tmp=''
[[ -f $target_file && ! -L $target_file ]] || die 'Target Dock.qml tidak valid setelah deployment.'
cmp -s -- "$source_file" "$target_file" || die 'Checksum/content Dock.qml tidak cocok setelah deployment.'
[[ $(stat -c %a -- "$target_file") == 644 ]] || die 'Mode permission Dock.qml tidak sesuai.'

if (( host_change )); then
    shell_mutated=1
    mv -fT -- "$shell_tmp" "$shell_file"
    shell_tmp=''
    grep -Fqx "$new_import" "$shell_file" || die 'Import K41 tidak ditemukan setelah update shell.qml.'
    grep -Fqx "$new_instance" "$shell_file" || die 'Instance Dock tidak ditemukan setelah update shell.qml.'
fi

module_mutated=0
shell_mutated=0
trap - EXIT
info "Modul K41 terpasang: $target_file"
info "Caelestia host diarahkan ke modul K41: $shell_file"
info "Source kanonis: $source_file"
info "Backup privat: $backup_root"
info 'shell.qml tetap milik Caelestia; hanya import dan instance Bottombar K41 yang dimigrasikan.'
info 'File legacy k41dock tidak dihapus; cleanup harus dilakukan terpisah setelah runtime verification.'
info 'Quickshell tidak di-reload atau di-restart.'
 "$shell_file" || die 'Instance Dock tidak ditemukan setelah update shell.qml.'
fi

module_mutated=0
shell_mutated=0
trap - EXIT
info "Modul K41 terpasang: $target_file"
info "Caelestia host diarahkan ke modul K41: $shell_file"
info "Source kanonis: $source_file"
info "Backup privat: $backup_root"
info 'shell.qml tetap milik Caelestia; hanya import dan instance Bottombar K41 yang dimigrasikan.'
info 'File legacy k41dock tidak dihapus; cleanup harus dilakukan terpisah setelah runtime verification.'
info 'Quickshell tidak di-reload atau di-restart.'
 "$shell_tmp" || die 'Staging shell.qml tidak memiliki instance Dock baru.'
fi

# Commit module first, then host. Any failure restores every path already replaced.
module_mutated=1
mv -fT -- "$module_tmp" "$target_file"
module_tmp=''
[[ -f $target_file && ! -L $target_file ]] || die 'Target Dock.qml tidak valid setelah deployment.'
cmp -s -- "$source_file" "$target_file" || die 'Checksum/content Dock.qml tidak cocok setelah deployment.'
[[ $(stat -c %a -- "$target_file") == 644 ]] || die 'Mode permission Dock.qml tidak sesuai.'

if (( host_change )); then
    shell_mutated=1
    mv -fT -- "$shell_tmp" "$shell_file"
    shell_tmp=''
    grep -Fqx "$new_import" "$shell_file" || die 'Import K41 tidak ditemukan setelah update shell.qml.'
    grep -Fqx "$new_instance" "$shell_file" || die 'Instance Dock tidak ditemukan setelah update shell.qml.'
fi

module_mutated=0
shell_mutated=0
trap - EXIT
info "Modul K41 terpasang: $target_file"
info "Caelestia host diarahkan ke modul K41: $shell_file"
info "Source kanonis: $source_file"
info "Backup privat: $backup_root"
info 'shell.qml tetap milik Caelestia; hanya import dan instance Bottombar K41 yang dimigrasikan.'
info 'File legacy k41dock tidak dihapus; cleanup harus dilakukan terpisah setelah runtime verification.'
info 'Quickshell tidak di-reload atau di-restart.'
