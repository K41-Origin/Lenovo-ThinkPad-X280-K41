#!/usr/bin/env bash
# Read-only kernel block topology checks. No storage mutation is permitted here.

storage::topology_decode_mount_field() {
  local value=$1
  value=${value//\\040/ }
  value=${value//\\011/$'\t'}
  value=${value//\\012/$'\n'}
  value=${value//\\134/\\}
  printf '%s' "$value"
}

# Parse one mountinfo record and reject filesystems whose backing-device
# relationship is not safely represented by mountinfo's major:minor field.
storage::topology_parse_mount_record() {
  [[ $# -eq 1 ]] || return 2
  local -a fields=()
  local separator=-1 i
  read -r -a fields <<< "$1"
  (( ${#fields[@]} >= 10 )) || return 1
  for ((i=6; i<${#fields[@]}; i++)); do
    if [[ ${fields[i]} == - ]]; then separator=$i; break; fi
  done
  (( separator >= 6 && ${#fields[@]} > separator + 2 )) || return 1
  TOPOLOGY_MOUNT_MM=${fields[2]}
  TOPOLOGY_MOUNT_POINT=$(storage::topology_decode_mount_field "${fields[4]}") || return 1
  TOPOLOGY_MOUNT_FSTYPE=${fields[separator+1]}
  [[ $TOPOLOGY_MOUNT_MM =~ ^[0-9]+:[0-9]+$ && -n $TOPOLOGY_MOUNT_POINT ]] || return 1
  case $TOPOLOGY_MOUNT_FSTYPE in
    ext2|ext3|ext4|xfs|vfat|fat|msdos|exfat|ntfs|ntfs3|f2fs|jfs|reiserfs|udf|iso9660)
      ;;
    proc|sysfs|tmpfs|devtmpfs|devpts|cgroup|cgroup2|mqueue|securityfs|debugfs|tracefs|pstore|configfs|autofs|rpc_pipefs|hugetlbfs|binfmt_misc|efivarfs|bpf)
      # Kernel pseudo-filesystems do not represent block-device backing.
      ;;
    *)
      printf 'storage: cannot prove backing-device topology for filesystem type %s\\n' "$TOPOLOGY_MOUNT_FSTYPE" >&2
      return 1
      ;;
  esac
}

# Return success only when the target's sysfs dependency closure is known and
# no mounted filesystem or active swap uses any device in that closure.
# Args: target major:minor, sysfs root, mountinfo file, swaps file.
storage::topology_check_target() {
  [[ $# -eq 4 ]] || return 2
  local target_mm=$1 sys_root=$2 mountinfo=$3 swaps_file=$4
  [[ $target_mm =~ ^[0-9]+:[0-9]+$ ]] || return 2
  [[ -d $sys_root/dev/block && -r $mountinfo && -r $swaps_file ]] || return 1
  command -v readlink >/dev/null 2>&1 || return 1
  command -v stat >/dev/null 2>&1 || return 1

  local target_link target_real candidate candidate_real rel
  target_link=$sys_root/dev/block/$target_mm
  [[ -L $target_link ]] || return 1
  target_real=$(readlink -f -- "$target_link") || return 1
  [[ -d $target_real ]] || return 1

  local -A seen=()
  local -a queue=()
  local node node_real entry mm
  queue+=("$target_real")
  seen[$target_mm]=1

  # Include all partition devices physically below the selected whole disk.
  # Also include holder/slave dependencies recursively (dm-crypt, RAID, etc.).
  shopt -s nullglob
  for entry in "$sys_root"/dev/block/*; do
    [[ -L $entry ]] || { shopt -u nullglob; return 1; }
    candidate_real=$(readlink -f -- "$entry") || { shopt -u nullglob; return 1; }
    if [[ $candidate_real == "$target_real/"* ]]; then
      mm=${entry##*/}
      [[ $mm =~ ^[0-9]+:[0-9]+$ ]] || { shopt -u nullglob; return 1; }
      if [[ ! -v seen[$mm] ]]; then
        seen[$mm]=1
        queue+=("$candidate_real")
      fi
    fi
  done
  shopt -u nullglob

  local index=0
  while (( index < ${#queue[@]} )); do
    node=${queue[index]}
    ((index += 1))
    for rel in holders slaves; do
      [[ -d $node/$rel && -r $node/$rel ]] || return 1
      shopt -s nullglob
      for entry in "$node/$rel"/*; do
        node_real=$(readlink -f -- "$entry") || { shopt -u nullglob; return 1; }
        [[ -d $node_real ]] || { shopt -u nullglob; return 1; }
        mm=
        for candidate in "$sys_root"/dev/block/*; do
          [[ -L $candidate ]] || continue
          candidate_real=$(readlink -f -- "$candidate") || { shopt -u nullglob; return 1; }
          if [[ $candidate_real == "$node_real" ]]; then mm=${candidate##*/}; break; fi
        done
        [[ $mm =~ ^[0-9]+:[0-9]+$ ]] || { shopt -u nullglob; return 1; }
        if [[ ! -v seen[$mm] ]]; then
          seen[$mm]=1
          queue+=("$node_real")
        fi
      done
      shopt -u nullglob
    done
  done

  # Every mounted filesystem is compared by kernel major:minor, not source
  # spelling. An unreadable/malformed mountinfo record is an unsafe result.
  local line rest mount_mm mount_point
  while IFS= read -r line; do
    [[ -n $line ]] || continue
    storage::topology_parse_mount_record "$line" || return 1
    mount_mm=$TOPOLOGY_MOUNT_MM
    mount_point=$TOPOLOGY_MOUNT_POINT
    if [[ -v seen[$mount_mm] ]]; then
      printf 'storage: target topology is mounted at %s (device %s)\n' "$mount_point" "$mount_mm" >&2
      return 1
    fi
  done < "$mountinfo"

  # /proc/swaps lists both block devices and swapfiles. Resolve block devices
  # by stat(2); resolve files to the longest containing mountpoint in mountinfo.
  local swap_source swap_mm hex_major hex_minor major minor best_len best_mm decoded
  local first=1
  while read -r swap_source _; do
    [[ -n $swap_source ]] || continue
    if (( first )); then first=0; continue; fi
    if [[ $swap_source == /dev/* ]]; then
      [[ -e $swap_source ]] || return 1
      local dev_hex
      dev_hex=$(stat -Lc '%t:%T' -- "$swap_source") || return 1
      [[ $dev_hex =~ ^([0-9a-fA-F]+):([0-9a-fA-F]+)$ ]] || return 1
      major=$((16#${BASH_REMATCH[1]}))
      minor=$((16#${BASH_REMATCH[2]}))
      swap_mm=$major:$minor
    else
      best_len=-1; best_mm=
      while IFS= read -r line; do
        storage::topology_parse_mount_record "$line" || return 1
        decoded=$TOPOLOGY_MOUNT_POINT
        if [[ $decoded == "/" && $swap_source == /* ]] || [[ $swap_source == "$decoded" || $swap_source == "$decoded/"* ]]; then
          if (( ${#decoded} > best_len )); then
            best_len=${#decoded}; best_mm=$TOPOLOGY_MOUNT_MM
          fi
        fi
      done < "$mountinfo"
      [[ $best_len -ge 0 && $best_mm =~ ^[0-9]+:[0-9]+$ ]] || return 1
      swap_mm=$best_mm
    fi
    if [[ -v seen[$swap_mm] ]]; then
      printf 'storage: target topology backs active swap %s (device %s)\n' "$swap_source" "$swap_mm" >&2
      return 1
    fi
  done < "$swaps_file"

  return 0
}
