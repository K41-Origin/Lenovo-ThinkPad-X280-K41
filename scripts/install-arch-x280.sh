#!/usr/bin/env bash
# Interactive Arch Linux installation for the Lenovo ThinkPad X280.
# DESTRUCTIVE: erases the selected whole NVMe disk after an exact plan confirmation.
set -Eeuo pipefail
umask 077

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=lib/common.sh
source "$ROOT/lib/common.sh"
# shellcheck source=lib/preflight.sh
source "$ROOT/lib/preflight.sh"
# shellcheck source=lib/storage.sh
source "$ROOT/lib/storage.sh"
# shellcheck source=lib/storage-plan.sh
source "$ROOT/lib/storage-plan.sh"
# shellcheck source=lib/storage-prerequisites.sh
source "$ROOT/lib/storage-prerequisites.sh"
# shellcheck source=lib/storage-confirmation.sh
source "$ROOT/lib/storage-confirmation.sh"
# shellcheck source=lib/base-system.sh
source "$ROOT/lib/base-system.sh"

die() { k41::log_error "$1"; exit 1; }
need_root() { (( EUID == 0 )) || die "Jalankan dari Arch ISO sebagai root."; }
current_stage=bootstrap
installer_log_dir=
installer_log_file=
installer::stage() {
  current_stage=$1
  shift
  printf '\n[STAGE] %s — %s\n' "$current_stage" "$*"
}
installer::init_logging() {
  local root timestamp suffix=0
  command -v tee >/dev/null 2>&1 || { printf 'FATAL: tee tidak tersedia; logging wajib tidak dapat diinisialisasi.\n' >&2; return 1; }
  command -v install >/dev/null 2>&1 || { printf 'FATAL: install tidak tersedia; direktori log aman tidak dapat dibuat.\n' >&2; return 1; }
  root=/var/log/x280-installer
  if ! install -d -o root -g root -m 0700 "$root" 2>/dev/null; then
    root=/run/x280-installer
    install -d -o root -g root -m 0700 "$root" || { printf 'FATAL: tidak dapat membuat direktori log root-only di /var/log maupun /run.\n' >&2; return 1; }
    printf 'WARNING: /var/log tidak dapat digunakan; log disimpan sementara di /run.\n' >&2
  fi
  printf -v timestamp '%(%Y%m%dT%H%M%SZ)T' -1
  installer_log_dir="$root/$timestamp"
  while ! mkdir -m 0700 -- "$installer_log_dir" 2>/dev/null; do
    suffix=$((suffix + 1))
    installer_log_dir="$root/$timestamp-$suffix"
  done
  installer_log_file="$installer_log_dir/installer.log"
  : >"$installer_log_file"
  chmod 0600 "$installer_log_file" || return 1
  # No xtrace is enabled. Interactive secrets are read from the controlling
  # terminal and are never passed as command arguments.
  exec > >(tee -a "$installer_log_file") 2>&1
  printf 'X280 installer diagnostic log\n'
  printf 'Started (UTC): %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  printf 'Kernel: %s\nArchitecture: %s\n' "$(uname -sr)" "$(uname -m)"
  printf 'Repository: %s\n' "$ROOT"
  if command -v git >/dev/null 2>&1; then printf 'Commit: %s\n' "$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || printf unknown)"; else printf 'Commit: unknown (git unavailable)\n'; fi
  printf 'Log directory: %s\nPermissions: directory 0700, file 0600\n' "$installer_log_dir"
}
installer::on_error() {
  local rc=$1 line=$2
  trap - ERR
  printf '[ERROR] Unhandled command failure: exit=%s line=%s stage=%s\n' "$rc" "$line" "$current_stage" >&2
  exit "$rc"
}
need_commands() {
  local cmd
  for cmd in lsblk jq swapon base64 readlink stat sha256sum date sgdisk partprobe udevadm cryptsetup mkfs.fat mkfs.ext4 pacstrap genfstab blkid findmnt blockdev wipefs arch-chroot mount awk sed grep install; do
    command -v "$cmd" >/dev/null 2>&1 || die "Perintah wajib tidak ditemukan: $cmd"
  done
}
cleanup() {
  local rc=$?
  if (( rc != 0 )); then
    k41::log_error "Installer berhenti (exit $rc) pada tahap '$current_stage'. Jangan mengulang secara buta; periksa status disk dan /mnt."
  fi
  if [[ -n $installer_log_file ]]; then
    printf 'Finished (UTC): %s\nExit status: %s\nLast stage: %s\n' \
      "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$rc" "$current_stage"
    printf 'Persistent diagnostic log: %s\n' "$installer_log_file"
  fi
}
need_root
installer::init_logging || exit 1
trap cleanup EXIT
trap 'installer::on_error "$?" "$LINENO"' ERR
need_commands
installer::stage preflight "Memeriksa profil X280, mode UEFI, dan prasyarat host"
preflight::check_target_inventory || die "Host tidak lolos verifikasi profil ThinkPad X280."
[[ -d /sys/firmware/efi ]] || die "Boot ISO dalam mode UEFI terlebih dahulu."
[[ ! -e /mnt/etc ]] || die "/mnt tampak sudah berisi sistem; unmount/periksa manual sebelum menjalankan installer."

