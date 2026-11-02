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
