#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
INSTALLER="$ROOT/scripts/k41-enable-caelestia-autologin.sh"
HELPER="$ROOT/scripts/k41-lock-caelestia-after-start.sh"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*"; }

[[ -f $INSTALLER && -f $HELPER ]] || fail 'autologin implementation files are missing'
bash -n "$INSTALLER" || fail 'autologin installer syntax invalid'
bash -n "$HELPER" || fail 'Caelestia lock helper syntax invalid'

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
grep -Fq 'caelestia shell lock lock' "$HELPER" || fail 'lock helper does not call Caelestia lock IPC'
pass 'autologin installer and lock helper pass syntax and static safety contracts'

# Exercise the helper using a deterministic Caelestia CLI mock.
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin"
cat >"$fixture/bin/caelestia" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$K41_MOCK_LOG"
if [[ $* == 'shell -s' ]]; then
  printf 'target lock\n  function lock(): void\n'
  exit 0
fi
[[ $* == 'shell lock lock' ]]
MOCK
chmod 0755 "$fixture/bin/caelestia"
export K41_MOCK_LOG="$fixture/calls.log"
PATH="$fixture/bin:$PATH" K41_LOCK_RETRIES=1 K41_LOCK_INTERVAL=0 bash "$HELPER" || fail 'mock Caelestia lock call failed'
grep -Fxq 'shell -s' "$K41_MOCK_LOG" || fail 'helper did not inspect Caelestia IPC'
grep -Fxq 'shell lock lock' "$K41_MOCK_LOG" || fail 'helper did not invoke lock IPC'
pass 'Caelestia lock helper passes mocked IPC readiness and lock invocation'
printf '%s\n' 'Autologin desktop tests passed.'