installer::stage disk-discovery "Mendeteksi disk NVMe internal dan identitas target"
declare -A discovered=()
storage::discover_candidates discovered || die "Gagal membaca inventaris disk."
(( discovered[candidate_count] > 0 )) || die "Tidak ditemukan disk NVMe internal yang layak."

printf '\nDisk NVMe internal yang terdeteksi:\n'
for ((i=0; i<discovered[candidate_count]; i++)); do
  printf ' [%d] %-18s %12s bytes  %-28s %s=%s\n' "$i" "${discovered[$i.device_path]}" "${discovered[$i.size_bytes]}" "${discovered[$i.model]:-unknown}" "${discovered[$i.stable_id_kind]}" "${discovered[$i.stable_id]}"
done
printf '\nPilih indeks disk internal X280 yang akan DIHAPUS: '
IFS= read -r selection
[[ $selection =~ ^[0-9]+$ ]] || die "Pilihan tidak valid."
(( selection < discovered[candidate_count] )) || die "Indeks disk di luar daftar."

declare -A target=()
for key in device_path major_minor size_bytes model transport removable read_only stable_id_kind stable_id wwn serial; do
  target[$key]=${discovered[$selection.$key]}
done
[[ ${target[transport]} == nvme && ${target[removable]} == false && ${target[read_only]} == false ]] || die "Target bukan NVMe internal writable."
[[ ${target[model]} == *"WDC PC SN730"* && ${target[size_bytes]} == 256060514304 && ${target[serial]} == 193839803177 ]] || die "Target tidak cocok dengan model, kapasitas, dan identitas SSD X280 yang telah diverifikasi."
[[ ${target[stable_id_kind]} == wwn || ${target[stable_id_kind]} == serial ]] || die "Disk tidak memiliki identitas stabil WWN/serial."
[[ ${discovered[$selection.has_mounted_descendant]} == no && ${discovered[$selection.has_active_swap_descendant]} == no ]] || die "Target memiliki mount atau swap aktif."

installer::stage storage-plan "Menghitung layout GPT dan ukuran swapfile"
ram_bytes="$(awk '/MemTotal:/ {print $2 * 1024}' /proc/meminfo)"
[[ $ram_bytes =~ ^[0-9]+$ ]] || die "Tidak dapat menentukan kapasitas RAM."
swap_margin_bytes=$((2 * 1024 * 1024 * 1024))
# shellcheck disable=SC2034 # output arrays are populated/read through nameref parameters
declare -A plan=() prereq=() confirmation=() fresh_target=() fresh_prereq=() gate=()
storage::plan_gpt_layout plan "${target[size_bytes]}" "$(blockdev --getss "${target[device_path]}")" "$(blockdev --getpbsz "${target[device_path]}")" "$ram_bytes" "$swap_margin_bytes" || die "Perhitungan layout disk gagal."
storage::plan_bind_target plan target || die "Binding identitas target gagal."
installer::stage initial-revalidation "Mengumpulkan prasyarat read-only sebelum review"
storage::plan_collect_live_prerequisites plan fresh_target prereq || die "Pemeriksaan prasyarat awal gagal."
storage::plan_render_review plan
printf '\nPERINGATAN: SELURUH DATA PADA %s AKAN DIHAPUS. Pastikan backup tersedia.\n' "${target[device_path]}" >&2
installer::stage operator-confirmation "Menampilkan rencana dan meminta konfirmasi target yang eksplisit"
storage::plan_confirm_interactive plan confirmation || die "Konfirmasi dibatalkan."
installer::stage final-revalidation "Memeriksa ulang konfirmasi, identitas, topologi, dan prasyarat; belum ada operasi disk"
storage::plan_final_revalidate plan confirmation fresh_target fresh_prereq gate || die "Validasi final gagal; tidak ada perubahan disk."

