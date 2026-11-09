#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/stages/stage-2-basic-arch-install/scripts/install-arch-x280.sh"
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

[[ -f $SCRIPT ]] || fail "Arch installer script is missing"
bash -n "$SCRIPT" || fail "Arch installer has a Bash syntax error"
pass "installer passes bash -n"

# shellcheck disable=SC2016
for required in \
  'preflight::check_target_inventory' \
  'installer::init_logging' \
  'root="$ROOT/reports/installer"' \
  'findmnt -nro FSTYPE -T "$ROOT"' \
  'exec > >(tee -a "$installer_log_file") 2>&1' \
  'chmod 0600 "$installer_log_file"' \
  'installer::stage final-revalidation' \
  'pre-operation-check:$label' \
  'disk-operation:$label' \
  'Diagnostic log:' \
  'WDC PC SN730' \
  '256060514304' \
  'storage::plan_gpt_layout' \
  'storage::plan_confirm_interactive' \
  'storage::plan_final_revalidate' \
  'initial_target=() fresh_target=()' \
  'storage::plan_collect_live_prerequisites plan initial_target prereq' \
  'exec {disk_fd}<>"$disk"' \
  'disk_ref="/proc/self/fd/$disk_fd"' \
  'root_ref="/proc/self/fd/$root_fd"' \
  'esp_ref="/proc/self/fd/$esp_fd"' \
  'sgdisk --zap-all --clear' \
  'cryptsetup luksFormat --type luks2' \
  'base_system::bootstrap /mnt "BOOTSTRAP ARCH BASE"' \
  'mount -o fmask=0177,dmask=0077 "$esp_ref" /mnt/efi' \
  'fmask=0177' \
  'dmask=0077' \
  'install -D -m 0755 "$ROOT/scripts/x280-first-boot-check.sh" /mnt/usr/local/sbin/x280-first-boot-check' \
  '[[ -x /mnt/usr/local/sbin/x280-first-boot-check ]]' \
  "PRESETS=('default')" \
  'default_uki="/efi/EFI/Linux/arch-linux.efi"' \
  'default_cmdline="/etc/kernel/cmdline"' \
  'HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)' \
  'rd.luks.name=${root_uuid}=cryptroot root=/dev/mapper/cryptroot rw' \
  '[[ -s /mnt/efi/EFI/Linux/arch-linux.efi ]]' \
  '[[ -s /mnt/etc/locale.conf ]]'; do
  grep -Fq -- "$required" "$SCRIPT" || fail "required installer guard/action is missing: $required"
done
if grep -Eq '/var/log/x280-installer|/run/x280-installer' "$SCRIPT"; then
  fail "installer logs must remain inside the repository checkout"
fi
# shellcheck disable=SC2016
grep -Fq '[[ -e $installer_log_dir ]] ||' "$SCRIPT" || fail "installer log creation must stop on non-collision mkdir errors"
# shellcheck disable=SC2016
grep -Fq ': >"$installer_log_file" || return 1' "$SCRIPT" || fail "installer must stop if its repository log cannot be created"
# shellcheck disable=SC2016
grep -Fq 'chmod 0600 "$installer_log_file" || return 1' "$SCRIPT" || fail "installer must stop if log permissions cannot be secured"
pass "installer includes repository-local root-only logging, stage reporting, X280 profile, confirmation gate, LUKS2, base bootstrap, sd-encrypt UKI setup, and postcondition checks"
grep -Fq "grep -Eq '(^|[[:space:]])root=/dev/mapper/cryptroot([[:space:]]|$)' /etc/kernel/cmdline" "$SCRIPT" || fail "installer must validate root= as a whitespace-delimited kernel argument"
if grep -Eq '^[[:space:]]*set[[:space:]]+-[^#]*x|^[[:space:]]*set[[:space:]]+-o[[:space:]]+xtrace' "$SCRIPT"; then
  fail "installer enables shell xtrace, which could expose sensitive command arguments"
fi
pass "installer does not enable shell xtrace"
grep -Fq 'umask 022' "$SCRIPT" || fail "installer must preserve standard target directory permissions for pacstrap"
if grep -Fq 'umask 077' "$SCRIPT"; then
  fail "installer must not propagate a restrictive log umask into the installed system"
