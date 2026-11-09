#!/usr/bin/env bash
# Read-only lock-screen inventory for the K41 ThinkPad X280.
# Run as the regular user inside the active Hyprland session; never use sudo.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
(( EUID != 0 )) || die 'Jalankan sebagai user desktop biasa, bukan root/sudo.'
[[ -n ${HOME:-} && -d $HOME ]] || die 'HOME tidak valid.'
for cmd in date mkdir chmod uname id pacman grep awk find pgrep sed git head; do
  command -v "$cmd" >/dev/null 2>&1 || die "Perintah wajib tidak tersedia: $cmd"
done

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
state_root="${XDG_STATE_HOME:-$HOME/.local/state}"
report_root="$state_root/k41/lockscreen-audit"
mkdir -p -- "$report_root"
run_dir="$report_root/$timestamp"
suffix=0
while ! mkdir -- "$run_dir" 2>/dev/null; do
  suffix=$((suffix + 1))
  run_dir="$report_root/$timestamp-$suffix"
done
chmod 0700 "$run_dir"
report="$run_dir/audit.txt"
: > "$report"
chmod 0600 "$report"

section() { printf '\n===== %s =====\n' "$1" >> "$report"; }
note() { printf '%s\n' "$*" >> "$report"; }
have() { command -v "$1" >/dev/null 2>&1; }

{
  printf 'K41 Lock Screen Read-only Audit\n'
  printf 'Captured UTC: %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  printf 'Repository commit: %s\n' "$(git -C "$repo_root" rev-parse HEAD 2>/dev/null || printf unknown)"
  printf 'User: %s\n' "$(id -un)"
  printf 'Kernel: %s\n' "$(uname -sr)"
  printf 'Session: %s\n' "${XDG_SESSION_TYPE:-unknown}"
  printf 'Wayland session: %s\n' "$([[ -n ${WAYLAND_DISPLAY:-} ]] && printf present || printf absent)"
  printf 'Hyprland session marker: %s\n' "$([[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && printf present || printf absent)"
  printf 'Report directory: %s\n' "$run_dir"
} >> "$report"

section 'Installed package versions'
for pkg in caelestia-shell caelestia-cli quickshell quickshell-git hyprland hyprlock swaylock gtklock greetd fprintd pam_fprintd howdy; do
  if pacman -Q "$pkg" >> "$report" 2>&1; then :; else
    printf '%s: not installed (or package name differs)\n' "$pkg" >> "$report"
  fi
done

section 'Relevant executable paths and versions'
for bin in caelestia qs quickshell hyprctl hyprlock swaylock gtklock loginctl fprintd howdy; do
  if have "$bin"; then
    printf '%s: %s\n' "$bin" "$(command -v "$bin")" >> "$report"
    case "$bin" in
      caelestia|qs|quickshell|hyprctl|hyprlock|swaylock|gtklock)
        "$bin" --version >> "$report" 2>&1 || printf 'version flag unsupported\n' >> "$report"
        ;;
    esac
  else
    printf '%s: not found in PATH\n' "$bin" >> "$report"
  fi
done

section 'Lock-related process names (arguments intentionally omitted)'
for proc in Hyprland quickshell qs caelestia hyprlock swaylock gtklock fprintd; do
  if pgrep -x "$proc" >/dev/null 2>&1; then
    printf '%s: running (PID values omitted)\n' "$proc" >> "$report"
  else
    printf '%s: not detected\n' "$proc" >> "$report"
  fi
done

section 'Hyprland live lock-related bindings'
if have hyprctl && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  if ! hyprctl binds 2>/dev/null | grep -iE -C 2 '(^|[^[:alnum:]_])(lock|hyprlock|swaylock)([^[:alnum:]_]|$)' >> "$report"; then
    printf 'No matching lock-related binding found, or query unavailable.\n' >> "$report"
  fi
  printf '\nMonitor summary:\n' >> "$report"
  hyprctl monitors 2>/dev/null | grep -E 'Monitor |description:|model:|width:|height:|refreshRate:|scale:' >> "$report" || true
else
  note 'Skipped: not inside an active Hyprland session or hyprctl unavailable.'
fi

