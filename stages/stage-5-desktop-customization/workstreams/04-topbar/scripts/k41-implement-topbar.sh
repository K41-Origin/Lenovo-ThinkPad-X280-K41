#!/usr/bin/env bash
# Deploy the canonical K41 Topbar module and add its Caelestia host instance.
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
source_file="$repo_root/stages/stage-5-desktop-customization/workstreams/04-topbar/modules/topbar/Topbar.qml"
[[ -f $source_file && ! -L $source_file ]] || die 'Source canonical Topbar.qml tidak tersedia atau berupa symlink.'
owned "$source_file" || die 'Source canonical bukan milik user aktif.'

# Fail closed if the module stops using the backend services verified in the WS04 audit.
for contract in \
    'import Caelestia.Services' \
    'import Quickshell.Services.UPower' \
    'service: Cpu' \
    'service: Memory' \
    'Cpu.percentage' \
    'Memory.percentage' \
    'UPower.displayDevice.percentage' \
    'UPower.onBattery' \
    'Time.format(' \
    'Notifs.notClosed.length' \
    'ShellState.forScreen(modelData)'; do
    grep -Fq -- "$contract" "$source_file" || die "Kontrak backend Topbar tidak lengkap: $contract"
done
if grep -Eq '/proc/(stat|meminfo)|/sys/class/power_supply|new Date\\(|Timer[[:space:]]*\\{|NotificationServer|trayWindow' "$source_file"; then
    die 'Provider/polling duplikat terdeteksi pada Topbar.qml.'
