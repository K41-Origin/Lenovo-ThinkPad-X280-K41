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
def safe_inventory(label, root, limit=5000):
    add(f"{label}: {'PRESENT' if root.is_dir() and not root.is_symlink() else 'ABSENT_OR_NOT_DIRECTORY'}")
    if not root.is_dir() or root.is_symlink():
        return
    counts = {}
    total = 0
    truncated = False
    for base, dirs, names in os.walk(root, followlinks=False):
        dirs[:] = sorted(d for d in dirs if d not in {
            ".git", "node_modules", "build", ".cache", "__pycache__", ".venv"
        } and not (pathlib.Path(base) / d).is_symlink())
        for name in names:
            p = pathlib.Path(base) / name
            if p.is_symlink() or not p.is_file():
                continue
            suffix = p.suffix.lower() or "[no-extension]"
            counts[suffix] = counts.get(suffix, 0) + 1
            total += 1
            if total >= limit:
                truncated = True
                break
        if truncated:
            break
    add("  file-count-by-type: " + (", ".join(f"{k}={v}" for k, v in sorted(counts.items())) or "none"))
    add(f"  files-counted={total}; truncated={'yes' if truncated else 'no'}")
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

section("QML ENTRY-POINT AND INTEGRATION DISCOVERY (NO SOURCE CONTENT)")
qml_roots = [
    ("USER_QUICKSHELL", config / "quickshell"),
    ("SYSTEM_QUICKSHELL", pathlib.Path("/etc/xdg/quickshell")),
    ("SYSTEM_SHARE_QUICKSHELL", pathlib.Path("/usr/share/quickshell")),
]
qml_candidates = []
qml_tokens = ("ShellRoot", "PanelWindow", "Variants", "Quickshell", "IpcHandler",
              "GlobalShortcut", "Notification", "SystemTray", "StatusNotifier")
scanned = 0
for label, root in qml_roots:
    if not root.is_dir() or root.is_symlink():
        add(f"{label}: unavailable")
        continue
    add(f"{label}: available")
    for base, dirs, names in os.walk(root, followlinks=False):
        dirs[:] = sorted(d for d in dirs if not (pathlib.Path(base) / d).is_symlink()
                         and d not in {".git", "node_modules", "build", ".cache"})
        for name in sorted(names):
            candidate = pathlib.Path(base) / name
            if candidate.suffix.lower() != ".qml" or candidate.is_symlink() or not candidate.is_file():
                continue
            scanned += 1
            if scanned > 2500:
                break
            try:
                if candidate.stat().st_size > 1024 * 1024:
                    continue
                source = candidate.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            matched = [token for token in qml_tokens if re.search(r"\b" + re.escape(token) + r"\b", source)]
            if matched and (re.search(r"\b(?:ShellRoot|PanelWindow|Variants)\b", source)
                            or candidate.name.lower() in {"shell.qml", "main.qml", "quickshell.qml"}):
                rel = candidate.relative_to(root).as_posix()
                qml_candidates.append((label, rel[:180], matched))
        if scanned > 2500:
            break
for label, rel, matched in qml_candidates[:40]:
    add(f"candidate: root={label}; relative-path={rel}; identifiers={','.join(matched)}")
add(f"qml-files-scanned={min(scanned, 2500)}; candidate-count={len(qml_candidates)}; scan-truncated={'yes' if scanned > 2500 else 'no'}")
if not qml_candidates:
    add("No likely ShellRoot/PanelWindow/Variants entry-point candidate identified by bounded static scan.")
add("Static token matches are leads only; they do not prove the active entry point or API compatibility.")

section("CPU, MEMORY, CLOCK AND SESSION CAPABILITIES")
try:
    stat_lines = pathlib.Path("/proc/stat").read_text(encoding="ascii", errors="replace").splitlines()
    cpu_line = next((line for line in stat_lines if line.startswith("cpu ")), "")
    add("CPU counters: " + ("available; aggregate counters present" if cpu_line else "aggregate counters unavailable"))
except OSError:
    add("CPU counters: unavailable")
try:
    memory_lines = pathlib.Path("/proc/meminfo").read_text(encoding="ascii", errors="replace").splitlines()
    keys = {"MemTotal", "MemAvailable", "SwapTotal", "SwapFree"}
    values = [line[:100] for line in memory_lines if line.split(":", 1)[0] in keys]
    add("Memory fields: " + ("; ".join(values) if values else "not available"))
except OSError:
    add("Memory fields: unavailable")
