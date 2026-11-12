#!/usr/bin/env bash
set -Eeuo pipefail

root="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
base="$root/stages/stage-5-desktop-customization/workstreams/02-lock-screen"
helper="$base/scripts/k41-lock-caelestia-after-start.sh"
updater="$base/scripts/k41-update-lockscreen-startup-helper.sh"
config="$base/config/hyprlock-fallback.conf"
audit="$base/scripts/k41-audit-desktop-startup.sh"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*"; }

for script in "$helper" "$updater" "$audit"; do
    [[ -s $script ]] || fail "missing script: $script"
    bash -n "$script" || fail "invalid Bash syntax: $script"
done
grep -Fq 'qs log -c caelestia --tail 400 --no-color' "$audit" ||
    fail 'audit collector does not capture Caelestia Quickshell logs'
grep -Fq 'K41_AUDIT_RUN_QS_PROBE=1' "$audit" ||
    fail 'audit collector does not document the opt-in Quickshell startup probe'
grep -Fq 'timeout --signal=TERM --kill-after=3 15s qs -c caelestia' "$audit" ||
    fail 'audit Quickshell startup probe is not bounded'
grep -Fq '[[ ! -S $wayland_socket ]]' "$audit" ||
    fail 'audit Quickshell startup probe does not validate the Wayland socket'
[[ -s $config ]] || fail 'managed Hyprlock fallback config is missing'
grep -Fq 'hyprlock --config "$hyprlock_config"' "$helper" || fail 'helper does not pass the managed config explicitly'
grep -Fq 'hyprlock --config' "$helper" || fail 'explicit Hyprlock config argument missing'
grep -Fq 'background {' "$config" && grep -Fq 'input-field {' "$config" ||
    fail 'fallback config must define a background and password input field'
grep -Fq 'deadline=$((SECONDS + ready_timeout))' "$helper" || fail 'bounded IPC deadline missing'
grep -Fq '(( ready_timeout <= 30 ))' "$helper" || fail 'readiness budget cap missing'
grep -Fq '(( verify_attempts <= 10 ))' "$helper" || fail 'verification retry cap missing'
grep -Fq 'for ((attempt = 1; attempt <= verify_attempts; attempt++))' "$helper" ||
    fail 'lock verification is not bounded'
grep -Fq 'config-backups' "$updater" || fail 'updater does not preserve config backups'
grep -Fq 'helper-backups' "$updater" && fail 'obsolete backup path remains' || true
grep -Fq 'Expected exactly one' "$updater" || fail 'updater does not guard ambiguous config edits'
! grep -Eiq '^[[:space:]]*(systemctl|pacman|sudo|cryptsetup|mkinitcpio|plymouth-set-default-theme)([[:space:]]|$)' "$updater" ||
    fail 'updater contains unrelated system mutations'
pass 'helper, updater, managed config and bounded safety checks pass'

fixture="$(mktemp -d)"
trap 'rm -rf -- "$fixture"' EXIT
home="$fixture/home"
mkdir -m 0700 -- "$home"
mkdir -p "$home/.config/hypr"
cat >"$home/.config/hypr/hyprland.conf" <<'CONF'
exec-once = systemctl --user start pipewire.socket
exec-once = caelestia shell -d
CONF
cat >"$home/.config/hypr/hyprland.lua" <<'LUA'
-- unrelated setting must survive
hl.config({ general = { gaps_in = 5 } })
-- K41 CAELESTIA AUTOLOCK START
hl.on("hyprland.start", function()
    hl.exec_cmd("sh -c 'mkdir -p \"$HOME/.cache/k41\"; qs -c k41-boot-splash >/dev/null 2>&1 &'")
    -- K41 ANIMATED BOOT SPLASH START
    hl.exec_cmd("/home/test/.local/bin/k41-lock-caelestia-after-start")
end)
-- K41 CAELESTIA AUTOLOCK END
LUA

