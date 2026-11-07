#!/usr/bin/env bash
# Integration test: prove core disk tools accept inherited descriptor-pinned block paths.
set -Eeuo pipefail
if (( EUID != 0 )); then
  if command -v sudo >/dev/null 2>&1; then exec sudo bash "$0"; fi
  printf 'SKIP: requires root for loop-device integration test.\n'
  exit 0
fi

for cmd in losetup sgdisk wipefs partprobe udevadm mkfs.fat cryptsetup mkfs.ext4 blkid mount umount findmnt; do
  command -v "$cmd" >/dev/null 2>&1 || { printf 'SKIP: missing command: %s\n' "$cmd"; exit 0; }
done

tmp="$(mktemp -d)"
loop=
mapper=
cleanup() {
  local rc=$?
  if [[ -n $mapper ]] && cryptsetup status "$mapper" >/dev/null 2>&1; then
    cryptsetup close "$mapper" || true
  fi
  if [[ -n ${root_fd-} ]]; then exec {root_fd}>&-; fi
  if [[ -n ${esp_fd-} ]]; then exec {esp_fd}>&-; fi
  if [[ -n ${disk_fd-} ]]; then exec {disk_fd}>&-; fi
  if [[ -n $loop ]]; then
    losetup -d "$loop" >/dev/null 2>&1 || true
  fi
  rm -rf -- "$tmp"
  exit "$rc"
}
trap cleanup EXIT

truncate -s 768M "$tmp/disk.img"
head -c 64 /dev/urandom > "$tmp/key"
chmod 0600 "$tmp/key"
loop="$(losetup --find --show --partscan "$tmp/disk.img")"
[[ -b $loop ]] || { printf 'FAIL: losetup did not return a block device.\n' >&2; exit 1; }

# The descriptor is deliberately inherited by child tools. The procfs magic
# link resolves to the pinned open block-device object, not a re-resolved /dev path.
exec {disk_fd}<>"$loop"
disk_ref="/proc/self/fd/$disk_fd"
[[ -b $disk_ref ]] || { printf 'FAIL: pinned whole-disk descriptor is not a block device.\n' >&2; exit 1; }
wipefs --all --force "$disk_ref"
sgdisk --zap-all --clear \
  --new=1:2048:+128M --typecode=1:ef00 --change-name=1:K41-ESP \
  --new=2:0:0 --typecode=2:8309 --change-name=2:K41-ROOT "$disk_ref"
partprobe "$disk_ref"
udevadm settle

if [[ $loop == *loop* ]]; then
  esp="${loop}p1"
  root_part="${loop}p2"
else
  printf 'FAIL: unexpected loop device name.\n' >&2
  exit 1
fi
[[ -b $esp && -b $root_part ]] || { printf 'FAIL: loop partition nodes were not created.\n' >&2; exit 1; }

exec {esp_fd}<>"$esp"
exec {root_fd}<>"$root_part"
esp_ref="/proc/self/fd/$esp_fd"
root_ref="/proc/self/fd/$root_fd"
[[ -b $esp_ref && -b $root_ref ]] || { printf 'FAIL: pinned partition descriptors are not block devices.\n' >&2; exit 1; }

mkfs.fat -F 32 "$esp_ref" >/dev/null
# Verify the filesystem before mounting so a descriptor/path problem is not
# obscured by mount(8) filesystem auto-probing and its final probe error.
blkid -p "$esp_ref" | grep -q 'TYPE="vfat"' || {
  printf 'FAIL: mkfs.fat did not produce a detectable vfat filesystem on the pinned ESP.\n' >&2
  exit 1
}
mkdir "$tmp/esp-mount"
mount -t vfat "$esp_ref" "$tmp/esp-mount"
esp_source="$(findmnt --noheadings --raw --mountpoint "$tmp/esp-mount" --output SOURCE)"
[[ $esp_source == /dev/* ]] || { printf 'FAIL: pinned ESP mount did not resolve to a block-device source.\n' >&2; exit 1; }
umount "$tmp/esp-mount"
cryptsetup luksFormat --batch-mode --type luks2 --key-file "$tmp/key" "$root_ref"
mapper=k41-ci-pinned-test
cryptsetup open --key-file "$tmp/key" "$root_ref" "$mapper"
mkfs.ext4 -F "/dev/mapper/$mapper" >/dev/null
blkid "/dev/mapper/$mapper" | grep -q 'TYPE="ext4"'
printf 'PASS: wipefs, sgdisk, partprobe, mkfs.fat, cryptsetup, and mkfs.ext4 operate through inherited pinned block descriptors.\n'
