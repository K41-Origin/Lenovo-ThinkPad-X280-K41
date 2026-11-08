#!/usr/bin/env bash
# Base Arch bootstrap for an already-prepared and mounted target.
# Never partitions, formats, opens LUKS, mounts, or changes firmware.
# Source lib/common.sh before calling these functions.

base_system::validate_mounts() {
  [[ $# -eq 1 && -n $1 ]] || return 2
  local root=$1 esp="$1/efi"
  local root_info esp_info root_target root_source root_type esp_target esp_source esp_type
  [[ $root == /* && $root != / && $root != *$'\n'* ]] || return 2
  [[ -d $root && -d $esp ]] || return 1
  command -v findmnt >/dev/null 2>&1 || return 1

  root_info="$(findmnt --noheadings --raw --mountpoint "$root" --output TARGET,SOURCE,FSTYPE)" || return 1
  esp_info="$(findmnt --noheadings --raw --mountpoint "$esp" --output TARGET,SOURCE,FSTYPE)" || return 1
  read -r root_target root_source root_type <<<"$root_info"
  read -r esp_target esp_source esp_type <<<"$esp_info"

  [[ $root_target == "$root" && $root_type == ext4 ]] || {
    k41::log_error "Target root must be an exact ext4 mountpoint: $root"
    return 1
  }
  [[ $root_source == /dev/mapper/* ]] || {
    k41::log_error 'Target root must be the unlocked encrypted mapper device.'
    return 1
  }
  [[ $esp_target == "$esp" && $esp_type == vfat ]] || {
    k41::log_error "EFI system partition must be mounted as vfat at: $esp"
    return 1
  }
  [[ $esp_source == /dev/* && $root_source != "$esp_source" ]] || {
    k41::log_error 'EFI source must be a separate block-device path.'
    return 1
  }
  k41::log_info "Mounted target accepted: root=$root (ext4 mapper), ESP=$esp (vfat)."
}

base_system::install_packages() {
  [[ $# -eq 2 && -n $1 && $2 == 'INSTALL BASE SYSTEM' ]] || {
    k41::log_error 'Expected ROOT and exact confirmation: INSTALL BASE SYSTEM.'
    return 2
  }
  local root=$1
  (( EUID == 0 )) || {
    k41::log_error 'Base package installation must run as root from the Arch ISO.'
    return 1
  }
  base_system::validate_mounts "$root" || return 1
  command -v pacstrap >/dev/null 2>&1 || {
    k41::log_error 'pacstrap is unavailable; boot the official Arch ISO or install arch-install-scripts.'
    return 1
  }

  # Intel microcode is deliberately not auto-installed under the current
  # project decision; it remains a post-install recommendation.
  local -a packages=(
    base linux linux-firmware
    cryptsetup networkmanager sudo
    e2fsprogs dosfstools
    iptables mkinitcpio
    nano man-db man-pages
  )
  k41::log_info 'Installing the minimal approved Arch base package set.'
  pacstrap -K "$root" "${packages[@]}"
}

base_system::generate_fstab() {
  [[ $# -eq 2 && -n $1 && $2 == 'WRITE FSTAB' ]] || {
    k41::log_error 'Expected ROOT and exact confirmation: WRITE FSTAB.'
    return 2
  }
  local root=$1 fstab="$1/etc/fstab" generated root_line efi_line existing_line
  local tmp candidate mountpoint
  (( EUID == 0 )) || return 1
  base_system::validate_mounts "$root" || return 1
  command -v genfstab >/dev/null 2>&1 || return 1
  [[ -d $root/etc ]] || return 1

  generated="$(mktemp "$root/etc/.fstab.generated.k41.XXXXXX")" || return 1
  if ! genfstab -U "$root" >"$generated"; then
    rm -f -- "$generated"
    return 1
  fi
  root_line="$(awk '$0 !~ /^[[:space:]]*#/ && NF >= 2 && $2 == "/" { print; count++ } END { if (count != 1) exit 1 }' "$generated")" || {
    rm -f -- "$generated"
    k41::log_error 'Generated fstab must contain exactly one root entry.'
    return 1
  }
  efi_line="$(awk '$0 !~ /^[[:space:]]*#/ && NF >= 2 && $2 == "/efi" { print; count++ } END { if (count != 1) exit 1 }' "$generated")" || {
    rm -f -- "$generated"
    k41::log_error 'Generated fstab must contain exactly one /efi entry.'
    return 1
  }

  tmp="$(mktemp "$root/etc/.fstab.k41.XXXXXX")" || {
    rm -f -- "$generated"
    return 1
  }
  if [[ -f $fstab ]]; then
    cat -- "$fstab" >"$tmp" || {
      rm -f -- "$generated" "$tmp"
      return 1
    }
  fi

  for mountpoint in / /efi; do
    if [[ $mountpoint == / ]]; then
      candidate=$root_line
    else
      candidate=$efi_line
    fi
    if existing_line="$(awk -v mp="$mountpoint" '$0 !~ /^[[:space:]]*#/ && NF >= 2 && $2 == mp { print; count++ } END { if (count > 1) exit 2 }' "$tmp")"; then
      :
    else
      local inspect_rc=$?
      rm -f -- "$generated" "$tmp"
      if (( inspect_rc == 2 )); then
        k41::log_error "Target fstab contains duplicate entries for $mountpoint."
      else
        k41::log_error "Could not inspect existing fstab entry for $mountpoint."
      fi
      return 1
    fi
    if [[ -n $existing_line ]]; then
      if [[ $existing_line != "$candidate" ]]; then
        rm -f -- "$generated" "$tmp"
        k41::log_error "Target fstab has a conflicting entry for $mountpoint; refusing to replace it."
        return 1
      fi
    else
      printf '%s\n' "$candidate" >>"$tmp" || {
        rm -f -- "$generated" "$tmp"
        return 1
      }
    fi
  done

  rm -f -- "$generated"
  chmod 0644 "$tmp" || { rm -f -- "$tmp"; return 1; }
  mv -- "$tmp" "$fstab" || { rm -f -- "$tmp"; return 1; }
  k41::log_info 'Target fstab validated/updated using filesystem UUIDs; existing unrelated entries were preserved.'
}

base_system::bootstrap() {
  [[ $# -eq 2 && -n $1 && $2 == 'BOOTSTRAP ARCH BASE' ]] || {
    k41::log_error 'Expected ROOT and exact confirmation: BOOTSTRAP ARCH BASE.'
    return 2
  }
  base_system::install_packages "$1" 'INSTALL BASE SYSTEM' || return $?
  base_system::generate_fstab "$1" 'WRITE FSTAB'
}
