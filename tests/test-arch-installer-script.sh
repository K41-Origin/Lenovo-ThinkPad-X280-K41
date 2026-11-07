#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/scripts/install-arch-x280.sh"
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

[[ -f $SCRIPT ]] || fail "Arch installer script is missing"
bash -n "$SCRIPT" || fail "Arch installer has a Bash syntax error"
pass "installer passes bash -n"

# shellcheck disable=SC2016
for required in \
  'preflight::check_target_inventory' \
  'WDC PC SN730' \
  '256052966400' \
  'storage::plan_gpt_layout' \
  'storage::plan_confirm_interactive' \
  'storage::plan_final_revalidate' \
  'exec {disk_fd}<>"$disk"' \
  'disk_ref="/proc/self/fd/$disk_fd"' \
  'root_ref="/proc/self/fd/$root_fd"' \
  'esp_ref="/proc/self/fd/$esp_fd"' \
  'sgdisk --zap-all --clear' \
  'cryptsetup luksFormat --type luks2' \
  'base_system::bootstrap /mnt "BOOTSTRAP ARCH BASE"' \
  "PRESETS=('default')" \
  'default_uki="/efi/EFI/Linux/arch-linux.efi"' \
  'default_cmdline="/etc/kernel/cmdline"' \
  'HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)' \
  'rd.luks.name=${root_uuid}=cryptroot root=/dev/mapper/cryptroot rw' \
  '[[ -s /mnt/efi/EFI/Linux/arch-linux.efi ]]' \
  '[[ -s /mnt/etc/locale.conf ]]'; do
  grep -Fq -- "$required" "$SCRIPT" || fail "required installer guard/action is missing: $required"
done
pass "installer includes X280 profile, confirmation gate, LUKS2, base bootstrap, sd-encrypt UKI setup, and postcondition checks"
preset_printf_line="$(grep -F 'default_uki=' "$SCRIPT" | grep 'printf' || true)"
[[ $preset_printf_line == *"printf '%s\\n'"* ]] || fail "mkinitcpio preset entries must use a single newline escape"
pass "mkinitcpio preset formatter uses real newline delimiters"
if grep -Eq 'user non-root, locale, timezone, hostname, swapfile.*belum dijalankan|chroot manual untuk menyelesaikan konfigurasi' "$SCRIPT"; then
  fail "installer completion message contradicts the target configuration stage"
fi
pass "installer completion message matches the configuration stage actually run"
[[ $preset_printf_line == *"printf '%s\\\\n'"* ]] || fail "mkinitcpio preset entries must use a single newline escape"
pass "mkinitcpio preset formatter uses real newline delimiters"
if grep -Eq 'user non-root, locale, timezone, hostname, swapfile.*belum dijalankan|chroot manual untuk menyelesaikan konfigurasi' "$SCRIPT"; then
  fail "installer completion message contradicts the target configuration stage"
fi
pass "installer completion message matches the configuration stage actually run"

if grep -Eq 'swapoff[[:space:]]+-a|pacstrap[[:space:]]+-K[[:space:]]+/mnt' "$SCRIPT"; then
  fail "installer bypasses guarded base bootstrap or disables unrelated swap"
fi
pass "installer does not disable all live-ISO swap or bypass base-system module"

confirmation_line="$(grep -nF 'storage::plan_confirm_interactive plan confirmation' "$SCRIPT" | cut -d: -f1)"
revalidate_line="$(grep -nF 'storage::plan_final_revalidate plan confirmation' "$SCRIPT" | cut -d: -f1)"
erase_line="$(grep -nF 'wipefs --all --force' "$SCRIPT" | cut -d: -f1)"
[[ -n $confirmation_line && -n $revalidate_line && -n $erase_line ]] || fail "confirmation, revalidation, or erase step is absent"
(( confirmation_line < revalidate_line && revalidate_line < erase_line )) || fail "destructive step appears before confirmation/revalidation"
pass "destructive signature erasure is ordered after confirmation and final revalidation"

printf '%s\n' 'All Arch installer script tests passed.'
