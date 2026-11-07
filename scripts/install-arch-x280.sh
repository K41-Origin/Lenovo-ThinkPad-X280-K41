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
need_commands() {
  local cmd
  for cmd in lsblk jq swapon base64 readlink stat sha256sum date sgdisk partprobe udevadm cryptsetup mkfs.fat mkfs.ext4 pacstrap genfstab blkid findmnt blockdev wipefs arch-chroot mount awk sed grep install; do
    command -v "$cmd" >/dev/null 2>&1 || die "Perintah wajib tidak ditemukan: $cmd"
  done
}
cleanup() {
  local rc=$?
  if (( rc != 0 )); then
    k41::log_error "Installer berhenti (exit $rc). Jangan mengulang secara buta; periksa status disk dan /mnt."
  fi
}
trap cleanup EXIT

need_root
need_commands
preflight::check_target_inventory || die "Host tidak lolos verifikasi profil ThinkPad X280."
[[ -d /sys/firmware/efi ]] || die "Boot ISO dalam mode UEFI terlebih dahulu."
[[ ! -e /mnt/etc ]] || die "/mnt tampak sudah berisi sistem; unmount/periksa manual sebelum menjalankan installer."

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
[[ ${target[model]} == "WDC PC SN730" && ${target[size_bytes]} == 256052966400 ]] || die "Target tidak cocok dengan model dan kapasitas SSD X280 yang telah diverifikasi."
[[ ${target[stable_id_kind]} == wwn || ${target[stable_id_kind]} == serial ]] || die "Disk tidak memiliki identitas stabil WWN/serial."
[[ ${discovered[$selection.has_mounted_descendant]} == no && ${discovered[$selection.has_active_swap_descendant]} == no ]] || die "Target memiliki mount atau swap aktif."

ram_bytes="$(awk '/MemTotal:/ {print $2 * 1024}' /proc/meminfo)"
[[ $ram_bytes =~ ^[0-9]+$ ]] || die "Tidak dapat menentukan kapasitas RAM."
swap_margin_bytes=$((2 * 1024 * 1024 * 1024))
declare -A plan=() confirmation=() fresh_target=() fresh_prereq=() gate=()
storage::plan_gpt_layout plan "${target[size_bytes]}" "$(blockdev --getss "${target[device_path]}")" "$(blockdev --getpbsz "${target[device_path]}")" "$ram_bytes" "$swap_margin_bytes" || die "Perhitungan layout disk gagal."
storage::plan_bind_target plan target || die "Binding identitas target gagal."
storage::plan_collect_live_prerequisites plan fresh_target prereq || die "Pemeriksaan prasyarat awal gagal."
storage::plan_render_review plan
printf '\nPERINGATAN: SELURUH DATA PADA %s AKAN DIHAPUS. Pastikan backup tersedia.\n' "${target[device_path]}" >&2
storage::plan_confirm_interactive plan confirmation || die "Konfirmasi dibatalkan."
storage::plan_final_revalidate plan confirmation fresh_target fresh_prereq gate || die "Validasi final gagal; tidak ada perubahan disk."

disk=${gate[target_device_path]}
disk_identity_before="$(lsblk -dnro MAJ:MIN,SIZE,SERIAL,WWN,TRAN,RM,RO "$disk" | sed 's/[[:space:]]\+$//')"
[[ -n $disk_identity_before ]] || die "Identitas target tidak dapat dibaca ulang."
storage::validate_target fresh_target || die "Target berubah sebelum operasi pertama."

