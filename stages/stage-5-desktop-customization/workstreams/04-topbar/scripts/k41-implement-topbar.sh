#!/usr/bin/env bash
# Deploy the K41-owned Topbar module into the existing Caelestia Quickshell host.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\n' "$*"; }
owned() { [[ $(stat -c %u -- "$1") == "$EUID" ]]; }

[[ $# -eq 0 ]] || die 'Script ini tidak menerima opsi.'
(( EUID != 0 )) || die 'Jalankan sebagai user desktop biasa, tanpa sudo.'
[[ -n ${HOME:-} && $HOME == /* && -d $HOME ]] || die 'HOME tidak valid.'
for cmd in git dirname install cp cmp sha256sum stat mkdir chmod mktemp mv rm date grep awk cut; do
    command -v "$cmd" >/dev/null 2>&1 || die "Command wajib tidak tersedia: $cmd"
done

script_dir="$(cd -- "$(dirname -- "$0")" && pwd -P)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)" || die 'Git checkout tidak ditemukan.'
repo_root="$(cd -- "$repo_root" && pwd -P)"
source_file="$repo_root/stages/stage-5-desktop-customization/workstreams/04-topbar/modules/topbar/Topbar.qml"
[[ -f $source_file && ! -L $source_file ]] || die 'Source Topbar.qml tidak tersedia atau bukan regular file.'
owned "$source_file" || die 'Source Topbar.qml bukan milik user aktif.'

# Migration-first gate: K41-owned providers must exist before Topbar can be deployed.
service_source_dir="$repo_root/stages/stage-5-desktop-customization/workstreams/04-topbar/modules/topbar/services"
required_services=(Cpu.qml Memory.qml Battery.qml Clock.qml Notifications.qml TopbarState.qml)
[[ -d $service_source_dir && ! -L $service_source_dir ]] || die 'Direktori service K41 belum tersedia; migrasi service harus diselesaikan sebelum deployment Topbar.'
for service in "${required_services[@]}"; do
    service_file="$service_source_dir/$service"
    [[ -f $service_file && ! -L $service_file ]] || die "Service K41 belum dimigrasikan: $service"
    owned "$service_file" || die "Source service bukan milik user aktif: $service"
    if grep -En 'Caelestia|qs\.services|ShellState|Notifs|Time\.format|ServiceRef|import[[:space:]]+qs\.' "$service_file"; then
        die "Dependency internal Caelestia terdeteksi pada $service; migrasi belum mandiri."
    fi
done

# K41 module is self-contained: no private Caelestia modules/services are allowed.
if grep -En 'Caelestia|qs\.services|ShellState|Notifs|Time\.format|ServiceRef|import[[:space:]]+qs\.' "$source_file"; then
    die 'Dependency internal Caelestia terdeteksi; migrasikan source ke API mandiri K41 terlebih dahulu.'
fi
grep -Fq 'K41Topbar' "$source_file" || die 'Source tidak memiliki marker K41Topbar.'

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
[[ $config_home == /* && -d $config_home && ! -L $config_home ]] || die 'XDG_CONFIG_HOME tidak aman atau tidak tersedia.'
owned "$config_home" || die 'XDG_CONFIG_HOME bukan milik user aktif.'
qs_root="$config_home/quickshell"
host_root="$qs_root/caelestia"
host_file="$host_root/shell.qml"
module_root="$host_root/k41/modules/topbar"
target_file="$module_root/Topbar.qml"
service_target_dir="$module_root/services"
[[ -d $qs_root && ! -L $qs_root && -d $host_root && ! -L $host_root ]] || die 'Quickshell/Caelestia config directory tidak tersedia atau berupa symlink.'
[[ -f $host_file && ! -L $host_file ]] || die 'Caelestia shell.qml tidak tersedia atau bukan regular file.'
owned "$qs_root" && owned "$host_root" && owned "$host_file" || die 'Caelestia host bukan milik user aktif.'
for path in "$host_root/k41" "$host_root/k41/modules" "$module_root"; do
    [[ ! -L $path ]] || die "Symlink runtime ditolak: $path"
    if [[ -e $path ]]; then [[ -d $path ]] || die "Path runtime bukan direktori: $path"; owned "$path" || die "Path bukan milik user aktif: $path"; fi
done
if [[ -e $target_file || -L $target_file ]]; then
    [[ -f $target_file && ! -L $target_file ]] || die 'Target Topbar bukan regular file.'
    owned "$target_file" || die 'Target Topbar bukan milik user aktif.'
fi
if [[ -e $service_target_dir || -L $service_target_dir ]]; then
    [[ -d $service_target_dir && ! -L $service_target_dir ]] || die 'Target service bukan direktori regular.'
    owned "$service_target_dir" || die 'Target service bukan milik user aktif.'
    for service in "${required_services[@]}"; do
        if [[ -e $service_target_dir/$service || -L $service_target_dir/$service ]]; then
            [[ -f $service_target_dir/$service && ! -L $service_target_dir/$service ]] || die "Target service tidak valid: $service"
            owned "$service_target_dir/$service" || die "Target service bukan milik user aktif: $service"
        fi
    done
fi

new_import='import qs.k41.modules.topbar as K41Topbar'
import_n="$(grep -Fc "$new_import" "$host_file" || true)"
instance_n="$(grep -Ec '^[[:space:]]*K41Topbar\.Topbar[[:space:]]*\{[[:space:]]*\}[[:space:]]*$' "$host_file" || true)"
root_id_n="$(grep -Ec '^[[:space:]]*id:[[:space:]]*root[[:space:]]*$' "$host_file" || true)"
(( root_id_n == 1 )) || die 'Caelestia shell.qml harus memiliki tepat satu id: root.'
(( import_n <= 1 && instance_n <= 1 )) || die 'Integrasi K41 duplikat terdeteksi.'
services_match=1
for service in "${required_services[@]}"; do
    if ! cmp -s "$service_source_dir/$service" "$service_target_dir/$service"; then
        services_match=0
        break
    fi
done
if (( import_n == 1 && instance_n == 1 && services_match == 1 )) && cmp -s "$source_file" "$target_file"; then
    info 'K41 services dan Topbar sudah terpasang pada Caelestia host; tidak ada perubahan.'
    exit 0
fi
if (( (import_n == 1) != (instance_n == 1) )); then
    die 'Integrasi K41 parsial terdeteksi; periksa shell.qml secara manual.'
fi

state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
[[ $state_home == /* ]] || die 'XDG_STATE_HOME harus absolut.'
backup_parent="$state_home/k41/backups/topbar"
for path in "$state_home" "$state_home/k41" "$state_home/k41/backups" "$backup_parent"; do
    [[ ! -L $path ]] || die "Symlink backup ditolak: $path"
    if [[ -e $path ]]; then [[ -d $path ]] || die "Path backup bukan direktori: $path"; owned "$path" || die 'Path backup bukan milik user aktif.'; fi
done
mkdir -p "$module_root" "$backup_parent"
chmod 0700 "$backup_parent"
stamp="$(date -u +'%Y%m%dT%H%M%SZ')"; backup_root="$backup_parent/$stamp"; n=0
while ! mkdir "$backup_root" 2>/dev/null; do
    [[ -e $backup_root || -L $backup_root ]] || die 'Gagal membuat backup.'
    n=$((n+1)); backup_root="$backup_parent/$stamp-$n"
done
chmod 0700 "$backup_root"
had_module=0
if [[ -f $target_file ]]; then had_module=1; cp -a "$target_file" "$backup_root/Topbar.qml"; fi
had_services=0
if [[ -d $service_target_dir ]]; then
    had_services=1
    cp -a "$service_target_dir" "$backup_root/services"
fi
cp -a "$host_file" "$backup_root/shell.qml"
{
    printf 'module_target=%s\nmodule_previous=%s\nmodule_source_sha256=%s\n' "$target_file" "$had_module" "$(sha256sum "$source_file" | cut -d' ' -f1)"
    printf 'host_target=%s\nhost_previous_sha256=%s\n' "$host_file" "$(sha256sum "$host_file" | cut -d' ' -f1)"
} >"$backup_root/manifest.txt"
chmod 0600 "$backup_root/manifest.txt"

module_tmp=''; host_tmp=''; services_tmp=''; module_replaced=0; host_replaced=0; services_replaced=0
rollback() {
    local rc=$1 restore
    trap - EXIT
    if (( rc != 0 )); then
        if (( host_replaced )); then
            restore="$(mktemp "$host_root/.shell.restore.XXXXXX")"
            if cp -a "$backup_root/shell.qml" "$restore" && mv -fT "$restore" "$host_file"; then printf 'ROLLBACK: Caelestia shell.qml dipulihkan.\n' >&2; else rm -f "$restore"; printf 'CRITICAL: rollback host gagal; backup %s\n' "$backup_root" >&2; fi
        fi
        if (( services_replaced )); then
            if (( had_services )); then
                rm -rf -- "$service_target_dir"
                cp -a "$backup_root/services" "$service_target_dir"
                printf 'ROLLBACK: K41 services dipulihkan.\n' >&2
            else
                rm -rf -- "$service_target_dir"
            fi
        fi
        if (( module_replaced )); then
            if (( had_module )); then
                restore="$(mktemp "$module_root/.Topbar.restore.XXXXXX")"
                if cp -a "$backup_root/Topbar.qml" "$restore" && mv -fT "$restore" "$target_file"; then printf 'ROLLBACK: Topbar.qml dipulihkan.\n' >&2; else rm -f "$restore"; printf 'CRITICAL: rollback module gagal; backup %s\n' "$backup_root" >&2; fi
            else rm -f "$target_file"; fi
        fi
    fi
    [[ -z $module_tmp ]] || rm -f "$module_tmp"
    [[ -z $host_tmp ]] || rm -f "$host_tmp"
    [[ -z $services_tmp ]] || rm -rf "$services_tmp"
    exit "$rc"
}
trap 'rollback $?' EXIT

# Stage and publish K41-owned services first. Topbar is installed only after this phase.
services_tmp="$(mktemp -d "$module_root/.services.install.XXXXXX")"
for service in "${required_services[@]}"; do
    install -m 0644 "$service_source_dir/$service" "$services_tmp/$service"
    cmp -s "$service_source_dir/$service" "$services_tmp/$service" || die "Verifikasi staging service gagal: $service"
done
if [[ -e $service_target_dir ]]; then
    mv -T "$service_target_dir" "$backup_root/services.previous"
fi
services_replaced=1
mv -T "$services_tmp" "$service_target_dir"
services_tmp=''

module_tmp="$(mktemp "$module_root/.Topbar.install.XXXXXX")"
host_tmp="$(mktemp "$host_root/.shell.install.XXXXXX")"
install -m 0644 "$source_file" "$module_tmp"
awk -v new_import="$new_import" '
    $0 ~ /^[[:space:]]*import[[:space:]]+QtQuick[[:space:]]*$/ && !added_import { print new_import; added_import=1 }
    $0 ~ /^[[:space:]]*K41Topbar\.Topbar[[:space:]]*\{[[:space:]]*\}[[:space:]]*$/ { next }
    $0 ~ /^[[:space:]]*id:[[:space:]]*root[[:space:]]*$/ { print; print "    K41Topbar.Topbar {}"; added_instance=1; next }
    { print }
    END { if (!added_import || !added_instance) exit 42 }
' "$host_file" >"$host_tmp" || die 'Tidak dapat menyisipkan K41 Topbar secara aman ke host.'
chmod --reference="$host_file" "$host_tmp"
grep -Fqx "$new_import" "$host_tmp" || die 'Import K41 tidak ada pada staging.'
grep -Eq '^[[:space:]]*K41Topbar\.Topbar[[:space:]]*\{[[:space:]]*\}[[:space:]]*$' "$host_tmp" || die 'Instance K41 tidak ada pada staging.'
cmp -s "$source_file" "$module_tmp" || die 'Verifikasi staging module gagal.'

module_replaced=1; mv -fT "$module_tmp" "$target_file"; module_tmp=''
cmp -s "$source_file" "$target_file" || die 'Verifikasi module setelah install gagal.'
host_replaced=1; mv -fT "$host_tmp" "$host_file"; host_tmp=''
grep -Fqx "$new_import" "$host_file" || die 'Import K41 tidak ditemukan setelah install.'
grep -Eq '^[[:space:]]*K41Topbar\.Topbar[[:space:]]*\{[[:space:]]*\}[[:space:]]*$' "$host_file" || die 'Instance K41 tidak ditemukan setelah install.'
module_replaced=0; host_replaced=0; services_replaced=0; trap - EXIT
info "K41 services: $service_target_dir"
info "K41 module: $target_file"
info "Entrypoint host tetap: $host_file"
info "Backup privat: $backup_root"
info 'Caelestia shell.qml hanya menerima import dan instance K41; source Caelestia lainnya tidak diubah.'
info 'Tidak melakukan reload/restart Quickshell atau mengubah autostart.'
