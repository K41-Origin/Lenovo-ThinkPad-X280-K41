#!/usr/bin/env bash
# Pure arithmetic storage layout planner. This module never invokes disk tools.

storage::plan_gpt_layout() {
  [[ $# -eq 6 ]] || return 2
  local -n _plan=$1
  [[ $(declare -p "$1" 2>/dev/null) == 'declare -A '* ]] || return 2
  [[ ! -v _plan[status] ]] || return 2
  local disk_bytes=$2 logical_sector=$3 physical_sector=$4 ram_bytes=$5 swap_margin_bytes=$6
  local value variable
  for variable in disk_bytes logical_sector physical_sector ram_bytes swap_margin_bytes; do
    value=${!variable}
    [[ $value =~ ^[0-9]+$ ]] || return 2
    while [[ ${#value} -gt 1 && $value == 0* ]]; do value=${value#0}; done
    (( ${#value} < 19 )) || {
      (( ${#value} == 19 )) && [[ $value < 9223372036854775808 ]] || return 2
    }
    (( value > 0 )) || return 2
    printf -v "$variable" '%s' "$value"
  done
  (( logical_sector >= 512 && logical_sector <= 65536 )) || return 2
  (( (logical_sector & (logical_sector - 1)) == 0 )) || return 2
  (( physical_sector >= logical_sector && physical_sector % logical_sector == 0 )) || return 2
  (( disk_bytes % logical_sector == 0 )) || return 1
  local total_sectors=$((disk_bytes / logical_sector))
  local align_sectors=$((1048576 / logical_sector))
  (( 1048576 % logical_sector == 0 && align_sectors > 0 )) || return 2
  local entry_sectors=$(((128 * 128 + logical_sector - 1) / logical_sector))
  local first_usable=$((2 + entry_sectors))
  local last_usable=$((total_sectors - entry_sectors - 2))
  (( last_usable > first_usable )) || return 1
  local esp_start=$((((first_usable + align_sectors - 1) / align_sectors) * align_sectors))
  local esp_sectors=$((1073741824 / logical_sector))
  (( 1073741824 % logical_sector == 0 )) || return 2
  local esp_end=$((esp_start + esp_sectors - 1))
  local root_start=$((((esp_end + 1 + align_sectors - 1) / align_sectors) * align_sectors))
  local root_end=$last_usable
  local minimum_root_bytes=$((32 * 1024 * 1024 * 1024))
  (( ram_bytes <= 9223372036854775807 - swap_margin_bytes )) || return 2
  local swap_bytes=$((ram_bytes + swap_margin_bytes))
  (( swap_bytes <= 9223372036854775807 - minimum_root_bytes )) || return 2
  local root_bytes=$(((root_end - root_start + 1) * logical_sector))
  (( esp_end <= last_usable && root_start <= root_end )) || return 1
  (( root_bytes >= minimum_root_bytes + swap_bytes )) || return 1
  _plan[status]=calculated
  _plan[logical_sector_bytes]=$logical_sector
  _plan[physical_sector_bytes]=$physical_sector
  _plan[disk_bytes]=$disk_bytes
  _plan[total_sectors]=$total_sectors
  _plan[gpt_entry_count]=128
  _plan[esp_start_sector]=$esp_start
  _plan[esp_end_sector]=$esp_end
  _plan[esp_size_bytes]=$((esp_sectors * logical_sector))
  _plan[root_start_sector]=$root_start
  _plan[root_end_sector]=$root_end
  _plan[root_size_bytes]=$root_bytes
  _plan[swapfile_target_bytes]=$swap_bytes
  _plan[minimum_root_headroom_bytes]=$minimum_root_bytes
}

# Stable key-sorted representation for review and integrity binding.
storage::plan_serialize() {
  [[ $# -eq 1 ]] || return 2
  local declaration
  declaration=$(declare -p "$1" 2>/dev/null) || return 2
  [[ $declaration == 'declare -A '* ]] || return 2
  local -n _plan="$1"
  (( ${#_plan[@]} > 0 )) || return 1
  local LC_ALL=C key value i j
  local -a keys=()
  for key in "${!_plan[@]}"; do
    [[ $key =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]] || return 1
    value=${_plan[$key]}
    [[ $value != *[[:cntrl:]]* ]] || return 1
    keys+=("$key")
  done
  for ((i=1; i<${#keys[@]}; i++)); do
    key=${keys[i]}; j=$((i - 1))
    while (( j >= 0 )) && [[ $key < ${keys[j]} ]]; do
      keys[j+1]=${keys[j]}; ((j -= 1))
    done
    keys[j+1]=$key
  done
  for key in "${keys[@]}"; do printf '%s=%s\n' "$key" "${_plan[$key]}"; done
}

# SHA-256 is an integrity binding, not an authorization mechanism.
storage::plan_digest() {
  [[ $# -eq 1 ]] || return 2
  command -v sha256sum >/dev/null 2>&1 || return 1
  local serialized digest
  serialized=$(storage::plan_serialize "$1") || return 1
  digest=$(printf '%s\\n' "$serialized" | sha256sum) || return 1
  digest=${digest%% *}
  [[ $digest =~ ^[a-f0-9]{64}$ ]] || return 1
  printf '%s\n' "$digest"
}

# Bind calculated geometry to a freshly discovered stable disk identity and
# the approved installation profile. This function only changes plan data.
storage::plan_bind_target() {
  [[ $# -eq 2 ]] || return 2
  local declaration
  declaration=$(declare -p "$1" 2>/dev/null) || return 2
  [[ $declaration == 'declare -A '* ]] || return 2
  declaration=$(declare -p "$2" 2>/dev/null) || return 2
  [[ $declaration == 'declare -A '* ]] || return 2
  local -n _plan="$1" _target="$2"
  [[ ${_plan[status]-} == calculated ]] || return 1

  local required
  for required in device_path major_minor size_bytes transport removable read_only stable_id_kind stable_id; do
    [[ -n ${_target[$required]-} ]] || return 1
  done
  [[ ${_target[device_path]} == /dev/* ]] || return 1
  [[ ${_target[major_minor]} =~ ^[0-9]+:[0-9]+$ ]] || return 1
  [[ ${_target[size_bytes]} =~ ^[0-9]+$ ]] || return 1
  [[ ${_target[transport]} == nvme && ${_target[removable]} == false && ${_target[read_only]} == false ]] || return 1
  [[ ${_target[size_bytes]} == "${_plan[disk_bytes]-}" ]] || return 1
  case ${_target[stable_id_kind]} in
    wwn) [[ -n ${_target[wwn]-} && ${_target[stable_id]} == "${_target[wwn]}" ]] || return 1 ;;
    serial) [[ -n ${_target[serial]-} && ${_target[stable_id]} == "${_target[serial]}" ]] || return 1 ;;
    *) return 1 ;;
  esac

  local key
  for key in "${!_plan[@]}"; do
    [[ $key != target_* && $key != profile_* && $key != schema_version ]] || return 2
  done
  _plan[schema_version]=1
  _plan[target_device_path]=${_target[device_path]}
  _plan[target_major_minor]=${_target[major_minor]}
  _plan[target_size_bytes]=${_target[size_bytes]}
  _plan[target_transport]=${_target[transport]}
  _plan[target_removable]=${_target[removable]}
  _plan[target_read_only]=${_target[read_only]}
  _plan[target_stable_id_kind]=${_target[stable_id_kind]}
  _plan[target_stable_id]=${_target[stable_id]}
  _plan[target_wwn]=${_target[wwn]-}
  _plan[target_serial]=${_target[serial]-}
  _plan[target_model]=${_target[model]-}
  _plan[profile_partition_table]=gpt
  _plan[profile_partition_alignment_bytes]=1048576
  _plan[profile_esp_size_bytes]=1073741824
  _plan[profile_esp_type_guid]=c12a7328-f81f-11d2-ba4b-00a0c93ec93b
  _plan[profile_esp_filesystem]=vfat
  _plan[profile_esp_mountpoint]=/efi
  _plan[profile_root_type_guid]=0fc63daf-8483-4772-8e79-3d69d8477de4
  _plan[profile_root_encryption]=luks2
  _plan[profile_root_filesystem]=ext4
  _plan[profile_root_mountpoint]=/
  _plan[profile_swap_type]=swapfile
  _plan[profile_swap_target_bytes]=${_plan[swapfile_target_bytes]}
  _plan[profile_swap_policy]=runtime_ram_plus_configured_margin
  _plan[profile_resume_policy]=defer_until_swapfile_offset_verified
  _plan[profile_bootloader]=systemd-boot
  _plan[profile_boot_artifact]=uki
  _plan[profile_uki_path]=/efi/EFI/Linux/arch-linux.efi
  _plan[profile_kernel_package]=linux
  _plan[profile_secure_boot]=disabled
}