fakebin="$fixture/bin"
mkdir -p "$fakebin"
cat >"$fakebin/hyprlock" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$K41_TEST_HYPRLOCK_ARGS"
[[ ${1:-} == --help ]] && { printf '%s\n' '--config FILE'; exit 0; }
[[ ${1:-} == --config && -s ${2:-} ]] || exit 23
exit 0
MOCK
chmod 0755 "$fakebin/hyprlock"
PATH="$fakebin:$PATH" K41_TEST_HYPRLOCK_ARGS="$fixture/hyprlock.args" HOME="$home" bash "$updater" >/dev/null

target="$home/.local/bin/k41-lock-caelestia-after-start"
target_config="$home/.config/k41/hyprlock-fallback.conf"
[[ -x $target && ! -L $target ]] || fail 'updater did not install executable helper'
[[ -s $target_config && ! -L $target_config ]] || fail 'updater did not install managed fallback config'
cmp -s "$helper" "$target" || fail 'installed helper differs from repository source'
cmp -s "$config" "$target_config" || fail 'installed fallback config differs from repository source'
grep -Fq 'exec-once = caelestia shell -d' "$home/.config/hypr/hyprland.conf" ||
    fail 'updater changed the single retained Caelestia startup directive'
grep -Fq 'unrelated setting must survive' "$home/.config/hypr/hyprland.lua" ||
    fail 'updater lost unrelated Hyprland Lua content'
grep -Fq 'k41-lock-caelestia-after-start' "$home/.config/hypr/hyprland.lua" ||
    fail 'updater removed the lock helper invocation'
! grep -Fq 'qs -c k41-boot-splash' "$home/.config/hypr/hyprland.lua" ||
    fail 'updater left the obsolete splash command'
[[ $(grep -Fc 'hl.exec_cmd("caelestia shell -d")' "$home/.config/hypr/hyprland.lua") == 1 ]] ||
    fail 'updater did not add exactly one Caelestia startup command to the active Lua config'
caelestia_line="$(grep -nF 'hl.exec_cmd("caelestia shell -d")' "$home/.config/hypr/hyprland.lua" | cut -d: -f1)"
helper_line="$(grep -nF 'k41-lock-caelestia-after-start' "$home/.config/hypr/hyprland.lua" | cut -d: -f1)"
(( caelestia_line < helper_line )) || fail 'Caelestia startup does not precede the lock helper'
pass 'active Lua config starts Caelestia before the readiness helper'
pass 'updater installs managed fallback and normalizes only the marked Lua block'

# Idempotent second run must not create another backup or change the config.
before="$(find "$home/.local/state/k41/lockscreen/config-backups" -type f | wc -l)"
PATH="$fakebin:$PATH" K41_TEST_HYPRLOCK_ARGS="$fixture/hyprlock.args" HOME="$home" bash "$updater" >/dev/null
after="$(find "$home/.local/state/k41/lockscreen/config-backups" -type f | wc -l)"
[[ $before == "$after" ]] || fail 'idempotent updater created unnecessary backups'
pass 'updater is idempotent and does not create redundant backups'

# Modified existing helper/config/Lua files must be backed up before replacement.
printf '\n# modified helper fixture\n' >>"$target"
printf '\n# modified config fixture\n' >>"$target_config"
printf '\n-- local Lua edit --\n' >>"$home/.config/hypr/hyprland.lua"
PATH="$fakebin:$PATH" K41_TEST_HYPRLOCK_ARGS="$fixture/hyprlock.args" HOME="$home" bash "$updater" >/dev/null
cmp -s "$helper" "$target" || fail 'updater did not restore canonical helper source'
cmp -s "$config" "$target_config" || fail 'updater did not restore canonical fallback config'
grep -Fq 'local Lua edit' "$home/.config/hypr/hyprland.lua" ||
    fail 'updater did not preserve an unrelated Lua edit'
backup_count="$(find "$home/.local/state/k41/lockscreen/config-backups" -type f | wc -l)"
(( backup_count >= 3 )) || fail 'updater did not back up all modified targets'
pass 'updater backs up modified helper/config/Lua files and preserves unrelated Lua content'

