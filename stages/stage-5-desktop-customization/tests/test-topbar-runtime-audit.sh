#!/usr/bin/env bash
set -Eeuo pipefail
root="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
script="$root/stages/stage-5-desktop-customization/workstreams/04-topbar/scripts/k41-audit-topbar-runtime.sh"

[[ -s $script ]] || { printf 'FAIL: WS04 runtime audit script missing.\n' >&2; exit 1; }
bash -n "$script"

for token in \
  'report_root="$state_root/k41/topbar/runtime-audits"' \
  'chmod 0700 "$run_dir"' \
  'chmod 0600 "$report"' \
  'RUNTIME CAELESTIA HOST SHELL' \
  'RUNTIME K41 TOPBAR MODULE' \
  'CANONICAL K41 TOPBAR SOURCE' \
  'import qs.k41.modules.topbar as K41Topbar' \
  'RUNTIME CAELESTIA NOTIFS SERVICE' \
  'RUNTIME K41 NOTIFICATIONS SERVICE' \
  'K41.Topbar.Topbar {}' \
  'NOTIFICATION SERVER CONFIGURATION AND D-BUS OWNERSHIP' \
  'org.freedesktop.Notifications' \
  'GetNameOwner' \
  'KNOWN COMPETING NOTIFICATION DAEMONS' \
  'USER NOTIFICATION-RELATED SYSTEMD UNITS' \
  'ACTIVE QUICKSHELL PROCESS AND SELECTOR' \
  'QUICKSHELL CAELESTIA LOG' \
  'HYPRLAND CONFIG ERRORS' \
  'RECENT USER JOURNAL' \
  'QML STATIC VALIDATION' \
  'qmllint unavailable' \
  'publish_report()' \
  'git clone --quiet --no-tags --single-branch --branch main "$remote_url" "$publish_dir"' \
  'GIT_TERMINAL_PROMPT=0 git -C "$publish_dir" push origin HEAD:main' \
  'local checkout Git metadata tidak digunakan'; do
  grep -Fq -- "$token" "$script" || {
    printf 'FAIL: WS04 audit missing required coverage: %s\n' "$token" >&2
    exit 1
  }
done

# Audit must never deploy, launch, restart, or modify the host.
if grep -Eiq 'systemctl[[:space:]]+(enable|disable|start|stop|restart|daemon-reload)|pacman[[:space:]]+(-S|--sync)|(^|[;&|[:space:]])(sudo|chown)[[:space:]]' "$script"; then
  printf 'FAIL: audit contains a host mutation/elevation command.\n' >&2
  exit 1
fi
for forbidden in 'qs -c caelestia' 'caelestia shell -r' 'systemctl --user restart' 'git -C "$repo_root" fetch' 'git -C "$repo_root" worktree'; do
  ! grep -Fq -- "$forbidden" "$script" || {
    printf 'FAIL: audit contains forbidden operation: %s\n' "$forbidden" >&2
    exit 1
  }
done
! grep -Eq 'git[[:space:]].*push.*--force' "$script"
grep -Fq 'umask 077' "$script"
grep -Fq 'GIT_OPTIONAL_LOCKS=0' "$script"
grep -Fq 'redact(s)' "$script"
grep -Fq 'rm -rf -- "$publish_tmp"' "$script"

# Compile the embedded Python collector without executing host probes.
python3 - "$script" <<'PY'
from pathlib import Path
import sys
text = Path(sys.argv[1]).read_text()
start = text.index("python3 <<'PY'\n") + len("python3 <<'PY'\n")
end = text.index("\nPY\n", start)
compile(text[start:end], sys.argv[1] + ":embedded-python", "exec")
print("PASS: embedded Python syntax.")
PY

printf 'PASS: WS04 runtime audit syntax, coverage, privacy, and read-only guards.\n'