fi
pass "installer uses a normal system umask while securing diagnostic files explicitly"
# shellcheck disable=SC2016
grep -Fq '$1 == "/swapfile" && $2 == "none" && $3 == "swap"' "$SCRIPT" || fail "installer must validate swapfile source, target, and type using fstab columns"
pass "installer validates the swapfile fstab entry using the correct source/target/type columns"

fstab_sample="$(mktemp)"
trap 'rm -f -- "$fstab_sample"' EXIT
printf '%s\n' 'UUID=root / ext4 defaults 0 1' '/swapfile none swap defaults 0 0' >"$fstab_sample"
swap_count="$(awk '$0 !~ /^[[:space:]]*#/ && NF >= 3 && $1 == "/swapfile" && $2 == "none" && $3 == "swap" { count++ } END { print count + 0 }' "$fstab_sample")"
[[ $swap_count == 1 ]] || fail "valid /swapfile none swap entry must be detected"
printf '%s\n' 'UUID=root / ext4 defaults 0 1' >"$fstab_sample"
swap_count="$(awk '$0 !~ /^[[:space:]]*#/ && NF >= 3 && $1 == "/swapfile" && $2 == "none" && $3 == "swap" { count++ } END { print count + 0 }' "$fstab_sample")"
[[ $swap_count == 0 ]] || fail "missing swap entry must be rejected"
printf '%s\n' '/swapfile none swap defaults 0 0' '/swapfile none swap defaults 0 0' >"$fstab_sample"
swap_count="$(awk '$0 !~ /^[[:space:]]*#/ && NF >= 3 && $1 == "/swapfile" && $2 == "none" && $3 == "swap" { count++ } END { print count + 0 }' "$fstab_sample")"
[[ $swap_count == 2 ]] || fail "duplicate swap entries must be detected"
pass "swap fstab postcondition detects valid, missing, and duplicate entries"
log_init_line="$(grep -nF 'installer::init_logging || exit 1' "$SCRIPT" | cut -d: -f1)"
erase_line_for_log="$(grep -nF 'wipefs --all --force' "$SCRIPT" | cut -d: -f1)"
[[ -n $log_init_line && -n $erase_line_for_log ]] || fail "logging initialization or destructive step is absent"
(( log_init_line < erase_line_for_log )) || fail "logging is initialized after the first destructive operation"
pass "logging is initialized before any destructive disk operation"
preset_printf_line="$(grep -F 'default_uki=' "$SCRIPT" | grep 'printf' || true)"
[[ $preset_printf_line == *"printf '%s\\n'"* ]] || fail "mkinitcpio preset entries must use a single newline escape"
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
initial_revalidation_line="$(grep -nF 'storage::plan_collect_live_prerequisites plan initial_target prereq' "$SCRIPT" | cut -d: -f1)"
final_revalidation_line="$(grep -nF 'storage::plan_final_revalidate plan confirmation fresh_target fresh_prereq gate' "$SCRIPT" | cut -d: -f1)"
[[ -n $initial_revalidation_line && -n $final_revalidation_line ]] || fail "initial or final prerequisite revalidation call is absent"
(( initial_revalidation_line < final_revalidation_line )) || fail "final revalidation appears before initial prerequisite collection"
if grep -Fq 'storage::plan_collect_live_prerequisites plan fresh_target prereq' "$SCRIPT"; then
  fail "initial prerequisite collection reuses the final-revalidation output array"
fi
pass "initial and final revalidation use separate target snapshots, leaving final output arrays empty"

# Kernel command-line parameters are whitespace-separated tokens on one line.
cmdline_sample='rd.luks.name=01234567-89ab-cdef-0123-456789abcdef=cryptroot root=/dev/mapper/cryptroot rw'
grep -Eq '(^|[[:space:]])root=/dev/mapper/cryptroot([[:space:]]|$)' <<<"$cmdline_sample" || fail "root= token must be found after rd.luks.name on the same kernel command line"
pass "UKI kernel command-line root token is validated as a whitespace-delimited argument"

printf '%s\n' 'All Arch installer script tests passed.'
