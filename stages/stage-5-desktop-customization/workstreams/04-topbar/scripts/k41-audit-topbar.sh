#!/usr/bin/env bash
# Read-only K41 Topbar environment audit; publishes a bounded, privacy-minimized summary.
set -Eeuo pipefail
umask 077
export GIT_OPTIONAL_LOCKS=0

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
have() { command -v "$1" >/dev/null 2>&1; }

(( EUID != 0 )) || die 'Jalankan sebagai user desktop biasa, tanpa sudo.'
[[ -n ${HOME:-} && $HOME == /* && -d $HOME ]] || die 'HOME tidak valid.'
for cmd in git python3 date mkdir stat chmod mktemp cp; do
    have "$cmd" || die "Command wajib tidak tersedia: $cmd"
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)" ||
    die 'Script harus dijalankan dari Git checkout.'
repo_root="$(cd -- "$repo_root" && pwd -P)"
[[ $(git -C "$repo_root" branch --show-current) == main ]] ||
    die 'Audit hanya berjalan pada branch main.'
[[ $(stat -c %u -- "$repo_root") == "$EUID" ]] ||
    die 'Repository bukan milik user aktif; jangan gunakan sudo/chown.'

state_root="${XDG_STATE_HOME:-$HOME/.local/state}"
[[ $state_root == /* ]] || die 'XDG_STATE_HOME harus berupa path absolut.'
report_root="$state_root/k41/topbar/audits"
for path_check in "$HOME/.local" "$state_root" "$state_root/k41" "$state_root/k41/topbar" "$report_root"; do
    [[ ! -L $path_check ]] || die "Symlink report path ditolak: $path_check"
    [[ ! -e $path_check || -d $path_check ]] || die "Report path bukan direktori: $path_check"
    if [[ -e $path_check ]]; then
        [[ $(stat -c %u -- "$path_check") == "$EUID" ]] || die "Report path bukan milik user aktif: $path_check"
    fi
done
mkdir -p -- "$report_root"
report_mode="$(stat -c %a -- "$report_root")"
(( (8#$report_mode & 8#077) == 0 )) || die "Permission report directory terlalu terbuka: $report_mode (butuh 0700)."

stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
run_dir="$report_root/$stamp"
n=0
while ! mkdir -- "$run_dir" 2>/dev/null; do
    [[ -e $run_dir ]] || die 'Tidak dapat membuat direktori report.'
    n=$((n + 1))
    run_dir="$report_root/$stamp-$n"
done
chmod 0700 "$run_dir"
report="$run_dir/topbar-audit.txt"
published_report="$run_dir/published-summary.txt"
( set -o noclobber; : > "$report" ) 2>/dev/null || die 'Tidak dapat membuat report.'
chmod 0600 "$report"

export K41_AUDIT_REPO="$repo_root"
export K41_AUDIT_REPORT="$report"
export K41_AUDIT_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"

python3 <<'PY'
import json, os, pathlib, re, shutil, subprocess
from datetime import datetime, timezone

repo = pathlib.Path(os.environ["K41_AUDIT_REPO"])
config = pathlib.Path(os.environ["K41_AUDIT_CONFIG"])
report = pathlib.Path(os.environ["K41_AUDIT_REPORT"])
out = []

def add(value=""):
    out.append(str(value))
def section(title):
    add()
    add("=" * 76)
    add(title)
    add("=" * 76)
def run(args, timeout=6):
    try:
        p = subprocess.run(args, text=True, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, timeout=timeout, check=False,
                           env={**os.environ, "GIT_OPTIONAL_LOCKS": "0"})
        return p.returncode, p.stdout.strip()
    except (OSError, subprocess.TimeoutExpired) as exc:
        return 127, type(exc).__name__
def bounded(text, limit=1200):
    text = re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", str(text))
    text = "".join(c for c in text if c in "\n\r\t" or ord(c) >= 32)
    return text[:limit]
def version(binary):
    path = shutil.which(binary)
    if not path:
        add(f"{binary}: NOT_FOUND")
        return
    rc, value = run([path, "--version"])
    add(f"{binary}: path-present; version-exit={rc}; {bounded(value, 240)}")
def safe_inventory(label, root, limit=160):
    add(f"{label}: {'PRESENT' if root.is_dir() and not root.is_symlink() else 'ABSENT_OR_NOT_DIRECTORY'}")
    if not root.is_dir() or root.is_symlink():
        return
    count = 0
    truncated = False
    for base, dirs, names in os.walk(root, followlinks=False):
        dirs[:] = sorted(d for d in dirs if d not in {
            ".git", "node_modules", "build", ".cache", "__pycache__", ".venv"
        } and not (pathlib.Path(base) / d).is_symlink())
        for name in sorted(names):
            p = pathlib.Path(base) / name
            if p.is_symlink() or not p.is_file():
                continue
            try:
                rel = p.relative_to(root).as_posix()
                suffix = p.suffix.lower() or "[no-extension]"
                size = p.stat().st_size
            except OSError:
                continue
            add(f"  file: {rel[:180]} | type={suffix} | bytes={size}")
            count += 1
            if count >= limit:
                truncated = True
                break
        if truncated:
            break
    add(f"  files-listed={count}; truncated={'yes' if truncated else 'no'}")
def parse_json_command(args):
    rc, value = run(args)
    if rc != 0:
        add(f"exit={rc}; {bounded(value, 500)}")
        return None
    try:
        return json.loads(value)
    except (ValueError, TypeError):
        add("exit=0; response was not valid JSON")
        return None

section("AUDIT SCOPE")
add("Purpose: establish evidence for K41 Topbar technical design and implementation planning.")
add("Mode: observational/read-only; no package, service, runtime, configuration, source, or Git mutation.")
add("Captured UTC: " + datetime.now(timezone.utc).isoformat())
add("Repository HEAD: " + run(["git", "-C", str(repo), "rev-parse", "--short", "HEAD"])[1])
add("Repository branch: " + run(["git", "-C", str(repo), "branch", "--show-current"])[1])
rc, status = run(["git", "-C", str(repo), "status", "--porcelain"])
add("Checkout status: " + ("clean" if rc == 0 and not status else "has local changes" if rc == 0 else "unavailable"))
add("Note: local changes are observed but never staged, committed, stashed, or reset.")

section("IMPORTANT ARCHITECTURE CONTEXT")
add("Caelestia does not provide a Topbar in this environment/project baseline.")
add("Do not treat absence of a native Caelestia Topbar as an error or assume a native bar integration point.")
add("Audit discovers available Quickshell/Caelestia shell configuration and active runtime only.")
add("Topbar is a K41-owned component to be designed and integrated after this evidence is reviewed.")
add("No existing panel/bar source is copied or modified by this audit.")

section("RUNTIME AND PACKAGE EVIDENCE")
for binary in ("qs", "quickshell", "caelestia", "hyprctl", "qmllint", "qmlformat"):
    version(binary)
for package in ("caelestia-shell", "quickshell", "quickshell-git", "hyprland",
                "qt6-base", "qt6-declarative", "qt6-wayland"):
    rc, value = run(["pacman", "-Q", package])
    add(f"package {package}: {bounded(value, 240) if rc == 0 else 'not installed or pacman unavailable'}")

section("SHELL CONFIGURATION INVENTORY (NO SOURCE CONTENT)")
roots = [
    ("XDG_QUICKSHELL", config / "quickshell"),
    ("HOME_QUICKSHELL", pathlib.Path.home() / ".config/quickshell"),
    ("SYSTEM_XDG_QUICKSHELL", pathlib.Path("/etc/xdg/quickshell")),
    ("SYSTEM_SHARE_QUICKSHELL", pathlib.Path("/usr/share/quickshell")),
    ("XDG_CAeleSTIA", config / "caelestia"),
    ("SYSTEM_CAelestia_ETC", pathlib.Path("/etc/xdg/caelestia")),
    ("SYSTEM_CAelestia_SHARE", pathlib.Path("/usr/share/caelestia")),
]
seen = set()
for label, root in roots:
    key = str(root.resolve(strict=False))
    if key in seen:
        continue
    seen.add(key)
    safe_inventory(label, root)

section("ACTIVE PROCESSES (NAMES ONLY; NO COMMAND-LINE ARGUMENTS)")
matched = []
for proc in pathlib.Path("/proc").glob("[0-9]*"):
    try:
        name = (proc / "comm").read_text(encoding="utf-8", errors="replace").strip()
    except OSError:
        continue
    if re.search(r"quickshell|caelestia|dunst|mako|swaync|fnott|notify", name, re.I):
        matched.append(name[:100])
add("\n".join(sorted(set(matched))) if matched else "No matching process names observed.")
add("Process arguments, environment variables, usernames, PIDs, and executable paths are intentionally excluded.")

section("NOTIFICATION PROVIDER AND DBUS")
for binary in ("notify-send", "gdbus", "busctl"):
    add(f"{binary}: {'AVAILABLE' if shutil.which(binary) else 'NOT_FOUND'}")
rc, value = run(["gdbus", "introspect", "--session", "--dest",
                 "org.freedesktop.Notifications", "--object-path",
                 "/org/freedesktop/Notifications"])
add(f"freedesktop notification interface: exit={rc}")
if rc == 0:
    methods = sorted(set(re.findall(r"\b(?:method|signal)\s+([A-Za-z_][A-Za-z0-9_]*)", value)))
    add("interface members: " + (", ".join(methods[:40]) if methods else "introspection succeeded; member parsing unavailable"))
else:
    add("interface unavailable or session D-Bus not reachable: " + bounded(value, 400))
add("No test notification is sent.")

section("HYPRLAND MONITOR AND LAYER EVIDENCE")
monitors = parse_json_command(["hyprctl", "monitors", "-j"])
if isinstance(monitors, list):
    for item in monitors[:16]:
        if isinstance(item, dict):
            add("monitor: name={}; resolution={}x{}; scale={}; position={},{}".format(
                bounded(item.get("name", "?"), 80),
                item.get("width", "?"), item.get("height", "?"),
                item.get("scale", "?"), item.get("x", "?"), item.get("y", "?")))
    add(f"monitor-count={len(monitors)}")
layers = parse_json_command(["hyprctl", "-j", "layers"])
if isinstance(layers, dict):
    add("layer namespaces: " + ", ".join(sorted(str(k)[:80] for k in layers)[:40]))
else:
    add("layer namespace inventory unavailable.")
rc, value = run(["hyprctl", "configerrors"])
add(f"Hyprland config errors command: exit={rc}; {bounded(value, 800)}")

section("BATTERY AND POWER SUPPLY")
power_root = pathlib.Path("/sys/class/power_supply")
if power_root.is_dir():
    for device in sorted(power_root.iterdir()):
        if device.is_symlink():
            continue
        fields = []
        for key in ("type", "status", "capacity", "online"):
            item = device / key
            try:
                if item.is_file() and not item.is_symlink():
                    fields.append(f"{key}={item.read_text(encoding='ascii', errors='replace').strip()[:40]}")
            except OSError:
                pass
        add(f"device={device.name[:80]} " + (", ".join(fields) if fields else "standard attributes unavailable"))
else:
    add("power_supply sysfs path unavailable.")

section("K41 IMPLEMENTATION REFERENCES")
ws = repo / "stages/stage-5-desktop-customization/workstreams/04-topbar"
for rel in ("modules", "scripts", "tests", "docs"):
    path = ws / rel
    add(f"WS04 {rel}: {'present' if path.is_dir() else 'absent'}")
    if path.is_dir():
        names = sorted(p.name for p in path.iterdir() if not p.is_symlink())
        add("  entries: " + (", ".join(names[:60]) if names else "(empty)"))
add("Bottombar source is a reference for project conventions only; it is not assumed to be a reusable Topbar implementation.")

section("AUDIT HANDOFF AND LIMITATIONS")
add("Design order: CPU, RAM, Notifications, Battery, Clock (left to right).")
add("Visual target: top horizontal panel, 32-36 px initial height, dark translucent, minimal radius, subtle shadow.")
add("Visibility target: always visible, all monitors; fullscreen behavior requires runtime verification.")
add("Notification interaction: icon click opens a notification tray/panel; tray is not permanently open.")
add("Still to decide from evidence: QML integration point, data providers, tray implementation/API, sizing/layout, locale/time format, exclusive zone, focus/fullscreen, hotplug/scaling.")
add("This audit does not compile QML, prove API compatibility, send notifications, alter services, or verify visual behavior.")
add("Configuration inventory contains bounded relative filenames and file sizes only; source/configuration contents and process arguments are never published.")
add("Review findings before writing the separate implementation/deployment script.")
report.write_text("\n".join(out) + "\n", encoding="utf-8")
print(f"Private audit report created; bytes={report.stat().st_size}")
PY

[[ -s "$report" ]] || die 'Audit tidak menghasilkan report valid.'
report_bytes="$(stat -c %s -- "$report")"
(( report_bytes <= 65536 )) || die "Report melebihi batas 64 KiB: $report_bytes bytes."

# Public copy is the same deliberately minimized report; no raw command lines,
# source excerpts, environment values, host identity, or absolute home paths exist.
cp -- "$report" "$published_report"
chmod 0600 "$published_report"
published_bytes="$(stat -c %s -- "$published_report")"
(( published_bytes <= 65536 )) || die 'Published summary melebihi batas 64 KiB.'

cat >"$run_dir/README.txt" <<EOF
K41 Topbar environment audit
============================
Run as the regular desktop user from the repository checkout on branch main:

  bash stages/stage-5-desktop-customization/workstreams/04-topbar/scripts/k41-audit-topbar.sh

The audit is observational and does not modify runtime configuration, packages,
services, source files, or the active Git checkout. The full report is stored
privately at ~/.local/state/k41/topbar/audits/<timestamp>/topbar-audit.txt.

Only a bounded, privacy-minimized summary is published. It excludes source/config
contents, process command-line arguments, environment variables, host identity,
user identity, and absolute home paths. Automated minimization is not a guarantee
against every possible disclosure; inspect the summary before sharing further.

Caelestia has no native Topbar in this project baseline. The audit does not
assume one exists; it inventories the available shell/runtime environment so
K41 can implement its own Topbar using a verified integration point.
EOF
chmod 0600 "$run_dir/README.txt"

publish_tmp=""
cleanup() {
    if [[ -n $publish_tmp && -d $publish_tmp ]]; then
        rm -rf -- "$publish_tmp"
    fi
}
trap cleanup EXIT

publish_report() {
    local remote_url publish_dir relative_dir publish_target
    remote_url="$(git -C "$repo_root" remote get-url origin 2>/dev/null)" ||
        { printf 'ERROR: Git origin tidak tersedia; report tetap lokal.\n' >&2; return 1; }
    case "$remote_url" in
        https://github.com/K41-Origin/Lenovo-ThinkPad-X280-K41|https://github.com/K41-Origin/Lenovo-ThinkPad-X280-K41.git|git@github.com:K41-Origin/Lenovo-ThinkPad-X280-K41.git|ssh://git@github.com/K41-Origin/Lenovo-ThinkPad-X280-K41.git) ;;
        *) printf 'ERROR: Git origin bukan repository K41 yang diizinkan; report tetap lokal.\n' >&2; return 1 ;;
    esac
    publish_tmp="$(mktemp -d "${TMPDIR:-/tmp}/k41-topbar-audit-publish.XXXXXX")" || return 1
    publish_dir="$publish_tmp/repository"
    if ! GIT_TERMINAL_PROMPT=0 git clone --quiet --no-tags --single-branch --branch main "$remote_url" "$publish_dir"; then
        printf 'ERROR: isolated clone gagal; report privat tetap tersedia.\n' >&2
        return 1
    fi
    relative_dir="reports/stage-5-desktop-customization/04-topbar/audits/${run_dir##*/}"
    publish_target="$publish_dir/$relative_dir"
    if [[ -e $publish_target || -L $publish_target ]]; then
        printf 'ERROR: target report sudah ada; tidak akan ditimpa.\n' >&2
        return 1
    fi
    if ! mkdir -p -- "$publish_target" ||
       ! cp -- "$published_report" "$publish_target/report.txt" ||
       ! cp -- "$run_dir/README.txt" "$publish_target/README.txt" ||
       ! chmod 0644 "$publish_target/report.txt" "$publish_target/README.txt" ||
       ! chmod 0755 "$publish_target"; then
        printf 'ERROR: staging report gagal; report privat tetap tersedia.\n' >&2
        return 1
    fi
    if ! git -C "$publish_dir" -c user.name="K41 Topbar Audit" -c user.email="k41-topbar-audit@users.noreply.github.com" add -- "$relative_dir" ||
       ! git -C "$publish_dir" -c user.name="K41 Topbar Audit" -c user.email="k41-topbar-audit@users.noreply.github.com" commit -m "Add K41 Topbar environment audit"; then
        printf 'ERROR: commit report gagal; report privat tetap tersedia.\n' >&2
        return 1
    fi
    if ! GIT_TERMINAL_PROMPT=0 git -C "$publish_dir" push origin HEAD:main; then
        printf 'INFO: main berubah saat push; mencoba fetch/rebase satu kali pada clone terisolasi.\n'
        if ! GIT_TERMINAL_PROMPT=0 git -C "$publish_dir" fetch --no-tags origin main ||
           ! git -C "$publish_dir" rebase FETCH_HEAD ||
           ! GIT_TERMINAL_PROMPT=0 git -C "$publish_dir" push origin HEAD:main; then
            printf 'ERROR: publikasi gagal; report privat tetap tersedia: %s\n' "$report" >&2
            return 1
        fi
    fi
    printf 'INFO: sanitized summary published: %s\n' "$relative_dir"
    printf 'INFO: active checkout Git metadata was not used for publication.\n'
}

printf 'Private audit report: %s\n' "$report"
printf 'Report size: %s bytes\n' "$report_bytes"
if publish_report; then
    printf 'Automated publication succeeded.\n'
else
    printf 'WARNING: publication failed; private report retained locally.\n' >&2
    exit 1
fi
printf 'Runtime and active checkout state were not modified.\n'
