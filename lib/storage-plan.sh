#!/usr/bin/env bash
# Pure arithmetic storage layout planner. This module never invokes disk tools.

storage::plan_gpt_layout() {
  [[ $# -eq 6 ]] || return 2
  local -n _plan=$1
  [[ $(declare -p "$1" 2>/dev/null) == 'declare -A '* ]] || return 2
  [[ ! -v _plan[status] ]] || return 2
  local disk_bytes=$2 logical_sector=$3 physical_sector=$4 ram_bytes=$5 swap_margin_bytes=$6
  local value
  for value in "$disk_bytes" "$logical_sector" "$physical_sector" "$ram_bytes" "$swap_margin_bytes"; do
    [[ $value =~ ^[0-9]+$ ]] || return 2
    (( value > 0 )) || return 2
  done
  (( logical_sector >= 512 && logical_sector <= 65536 )) || return 2
  (( (logical_sector & (logical_sector - 1)) == 0 )) || return 2
  (( physical_sector >= logical_sector && physical_sector % logical_sector == 0 )) || return 2
  (( disk_bytes % logical_sector == 0 )) || return 1

  local total_sectors=$((disk_bytes / logical_sector))
  local align_sectors=$((1048576 / logical_sector))
  (( 1048576 % logical_sector == 0 )) || return 2
  (( align_sectors > 0 )) || return 2

  # GPT uses a 128-entry (16 KiB) array; reserve one header sector
  # plus the rounded-up entry-array sectors at both ends of the disk.
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
  local swap_bytes=$((ram_bytes + swap_margin_bytes))
  local root_bytes=$(((root_end - root_start + 1) * logical_sector))
  local minimum_root_bytes=$((32 * 1024 * 1024 * 1024))

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