# The external disk utilities open the device pathname themselves. The
# read-only identity checks immediately before each command reduce, but do not
# eliminate, the kernel device-rebinding/TOCTOU window. This is not descriptor-
# bound execution and must not be represented as race-proof.
assert_target() {
  local now
  now="$(lsblk -dnro MAJ:MIN,SIZE,SERIAL,WWN,TRAN,RM,RO "$disk" | sed 's/[[:space:]]\+$//')" || return 1
  [[ $now == "$disk_identity_before" ]] || {
    k41::log_error "Identitas block device berubah; menghentikan proses."
    return 1
  }
  [[ -b "$disk" ]] || return 1
}
run_step() {
  local label=$1; shift
  assert_target || die "Revalidasi target gagal sebelum: $label"
  k41::log_info "Menjalankan tahap: $label"
  "$@" || die "Tahap gagal: $label"
}

# Do not disable unrelated swap devices or swapfiles on the live ISO.
run_step "hapus signature lama" wipefs --all --force "$disk"
run_step "buat tabel GPT dan partisi" sgdisk --zap-all --clear \
  --new=1:"${plan[esp_start_sector]}":"${plan[esp_end_sector]}" --typecode=1:ef00 --change-name=1:K41-ESP \
  --new=2:"${plan[root_start_sector]}":"${plan[root_end_sector]}" --typecode=2:8309 --change-name=2:K41-ROOT "$disk"
run_step "sinkronisasi tabel partisi" partprobe "$disk"
run_step "tunggu node partisi" udevadm settle

if [[ $disk == *nvme* || $disk == *mmcblk* ]]; then
  esp="${disk}p1"; root_part="${disk}p2"
else
  esp="${disk}1"; root_part="${disk}2"
fi
[[ -b $esp && -b $root_part ]] || die "Node partisi tidak muncul; hentikan dan periksa manual."
assert_target || die "Identitas disk berubah setelah partisi."

printf '\nBuat passphrase LUKS2 untuk root (input tidak dicatat):\n' >&2
run_step "format partisi root dengan LUKS2" cryptsetup luksFormat --type luks2 --verify-passphrase "$root_part"
run_step "buka volume LUKS2" cryptsetup open "$root_part" cryptroot
run_step "format ESP FAT32" mkfs.fat -F 32 -n K41_EFI "$esp"
run_step "format root ext4" mkfs.ext4 -F -L K41_ROOT /dev/mapper/cryptroot

mkdir -p /mnt
run_step "mount root" mount /dev/mapper/cryptroot /mnt
mkdir -p /mnt/efi
run_step "mount ESP" mount "$esp" /mnt/efi

run_step "instal sistem dasar Arch" base_system::bootstrap /mnt "BOOTSTRAP ARCH BASE"


# Minimal bootable configuration: systemd-boot + mkinitcpio UKI.
run_step "pasang systemd-boot" arch-chroot /mnt bootctl --esp-path=/efi install
root_uuid="$(blkid -s UUID -o value "$root_part")"
[[ -n $root_uuid ]] || die "UUID LUKS tidak ditemukan."
arch-chroot /mnt /bin/bash -euo pipefail <<CHROOT
sed -i 's|^HOOKS=.*|HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)|' /etc/mkinitcpio.conf
mkdir -p /efi/EFI/Linux /etc/kernel
printf '%s\\n' 'cryptdevice=UUID=${root_uuid}:cryptroot root=/dev/mapper/cryptroot rw' > /etc/kernel/cmdline
sed -i '/^default_uki=/d; /^default_image=/d' /etc/mkinitcpio.d/linux.preset
printf '%s\\n' 'default_uki="/efi/EFI/Linux/arch-linux.efi"' 'default_cmdline="/etc/kernel/cmdline"' >> /etc/mkinitcpio.d/linux.preset
systemctl enable NetworkManager
mkinitcpio -P
CHROOT

k41::log_info "Base Arch berhasil dipasang ke /mnt. Bootloader systemd-boot dan initramfs dikonfigurasi."
k41::log_warn "Tahap Caelestia/Hyprland, user non-root, locale, timezone, hostname, swapfile, dan optimasi X280 belum dijalankan."
k41::log_info "Periksa /mnt, lalu chroot manual untuk menyelesaikan konfigurasi sebelum reboot."