# Refuse ambiguous config rather than guessing.
cp "$home/.config/hypr/hyprland.lua" "$fixture/ambiguous.lua"
printf '\n-- K41 CAELESTIA AUTOLOCK START\n' >>"$home/.config/hypr/hyprland.lua"
if PATH="$fakebin:$PATH" K41_TEST_HYPRLOCK_ARGS="$fixture/hyprlock.args" HOME="$home" bash "$updater" >/dev/null 2>&1; then
    fail 'updater accepted an ambiguous duplicate K41 block'
fi
pass 'updater refuses ambiguous Hyprland Lua blocks'

# Exercise Caelestia success path and explicit Hyprlock fallback in isolated homes.
runtime_home="$fixture/runtime-home"
mkdir -m 0700 -- "$runtime_home"
mkdir -p "$runtime_home/.config/k41"
cp "$config" "$runtime_home/.config/k41/hyprlock-fallback.conf"
runtime_bin="$fixture/runtime-bin"
mkdir -p "$runtime_bin"
cat >"$runtime_bin/caelestia" <<'MOCK'
#!/usr/bin/env bash
case "$*" in
  'shell -s')
    printf 'target lock\n  function lock(): void\n  function isLocked(): bool\n'
    ;;
  'shell lock lock') exit 0 ;;
  'shell lock isLocked') printf 'true\n' ;;
  *) exit 1 ;;
esac
MOCK
cat >"$runtime_bin/hyprlock" <<'MOCK'
#!/usr/bin/env bash
[[ ${1:-} == --config && -s ${2:-} ]] || exit 41
printf '%s\n' "$2" >"$K41_TEST_FALLBACK_CONFIG"
sleep 2
MOCK
chmod 0755 "$runtime_bin/caelestia" "$runtime_bin/hyprlock"
PATH="$runtime_bin:$PATH" HOME="$runtime_home" K41_TEST_FALLBACK_CONFIG="$fixture/fallback-path"     bash "$helper" >/dev/null
[[ -f "$runtime_home/.cache/k41/boot-lock-ready" ]] ||
    fail 'Caelestia success path did not publish readiness marker'
pass 'helper publishes readiness only after Caelestia lock state verifies'

# Fallback path: IPC absent, Hyprlock starts with explicit managed config and marker is published.
rm -f "$runtime_home/.cache/k41/boot-lock-ready"
cat >"$runtime_bin/caelestia" <<'MOCK'
#!/usr/bin/env bash
printf 'Caelestia shell IPC unavailable in test fixture\n' >&2
exit 1
MOCK
PATH="$runtime_bin:$PATH" HOME="$runtime_home" K41_LOCK_READY_TIMEOUT=1 K41_LOCK_INTERVAL=0     K41_TEST_FALLBACK_CONFIG="$fixture/fallback-path" bash "$helper" >/dev/null
[[ -f "$runtime_home/.cache/k41/boot-lock-ready" ]] ||
    fail 'Hyprlock fallback did not publish readiness marker'
[[ $(<"$fixture/fallback-path") == "$runtime_home/.config/k41/hyprlock-fallback.conf" ]] ||
    fail 'helper did not pass the explicit managed Hyprlock config path'
pass 'helper falls back with explicit config and publishes readiness after Hyprlock remains alive'

# Missing fallback config must fail closed and must not publish a marker.
rm -f "$runtime_home/.cache/k41/boot-lock-ready" "$runtime_home/.config/k41/hyprlock-fallback.conf"
if PATH="$runtime_bin:$PATH" HOME="$runtime_home" K41_LOCK_READY_TIMEOUT=1 K41_LOCK_INTERVAL=0     bash "$helper" >/dev/null 2>&1; then
    fail 'helper accepted a missing Hyprlock fallback config'
fi
[[ ! -e "$runtime_home/.cache/k41/boot-lock-ready" ]] ||
    fail 'helper published readiness without a verified lock or running fallback'
pass 'helper fails closed when managed Hyprlock config is missing'

printf '%s\n' 'Lock startup helper tests passed.'