rc, tz = run(["timedatectl", "show", "-p", "Timezone", "--value"])
add("Timezone: " + (bounded(tz, 100) if rc == 0 and tz else "timedatectl unavailable"))
rc, locale_value = run(["locale", "charmap"])
add("Locale character map: " + (bounded(locale_value, 80) if rc == 0 else "unavailable"))
add("Clock sample format: " + datetime.now().astimezone().strftime("%Y-%m-%d %H:%M:%S %Z"))

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
    # gdbus emits indented methods/signals/properties sections.
    section_name = None
    members = {"methods": [], "signals": [], "properties": []}
    for line in value.splitlines():
        heading = re.match(r"^\s{2}(methods|signals|properties):\s*$", line)
        if heading:
            section_name = heading.group(1)
            continue
        if section_name in ("methods", "signals"):
            match = re.match(r"^\s{4}([A-Za-z_][A-Za-z0-9_]*)\(", line)
            if match:
                members[section_name].append(match.group(1))
        elif section_name == "properties":
            match = re.match(r"^\s{4}([A-Za-z_][A-Za-z0-9_]*)\s*\(", line)
            if match:
                members[section_name].append(match.group(1))
    for kind in ("methods", "signals", "properties"):
        names = sorted(set(members[kind]))
        add(f"  {kind}: " + (", ".join(names[:40]) if names else "none parsed"))
    add("  parser: gdbus section/signature parser; member names only")
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
sys_devices = pathlib.Path("/sys/devices").resolve()
if power_root.is_dir():
    found = 0
    for device in sorted(power_root.iterdir()):
        try:
            resolved = device.resolve(strict=True)
            if os.path.commonpath((str(sys_devices), str(resolved))) != str(sys_devices):
                add(f"device={device.name[:80]} rejected: target outside /sys/devices")
                continue
            if not resolved.is_dir():
                continue
        except (OSError, RuntimeError, ValueError):
            add(f"device={device.name[:80]} unresolved_or_inaccessible")
            continue
        fields = []
        for key in ("type", "status", "capacity", "online", "energy_now",
                    "energy_full", "charge_now", "charge_full", "power_now",
                    "current_now", "voltage_now", "model_name", "manufacturer"):
            item = resolved / key
            try:
                if item.is_file() and not item.is_symlink():
                    raw = item.read_text(encoding="ascii", errors="replace").strip()
                    if raw and all(ord(ch) >= 32 for ch in raw):
                        fields.append(f"{key}={raw[:48]}")
            except OSError:
                pass
        add(f"device={device.name[:80]} " + (", ".join(fields) if fields else "known attributes unavailable"))
        found += 1
    add(f"power-supply entries inspected={found}")
    if found == 0:
        add("No readable power-supply device identified; this does not prove no battery exists.")
else:
    add("power_supply sysfs path unavailable.")



section("ACTIVE QUICKSHELL CONFIGURATION AND HOST INTEGRATION")
home = pathlib.Path.home()
xdg_config = pathlib.Path(os.environ.get("XDG_CONFIG_HOME", str(home / ".config")))
qs_root = xdg_config / "quickshell"
host_file = qs_root / "caelestia" / "shell.qml"
module_file = qs_root / "k41" / "modules" / "topbar" / "Topbar.qml"

def short_path(path):
    value = str(path)
    home_value = str(home)
    if value == home_value or value.startswith(home_value + os.sep):
        return "~" + value[len(home_value):]
    return value

def inspect_qml_file(path, label):
    if not path.is_file() or path.is_symlink():
        add(f"{label}: absent_or_not_regular")
        return
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        size = path.stat().st_size
    except OSError as exc:
        add(f"{label}: read_failed={type(exc).__name__}")
        return
    def positions(value):
        return [i for i, line in enumerate(lines, 1) if line.strip() == value]
    roots = positions("ShellRoot {")
    root_ids = positions("id: root")
    imports = [i for i, line in enumerate(lines, 1)
               if line.strip() == 'import "../k41/modules/topbar" as K41Topbar']
    instances = positions("K41Topbar.Topbar {}")
    watch = positions("settings.watchFiles: true")
    add(f"{label}: present; bytes={size}; sha256={__import__('hashlib').sha256(path.read_bytes()).hexdigest()[:16]}")
    add(f"{label} structure: ShellRoot={roots}; id-root={root_ids}; watchFiles={watch}")
    add(f"{label} integration: imports={imports}; instances={instances}")
    if root_ids and instances:
        add(f"{label} instance-before-id-root={'yes' if instances[0] < root_ids[0] else 'no'}")
    else:
        add(f"{label} instance-before-id-root=unknown")

inspect_qml_file(host_file, "EXPECTED_CAelestia_HOST")
inspect_qml_file(module_file, "DEPLOYED_K41_TOPBAR")