installer::stage pin-target "Memastikan identitas block device dan menahan descriptor target"
disk=${gate[target_device_path]}
disk_identity_before="$(lsblk -dnro MAJ:MIN,SIZE,SERIAL,WWN,TRAN,RM,RO "$disk" | sed -E 's/[[:space:]]+$//')"
[[ -n $disk_identity_before ]] || die "Identitas target tidak dapat dibaca ulang."
storage::validate_target fresh_target || die "Target berubah sebelum operasi pertama."
# Pin the whole-disk block inode and pass its inherited descriptor to child tools.
exec {disk_fd}<>"$disk" || die "Tidak dapat membuka descriptor target untuk ditahan."
disk_ref="/proc/self/fd/$disk_fd"
[[ -b "/proc/$BASHPID/fd/$disk_fd" ]] || die "Descriptor target bukan block device."
disk_fd_major_minor="$(lsblk -dnro MAJ:MIN "/proc/$BASHPID/fd/$disk_fd")"
[[ $disk_fd_major_minor == "${gate[target_major_minor]}" ]] || die "Descriptor tidak cocok dengan major:minor target yang dikonfirmasi."
[[ "$(stat -Lc '%t:%T' "$disk")" == "$(stat -Lc '%t:%T' "/proc/$BASHPID/fd/$disk_fd")" ]] || die "Path target berubah ketika descriptor dibuka."

# Disk and partition descriptors are held open by this Bash process. Child
# utilities receive /proc/self/fd/N paths, which refer to the inherited open
# block-device objects rather than re-resolving the original /dev pathname.
# This design is validated by the isolated loop-device integration test.
assert_target() {
  local now
  now="$(lsblk -dnro MAJ:MIN,SIZE,SERIAL,WWN,TRAN,RM,RO "$disk" | sed 's/[[:space:]]\+$//')" || return 1
  [[ $now == "$disk_identity_before" ]] || {
    k41::log_error "Identitas block device berubah; menghentikan proses."
    return 1
  }
  [[ -b "/proc/$BASHPID/fd/$disk_fd" ]] || return 1
  [[ "$(stat -Lc '%t:%T' "$disk")" == "$(stat -Lc '%t:%T' "/proc/$BASHPID/fd/$disk_fd")" ]] || return 1
}
run_step() {
  local label=$1; shift
  current_stage="disk-operation:$label"
  assert_target || die "Revalidasi target gagal sebelum: $label"
  k41::log_info "Menjalankan tahap: $label"
  "$@" || die "Tahap gagal: $label"
}

# Do not disable unrelated swap devices or swapfiles on the live ISO.
run_step "hapus signature lama" wipefs --all --force "$disk_ref"
run_step "buat tabel GPT dan partisi" sgdisk --zap-all --clear \
  --new=1:"${plan[esp_start_sector]}":"${plan[esp_end_sector]}" --typecode=1:ef00 --change-name=1:K41-ESP \
  --new=2:"${plan[root_start_sector]}":"${plan[root_end_sector]}" --typecode=2:8309 --change-name=2:K41-ROOT "$disk_ref"
run_step "sinkronisasi tabel partisi" partprobe "$disk_ref"
run_step "tunggu node partisi" udevadm settle

if [[ $disk == *nvme* || $disk == *mmcblk* ]]; then
  esp="${disk}p1"; root_part="${disk}p2"
else
  esp="${disk}1"; root_part="${disk}2"
fi
[[ -b $esp && -b $root_part ]] || die "Node partisi tidak muncul; hentikan dan periksa manual."
exec {esp_fd}<>"$esp" || die "Tidak dapat menahan descriptor ESP."
exec {root_fd}<>"$root_part" || die "Tidak dapat menahan descriptor root partition."
esp_ref="/proc/self/fd/$esp_fd"
root_ref="/proc/self/fd/$root_fd"
[[ -b "/proc/$BASHPID/fd/$esp_fd" && -b "/proc/$BASHPID/fd/$root_fd" ]] || die "Descriptor partisi bukan block device."
[[ "$(stat -Lc '%t:%T' "$esp")" == "$(stat -Lc '%t:%T' "/proc/$BASHPID/fd/$esp_fd")" ]] || die "Path ESP berubah saat descriptor dibuka."
[[ "$(stat -Lc '%t:%T' "$root_part")" == "$(stat -Lc '%t:%T' "/proc/$BASHPID/fd/$root_fd")" ]] || die "Path root partition berubah saat descriptor dibuka."
assert_target || die "Identitas disk berubah setelah partisi."

