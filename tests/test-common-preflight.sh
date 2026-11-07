#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

# Sourcing must not emit output or alter shell options/traps.
before_options="$(set +o)"
before_traps="$(trap -p)"
source "$repo_root/lib/common.sh" >"$tmp/source.out" 2>"$tmp/source.err" || fail 'common module sourcing returned failure'
source "$repo_root/lib/preflight.sh" >>"$tmp/source.out" 2>>"$tmp/source.err" || fail 'preflight module sourcing returned failure'
[[ ! -s "$tmp/source.out" && ! -s "$tmp/source.err" ]] || fail 'module sourcing emitted output'
[[ "$(set +o)" == "$before_options" ]] || fail 'module sourcing changed shell options'
[[ "$(trap -p)" == "$before_traps" ]] || fail 'module sourcing changed traps'
pass 'module sourcing has no output or shell-option/trap changes'

# Logging goes to stderr and validates its argument count.
log_stdout="$(k41::log_info 'diagnostic' 2>/dev/null)" || fail 'info logger failed'
[[ -z "$log_stdout" ]] || fail 'logger wrote to stdout'
log_stderr="$(k41::log_info 'diagnostic' 2>&1 >/dev/null)"
[[ "$log_stderr" == 'INFO: diagnostic' ]] || fail 'logger stderr format mismatch'
if k41::log_warn >/dev/null 2>&1; then fail 'logger accepted missing argument'; fi
pass 'logging helpers validate arguments and write to stderr'

# Boot-mode detector accepts a fixture root, allowing deterministic tests.
mkdir -p "$tmp/uefi/efi" "$tmp/legacy"
preflight::detect_boot_mode_at "$tmp/uefi" 2>"$tmp/uefi.log" || fail 'UEFI fixture failed'
grep -q 'UEFI' "$tmp/uefi.log" || fail 'UEFI result not reported'
if preflight::detect_boot_mode_at "$tmp/legacy" 2>"$tmp/legacy.log"; then
  fail 'legacy candidate was incorrectly treated as verified'
fi
grep -q 'legacy/BIOS candidate only' "$tmp/legacy.log" || fail 'legacy candidate not reported as uncertain'
if preflight::detect_boot_mode_at "$tmp/missing" 2>"$tmp/unknown.log"; then
  fail 'unknown firmware state was treated as success'
fi
grep -q 'unknown' "$tmp/unknown.log" || fail 'unknown state not reported'
pass 'boot-mode detection distinguishes UEFI, legacy candidate, and unknown'

# Required-command check handles present, absent, and invalid names.
preflight::check_commands bash 2>"$tmp/commands-ok.log" || fail 'present command not detected'
if preflight::check_commands command-that-does-not-exist-k41 2>"$tmp/commands-missing.log"; then
  fail 'missing command was treated as success'
fi
if preflight::check_commands 'bad/name' 2>"$tmp/commands-invalid.log"; then
  fail 'invalid command name was accepted'
fi
pass 'required-command check handles present, missing, and invalid names'

# Network diagnostic uses only a read-only link query.
mkdir -p "$tmp/bin"
cat >"$tmp/bin/ip" <<'MOCK_IP'
#!/usr/bin/env bash
[[ "$*" == '-brief link show' ]] || exit 9
printf 'lo UNKNOWN 00:00:00:00:00:00\n'
MOCK_IP
chmod +x "$tmp/bin/ip"
PATH="$tmp/bin:$PATH" preflight::report_network_links 2>"$tmp/network.log" || fail 'mock network link query failed'
grep -q 'not proof of internet connectivity' "$tmp/network.log" || fail 'network limitation not disclosed'
grep -q 'lo UNKNOWN' "$tmp/network.log" || fail 'network link observation missing'
pass 'network check reports link state without claiming internet access'

mkdir -p "$tmp/empty-bin"
if PATH="$tmp/empty-bin" preflight::report_network_links 2>"$tmp/network-unknown.log"; then
  fail 'network check treated unavailable ip tool as verified'
fi
grep -q 'state unknown' "$tmp/network-unknown.log" || fail 'unavailable ip tool was not reported as unknown'
pass 'network check reports unavailable diagnostics as unknown'


# Base-system module is source-safe and validates exact encrypted-root/ESP mounts.
before_options="$(set +o)"
before_traps="$(trap -p)"
source "$repo_root/lib/base-system.sh" >"$tmp/base-source.out" 2>"$tmp/base-source.err" || fail 'base-system module sourcing failed'
[[ ! -s "$tmp/base-source.out" && ! -s "$tmp/base-source.err" ]] || fail 'base-system sourcing emitted output'
[[ "$(set +o)" == "$before_options" ]] || fail 'base-system sourcing changed shell options'
[[ "$(trap -p)" == "$before_traps" ]] || fail 'base-system sourcing changed traps'
mkdir -p "$tmp/target/efi" "$tmp/bin"
cat >"$tmp/bin/findmnt" <<'MOCK_FINDMNT'
#!/usr/bin/env bash
mountpoint=
while (($#)); do
  case $1 in
    --mountpoint) mountpoint=$2; shift 2 ;;
    *) shift ;;
  esac
done
case $mountpoint in
  */efi) printf '%s /dev/nvme0n1p1 vfat\n' "$mountpoint" ;;
  *) printf '%s /dev/mapper/cryptroot %s\n' "$mountpoint" "${K41_TEST_ROOT_FSTYPE:-ext4}" ;;
esac
MOCK_FINDMNT
chmod +x "$tmp/bin/findmnt"
PATH="$tmp/bin:$PATH" base_system::validate_mounts "$tmp/target" 2>"$tmp/base-mounts.log" || fail 'valid encrypted-root and ESP mount fixture rejected'
grep -q 'Mounted target accepted' "$tmp/base-mounts.log" || fail 'valid mount fixture was not reported'
if PATH="$tmp/bin:$PATH" K41_TEST_ROOT_FSTYPE=btrfs base_system::validate_mounts "$tmp/target" >/dev/null 2>&1; then
  fail 'non-ext4 target root was accepted'
fi
if base_system::validate_mounts / >/dev/null 2>&1; then
  fail 'live root filesystem was accepted as installation target'
fi
if base_system::install_packages "$tmp/target" WRONG-CONFIRMATION >/dev/null 2>&1; then
  fail 'base package stage accepted an incorrect confirmation'
fi
pass 'base-system module validates encrypted ext4 root, separate vfat ESP, and explicit confirmation'

printf '%s\\n' 'All common/preflight tests passed.'