section 'Caelestia user configuration: selected lock and wallpaper fields only'
config_candidates=(
  "$HOME/.config/caelestia/shell.json"
  "$HOME/.config/caelestia/shell.jsonc"
  "$HOME/.config/caelestia/shell.qml"
)
found_config=0
for cfg in "${config_candidates[@]}"; do
  [[ -f $cfg ]] || continue
  found_config=1
  printf 'Config file: %s\n' "$cfg" >> "$report"
  if have python; then
    python - "$cfg" >> "$report" 2>&1 <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
try:
    data = json.loads(path.read_text())
except Exception as exc:
    print(f"JSON parse unavailable/failed: {type(exc).__name__}")
    raise SystemExit(0)
def walk(obj, prefix=""):
    if isinstance(obj, dict):
        for key, value in obj.items():
            here = f"{prefix}.{key}" if prefix else key
            low = here.lower()
            if any(token in low for token in ("lock", "wallpaper")):
                if isinstance(value, (str, int, float, bool)) or value is None:
                    print(f"{here} = {value!r}")
                else:
                    print(f"{here} = <{type(value).__name__}>")
            walk(value, here)
    elif isinstance(obj, list):
        for index, value in enumerate(obj):
            walk(value, f"{prefix}[{index}]")
walk(data)
PY
  else
    printf 'Python unavailable; selected config values not parsed.\n' >> "$report"
  fi
done
(( found_config == 1 )) || note 'No conventional Caelestia shell.json/shell.jsonc candidate found under ~/.config/caelestia.'

section 'Relevant configuration file inventory (paths only)'
for base in "$HOME/.config/hypr" "$HOME/.config/caelestia" "$HOME/.config/quickshell" /etc/xdg/caelestia /usr/share/caelestia /usr/lib/caelestia; do
  [[ -d $base ]] || continue
  printf '\n[%s]\n' "$base" >> "$report"
  find "$base" -maxdepth 4 -type f \( -iname '*lock*' -o -iname '*.qml' -o -iname 'hyprland.lua' -o -iname 'hyprland.conf' \) -printf '%p\n' 2>/dev/null | head -n 150 >> "$report" || true
  printf 'Files containing lock-related configuration keywords (paths only):\n' >> "$report"
  grep -RIlE 'lock|hyprlock|swaylock' "$base" 2>/dev/null | head -n 100 >> "$report" || true
done

section 'PAM auth stack: module names only; no options or credentials'
pam_files=(/etc/pam.d/hyprlock /etc/pam.d/caelestia /etc/pam.d/login /etc/pam.d/system-local-login /etc/pam.d/system-auth /etc/pam.d/sudo /etc/pam.d/polkit-1)
pam_found=0
for pam in "${pam_files[@]}"; do
  [[ -r $pam ]] || continue
  pam_found=1
  printf '\n[%s]\n' "$pam" >> "$report"
  awk 'BEGIN{IGNORECASE=1} /^[[:space:]]*auth[[:space:]]/ { if ($1 !~ /^#/) print $1, $2, $3 }' "$pam" >> "$report"
done
(( pam_found == 1 )) || note 'No listed PAM file readable/found; this is not proof that PAM is unused.'

section 'Relevant user and system services'
if have systemctl; then
  for unit in caelestia.service quickshell.service hyprlock.service fprintd.service; do
    printf '%s: ' "$unit" >> "$report"
    systemctl --user is-active "$unit" 2>/dev/null >> "$report" || printf 'inactive/not found\n' >> "$report"
  done
  for unit in greetd.service display-manager.service; do
    printf '%s: ' "$unit" >> "$report"
    systemctl is-active "$unit" 2>/dev/null >> "$report" || printf 'inactive/not found\n' >> "$report"
  done
else
  note 'systemctl unavailable.'
fi

section 'Audit limitations and manual checks'
note '- This collector does not change configuration, services, packages, PAM, or authentication.'
note '- Process arguments, environment values, passwords, tokens, and full PAM options are intentionally omitted.'
note '- Static inventory cannot prove which lock implementation is invoked at runtime.'
note '- Wallpaper identity, actual lock/unlock, wrong-password behavior, fingerprint/Howdy, wake behavior, notification leakage, and visual layout require separate manual/runtime validation.'
note '- Review this report before sharing; redact personal paths/usernames if desired.'

printf 'Audit selesai. Laporan: %s\n' "$report"
printf 'Collector bersifat read-only; jalankan tanpa sudo.\n'