installer::stage encryption "Meminta passphrase LUKS2 secara interaktif; input tidak dicatat"
printf '\nBuat passphrase LUKS2 untuk root (input tidak dicatat):\n' >&2
run_step "format partisi root dengan LUKS2" cryptsetup luksFormat --type luks2 --verify-passphrase "$root_ref"
run_step "buka volume LUKS2" cryptsetup open "$root_ref" cryptroot
run_step "format ESP FAT32" mkfs.fat -F 32 -n K41_EFI "$esp_ref"
run_step "format root ext4" mkfs.ext4 -F -L K41_ROOT /dev/mapper/cryptroot

mkdir -p /mnt
run_step "mount root" mount /dev/mapper/cryptroot /mnt
mkdir -p /mnt/efi
run_step "mount ESP" mount "$esp_ref" /mnt/efi

run_step "instal sistem dasar Arch" base_system::bootstrap /mnt "BOOTSTRAP ARCH BASE"
install -m 0700 "$ROOT/scripts/configure-arch-x280.sh" /mnt/root/k41-configure-arch-x280.sh
run_step "konfigurasi user, locale, timezone, microcode, dan swapfile" arch-chroot /mnt /root/k41-configure-arch-x280.sh "${plan[swapfile_target_bytes]}"
rm -f -- /mnt/root/k41-configure-arch-x280.sh

installer::stage boot-configuration "Memasang systemd-boot dan membangun UKI"
# Minimal bootable configuration: systemd-boot + mkinitcpio UKI.
run_step "pasang systemd-boot" arch-chroot /mnt bootctl --esp-path=/efi install
root_uuid="$(blkid -s UUID -o value "$root_ref")"
[[ -n $root_uuid ]] || die "UUID LUKS tidak ditemukan."
assert_target || die "Identitas disk berubah sebelum konfigurasi boot."
arch-chroot /mnt /bin/bash -euo pipefail <<CHROOT
sed -i 's|^HOOKS=.*|HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)|' /etc/mkinitcpio.conf
mkdir -p /efi/EFI/Linux /etc/kernel
printf '%s\n' 'rd.luks.name=${root_uuid}=cryptroot root=/dev/mapper/cryptroot rw' > /etc/kernel/cmdline
sed -i -e "s/^PRESETS=.*/PRESETS=('default')/" -e '/^fallback_/d' -e '/^default_uki=/d' -e '/^default_image=/d' -e '/^default_cmdline=/d' /etc/mkinitcpio.d/linux.preset
printf '%s\n' 'default_uki="/efi/EFI/Linux/arch-linux.efi"' 'default_cmdline="/etc/kernel/cmdline"' >> /etc/mkinitcpio.d/linux.preset
systemctl enable NetworkManager
mkinitcpio -P
[[ -s /efi/EFI/Linux/arch-linux.efi ]]
[[ -s /etc/kernel/cmdline ]]
grep -q '^rd.luks.name=' /etc/kernel/cmdline
grep -q '^root=/dev/mapper/cryptroot' /etc/kernel/cmdline
CHROOT

[[ -s /mnt/etc/fstab ]] || die "Target fstab tidak ditemukan atau kosong."
[[ -s /mnt/efi/EFI/Linux/arch-linux.efi ]] || die "UKI tidak berhasil dibuat."
grep -qE '^[^#].+[[:space:]]+/swapfile[[:space:]]+swap[[:space:]]' /mnt/etc/fstab || die "Entri swapfile tidak ditemukan di fstab."
[[ -s /mnt/etc/hostname ]] || die "Hostname target tidak terkonfigurasi."
[[ -s /mnt/etc/locale.conf ]] || die "Locale target tidak terkonfigurasi."
[[ -L /mnt/etc/localtime ]] || die "Timezone target tidak terkonfigurasi."

installer::stage completion "Memvalidasi artefak hasil instalasi"
k41::log_info "Konfigurasi awal base Arch selesai: user, sudo, locale, timezone, hostname, swapfile, NetworkManager, systemd-boot, dan UKI telah diproses."
k41::log_warn "Caelestia/Hyprland/Quickshell, tuning hardware X280, hibernation/resume, dan BlackArch belum diimplementasikan pada tahap ini."
k41::log_info "Jangan reboot otomatis. Periksa hasil instalasi dan lakukan unmount/cryptsetup close secara manual setelah verifikasi."
