#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
INSTALLER="$ROOT/stages/stage-5-desktop-customization/workstreams/01-boot-experience/scripts/k41-enable-caelestia-autologin.sh"
HELPER="$ROOT/stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-lock-caelestia-after-start.sh"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*"; }

[[ -f $INSTALLER && -f $HELPER ]] || fail 'autologin implementation files are missing'
bash -n "$INSTALLER" || fail 'autologin installer syntax invalid'
bash -n "$HELPER" || fail 'Caelestia lock helper syntax invalid'

launcher_source_line="$(grep -n '^LAUNCHER_SOURCE=' "$INSTALLER" | head -n 1 | cut -d: -f1)"
launcher_check_line="$(grep -nF '[[ -r $LAUNCHER_SOURCE ]]' "$INSTALLER" | head -n 1 | cut -d: -f1)"
[[ -n $launcher_source_line && -n $launcher_check_line ]] || fail 'launcher source assignment/check missing'
(( launcher_source_line < launcher_check_line )) || fail 'launcher source is referenced before assignment under set -u'
if grep -Fq 'k41-boot-splash' "$INSTALLER" || grep -Fq 'qs -c' "$INSTALLER"; then
  fail 'autologin installer must not start a Quickshell boot splash; Plymouth is the only boot splash'
fi

tokens=(
  'getty@tty1.service.d/k41-autologin.conf'
  '--autologin $USER_NAME'
  'start-hyprland'
  'hyprland.start'
  'caelestia shell -d'
  'systemctl daemon-reload'
  '--rollback BACKUP_DIRECTORY'
  'SUDO_USER'
  'lock.enabled'
  'getty@tty1.service'
)
for token in "${tokens[@]}"; do
  grep -Fq -- "$token" "$INSTALLER" || fail "installer contract missing: $token"
done
if grep -Eq 'systemctl (enable|start).*?(gdm|sddm|ly|greetd)|default.target' "$INSTALLER"; then
  fail 'installer must not enable a display manager or change boot target'
fi
grep -Fq 'caelestia shell -s' "$HELPER" || fail 'lock helper does not wait for Caelestia IPC'
grep -Fq 'caelestia shell lock lock' "$HELPER" || fail 'lock helper does not invoke Caelestia lock IPC'
grep -Fq 'caelestia shell lock isLocked' "$HELPER" || fail 'lock helper does not verify lock state'
grep -Fq 'hyprlock &' "$HELPER" || fail 'lock helper lacks a fail-safe Hyprlock fallback'
grep -Fq 'wait "$lock_pid"' "$HELPER" || fail 'lock helper does not retain and wait for the fallback lock process'
pass 'autologin installer and lock helper pass syntax and static safety contracts'

fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin"
cat >"$fixture/bin/caelestia" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$K41_MOCK_LOG"
case "$*" in
  'shell -s')
    printf 'target lock\n  function lock(): void\n  function isLocked(): bool\n'
    ;;
  'shell lock lock')
    : >"$K41_LOCKED_STATE"
    ;;
  'shell lock isLocked')
    [[ -f $K41_LOCKED_STATE ]] && printf 'true\n' || printf 'false\n'
    ;;
  *) exit 1 ;;
esac
MOCK
chmod 0755 "$fixture/bin/caelestia"
export K41_MOCK_LOG="$fixture/calls.log"
export K41_LOCKED_STATE="$fixture/locked"
PATH="$fixture/bin:$PATH" K41_LOCK_RETRIES=1 K41_LOCK_INTERVAL=0 K41_LOCK_VERIFY_RETRIES=1 bash "$HELPER" || fail 'verified Caelestia lock flow failed'
grep -Fxq 'shell -s' "$K41_MOCK_LOG" || fail 'helper did not inspect Caelestia IPC'
grep -Fxq 'shell lock lock' "$K41_MOCK_LOG" || fail 'helper did not invoke lock IPC'
grep -Fxq 'shell lock isLocked' "$K41_MOCK_LOG" || fail 'helper did not verify the lock state'
pass 'Caelestia lock helper passes mocked IPC readiness, lock request, and state verification'

# If Caelestia never exposes the lock target, fail closed through Hyprlock.
cat >"$fixture/bin/caelestia" <<'MOCK'
#!/usr/bin/env bash
[[ $* == 'shell -s' ]] && printf 'target notifs\n'
exit 0
MOCK
cat >"$fixture/bin/hyprlock" <<'MOCK'
#!/usr/bin/env bash
printf 'fallback\n' >"$K41_FALLBACK_LOG"
sleep 2
MOCK
chmod 0755 "$fixture/bin/caelestia" "$fixture/bin/hyprlock"
export K41_FALLBACK_LOG="$fixture/fallback.log"
PATH="$fixture/bin:$PATH" K41_LOCK_RETRIES=1 K41_LOCK_INTERVAL=0 K41_LOCK_VERIFY_RETRIES=1 bash "$HELPER" || fail 'Hyprlock fallback did not run'
grep -Fxq 'fallback' "$K41_FALLBACK_LOG" || fail 'helper did not invoke Hyprlock fallback'
pass 'Caelestia lock helper passes fail-safe Hyprlock fallback fixture'
printf '%s\n' 'Autologin desktop tests passed.'
