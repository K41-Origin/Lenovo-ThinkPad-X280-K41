#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../lib/base-system.sh
source "$ROOT/lib/base-system.sh"

if (( EUID != 0 )); then
  command -v sudo >/dev/null 2>&1 || {
    printf 'FAIL: test requires root or passwordless sudo\\n' >&2
    exit 1
  }
  exec sudo -- bash "$0"
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf -- "$tmpdir"' EXIT
target="$tmpdir/target"
mkdir -p "$target/etc"
: >"$target/etc/fstab"

base_system::validate_mounts() { return 0; }
k41::log_error() { printf 'ERROR: %s\n' "$*" >&2; }
k41::log_info() { printf 'INFO: %s\n' "$*"; }
genfstab() {
  cat <<'EOF'
UUID=root-uuid / ext4 rw,relatime 0 1
UUID=efi-uuid /efi vfat rw,relatime,fmask=0022,dmask=0022 0 2
EOF
}

# Existing package-provided comments and unrelated mounts must be preserved.
cat >"$target/etc/fstab" <<'EOF'
# Static information about the filesystems.
tmpfs /tmp tmpfs nosuid,nodev 0 0
EOF
base_system::generate_fstab "$target" 'WRITE FSTAB'
grep -Fxq 'tmpfs /tmp tmpfs nosuid,nodev 0 0' "$target/etc/fstab"
grep -Fxq 'UUID=root-uuid / ext4 rw,relatime 0 1' "$target/etc/fstab"
grep -Fxq 'UUID=efi-uuid /efi vfat rw,relatime,fmask=0022,dmask=0022 0 2' "$target/etc/fstab"
[[ "$(grep -cE '^[^#[:space:]]+[[:space:]]+/$' "$target/etc/fstab" || true)" -eq 0 ]]

# Re-running is idempotent: it must not duplicate the two generated mountpoints.
before="$(cat "$target/etc/fstab")"
base_system::generate_fstab "$target" 'WRITE FSTAB'
[[ "$(cat "$target/etc/fstab")" == "$before" ]]

# A conflicting root entry must fail closed and leave the file byte-for-byte intact.
printf '%s\n' 'UUID=wrong-root / ext4 defaults 0 1' >>"$target/etc/fstab"
before="$(cat "$target/etc/fstab")"
if base_system::generate_fstab "$target" 'WRITE FSTAB'; then
  printf 'FAIL: conflicting fstab entry was accepted\n' >&2
  exit 1
fi
[[ "$(cat "$target/etc/fstab")" == "$before" ]]

# Verify the base package set explicitly selects providers to avoid pacstrap prompts.
pacstrap() { printf '%s\n' "$@" >"$tmpdir/pacstrap.args"; }
base_system::install_packages "$target" 'INSTALL BASE SYSTEM'
grep -Fxq iptables "$tmpdir/pacstrap.args"
grep -Fxq mkinitcpio "$tmpdir/pacstrap.args"

echo 'PASS: fstab generation preserves unrelated entries, is idempotent, and rejects conflicting mountpoints'