fi

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
[[ $config_home == /* && -d $config_home && ! -L $config_home ]] || die 'XDG_CONFIG_HOME tidak aman atau tidak tersedia.'
owned "$config_home" || die 'XDG_CONFIG_HOME bukan milik user aktif.'
qs_root="$config_home/quickshell"
caelestia_root="$qs_root/caelestia"
shell_file="$caelestia_root/shell.qml"
[[ -d $qs_root && ! -L $qs_root && -d $caelestia_root && ! -L $caelestia_root ]] || die 'Direktori Quickshell/Caelestia tidak tersedia atau berupa symlink.'
[[ -f $shell_file && ! -L $shell_file ]] || die 'Caelestia shell.qml tidak tersedia atau bukan regular file.'
owned "$qs_root" && owned "$caelestia_root" && owned "$shell_file" || die 'Host Caelestia bukan milik user aktif.'

runtime_root="$qs_root/k41"
modules_root="$runtime_root/modules"
module_root="$modules_root/topbar"
target_file="$module_root/Topbar.qml"
for standalone_entry in "$runtime_root/shell.qml" "$runtime_root/qmldir" "$modules_root/qmldir" "$module_root/qmldir"; do
    [[ ! -e $standalone_entry && ! -L $standalone_entry ]] || die "Namespace K41 bukan module-only; review manual diperlukan: $standalone_entry"
done
for path in "$runtime_root" "$modules_root" "$module_root"; do
    [[ ! -L $path ]] || die "Symlink runtime ditolak: $path"
    if [[ -e $path ]]; then
        [[ -d $path ]] || die "Path runtime bukan direktori: $path"
        owned "$path" || die "Direktori runtime bukan milik user aktif: $path"
    fi
done
if [[ -e $target_file || -L $target_file ]]; then
    [[ -f $target_file && ! -L $target_file ]] || die 'Target Topbar.qml bukan regular file.'
    owned "$target_file" || die 'Target Topbar.qml bukan milik user aktif.'
fi

new_import='import "../k41/modules/topbar" as K41Topbar'
import_n="$(grep -Fc -- "$new_import" "$shell_file" || true)"
instance_n="$(grep -Ec '^[[:space:]]*K41Topbar\.Topbar[[:space:]]*\{[[:space:]]*\}[[:space:]]*$' "$shell_file" || true)"
shell_root_n="$(grep -Ec '^[[:space:]]*ShellRoot[[:space:]]*\{[[:space:]]*$' "$shell_file" || true)"
qtquick_import_n="$(grep -Ec '^[[:space:]]*import[[:space:]]+QtQuick[[:space:]]*$' "$shell_file" || true)"
(( shell_root_n == 1 && qtquick_import_n == 1 )) || die 'shell.qml tidak cocok dengan struktur Caelestia yang dikenali.'
host_change=0
if [[ $import_n == 0 && $instance_n == 0 ]]; then
    host_change=1
elif [[ $import_n == 1 && $instance_n == 1 ]]; then
    :
else
    die 'Integrasi Topbar parsial/duplikat terdeteksi; tidak ada perubahan.'
fi

source_sha="$(sha256sum -- "$source_file" | awk '{print $1}')"
module_matches=0
if [[ -f $target_file ]] && cmp -s -- "$source_file" "$target_file"; then module_matches=1; fi
if (( module_matches && ! host_change )); then
    info 'Modul Topbar dan integrasi Caelestia sudah sesuai; tidak ada perubahan.'
    exit 0
fi

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
mkdir -p -- "$module_root" "$backup_parent"
chmod 0700 "$backup_parent"
stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
backup_root="$backup_parent/$stamp"
n=0
while ! mkdir -- "$backup_root" 2>/dev/null; do
    [[ -e $backup_root || -L $backup_root ]] || die 'Gagal membuat direktori backup.'
    n=$((n + 1))
    backup_root="$backup_parent/$stamp-$n"
done
chmod 0700 "$backup_root"

had_module=0
if [[ -f $target_file ]]; then
    had_module=1
    cp -a -- "$target_file" "$backup_root/Topbar.qml"
    previous_module_sha="$(sha256sum -- "$target_file" | awk '{print $1}')"
else
    previous_module_sha=ABSENT
fi
cp -a -- "$shell_file" "$backup_root/shell.qml"
previous_shell_sha="$(sha256sum -- "$shell_file" | awk '{print $1}')"
{
    printf 'module_target=%s\nmodule_previous_sha256=%s\nmodule_source_sha256=%s\n' "$target_file" "$previous_module_sha" "$source_sha"
    printf 'host_target=%s\nhost_previous_sha256=%s\n' "$shell_file" "$previous_shell_sha"
    printf 'host_import=%s\nhost_instance=K41Topbar.Topbar {}\n' "$new_import"
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
                restore="$(mktemp "$module_root/.Topbar.restore.XXXXXX")" || {
                    printf 'CRITICAL: Topbar.qml gagal dipulihkan; backup %s\n' "$backup_root" >&2; exit "$rc";
                }
                if cp -a -- "$backup_root/Topbar.qml" "$restore" && mv -fT -- "$restore" "$target_file"; then
                    printf 'ROLLBACK: Topbar.qml dipulihkan.\n' >&2
                else
                    rm -f -- "$restore"; printf 'CRITICAL: rollback Topbar.qml gagal; backup %s\n' "$backup_root" >&2
                fi
            else
                rm -f -- "$target_file"
                printf 'ROLLBACK: Topbar.qml baru dihapus.\n' >&2
            fi
        fi
    fi
    [[ -z $module_tmp ]] || rm -f -- "$module_tmp"
    [[ -z $shell_tmp ]] || rm -f -- "$shell_tmp"
    exit "$rc"
}
trap 'rollback $?' EXIT

module_tmp="$(mktemp "$module_root/.Topbar.install.XXXXXX")"
install -m 0644 -- "$source_file" "$module_tmp"
cmp -s -- "$source_file" "$module_tmp" || die 'Staging Topbar.qml gagal diverifikasi.'

shell_tmp="$(mktemp "$caelestia_root/.shell.install.XXXXXX")"
awk -v replacement="$new_import" '
    $0 ~ /^[[:space:]]*import[[:space:]]+QtQuick[[:space:]]*$/ {
        print replacement
        print
        next
    }
    $0 ~ /^[[:space:]]*ShellRoot[[:space:]]*\{[[:space:]]*$/ {
        print
        print "    K41Topbar.Topbar {}"
        next
    }
    { print }
' "$shell_file" >"$shell_tmp"
chmod --reference="$shell_file" "$shell_tmp"
grep -Fqx -- "$new_import" "$shell_tmp" || die 'Staging shell.qml tidak memiliki import Topbar.'
grep -Eq '^[[:space:]]*K41Topbar\.Topbar[[:space:]]*\{[[:space:]]*\}[[:space:]]*$' "$shell_tmp" || die 'Staging shell.qml tidak memiliki instance Topbar.'

module_replaced=1
mv -fT -- "$module_tmp" "$target_file"
module_tmp=''
cmp -s -- "$source_file" "$target_file" || die 'Content Topbar.qml tidak cocok setelah deployment.'
[[ $(stat -c %a -- "$target_file") == 644 ]] || die 'Permission Topbar.qml bukan 0644.'
shell_replaced=1
mv -fT -- "$shell_tmp" "$shell_file"
shell_tmp=''
grep -Fqx -- "$new_import" "$shell_file" || die 'Import Topbar tidak ditemukan setelah deployment.'
grep -Eq '^[[:space:]]*K41Topbar\.Topbar[[:space:]]*\{[[:space:]]*\}[[:space:]]*$' "$shell_file" || die 'Instance Topbar tidak ditemukan setelah deployment.'

module_replaced=0
shell_replaced=0
trap - EXIT
info "Module K41 canonical: $target_file"
info "Caelestia host: $shell_file"
info "Backup privat: $backup_root"
info 'Integrasi menggunakan modul K41Topbar.Topbar; source upstream Caelestia tidak diubah.'
info 'Tidak dibuat shell.qml/qmldir mandiri pada namespace K41.'
info 'Quickshell tidak di-reload atau di-restart.'