section("ACTIVE QUICKSHELL PROCESS")
process_count = 0
for proc in pathlib.Path("/proc").glob("[0-9]*"):
    try:
        comm = (proc / "comm").read_text(encoding="utf-8", errors="replace").strip()
        if "quickshell" not in comm.lower() and comm.lower() != "qs":
            continue
        process_count += 1
        raw_args = [x.decode("utf-8", "replace") for x in (proc / "cmdline").read_bytes().split(b"\\0") if x]
        selected = None
        for index, arg in enumerate(raw_args[:-1]):
            if arg in ("-c", "--config"):
                selected = raw_args[index + 1]
                break
        add(f"process: name={comm[:80]}; explicit-config={short_path(pathlib.Path(selected)) if selected else 'not_specified'}")
    except OSError:
        continue
if process_count == 0:
    add("No Quickshell/qs process observed.")

section("QML VALIDATION TOOLING")
for tool_name in ("qmllint", "qmlformat", "qml"):
    tool_path = shutil.which(tool_name)
    add(f"{tool_name}: {'available' if tool_path else 'NOT_FOUND'}")
    if tool_name == "qmllint" and tool_path:
        for label, candidate in (("host", host_file), ("module", module_file)):
            if candidate.is_file() and not candidate.is_symlink():
                rc, value = run([tool_path, str(candidate)], timeout=20)
                add(f"qmllint {label}: exit={rc}; {bounded(value, 1200)}")

section("RECENT QUICKSHELL/QML JOURNAL")
journal = shutil.which("journalctl")
if journal:
    rc, value = run([journal, "--user", "-b", "--no-pager", "-n", "300"], timeout=12)
    if rc == 0:
        matches = [line for line in value.splitlines()
                   if any(token in line.lower() for token in ("quickshell", "qml", "k41topbar", "topbar"))]
        add(f"journal query: exit=0; matching-lines={len(matches)}")
        for line in matches[-25:]:
            add("  " + bounded(line.replace(str(home), "~"), 360))
    else:
        add(f"journal query: exit={rc}; {bounded(value, 400)}")
else:
    add("journalctl: NOT_FOUND")

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
add("QML discovery is a bounded static scan; candidate relative paths and recognized identifiers are leads, not proof of the active entry point.")
add("Configuration source contents, source lines, comments, literals, process arguments, environment variables, serial numbers, and absolute home paths are never published.")
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
, line)]
    instance_lines = [i for i, line in enumerate(lines, 1)
                      if re.search(r"^\s*K41Topbar\.Topbar\s*\{\s*\}\s*$", line)]
    add(f"{label} structural: ShellRoot-line={root_line or 'not_found'}; id-root-line={id_line or 'not_found'}; watchFiles-true-line={watch_line or 'not_found'}")
    add(f"{label} K41 integration: import-count={len(import_lines)}; instance-count={len(instance_lines)}")
    if import_lines:
        add(f"{label} import-line-numbers: " + ",".join(map(str, import_lines[:8])))
    if instance_lines:
        add(f"{label} instance-line-numbers: " + ",".join(map(str, instance_lines[:8])))
    if root_line and id_line and instance_lines:
        add(f"{label} instance-order: {'instance_before_root_id' if instance_lines[0] < id_line else 'instance_after_root_id'}")
    else:
        add(f"{label} instance-order: cannot_determine")
    add(f"{label} file-bytes={path.stat().st_size}; sha256={__import__('hashlib').sha256(path.read_bytes()).hexdigest()[:16]}")
    add(f"{label} contains ShellRoot exactly once={'yes' if sum(bool(re.search(r'^\s*ShellRoot\s*\{\s*
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
add("QML discovery is a bounded static scan; candidate relative paths and recognized identifiers are leads, not proof of the active entry point.")
add("Configuration source contents, source lines, comments, literals, process arguments, environment variables, serial numbers, and absolute home paths are never published.")
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
, x)) for x in lines) == 1 else 'no'}")
    add(f"{label} contains import QtQuick exactly once={'yes' if sum(bool(re.search(r'^\s*import\s+QtQuick\s*
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
add("QML discovery is a bounded static scan; candidate relative paths and recognized identifiers are leads, not proof of the active entry point.")
add("Configuration source contents, source lines, comments, literals, process arguments, environment variables, serial numbers, and absolute home paths are never published.")
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
, x)) for x in lines) == 1 else 'no'}")

inspect_host(expected_host, "EXPECTED_CAELestia_HOST")
add("K41 Topbar deployed module: " + ("present" if k41_module.is_file() and not k41_module.is_symlink() else "absent_or_not_regular"))
if k41_module.is_file() and not k41_module.is_symlink():
    add(f"K41 Topbar module bytes={k41_module.stat().st_size}; sha256={__import__('hashlib').sha256(k41_module.read_bytes()).hexdigest()[:16]}")
    try:
        module_text = k41_module.read_text(encoding="utf-8", errors="replace")
        battery_expr = re.search(r"UPower\.displayDevice\.percentage.{0,100}", module_text)
        add("Battery percentage expression: " + (bounded(battery_expr.group(0), 180) if battery_expr else "not recognized"))
        add("Topbar QML imports: " + "; ".join(line.strip()[:160] for line in module_text.splitlines()
            if re.match(r"^\s*import\s+", line))[:700])
    except OSError:
        add("Topbar module content: unreadable")

