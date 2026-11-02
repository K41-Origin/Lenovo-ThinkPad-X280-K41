#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$ROOT/lib/storage-topology.sh"
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
sys=$tmp/sys
mkdir -p "$sys/dev/block" "$sys/devices/pci/block/nvme0n1/nvme0n1p1/holders" "$sys/devices/pci/block/nvme0n1/nvme0n1p1/slaves"
mkdir -p "$sys/devices/pci/block/nvme0n1/nvme0n1p2/holders" "$sys/devices/pci/block/nvme0n1/nvme0n1p2/slaves"
mkdir -p "$sys/devices/pci/block/nvme0n1/holders" "$sys/devices/pci/block/nvme0n1/slaves"
mkdir -p "$sys/devices/virtual/block/dm-0/holders" "$sys/devices/virtual/block/dm-0/slaves"
mkdir -p "$sys/devices/virtual/block/sda/holders" "$sys/devices/virtual/block/sda/slaves"
ln -s ../../devices/pci/block/nvme0n1 "$sys/dev/block/259:0"
ln -s ../../devices/pci/block/nvme0n1/nvme0n1p1 "$sys/dev/block/259:1"
ln -s ../../devices/pci/block/nvme0n1/nvme0n1p2 "$sys/dev/block/259:2"
ln -s ../../devices/virtual/block/dm-0 "$sys/dev/block/253:0"
ln -s ../../devices/virtual/block/sda "$sys/dev/block/8:0"
ln -s "$sys/devices/virtual/block/dm-0" "$sys/devices/pci/block/nvme0n1/nvme0n1p2/holders/dm-0"
ln -s "$sys/devices/pci/block/nvme0n1/nvme0n1p2" "$sys/devices/virtual/block/dm-0/slaves/nvme0n1p2"
cat >"$tmp/mountinfo" <<'EOF_MOUNT'
36 25 8:0 / / rw,relatime - ext4 /dev/sda rw
37 25 8:0 / /boot rw,relatime - vfat /dev/sda rw
EOF_MOUNT
cat >"$tmp/swaps" <<'EOF_SWAP'
Filename Type Size Used Priority
EOF_SWAP

storage::topology_check_target 259:0 "$sys" "$tmp/mountinfo" "$tmp/swaps"
echo 'PASS: unrelated mounted disk does not block target'

cat >"$tmp/mountinfo" <<'EOF_MOUNT'
36 25 253:0 / / rw,relatime - ext4 /dev/mapper/cryptroot rw
EOF_MOUNT
if storage::topology_check_target 259:0 "$sys" "$tmp/mountinfo" "$tmp/swaps"; then
  echo 'FAIL: mounted mapper dependent on target was accepted' >&2; exit 1
fi
echo 'PASS: rejects mounted LUKS/device-mapper dependent'

cat >"$tmp/mountinfo" <<'EOF_MOUNT'
36 25 8:0 / / rw,relatime - ext4 /dev/sda rw
38 25 259:2 / /mnt/data rw,relatime - ext4 /dev/nvme0n1p2 rw
EOF_MOUNT
if storage::topology_check_target 259:0 "$sys" "$tmp/mountinfo" "$tmp/swaps"; then
  echo 'FAIL: mounted target partition was accepted' >&2; exit 1
fi
echo 'PASS: rejects mounted target partition'

cat >"$tmp/mountinfo" <<'EOF_MOUNT'
36 25 253:0 / / rw,relatime - ext4 /dev/mapper/cryptroot rw
EOF_MOUNT
cat >"$tmp/swaps" <<'EOF_SWAP'
Filename Type Size Used Priority
/var/swapfile file 1048576 0 -2
EOF_SWAP
if storage::topology_check_target 259:0 "$sys" "$tmp/mountinfo" "$tmp/swaps"; then
  echo 'FAIL: swapfile on target-backed filesystem was accepted' >&2; exit 1
fi
echo 'PASS: rejects swapfile on target-backed filesystem'

: >"$tmp/mountinfo"
if storage::topology_check_target 259:0 "$sys" "$tmp/mountinfo" "$tmp/swaps"; then
  echo 'FAIL: unresolved swapfile mount was accepted' >&2; exit 1
fi
echo 'PASS: fails closed when swapfile backing mount is unresolved'

if storage::topology_check_target invalid "$sys" "$tmp/mountinfo" "$tmp/swaps"; then
  echo 'FAIL: invalid target major:minor accepted' >&2; exit 1
fi
echo 'PASS: rejects malformed target identity'

cat >"$tmp/mountinfo" <<'EOF_MOUNT'
40 25 8:0 / / rw,relatime - btrfs /dev/sda rw
EOF_MOUNT
if storage::topology_check_target 259:0 "$sys" "$tmp/mountinfo" "$tmp/swaps"; then
  echo 'FAIL: multi-device btrfs backing was accepted' >&2; exit 1
fi
echo 'PASS: fails closed on btrfs backing topology'

