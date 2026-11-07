#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/scripts/x280-first-boot-check.sh"
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

[[ -f $SCRIPT ]] || fail "first-boot collector is missing"
bash -n "$SCRIPT" || fail "first-boot collector has a Bash syntax error"
pass "first-boot collector passes bash -n"

tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
mock_bin="$tmp/bin"
sys_root="$tmp/sys"
etc_root="$tmp/etc"
report_root="$tmp/reports"
efi_root="$tmp/efi"
mkdir -p "$mock_bin" "$sys_root/firmware/efi" "$sys_root/class/dmi/id" "$etc_root" "$efi_root/EFI/Linux"
: >"$etc_root/arch-release"
printf 'LENOVO\n' >"$sys_root/class/dmi/id/sys_vendor"
printf '20KESC2Y00\n' >"$sys_root/class/dmi/id/product_name"
printf 'N20ET49W\n' >"$sys_root/class/dmi/id/bios_version"
: >"$efi_root/EFI/Linux/arch-linux.efi"

cat >"$mock_bin/findmnt" <<'MOCK'
#!/usr/bin/env bash
case " $* " in
  *" /efi "*) printf '/efi vfat\n' ;;
  *" / "*) printf '/dev/mapper/cryptroot ext4\n' ;;
  *) exit 1 ;;
esac
MOCK
cat >"$mock_bin/cryptsetup" <<'MOCK'
#!/usr/bin/env bash
[[ $* == "status cryptroot" ]] || exit 1
printf 'cryptroot is active.\n'
MOCK
cat >"$mock_bin/bootctl" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
  status) printf 'Systemd Boot Loader: systemd-boot\n' ;;
  list) printf 'arch-linux.conf\n' ;;
  *) exit 1 ;;
esac
MOCK
cat >"$mock_bin/systemctl" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
  is-system-running) printf 'running\n' ;;
  --failed) exit 0 ;;
  get-default) printf 'multi-user.target\n' ;;
  is-active)
    [[ " $* " == *" NetworkManager "* || " $* " == *" multi-user.target "* ]] || exit 1
    printf 'active\n'
    ;;
  *) exit 1 ;;
esac
MOCK
cat >"$mock_bin/nmcli" <<'MOCK'
#!/usr/bin/env bash
printf 'connected\n'
MOCK
cat >"$mock_bin/lscpu" <<'MOCK'
#!/usr/bin/env bash
printf 'Model name: Intel Core i5-8250U\n'
MOCK
cat >"$mock_bin/free" <<'MOCK'
#!/usr/bin/env bash
printf 'Mem: 7.5Gi 2.0Gi\n'
MOCK
cat >"$mock_bin/lsblk" <<'MOCK'
#!/usr/bin/env bash
printf 'nvme0n1 disk 238G crypto_LUKS WDC\n'
MOCK
cat >"$mock_bin/lspci" <<'MOCK'
#!/usr/bin/env bash
printf '00:02.0 VGA compatible controller: Intel UHD Graphics 620\n'
MOCK
chmod +x "$mock_bin"/*

run_dir="$tmp/run"
mkdir -p "$run_dir"
(
  cd "$ROOT"
  PATH="$mock_bin:$PATH" \
  K41_FIRST_BOOT_SYS_ROOT="$sys_root" \
  K41_FIRST_BOOT_ETC_ROOT="$etc_root" \
  K41_FIRST_BOOT_REPORT_ROOT="$report_root" \
  K41_FIRST_BOOT_ESP_ROOT="$efi_root" \
  K41_FIRST_BOOT_BOOT_ROOT="$tmp/boot" \
  SUDO_UID=1000 \
    bash "$SCRIPT"
) >"$run_dir/pass.out" 2>&1 || fail "collector did not pass with healthy mocked first-boot state"
report="$(find "$report_root" -name summary.md -print -quit)"
[[ -n $report ]] || fail "summary.md was not generated"
report_dir="${report%/*}"
for file in summary.md diagnostics.log boot-status.txt system-status.txt hardware.txt; do
  [[ -s "$report_dir/$file" ]] || fail "expected evidence file missing or empty: $file"
done
grep -Fq -- '- Result: **PASS**' "$report" || fail "healthy fixture did not produce PASS"
grep -Fq 'Encrypted root mount' "$report" || fail "root encryption check is absent from summary"
grep -Fq 'Network connected' "$report" || fail "network check is absent from summary"
grep -Fq '20KESC2Y00' "$report_dir/hardware.txt" || fail "hardware profile evidence was not captured"
pass "healthy mocked first boot generates complete PASS report and evidence files"

# A failed systemd unit must make the overall collector exit non-zero.
cat >"$mock_bin/systemctl" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
  is-system-running) printf 'running\n' ;;
  --failed) printf 'broken.service loaded failed failed Test failure\n' ;;
  get-default) printf 'multi-user.target\n' ;;
  is-active) printf 'active\n' ;;
  *) exit 1 ;;
esac
MOCK
chmod +x "$mock_bin/systemctl"
failed_reports="$tmp/failed-reports"
if (
  cd "$ROOT"
  PATH="$mock_bin:$PATH" \
  K41_FIRST_BOOT_SYS_ROOT="$sys_root" \
  K41_FIRST_BOOT_ETC_ROOT="$etc_root" \
  K41_FIRST_BOOT_REPORT_ROOT="$failed_reports" \
  K41_FIRST_BOOT_ESP_ROOT="$efi_root" \
  K41_FIRST_BOOT_BOOT_ROOT="$tmp/boot" \
  SUDO_UID=1000 \
    bash "$SCRIPT"
) >"$run_dir/fail.out" 2>&1; then
  fail "collector returned success despite a failed systemd unit"
fi
failed_summary="$(find "$failed_reports" -name summary.md -print -quit)"
[[ -n $failed_summary ]] || fail "failure report was not generated"
grep -Fq -- '- Result: **FAIL**' "$failed_summary" || fail "failed systemd unit was not reflected in report"
grep -Fq '**FAIL**' "$failed_summary" || fail "failed check row is missing"
pass "failed systemd unit produces a retained FAIL report and non-zero exit"

if grep -Eq 'wipefs|sgdisk|mkfs\\.|cryptsetup[[:space:]]+(luksFormat|open)|pacstrap|systemctl[[:space:]]+(enable|disable|start|stop)' "$SCRIPT"; then
  fail "first-boot collector contains a mutating installer/service command"
fi
pass "first-boot collector contains no disk, encryption, package, or service mutation command"

printf '%s\n' 'All X280 first-boot collector tests passed.'
