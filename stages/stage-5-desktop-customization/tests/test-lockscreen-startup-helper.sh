#!/usr/bin/env bash
set -Eeuo pipefail

root="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
helper="$root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-lock-caelestia-after-start.sh"
updater="$root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-update-lockscreen-startup-helper.sh"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*"; }

for script in "$helper" "$updater"; do
    [[ -s $script ]] || fail "missing script: $script"
    bash -n "$script" || fail "invalid Bash syntax: $script"
done

grep -Fq 'K41_LOCK_READY_TIMEOUT' "$helper" || fail 'lock helper readiness timeout missing'
grep -Fq 'deadline=$((SECONDS + ready_timeout))' "$helper" || fail 'lock helper does not use a bounded readiness deadline'
grep -Fq '(( ready_timeout <= 30 ))' "$helper" || fail 'lock helper readiness budget is not capped below the handoff timeout'
grep -Fq '(( verify_attempts <= 10 ))' "$helper" || fail 'lock helper verification count is not capped'
grep -Fq 'for ((attempt = 1; attempt <= verify_attempts; attempt++))' "$helper" ||
    fail 'lock verification is not bounded'
grep -Fq 'helper-backups' "$updater" || fail 'updater does not preserve the previous helper'
grep -Fq 'cmp -s "$source_helper" "$target"' "$updater" || fail 'updater does not verify the installed helper'
! grep -Eiq '^[[:space:]]*(systemctl|pacman|sudo|cryptsetup|mkinitcpio|plymouth-set-default-theme)([[:space:]]|$)' "$updater" ||
    fail 'user-local updater contains an unrelated system mutation'
pass 'lock helper and updater pass syntax and bounded-timeout safety checks'

fixture="$(mktemp -d)"
trap 'rm -rf -- "$fixture"' EXIT
home="$fixture/home"
mkdir -m 0700 -- "$home"

# First run installs the helper into an isolated HOME.
env HOME="$home" bash "$updater" >/dev/null
target="$home/.local/bin/k41-lock-caelestia-after-start"
[[ -x $target && ! -L $target ]] || fail 'updater did not create a user-local executable'
cmp -s "$helper" "$target" || fail 'installed helper differs from Workstream 02 source'
pass 'updater installs and verifies the helper in an isolated HOME'

# A locally modified prior helper is backed up before it is replaced.
printf '\n# local legacy fixture\n' >>"$target"
env HOME="$home" bash "$updater" >/dev/null
cmp -s "$helper" "$target" || fail 'updater did not replace the outdated helper'
mapfile -t backups < <(find "$home/.local/state/k41/lockscreen/helper-backups" -maxdepth 1 -type f -name '*.sh' -print)
[[ ${#backups[@]} -eq 1 ]] || fail "expected one backup, found ${#backups[@]}"
grep -Fq 'local legacy fixture' "${backups[0]}" || fail 'backup did not preserve the previous helper content'
[[ $(stat -c %a "${backups[0]}") == 600 ]] || fail 'helper backup is not private (0600)'
pass 'updater backs up a modified prior helper before atomic replacement'

# Symlink targets are rejected and left untouched.
rm -f -- "$target"
ln -s /etc/passwd "$target"
if env HOME="$home" bash "$updater" >/dev/null 2>&1; then
    fail 'updater accepted a symlinked helper target'
fi
[[ -L $target ]] || fail 'updater changed a rejected symlink target'
pass 'updater refuses symlinked helper targets'

printf '%s\n' 'Lock startup helper tests passed.'
