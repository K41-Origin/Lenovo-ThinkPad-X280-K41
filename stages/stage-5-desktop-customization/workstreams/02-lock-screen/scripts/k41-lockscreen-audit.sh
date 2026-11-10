#!/usr/bin/env bash
# Read-only lock-screen inventory for the K41 ThinkPad X280.
# The only filesystem writes are a new report directory and its report file.
set -Eeuo pipefail

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

have() {
  command -v "$1" >/dev/null 2>&1
}

# Never let root create root-owned artifacts in a user's working tree.
(( EUID != 0 )) || die 'Jalankan sebagai user pemilik checkout, tanpa sudo.'

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" ||
  die 'Tidak dapat menentukan direktori script.'
have git || die 'Git tidak tersedia.'
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)" ||
  die 'Script harus dijalankan dari dalam working tree Git.'
repo_root="$(cd -- "$repo_root" && pwd -P)" || die 'Tidak dapat menentukan root repository.'
current_branch="$(git -C "$repo_root" branch --show-current)" || die 'Tidak dapat membaca branch aktif.'
[[ "$current_branch" == main ]] || die "Audit hanya diizinkan pada branch main; branch aktif: ${current_branch:-detached HEAD}."

# Do not create files in a checkout owned by another account.
have stat || die 'Perintah stat tidak tersedia.'
repo_owner="$(stat -c '%u' -- "$repo_root")" || die 'Tidak dapat membaca owner repository.'
current_uid="$(id -u)"
[[ "$repo_owner" == "$current_uid" ]] ||
  die "Repository dimiliki UID $repo_owner, sedangkan script berjalan sebagai UID $current_uid. Jangan gunakan sudo/chown; periksa checkout secara manual."

for cmd in date mkdir uname pacman grep awk find pgrep sed head id; do
  have "$cmd" || die "Perintah wajib tidak tersedia: $cmd"
done

# Reject symlinked report path components. This prevents writing outside the
# checkout if reports/ or reports/lockscreen-audit/ is redirected.
reports_parent="$repo_root/reports"
report_root="$reports_parent/lockscreen-audit"
[[ ! -L "$reports_parent" ]] || die 'reports/ adalah symlink; audit dibatalkan demi keamanan path.'
[[ ! -L "$report_root" ]] || die 'reports/lockscreen-audit adalah symlink; audit dibatalkan demi keamanan path.'

if [[ -e "$reports_parent" && ! -d "$reports_parent" ]]; then
  die 'reports sudah ada tetapi bukan direktori.'
fi
if [[ -e "$report_root" && ! -d "$report_root" ]]; then
  die 'reports/lockscreen-audit sudah ada tetapi bukan direktori.'
fi

# mkdir is the atomic reservation operation: concurrent runs cannot share a
# report directory. Do not alter umask, mode, owner, index, branch, or HEAD.
mkdir -p -- "$report_root" || die 'Gagal membuat direktori laporan.'
timestamp="$(date -u +'%Y%m%dT%H%M%SZ')" || die 'Gagal membuat timestamp.'
run_dir="$report_root/$timestamp"
suffix=0
while ! mkdir -- "$run_dir" 2>/dev/null; do
  [[ -e "$run_dir" ]] || die 'Gagal membuat direktori laporan (periksa permission/filesystem).'
  suffix=$((suffix + 1))
  run_dir="$report_root/$timestamp-$suffix"
done
report="$run_dir/audit.txt"
# noclobber prevents accidental replacement if an unexpected path exists.
( set -o noclobber; : > "$report" ) 2>/dev/null ||
  die 'Tidak dapat membuat file laporan baru.'

section() { printf '\n===== %s =====\n' "$1" >> "$report"; }
note() { printf '%s\n' "$*" >> "$report"; }

{
  printf 'K41 Lock Screen Read-only Audit\n'
  printf 'Captured UTC: %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  printf 'Kernel: %s\n' "$(uname -sr)"
  printf 'Session: %s\n' "${XDG_SESSION_TYPE:-unknown}"
  printf 'Wayland session marker: %s\n' "$([[ -n ${WAYLAND_DISPLAY:-} ]] && printf present || printf absent)"
  printf 'Hyprland session marker: %s\n' "$([[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && printf present || printf absent)"
  printf 'Report path (repository-relative): %s\n' "${run_dir#"$repo_root"/}"
} >> "$report"

section 'Installed package versions'
for pkg in caelestia-shell caelestia-cli quickshell quickshell-git hyprland hyprlock swaylock gtklock greetd fprintd pam_fprintd howdy; do
  if pacman -Q "$pkg" >> "$report" 2>&1; then
    :
  else
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

section 'Lock-related process names (arguments and PIDs intentionally omitted)'
for proc in Hyprland quickshell qs caelestia hyprlock swaylock gtklock fprintd; do
  if pgrep -x "$proc" >/dev/null 2>&1; then
    printf '%s: running\n' "$proc" >> "$report"
  else
    printf '%s: not detected\n' "$proc" >> "$report"
  fi