section("ACTIVE QUICKSHELL PROCESS AND CONFIG SELECTION")
processes = []
for proc in pathlib.Path("/proc").glob("[0-9]*"):
    try:
        comm = (proc / "comm").read_text(encoding="utf-8", errors="replace").strip()
        if not re.search(r"quickshell|^qs$", comm, re.I):
            continue
        raw = (proc / "cmdline").read_bytes()
        args = [x.decode("utf-8", "replace") for x in raw.split(b"\0") if x]
        normalized = []
        selected = None
        i = 0
        while i < len(args):
            arg = args[i]
            if arg in ("-c", "--config", "--path") and i + 1 < len(args):
                value = args[i + 1]
                if arg in ("-c", "--config"):
                    selected = value
                normalized.append(arg + "=" + display_path(pathlib.Path(value)))
                i += 2
                continue
            if arg.startswith("--config="):
                selected = arg.split("=", 1)[1]
                normalized.append("--config=" + display_path(pathlib.Path(selected)))
            elif arg.startswith("--path="):
                normalized.append("--path=" + display_path(pathlib.Path(arg.split("=", 1)[1])))
            elif i == 0:
                normalized.append(pathlib.Path(arg).name)
            elif arg.startswith("-") and len(arg) < 100:
                normalized.append(arg)
            else:
                normalized.append("[argument-redacted]")
            i += 1
        processes.append((comm[:80], selected, normalized[:24]))
    except (OSError, PermissionError):
        continue
if processes:
    for comm, selected, args in processes[:12]:
        add(f"process: comm={comm}; explicit-config={display_path(pathlib.Path(selected)) if selected else 'not_specified'}")
        add("  normalized-arguments: " + " ".join(args))
else:
    add("No Quickshell/qs process found in /proc at capture time.")
add("Process IDs, raw command lines, environment variables, and unrelated arguments are not published.")
add("If no explicit -c/--config is present, the default configuration selection must be confirmed from the installed Quickshell version and runtime context.")

section("QML STATIC VALIDATION AVAILABILITY")
for tool_name in ("qmllint", "qmlformat", "qml"):
    tool_path = shutil.which(tool_name)
    if not tool_path:
        add(f"{tool_name}: NOT_FOUND")
        continue
    rc, value = run([tool_path, "--version"], timeout=8)
    add(f"{tool_name}: available; version-exit={rc}; {bounded(value, 240)}")
if shutil.which("qmllint"):
    for label, candidate in (("expected-host", expected_host), ("deployed-topbar", k41_module)):
        if candidate.is_file() and not candidate.is_symlink():
            rc, value = run([shutil.which("qmllint"), str(candidate)], timeout=20)
            normalized = bounded(value, 1800).replace(str(home), "~")
            add(f"qmllint {label}: exit={rc}")
            add("  output: " + (normalized.replace("\n", " | ") if normalized else "(no diagnostics)"))
else:
    add("qmllint execution: skipped; tool unavailable.")
add("qmllint results are static diagnostics only; they do not prove successful Quickshell runtime loading or visual rendering.")

section("RECENT QUICKSHELL/QML JOURNAL DIAGNOSTICS")
journal = shutil.which("journalctl")
if journal:
    rc, value = run([journal, "--user", "-b", "--no-pager", "-n", "500",
                     "-o", "short-iso"], timeout=12)
    if rc == 0:
        relevant = []
        for line in value.splitlines():
            if re.search(r"quickshell|(^|[^a-z])qs([^a-z]|$)|qml|K41Topbar|topbar", line, re.I):
                line = line.replace(str(home), "~")
                line = re.sub(r"\bpid[=: ]+\d+\b", "pid=[redacted]", line, flags=re.I)
                relevant.append(bounded(line, 360))
        add(f"journalctl user boot tail: exit=0; relevant-lines={len(relevant)}")
        for line in relevant[-30:]:
            add("  " + line)
        if not relevant:
            add("  no matching entries in last 500 user-journal records")
    else:
        add(f"journalctl user boot tail: exit={rc}; {bounded(value, 500)}")
else:
    add("journalctl: NOT_FOUND")
add("Journal sample is bounded to the last 500 user records; absence of matches does not prove absence of earlier errors.")

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
add("QML discovery is a bounded static scan; candidate relative paths and recognized identifiers are leads, not proof of the active entry point.")
add("Configuration source contents, source lines, comments, literals, process arguments, environment variables, serial numbers, and absolute home paths are never published.")
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
