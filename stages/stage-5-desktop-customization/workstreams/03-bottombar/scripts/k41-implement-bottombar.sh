#!/usr/bin/env bash
# Deploy the canonical K41 Bottombar and migrate its Caelestia host reference.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\n' "$*"; }
owned() { [[ $(stat -c %u -- "$1") == "$EUID" ]]; }

[[ $# -eq 0 ]] || die 'Script ini tidak menerima opsi.'
(( EUID != 0 )) || die 'Jalankan sebagai user desktop biasa, tanpa sudo.'
[[ -n ${HOME:-} && $HOME == /* && -d $HOME ]] || die 'HOME tidak valid.'
for cmd in git dirname install cp cmp sha256sum stat mkdir chmod mktemp mv rm date awk grep; do
    command -v "$cmd" >/dev/null 2>&1 || die "Command wajib tidak tersedia: $cmd"
done

script_dir="$(cd -- "$(dirname -- "$0")" && pwd -P)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)" || die 'Git checkout tidak ditemukan.'
repo_root="$(cd -- "$repo_root" && pwd -P)"
source_file="$repo_root/stages/stage-5-desktop-customization/workstreams/03-bottombar/modules/bottombar/Dock.qml"
[[ -f $source_file && ! -L $source_file ]] || die "Source canonical tidak tersedia: $source_file"
owned "$source_file" || die 'Source canonical bukan milik user aktif.'

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
[[ $config_home == /* && -d $config_home && ! -L $config_home ]] || die 'XDG_CONFIG_HOME tidak aman atau tidak tersedia.'
owned "$config_home" || die 'XDG_CONFIG_HOME bukan milik user aktif.'
qs_root="$config_home/quickshell"
caelestia_root="$qs_root/caelestia"
shell_file="$caelestia_root/shell.qml"
[[ -d $qs_root && ! -L $qs_root && -d $caelestia_root && ! -L $caelestia_root ]] ||
    die 'Direktori Quickshell/Caelestia tidak tersedia atau berupa symlink.'
[[ -f $shell_file && ! -L $shell_file ]] || die 'Caelestia shell.qml tidak tersedia atau bukan regular file.'
owned "$qs_root" && owned "$caelestia_root" && owned "$shell_file" || die 'Host Caelestia bukan milik user aktif.'

# Primary module location is inside the active Caelestia config root so qs.* imports resolve.
caelestia_k41_root="$caelestia_root/k41"
caelestia_modules_root="$caelestia_k41_root/modules"
module_root="$caelestia_modules_root/bottombar"
target_file="$module_root/Dock.qml"
# Compatibility mirror retained at the historical sibling namespace.
legacy_runtime_root="$qs_root/k41"
legacy_modules_root="$legacy_runtime_root/modules"
legacy_module_root="$legacy_modules_root/bottombar"
legacy_target_file="$legacy_module_root/Dock.qml"
legacy_case_file="$module_root/Dock.Qml"

# K41 is a module namespace hosted by Caelestia, not a standalone Quickshell
# configuration. Do not create or silently adopt standalone entry points.
for standalone_entry in "$runtime_root/shell.qml" "$runtime_root/qmldir" \
                        "$modules_root/qmldir" "$module_root/qmldir"; do
    [[ ! -e $standalone_entry && ! -L $standalone_entry ]] ||
        die "Arsitektur K41 module-only tidak cocok: temukan entry point qmldir/shell: $standalone_entry. Review manual diperlukan."
done

# Dock.qml is the sole canonical runtime filename. Preserve any pre-existing
# case-variant file for explicit user-managed cleanup; never deploy to it.
legacy_case_present=0
legacy_case_sha=''
if [[ -e $legacy_case_file || -L $legacy_case_file ]]; then
    [[ -f $legacy_case_file && ! -L $legacy_case_file ]] ||
        die 'Legacy Dock.Qml bukan regular file atau berupa symlink; tidak ada perubahan.'
    owned "$legacy_case_file" || die 'Legacy Dock.Qml bukan milik user aktif.'
    legacy_case_present=1
    legacy_case_sha="$(sha256sum -- "$legacy_case_file" | awk '{print $1}')"
fi

for path in "$legacy_runtime_root" "$legacy_modules_root" "$legacy_module_root"; do
    [[ ! -L $path ]] || die "Symlink runtime ditolak: $path"
    if [[ -e $path ]]; then
        [[ -d $path ]] || die "Path runtime bukan direktori: $path"
        owned "$path" || die "Direktori runtime bukan milik user aktif: $path"
    fi
done
for path in "$caelestia_k41_root" "$caelestia_modules_root" "$module_root"; do
    [[ ! -L $path ]] || die "Symlink runtime ditolak: $path"
    if [[ -e $path ]]; then
        [[ -d $path ]] || die "Path runtime bukan direktori: $path"
        owned "$path" || die "Direktori runtime bukan milik user aktif: $path"
    fi
done
if [[ -e $legacy_target_file || -L $legacy_target_file ]]; then
    [[ -f $legacy_target_file && ! -L $legacy_target_file ]] || die 'Legacy mirror target bukan regular file.'
    owned "$legacy_target_file" || die 'Legacy mirror target bukan milik user aktif.'
fi
if [[ -e $target_file || -L $target_file ]]; then
    [[ -f $target_file && ! -L $target_file ]] || die 'Target Dock.qml bukan regular file.'
    owned "$target_file" || die 'Target Dock.qml bukan milik user aktif.'
fi

old_import='import "modules/k41dock" as K41Dock'
new_import='import qs.k41.modules.bottombar as K41Bottombar'
old_import_n="$(grep -Ec '^[[:space:]]*import[[:space:]]+"modules/k41dock"[[:space:]]+as[[:space:]]+K41Dock[[:space:]]*$' "$shell_file" || true)"
new_import_n="$(grep -Ec '^[[:space:]]*import[[:space:]]+"\.\./k41/modules/bottombar"[[:space:]]+as[[:space:]]+K41Bottombar[[:space:]]*$' "$shell_file" || true)"
old_instance_n="$(grep -Ec '^[[:space:]]*K41Dock\.K41Dock[[:space:]]*\{[[:space:]]*\}[[:space:]]*$' "$shell_file" || true)"
new_instance_n="$(grep -Ec '^[[:space:]]*K41Bottombar\.Dock[[:space:]]*\{[[:space:]]*\}[[:space:]]*$' "$shell_file" || true)"
host_change=0
if [[ $old_import_n == 1 && $old_instance_n == 1 && $new_import_n == 0 && $new_instance_n == 0 ]]; then
    host_change=1
elif [[ $new_import_n == 1 && $new_instance_n == 1 && $old_import_n == 0 && $old_instance_n == 0 ]]; then
    :
else
    die 'shell.qml bukan pasangan legacy K41Dock atau integrasi K41 baru yang dikenali; tidak ada perubahan.'
fi

source_sha="$(sha256sum -- "$source_file" | awk '{print $1}')"
module_matches=0
if [[ -f $target_file && -f $legacy_target_file ]] &&
   cmp -s -- "$source_file" "$target_file" && cmp -s -- "$source_file" "$legacy_target_file"; then module_matches=1; fi
if (( module_matches && ! host_change )); then
    info 'Modul canonical dan integrasi Caelestia sudah sesuai; tidak ada perubahan.'
    exit 0
fi

state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
[[ $state_home == /* ]] || die 'XDG_STATE_HOME harus absolut.'
backup_parent="$state_home/k41/backups/bottombar"
for path in "$state_home" "$state_home/k41" "$state_home/k41/backups" "$backup_parent"; do
    [[ ! -L $path ]] || die "Symlink backup ditolak: $path"
    if [[ -e $path ]]; then
        [[ -d $path ]] || die "Path backup bukan direktori: $path"
        owned "$path" || die "Path backup bukan milik user aktif: $path"
    fi
done
mkdir -p -- "$module_root" "$legacy_module_root" "$backup_parent"
chmod 0700 "$backup_parent"
stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
backup_root="$backup_parent/$stamp"
n=0
while ! mkdir -- "$backup_root" 2>/dev/null; do
    [[ -e $backup_root || -L $backup_root ]] || die 'Gagal membuat backup directory.'
    n=$((n + 1))
    backup_root="$backup_parent/$stamp-$n"
done
chmod 0700 "$backup_root"

had_module=0
if [[ -f $target_file ]]; then
    had_module=1
    cp -a -- "$target_file" "$backup_root/Dock.qml"
    previous_module_sha="$(sha256sum -- "$target_file" | awk '{print $1}')"
else
    previous_module_sha=ABSENT
fi
cp -a -- "$shell_file" "$backup_root/shell.qml"
previous_shell_sha="$(sha256sum -- "$shell_file" | awk '{print $1}')"
{
    printf 'module_target=%s\nmodule_previous_sha256=%s\nmodule_source_sha256=%s\n' "$target_file" "$previous_module_sha" "$source_sha"
    printf 'host_target=%s\nhost_previous_sha256=%s\n' "$shell_file" "$previous_shell_sha"
    printf 'host_import=%s\nhost_instance=K41Bottombar.Dock {}\n' "$new_import"
} >"$backup_root/manifest.txt"
chmod 0600 "$backup_root/manifest.txt"

module_tmp=''
shell_tmp=''
module_replaced=0
shell_replaced=0
rollback() {
    local rc=$1 restore
    trap - EXIT
    if (( rc != 0 )); then
        if (( shell_replaced )); then
            restore="$(mktemp "$caelestia_root/.shell.restore.XXXXXX")" || {
                printf 'CRITICAL: shell.qml gagal dipulihkan; backup %s\n' "$backup_root" >&2; exit "$rc";
            }
            if cp -a -- "$backup_root/shell.qml" "$restore" && mv -fT -- "$restore" "$shell_file"; then
                printf 'ROLLBACK: shell.qml dipulihkan.\n' >&2
            else
                rm -f -- "$restore"; printf 'CRITICAL: rollback shell.qml gagal; backup %s\n' "$backup_root" >&2
            fi
        fi
        if (( module_replaced )); then
            if (( had_module )); then
                restore="$(mktemp "$module_root/.Dock.restore.XXXXXX")" || {
                    printf 'CRITICAL: Dock.qml gagal dipulihkan; backup %s\n' "$backup_root" >&2; exit "$rc";
                }
                if cp -a -- "$backup_root/Dock.qml" "$restore" && mv -fT -- "$restore" "$target_file"; then
                    printf 'ROLLBACK: Dock.qml dipulihkan.\n' >&2
                else
                    rm -f -- "$restore"; printf 'CRITICAL: rollback Dock.qml gagal; backup %s\n' "$backup_root" >&2
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

module_tmp="$(mktemp "$module_root/.Dock.install.XXXXXX")"
install -m 0644 -- "$source_file" "$module_tmp"
cmp -s -- "$source_file" "$module_tmp" || die 'Staging Dock.qml gagal diverifikasi.'
if (( host_change )); then
    shell_tmp="$(mktemp "$caelestia_root/.shell.install.XXXXXX")"
    awk -v replacement="$new_import" '
        $0 ~ /^[[:space:]]*import[[:space:]]+"modules\/k41dock"[[:space:]]+as[[:space:]]+K41Dock[[:space:]]*$/ {
            print replacement
            next
        }
        $0 ~ /^[[:space:]]*K41Dock\.K41Dock[[:space:]]*\{[[:space:]]*\}[[:space:]]*$/ {
            print "K41Bottombar.Dock {}"
            next
        }
        { print }
    ' "$shell_file" >"$shell_tmp"
    chmod --reference="$shell_file" "$shell_tmp"
    grep -Eq '^[[:space:]]*import "\.\./k41/modules/bottombar" as K41Bottombar[[:space:]]*$' "$shell_tmp" ||
        die 'Staging shell.qml tidak memiliki import K41 baru.'
    grep -Eq '^[[:space:]]*K41Bottombar\.Dock[[:space:]]*\{[[:space:]]*\}[[:space:]]*$' "$shell_tmp" ||
        die 'Staging shell.qml tidak memiliki instance Dock baru.'
fi

module_replaced=1
mv -fT -- "$module_tmp" "$target_file"
module_tmp=''
[[ -f $target_file && ! -L $target_file ]] || die 'Target Dock.qml tidak valid setelah deployment.'
cmp -s -- "$source_file" "$target_file" || die 'Content Dock.qml tidak cocok setelah deployment.'
legacy_tmp="$(mktemp "$legacy_module_root/.Dock.qml.mirror.XXXXXX")"
install -m 0644 -- "$source_file" "$legacy_tmp"
cmp -s -- "$source_file" "$legacy_tmp" || { rm -f -- "$legacy_tmp"; die 'Staging compatibility mirror gagal diverifikasi.'; }
mv -fT -- "$legacy_tmp" "$legacy_target_file"
cmp -s -- "$source_file" "$legacy_target_file" || die 'Compatibility mirror Dock.qml tidak cocok setelah deployment.'
[[ $(stat -c %a -- "$target_file") == 644 ]] || die 'Permission Dock.qml bukan 0644.'
if (( legacy_case_present )); then
    [[ -f $legacy_case_file && ! -L $legacy_case_file ]] ||
        die 'Dock.Qml berubah tipe selama deployment; periksa runtime secara manual.'
    [[ $(sha256sum -- "$legacy_case_file" | awk '{print $1}') == "$legacy_case_sha" ]] ||
        die 'Dock.Qml berubah selama deployment; file tidak disentuh oleh installer.'
fi
if (( host_change )); then
    shell_replaced=1
    mv -fT -- "$shell_tmp" "$shell_file"
    shell_tmp=''
    grep -Eq '^[[:space:]]*import "\.\./k41/modules/bottombar" as K41Bottombar[[:space:]]*$' "$shell_file" ||
        die 'Import K41 tidak ditemukan setelah update shell.qml.'
    grep -Eq '^[[:space:]]*K41Bottombar\.Dock[[:space:]]*\{[[:space:]]*\}[[:space:]]*$' "$shell_file" ||
        die 'Instance Dock tidak ditemukan setelah update shell.qml.'
fi

module_replaced=0
shell_replaced=0
trap - EXIT
info "Module K41 aktif: $target_file"
info "Compatibility mirror: $legacy_target_file"
if (( legacy_case_present )); then
    info "Legacy case-variant preserved unchanged: $legacy_case_file"
    info 'Hapus Dock.Qml secara manual hanya setelah Dock.qml diverifikasi aktif.'
fi
info "Caelestia host: $shell_file"
info "Backup privat: $backup_root"
info 'Arsitektur: Caelestia adalah shell host; K41 hanya menyediakan modul Dock.qml.'
info 'Tidak membuat shell.qml, qmldir, atau konfigurasi Quickshell mandiri di namespace K41.'
info 'Integrasi memakai relative import qs.k41.modules.bottombar dan K41Bottombar.Dock {}.'
info 'File legacy k41dock tidak dihapus; cleanup dilakukan terpisah setelah runtime verification.'
info 'Quickshell tidak di-reload atau di-restart.'