cat >"$tmp/mountinfo" <<'EOF_MOUNT'
41 25 8:0 / / rw,relatime - overlay overlay rw
EOF_MOUNT
if storage::topology_check_target 259:0 "$sys" "$tmp/mountinfo" "$tmp/swaps"; then
  echo 'FAIL: overlay backing was accepted' >&2; exit 1
fi
echo 'PASS: fails closed on overlay backing topology'

cat >"$tmp/mountinfo" <<'EOF_MOUNT'
malformed mountinfo record
EOF_MOUNT
if storage::topology_check_target 259:0 "$sys" "$tmp/mountinfo" "$tmp/swaps"; then
  echo 'FAIL: malformed mountinfo was accepted' >&2; exit 1
fi
echo 'PASS: rejects malformed mountinfo'

# Backing-path resolution is tested against real temporary files and their
# actual st_dev major:minor values; no mounts or block-device writes are used.
mkdir -p "$sys/devices/virtual/block/loop0/loop"
ln -s "$sys/devices/virtual/block/loop0" "$sys/dev/block/7:0"
backing_file="$tmp/loop-backing.img"
: >"$backing_file"
printf '%s\n' "$backing_file" >"$sys/devices/virtual/block/loop0/loop/backing_file"
backing_mm=$(storage::topology_path_major_minor "$backing_file")
[[ $backing_mm =~ ^[0-9]+:[0-9]+$ ]]
declare -A no_seen=()
storage::topology_check_loop_backing 7:0 "$sys" no_seen
echo 'PASS: resolves loop backing file on an unrelated filesystem'

declare -A loop_seen=()
loop_seen[$backing_mm]=1
if storage::topology_check_loop_backing 7:0 "$sys" loop_seen; then
  echo 'FAIL: loop backing file on target dependency was accepted' >&2; exit 1
fi
echo 'PASS: rejects loop backing file on target dependency'

storage::topology_check_overlay_options "lowerdir=$tmp,upperdir=$tmp,workdir=$tmp" no_seen
echo 'PASS: resolves overlay lower, upper, and work paths outside target dependency'
if storage::topology_check_overlay_options "lowerdir=$tmp,upperdir=$tmp,workdir=$tmp" loop_seen; then
  echo 'FAIL: overlay path on target dependency was accepted' >&2; exit 1
fi
echo 'PASS: rejects overlay paths on target dependency'

if storage::topology_check_overlay_options "lowerdir=/path/that/does/not/exist" no_seen; then
  echo 'FAIL: unresolved overlay backing path was accepted' >&2; exit 1
fi
echo 'PASS: fails closed on unresolved overlay backing path'

# Exercise the complete mountinfo dispatch for squashfs-on-loop and overlay.
cat >"$tmp/mountinfo" <<EOF_MOUNT
42 25 7:0 / /run/archiso/bootmnt rw,relatime - squashfs /dev/loop0 ro
EOF_MOUNT
cat >"$tmp/swaps" <<'EOF_SWAP'
Filename Type Size Used Priority
EOF_SWAP
storage::topology_check_target 259:0 "$sys" "$tmp/mountinfo" "$tmp/swaps"
echo 'PASS: accepts squashfs loop mount backed by an unrelated filesystem'

ln -s "$sys/devices/pci/block/nvme0n1" "$sys/dev/block/$backing_mm"
if storage::topology_check_target "$backing_mm" "$sys" "$tmp/mountinfo" "$tmp/swaps"; then
  echo 'FAIL: rejects neither loop backing on target dependency nor target alias' >&2; exit 1
fi
echo 'PASS: complete topology check rejects squashfs loop backing on target'

cat >"$tmp/mountinfo" <<EOF_MOUNT
43 25 0:42 / / rw,relatime - overlay overlay rw,lowerdir=$tmp,upperdir=$tmp,workdir=$tmp
EOF_MOUNT
storage::topology_check_target 259:0 "$sys" "$tmp/mountinfo" "$tmp/swaps"
echo 'PASS: accepts overlay mount backed by unrelated filesystem'
if storage::topology_check_target "$backing_mm" "$sys" "$tmp/mountinfo" "$tmp/swaps"; then
  echo 'FAIL: complete topology check accepted overlay path on target dependency' >&2; exit 1
fi
echo 'PASS: complete topology check rejects overlay path on target'

swap_mm=$(stat -Lc '%t:%T' /dev/null)
swap_major=$((16#${swap_mm%%:*}))
swap_minor=$((16#${swap_mm##*:}))
swap_mm=$swap_major:$swap_minor
ln -s "$sys/devices/pci/block/nvme0n1" "$sys/dev/block/$swap_mm"
cat >"$tmp/mountinfo" <<'EOF_MOUNT'
36 25 8:0 / / rw,relatime - ext4 /dev/sda rw
EOF_MOUNT
cat >"$tmp/swaps" <<'EOF_SWAP'
Filename Type Size Used Priority
/dev/null partition 1024 0 -2
EOF_SWAP
if storage::topology_check_target "$swap_mm" "$sys" "$tmp/mountinfo" "$tmp/swaps"; then
  echo 'FAIL: active block swap on target dependency was accepted' >&2; exit 1
fi
echo 'PASS: complete topology check rejects active block swap dependency'
