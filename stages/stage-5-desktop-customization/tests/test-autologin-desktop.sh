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
grep -Fq 'HELPER_SOURCE="$SCRIPT_DIR/../../02-lock-screen/scripts/k41-lock-caelestia-after-start.sh"' "$INSTALLER" ||
    fail 'autologin installer does not source the Workstream 02 lock helper'
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
grep -Fq 'K41_LOCK_READY_TIMEOUT' "$HELPER" || fail 'lock helper has no bounded IPC readiness deadline'
grep -Fq 'deadline=$((SECONDS + ready_timeout))' "$HELPER" || fail 'lock helper readiness polling is not deadline-bounded'
grep -Fq 'hyprlock --config "$hyprlock_config" &' "$HELPER" || fail 'lock helper lacks an explicit-config Hyprlock fallback'
grep -Fq 'wait "$lock_pid"' "$HELPER" || fail 'lock helper does not retain and wait for the fallback lock process'
pass 'autologin installer and lock helper pass syntax and static safety contracts'

fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/home"
export HOME="$fixture/home"
export K41_MOCK_LOG="$fixture/calls.log"
export K41_LOCKED_STATE="$fixture/locked"

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
PATH="$fixture/bin:$PATH" K41_LOCK_READY_TIMEOUT=1 K41_LOCK_INTERVAL=0 K41_LOCK_VERIFY_RETRIES=1 \
    bash "$HELPER" || fail 'verified Caelestia lock flow failed'
grep -Fxq 'shell -s' "$K41_MOCK_LOG" || fail 'helper did not inspect Caelestia IPC'
grep -Fxq 'shell lock lock' "$K41_MOCK_LOG" || fail 'helper did not invoke Caelestia lock IPC'
grep -Fxq 'shell lock isLocked' "$K41_MOCK_LOG" || fail 'helper did not verify the lock state'
[[ -f "$HOME/.cache/k41/boot-lock-ready" ]] || fail 'verified Caelestia lock did not publish readiness marker'
pass 'Caelestia lock helper verifies IPC state and publishes readiness marker'

# IPC ready but lock state never becomes true: verify only within the bounded
# window, then fall back instead of multiplying verification by outer retries.
: >"$K41_MOCK_LOG"
rm -f -- "$K41_LOCKED_STATE"
cat >"$fixture/bin/caelestia" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$K41_MOCK_LOG"
case "$*" in
  'shell -s')
    printf 'target lock\n  function lock(): void\n  function isLocked(): bool\n'
    ;;
  'shell lock lock')
    ;;
  'shell lock isLocked')
    printf 'false\n'
    ;;
  *) exit 1 ;;
esac
MOCK
cat >"$fixture/bin/hyprlock" <<'MOCK'
#!/usr/bin/env bash
printf 'fallback\n' >>"$K41_FALLBACK_LOG"
sleep 2
MOCK
chmod 0755 "$fixture/bin/caelestia" "$fixture/bin/hyprlock"
export K41_FALLBACK_LOG="$fixture/fallback.log"
mkdir -p "$HOME/.config/k41"
printf 'background {}\\ninput-field {}\\n' >"$HOME/.config/k41/hyprlock-fallback.conf"
rm -f -- "$HOME/.cache/k41/boot-lock-ready"
PATH="$fixture/bin:$PATH" K41_LOCK_READY_TIMEOUT=1 K41_LOCK_INTERVAL=0 K41_LOCK_VERIFY_RETRIES=2 \
    bash "$HELPER" || fail 'bounded lock verification did not fall back'
[[ $(grep -Fc 'shell lock lock' "$K41_MOCK_LOG") -eq 1 ]] || fail 'lock request was retried outside the bounded verification window'
[[ $(grep -Fc 'shell lock isLocked' "$K41_MOCK_LOG") -eq 2 ]] || fail 'lock verification did not respect its configured retry bound'
grep -Fq 'fallback' "$K41_FALLBACK_LOG" || fail 'helper did not invoke Hyprlock after verification timeout'
[[ -f "$HOME/.cache/k41/boot-lock-ready" ]] || fail 'Hyprlock fallback did not publish readiness marker'
pass 'bounded lock verification reaches Hyprlock fallback without nested retry multiplication'

# If Caelestia is unavailable and no Hyprlock executable exists, fail closed.
rm -f -- "$fixture/bin/hyprlock" "$HOME/.cache/k41/boot-lock-ready"
cat >"$fixture/bin/caelestia" <<'MOCK'
#!/usr/bin/env bash
[[ $* == 'shell -s' ]] && printf 'target notifs\n'
exit 0
MOCK
chmod 0755 "$fixture/bin/caelestia"
PATH="$fixture/bin:/usr/bin:/bin" K41_LOCK_READY_TIMEOUT=1 K41_LOCK_INTERVAL=0 K41_LOCK_VERIFY_RETRIES=1 \
    bash "$HELPER" >/dev/null 2>&1 && fail 'helper should fail when both lock paths are unavailable'
[[ ! -e "$HOME/.cache/k41/boot-lock-ready" ]] || fail 'helper published readiness without a verified lock process'
pass 'lock helper fails closed when Caelestia and Hyprlock are unavailable'

printf '%s\n' 'Autologin desktop tests passed.'