done

section 'Hyprland live instances and lock-related bindings'
if have hyprctl; then
  instances_output="$(hyprctl instances 2>&1 || true)"
  if [[ -n "$instances_output" ]]; then
    printf '%s\n' "$instances_output" >> "$report"
    instance_count="$(printf '%s\n' "$instances_output" | grep -cE '^Instance[[:space:]]' || true)"
    if [[ "$instance_count" == 1 ]]; then
      if ! hyprctl -i 0 binds 2>/dev/null |
        grep -iE -C 2 '(^|[^[:alnum:]_])(lock|hyprlock|swaylock)([^[:alnum:]_]|$)' |
        sed "s|$HOME|~|g" >> "$report"; then
        printf 'No matching lock-related binding found, or query unavailable.\n' >> "$report"
      fi
      printf '\nMonitor summary:\n' >> "$report"
      hyprctl -i 0 monitors 2>/dev/null |
        grep -E 'Monitor |description:|model:|width:|height:|refreshRate:|scale:' >> "$report" || true
    else
      printf 'Live binding query skipped: expected exactly one discoverable Hyprland instance; found %s.\n' "${instance_count:-0}" >> "$report"
    fi
  else
    note 'Skipped: hyprctl could not discover a running Hyprland instance.'
  fi
else
  note 'Skipped: hyprctl unavailable.'
fi

section 'Caelestia user configuration: selected lock and wallpaper fields only'
config_candidates=(
  "$HOME/.config/caelestia/shell.json"
  "$HOME/.config/caelestia/shell.jsonc"
  "$HOME/.config/caelestia/shell.qml"
)
found_config=0
for cfg in "${config_candidates[@]}"; do
  [[ -f "$cfg" ]] || continue
  found_config=1
  printf 'Config file: %s\n' "${cfg#"$HOME"/}" >> "$report"
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

section 'Caelestia package source inventory (paths only)'
if pacman -Q caelestia-shell >/dev/null 2>&1; then
  pacman -Ql caelestia-shell 2>/dev/null |
    grep -iE 'quickshell|caelestia|modules/lock|Lock.qml|Content.qml' |
    sed "s|$HOME|~|g" | head -n 200 >> "$report" || true
else
  note 'caelestia-shell package file inventory unavailable.'
fi

section 'Relevant configuration file inventory (paths only)'
for base in "$HOME/.config/hypr" "$HOME/.config/caelestia" "$HOME/.config/quickshell" /etc/xdg/caelestia /usr/share/caelestia /usr/lib/caelestia; do
  [[ -d "$base" ]] || continue
  printf '\n[%s]\n' "$base" >> "$report"
  find "$base" -maxdepth 4 -type f \( -iname '*lock*' -o -iname '*.qml' -o -iname 'hyprland.lua' -o -iname 'hyprland.conf' \) -printf '%P\n' 2>/dev/null |
    head -n 150 >> "$report" || true
  printf 'Files containing lock-related configuration keywords (paths only):\n' >> "$report"
  grep -RIlE 'lock|hyprlock|swaylock' "$base" 2>/dev/null |
    sed "s|^$base/||" | head -n 100 >> "$report" || true
done

section 'PAM auth stack: module names only; no options or credentials'
pam_files=(/etc/pam.d/hyprlock /etc/pam.d/caelestia /etc/pam.d/login /etc/pam.d/system-local-login /etc/pam.d/system-auth /etc/pam.d/sudo /etc/pam.d/polkit-1)
pam_found=0
for pam in "${pam_files[@]}"; do
  [[ -r "$pam" ]] || continue
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
note '- Collector tidak mengubah konfigurasi, service, package, PAM, autentikasi, permission, ownership, Git index, branch, atau HEAD.'
note '- Process arguments, environment values, passwords, tokens, PIDs, dan opsi PAM lengkap sengaja tidak dikumpulkan.'
note '- Static inventory tidak membuktikan lock implementation yang benar-benar dipanggil saat runtime.'
note '- Wallpaper identity, lock/unlock, wrong-password behavior, fingerprint/Howdy, wake behavior, notification leakage, dan visual layout memerlukan validasi manual/runtime.'
note '- Periksa dan redaksi laporan sebelum commit; laporan dapat memuat versi package/kernel, model monitor, nama file, binding, dan nama modul PAM.'

printf 'Audit selesai. Laporan: %s\n' "$report"
printf 'Collector dijalankan sebagai user biasa dan tidak mengubah permission/ownership maupun state Git.\n'
printf '\nSetelah meninjau dan menyunting laporan, jalankan perintah berikut:\n'
printf 'git -C %q add -- %q\n' "$repo_root" "${report#"$repo_root"/}"
printf 'git -C %q diff --cached --check\n' "$repo_root"
printf 'git -C %q commit --only -m %q -- %q\n' "$repo_root" 'audit(lockscreen): add X280 audit report' "${report#"$repo_root"/}"
printf 'git -C %q push origin main\n' "$repo_root"
