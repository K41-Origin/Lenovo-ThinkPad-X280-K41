#!/usr/bin/env bash
# Read-only X280 WS04 runtime audit. Private local evidence + sanitized GitHub copy.
set -Eeuo pipefail
umask 077
export GIT_OPTIONAL_LOCKS=0

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
have() { command -v "$1" >/dev/null 2>&1; }

(( EUID != 0 )) || die 'Jalankan sebagai user desktop biasa, tanpa sudo.'
[[ -n ${HOME:-} && $HOME == /* && -d $HOME ]] || die 'HOME tidak valid.'
for cmd in git stat date mkdir chmod python3 mktemp cp rm; do
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
[[ $state_root == /* ]] || die 'XDG_STATE_HOME harus absolut.'
report_root="$state_root/k41/topbar/runtime-audits"
for path_check in "$HOME/.local" "$state_root" "$state_root/k41" "$state_root/k41/topbar" "$report_root"; do
  [[ ! -L $path_check ]] || die "Symlink report path ditolak: $path_check"
  [[ ! -e $path_check || -d $path_check ]] || die "Report path bukan direktori: $path_check"
  if [[ -e $path_check ]]; then
    [[ $(stat -c %u -- "$path_check") == "$EUID" ]] || die "Report path bukan milik user aktif: $path_check"
  fi
done
mkdir -p -- "$report_root"
chmod 0700 "$report_root"
stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
run_dir="$report_root/$stamp"
suffix=0
while ! mkdir -- "$run_dir" 2>/dev/null; do
  [[ -e $run_dir ]] || die 'Tidak dapat membuat direktori report.'
  suffix=$((suffix + 1))
  run_dir="$report_root/$stamp-$suffix"
done
chmod 0700 "$run_dir"
report="$run_dir/report.txt"
: >"$report"
chmod 0600 "$report"

export K41_AUDIT_REPO="$repo_root" K41_AUDIT_REPORT="$report"
python3 <<'PY'
import hashlib, os, pathlib, pwd, re, shutil, subprocess
from datetime import datetime, timezone

repo = pathlib.Path(os.environ["K41_AUDIT_REPO"])
home = pathlib.Path.home()
config_home = pathlib.Path(os.environ.get("XDG_CONFIG_HOME", str(home / ".config")))
qs_root = config_home / "quickshell"
host = qs_root / "caelestia" / "shell.qml"
module = qs_root / "caelestia" / "k41" / "modules" / "topbar" / "Topbar.qml"
compat_module = qs_root / "k41" / "modules" / "topbar" / "Topbar.qml"
source_module = repo / "stages/stage-5-desktop-customization/workstreams/04-topbar/modules/topbar/Topbar.qml"
notifs = qs_root / "caelestia" / "services" / "Notifs.qml"
k41_notifications = qs_root / "caelestia" / "k41" / "modules" / "topbar" / "services" / "Notifications.qml"
source_notifications = repo / "stages/stage-5-desktop-customization/workstreams/04-topbar/modules/topbar/services/Notifications.qml"
out = []

def add(s=""): out.append(str(s))
def section(s): add(); add("=" * 78); add(s); add("=" * 78)
def run(args, timeout=12):
    try:
        p = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           timeout=timeout, check=False, env={**os.environ, "GIT_OPTIONAL_LOCKS":"0"})
        return p.returncode, p.stdout
    except (OSError, subprocess.TimeoutExpired) as e:
        return 127, type(e).__name__
def redact(s):
    s = str(s).replace(str(home), "<HOME>")
    try: user = pwd.getpwuid(os.getuid()).pw_name
    except KeyError: user = os.environ.get("USER", "")
    if user:
        s = re.sub(r"(?<![A-Za-z0-9_.-])"+re.escape(user)+r"(?![A-Za-z0-9_.-])", "<USER>", s)
    s = re.sub(r"(?i)\b(password|passwd|token|secret|authorization|cookie|api[_-]?key)\b([=: ]+)[^\s,;]+", r"\1\2<REDACTED>", s)
    s = re.sub(r"\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b", "<IP-REDACTED>", s)
    s = re.sub(r"\b(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}\b", "<MAC-REDACTED>", s)
    s = re.sub(r"/run/user/\d+", "/run/user/<UID>", s)
    s = "".join(c for c in s if c in "\n\r\t" or ord(c) >= 32)
    return s

def file_block(label, path, include=False, limit=65536):
    section(label)
    if path.is_symlink() or not path.is_file():
        add("MISSING_OR_UNSAFE")
        return
    try:
        raw = path.read_bytes()
        st = path.stat()
        add(f"bytes={len(raw)} mode={oct(st.st_mode & 0o777)} uid={st.st_uid}")
        add("sha256=" + hashlib.sha256(raw).hexdigest())
        if include:
            add("--- BEGIN SOURCE (bounded) ---")
            add(redact(raw[:limit].decode("utf-8", "replace")))
            add("--- END SOURCE ---")
    except OSError as e:
        add("READ_FAILED=" + type(e).__name__)

def command_block(title, args, timeout=12, max_chars=14000):
    section(title)
    rc, value = run(args, timeout)
    add(f"exit={rc}")
    add(redact(value[-max_chars:]))

section("AUDIT SCOPE")
add("K41 WS04 Topbar runtime diagnostic; read-only; no deployment, reload, restart, package, service, or configuration changes.")
add("Captured UTC: " + datetime.now(timezone.utc).isoformat())
add("Repository HEAD: " + run(["git","-C",str(repo),"rev-parse","HEAD"])[1].strip())
add("Branch: " + run(["git","-C",str(repo),"branch","--show-current"])[1].strip())
rc, status = run(["git","-C",str(repo),"status","--porcelain"])
add("Checkout status: " + ("clean" if rc == 0 and not status.strip() else "has local changes" if rc == 0 else "unavailable"))
add("Session context: " + "; ".join(f"{k}={'present' if os.environ.get(k) else 'absent'}" for k in
    ("XDG_SESSION_TYPE","WAYLAND_DISPLAY","HYPRLAND_INSTANCE_SIGNATURE","XDG_RUNTIME_DIR","DBUS_SESSION_BUS_ADDRESS")))
add("Effective config root: " + ("<HOME>/.config" if config_home == home/".config" else redact(config_home)))

section("VERSIONS AND TOOLING")
for binary in ("qs","quickshell","caelestia","hyprctl","qmllint","qmlformat","qml"):
    path = shutil.which(binary)
    if not path: add(f"{binary}: NOT_FOUND"); continue
    if binary in ("qs","quickshell","caelestia","hyprctl"):
        rc, value = run([path,"--version"],5)
        add(f"{binary}: {path}; version_exit={rc}; {redact(value[:500]).strip()}")
    else: add(f"{binary}: {path}")
for package in ("caelestia-shell","quickshell","quickshell-git","hyprland","qt6-base","qt6-declarative","qt6-wayland"):
    rc, value = run(["pacman","-Q",package],5)
    add(f"package {package}: {redact(value.strip()) if rc == 0 else 'not installed or pacman unavailable'}")

section("EXPECTED RUNTIME FILES")
add("Host expected: ~/.config/quickshell/caelestia/shell.qml")
add("Primary module expected: ~/.config/quickshell/caelestia/k41/modules/topbar/Topbar.qml")
add("Compatibility mirror expected: ~/.config/quickshell/k41/modules/topbar/Topbar.qml")
file_block("RUNTIME CAELESTIA HOST SHELL", host, True)
file_block("RUNTIME PRIMARY K41 TOPBAR MODULE", module, True)
file_block("RUNTIME COMPATIBILITY TOPBAR MODULE", compat_module, True)
file_block("CANONICAL K41 TOPBAR SOURCE", source_module, True)
file_block("RUNTIME CAELESTIA NOTIFS SERVICE", notifs, True, 98304)
file_block("RUNTIME K41 NOTIFICATIONS SERVICE", k41_notifications, True, 98304)
file_block("CANONICAL K41 NOTIFICATIONS SOURCE", source_notifications, True, 98304)
for label, runtime_path in (("primary", module), ("compatibility", compat_module)):
    if runtime_path.is_file() and not runtime_path.is_symlink() and source_module.is_file() and not source_module.is_symlink():
        add(f"Runtime {label} module equals canonical source: " + ("YES" if runtime_path.read_bytes() == source_module.read_bytes() else "NO"))
    else: add(f"Runtime {label} module equals canonical source: UNKNOWN")
if host.is_file() and not host.is_symlink():
    text = host.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    for needle in ('import qs.k41.modules.topbar as K41Topbar','import "../k41/modules/topbar" as K41Topbar','K41Topbar.Topbar {}','K41.Topbar.Topbar {}'):
        matches = [str(i) for i,line in enumerate(lines,1) if needle in line]
        add(f"Host token {needle!r}: lines={','.join(matches) if matches else 'NOT_FOUND'}")
    root_ids = [i for i,line in enumerate(lines,1) if re.match(r"^\s*id:\s*root\s*$",line)]
    instances = [i for i,line in enumerate(lines,1) if re.match(r"^\s*K41Topbar\.Topbar\s*\{\s*\}\s*$",line)]
    add(f"Host root-id lines={root_ids}; K41Topbar instance lines={instances}")
    add("Structural placement after root id: " + ("YES" if root_ids and instances and instances[0] > root_ids[0] else "NO_OR_UNKNOWN"))

section("NOTIFICATION SERVER CONFIGURATION AND D-BUS OWNERSHIP")
for label, path in (("Caelestia Notifs.qml", notifs), ("K41 Notifications.qml", k41_notifications)):
    add(f"{label}: exists={path.is_file() and not path.is_symlink()} symlink={path.is_symlink()}")
    if path.is_file() and not path.is_symlink():
        try:
            lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
            server_lines = [i for i,line in enumerate(lines,1) if re.match(r"^\s*NotificationServer\s*\{", line)]
            marker_lines = [i for i,line in enumerate(lines,1) if "K41_NOTIFICATION_SERVER_DISABLED_BY_K41" in line]
            backend_lines = [i for i,line in enumerate(lines,1) if "K41_NOTIFICATION_BACKEND_READY" in line]
            add(f"{label}: NotificationServer_opening_lines={server_lines}; K41_disabled_marker_lines={marker_lines}; K41_backend_ready_marker_lines={backend_lines}")
        except OSError as exc:
            add(f"{label}: READ_FAILED={type(exc).__name__}")
add("Static QML block counts are textual evidence only; nested syntax is not parsed.")

section("D-BUS org.freedesktop.Notifications OWNER")
if shutil.which("busctl"):
    command_block("BUSCTL OWNER STATUS", ["busctl", "--user", "status", "org.freedesktop.Notifications"], 8, 5000)
    command_block("BUSCTL GETNAMEOWNER", ["busctl", "--user", "call", "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetNameOwner", "s", "org.freedesktop.Notifications"], 8, 3000)
    rc, listing = run(["busctl", "--user", "list", "--no-pager", "--no-legend"], 8)
    section("D-BUS NOTIFICATION-RELATED NAME OWNERS")
    add(f"exit={rc}")
    selected = [line for line in listing.splitlines() if re.search(r"notification|notify|dunst|mako|swaync|fnott", line, re.I)]
    add(redact("\n".join(selected) if selected else "No matching names in busctl list output."))
else:
    add("busctl: NOT_FOUND; D-Bus owner query unavailable.")
if shutil.which("dbus-send"):
    command_block("DBUS-SEND GETNAMEOWNER", ["dbus-send", "--session", "--print-reply=literal", "--dest=org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus.GetNameOwner", "string:org.freedesktop.Notifications"], 8, 3000)
else:
    add("dbus-send: NOT_FOUND; secondary D-Bus query unavailable.")

section("KNOWN COMPETING NOTIFICATION DAEMONS")
daemon_names = {"dunst", "mako", "swaync", "fnott", "xfce4-notifyd", "notification-daemon"}
daemon_count = 0
for proc in pathlib.Path("/proc").glob("[0-9]*"):
    try:
        comm = (proc / "comm").read_text(errors="replace").strip()
        if comm.lower() in daemon_names:
            daemon_count += 1
            try: exe = os.readlink(proc / "exe")
            except OSError: exe = "unavailable"
            add(f"daemon pid={proc.name}; comm={comm}; exe={redact(exe)}")
    except OSError:
        pass
add(f"known_competing_daemon_process_count={daemon_count}")
command_block("USER NOTIFICATION-RELATED SYSTEMD UNITS", ["systemctl", "--user", "list-units", "--all", "--no-legend", "--no-pager"], 10, 16000)
for package in ("dunst", "mako", "swaync", "fnott", "xfce4-notifyd", "notification-daemon"):
    rc, value = run(["pacman", "-Q", package], 5)
    add(f"notification package {package}: {redact(value.strip()) if rc == 0 else 'not installed or pacman unavailable'}")

section("ACTIVE QUICKSHELL PROCESS AND SELECTOR")
count = 0
for proc in pathlib.Path("/proc").glob("[0-9]*"):
    try:
        comm = (proc/"comm").read_text(errors="replace").strip()
        if comm.lower() not in {"qs","quickshell"} and "quickshell" not in comm.lower(): continue
        count += 1
        argv = [x.decode("utf-8","replace") for x in (proc/"cmdline").read_bytes().split(b"\0") if x]
        selector = None
        for i,arg in enumerate(argv[:-1]):
            if arg in ("-c","--config"): selector = argv[i+1]
        add(f"process name={comm}; config_selector={redact(selector) if selector else 'not-explicit'}")
        env = {}
        for item in (proc/"environ").read_bytes().split(b"\0"):
            if b"=" in item:
                k,v=item.split(b"=",1); key=k.decode("utf-8","replace")
                if key in ("XDG_CONFIG_HOME","QS_CONFIG_NAME"):
                    env[key]=v.decode("utf-8","replace")
        for k,v in env.items(): add(f"process_env {k}={redact(v)}")
    except (OSError, PermissionError): pass
add(f"matching process count={count}")
add("No PID, complete command line, or unrestricted process environment is recorded.")

command_block("QUICKSHELL INSTANCE INVENTORY", ["qs","list","--all"])
command_block("QUICKSHELL CAELESTIA LOG (LATEST 400 LINES)", ["qs","log","-c","caelestia","--tail","400","--no-color"], max_chars=24000)

section("BATTERY TELEMETRY — UPOWER AND KERNEL SYSFS")
add("Read-only comparison; serial numbers and device identifiers are deliberately omitted.")
rc, value = run(["upower", "-e"], 8)
add(f"upower -e exit={rc}")
device_paths = [line.strip() for line in value.splitlines() if line.strip().startswith("/org/freedesktop/UPower/devices/")]
if not device_paths:
    add("UPower device enumeration unavailable or returned no device paths.")
for device_path in device_paths:
    rc, detail = run(["upower", "-i", device_path], 8)
    add(f"DEVICE {device_path} exit={rc}")
    if rc == 0:
        allowed = ("native-path", "vendor", "model", "power supply", "updated",
                   "present", "rechargeable", "state", "warning-level", "energy",
                   "energy-empty", "energy-full", "energy-full-design", "energy-rate",
                   "voltage", "percentage", "capacity", "technology", "icon-name",
                   "time to empty", "time to full")
        for line in detail.splitlines():
            key = line.strip().split(":", 1)[0].lower() if ":" in line else ""
            if key in allowed:
                add(redact(line.strip()))
rc, value = run(["upower", "-d"], 10)
add(f"upower -d exit={rc}")
if rc != 0: add(redact(value[:3000]))
battery_root = pathlib.Path("/sys/class/power_supply")
batteries = sorted(battery_root.glob("BAT*")) if battery_root.is_dir() else []
for battery in batteries:
    if battery.is_symlink() or not battery.is_dir():
        continue
    section(f"KERNEL BATTERY {battery.name} — ALLOWLISTED ATTRIBUTES")
    for attr in ("type", "present", "status", "capacity", "energy_now", "energy_full",
                 "energy_full_design", "charge_now", "charge_full", "charge_full_design",
                 "power_now", "current_now", "voltage_now", "technology", "cycle_count",
                 "manufacturer", "model_name"):
        target = battery / attr
        try:
            if target.is_file() and not target.is_symlink():
                raw = target.read_text(encoding="utf-8", errors="replace").strip()
                add(f"{attr}={redact(raw[:300])}")
        except OSError as exc:
            add(f"{attr}=READ_FAILED:{type(exc).__name__}")
if not batteries:
    add("No BAT* sysfs directory found.")
command_block("UPower SYSTEM SERVICE STATUS", ["systemctl","status","upower.service","--no-pager"], 8, 3000)

section("NOTIFICATION SIDEBAR / DOCK SOURCE DISCOVERY")
add("Bounded source references identify Caelestia's notification-dock selection API; no API is inferred or invoked.")
source_roots = [qs_root / "caelestia", pathlib.Path("/usr/share/caelestia"),
                pathlib.Path("/usr/lib/caelestia"), pathlib.Path("/usr/share/quickshell/caelestia")]
seen_roots = set()
matches = 0
for root in source_roots:
    if root in seen_roots or root.is_symlink() or not root.is_dir():
        continue
    seen_roots.add(root)
    add(f"SOURCE_ROOT {redact(root)}")
    candidates = []
    for pattern in ("*.qml", "*.js"):
        candidates.extend(root.rglob(pattern))
    for source_path in sorted(candidates):
        if source_path.is_symlink() or not source_path.is_file():
            continue
        try:
            lines = source_path.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue
        for number, line in enumerate(lines, 1):
            if re.search(r"sidebar|notification|notifs|utilities|drawer|activeTab|selectedTab|currentTab", line, re.I):
                rel = source_path.relative_to(root).as_posix()
                add(f"{rel}:{number}: {redact(line.strip()[:260])}")
                matches += 1
                if matches >= 240:
                    break
        if matches >= 240:
            break
    if matches >= 240:
        add("SOURCE_MATCH_LIMIT_REACHED=240")
        break
if matches == 0:
    add("No matching readable Caelestia QML/JS source lines found.")
command_block("HYPRLAND CONFIG ERRORS", ["hyprctl","configerrors"])
command_block("HYPRLAND MONITORS", ["hyprctl","-j","monitors"])
command_block("USER SERVICE UNITS RELATED TO QUICKSHELL/CAELESIA", ["systemctl","--user","list-units","--all","--no-legend","--no-pager"])

section("RECENT USER JOURNAL — QUICKSHELL/QML/TOPBAR")
rc, journal = run(["journalctl","--user","-b","--no-pager","-o","short-iso-precise"],20)
add(f"journal_exit={rc}")
if rc == 0:
    lines = [line for line in journal.splitlines() if re.search(r"quickshell|caelestia|qml|topbar|k41",line,re.I)]
    add(redact("\n".join(lines[-500:])))
else: add(redact(journal[:2000]))
section("CURRENT BOOT JOURNAL — RELEVANT SYSTEM EVENTS")
rc, journal = run(["journalctl","-b","--no-pager","-o","short-iso-precise"],20)
if rc == 0:
    lines = [line for line in journal.splitlines() if re.search(r"hyprland|quickshell|caelestia|qml|topbar|k41",line,re.I)]
    add(redact("\n".join(lines[-300:])))
else: add(f"journal_exit={rc}; {redact(journal[:2000])}")

section("RELEVANT RUNTIME TREE")
for root in (qs_root/"caelestia", qs_root/"k41"):
    add(f"{redact(root)}: " + ("present" if root.is_dir() and not root.is_symlink() else "absent_or_unsafe"))
    if root.is_dir() and not root.is_symlink():
        paths=[]
        for p in root.rglob("*"):
            if p.is_symlink(): continue
            if p.is_file() and p.suffix.lower() in (".qml",".js","qmldir"):
                paths.append(p.relative_to(root).as_posix())
                if len(paths)>=300: break
        add("\n".join(paths) if paths else "no QML/JS/qmldir files found")

section("QML STATIC VALIDATION")
qmllint = shutil.which("qmllint")
if qmllint:
    for label,path in (("runtime host",host),("runtime module",module)):
        if path.is_file() and not path.is_symlink():
            rc,value=run([qmllint,str(path)],20)
            add(f"{label}: exit={rc}\n{redact(value[:8000])}")
        else: add(f"{label}: skipped; file unavailable")
else: add("qmllint unavailable; no package installation attempted.")
add("Static lint does not prove Quickshell runtime instantiation; import context and runtime services may differ.")

section("DIAGNOSTIC LIMITATIONS")
add("- Battery telemetry is observed only; no UPower, kernel, firmware, or power-management state is changed.")
add("- Notification diagnostics include bounded full Caelestia/K41 notification QML sources, static NotificationServer markers, D-Bus owner queries, and known competing daemon processes/units.")
add("- D-Bus owner queries may be unavailable outside the active user session; unavailable output is an evidence gap, not proof that no owner exists.")
add("- No Quickshell process is launched; no duplicate shell or temporary panel is created.")
add("- No reload/restart/deployment or config edit is performed.")
add("- Journal visibility depends on the current user's permissions.")
add("- Source/config snippets and logs are automatically redacted, but redaction is not a guarantee; inspect the private report before sharing.")
add("- The report distinguishes missing evidence from evidence of failure; absence of a log line does not prove an event did not occur.")
add("- This collector does not identify boot-time bottlenecks; systemd-analyze requires a separate boot audit.")
path = pathlib.Path(os.environ["K41_AUDIT_REPORT"])
path.write_text(redact("\n".join(out))+"\n",encoding="utf-8")
print(f"Collected {len(out)} report lines.")
PY

[[ -s $report ]] || die 'Report kosong; menolak publikasi.'
chmod 0600 "$report"
cat >"$run_dir/README.txt" <<'EOF'
K41 WS04 Topbar runtime audit
=============================
Run as the regular desktop user, preferably from TTY after the failed desktop startup:

  bash stages/stage-5-desktop-customization/workstreams/04-topbar/scripts/k41-audit-topbar-runtime.sh

The collector is read-only. It records runtime Topbar and notification QML files, static NotificationServer markers, the org.freedesktop.Notifications D-Bus owner, known notification-daemon processes and user units, Quickshell logs, UPower telemetry, and bounded Caelestia notification/sidebar QML references. It does not deploy files, launch Quickshell, trigger notification/sidebar actions, reload/restart services, install packages, or edit configuration. The complete local report is private under ~/.local/state/k41/topbar/runtime-audits/.

A separately redacted copy is published to the repository reports directory through an independent temporary clone. Review the published report for residual sensitive information. If publication fails, the private local report remains available and the script exits non-zero.
EOF
chmod 0600 "$run_dir/README.txt"

publish_report() {
  local remote_url publish_tmp publish_dir relative_dir target
  remote_url="$(git -C "$repo_root" remote get-url origin 2>/dev/null)" ||
    { printf 'ERROR: tidak dapat membaca Git origin; report tetap lokal.\n' >&2; return 1; }
  case "$remote_url" in
    https://github.com/K41-Origin/Lenovo-ThinkPad-X280-K41|https://github.com/K41-Origin/Lenovo-ThinkPad-X280-K41.git|git@github.com:K41-Origin/Lenovo-ThinkPad-X280-K41.git|ssh://git@github.com/K41-Origin/Lenovo-ThinkPad-X280-K41.git) ;;
    *) printf 'ERROR: Git origin bukan repository K41 yang diizinkan.\n' >&2; return 1 ;;
  esac
  publish_tmp="$(mktemp -d "${TMPDIR:-/tmp}/k41-topbar-audit-publish.XXXXXX")" || return 1
  publish_dir="$publish_tmp/repository"
  if ! git clone --quiet --no-tags --single-branch --branch main "$remote_url" "$publish_dir"; then
    rm -rf -- "$publish_tmp"; printf 'ERROR: isolated clone gagal; report tetap lokal.\n' >&2; return 1
  fi
  relative_dir="reports/stage-5-desktop-customization/04-topbar/runtime-audits/${run_dir##*/}"
  target="$publish_dir/$relative_dir"
  if ! mkdir -p -- "$target" ||
     ! cp -- "$report" "$target/report.txt" ||
     ! cp -- "$run_dir/README.txt" "$target/README.txt"; then
    rm -rf -- "$publish_tmp"; printf 'ERROR: staging report gagal; report tetap lokal.\n' >&2; return 1
  fi
  chmod 0644 "$target/report.txt" "$target/README.txt"
  chmod 0755 "$target"
  git -C "$publish_dir" config user.name "K41 Topbar Runtime Audit"
  git -C "$publish_dir" config user.email "k41-topbar-audit@users.noreply.github.com"
  if ! git -C "$publish_dir" add -- "$relative_dir" ||
     ! git -C "$publish_dir" commit -m "Add X280 Topbar runtime audit"; then
    rm -rf -- "$publish_tmp"; printf 'ERROR: commit report gagal; report tetap lokal.\n' >&2; return 1
  fi
  if ! GIT_TERMINAL_PROMPT=0 git -C "$publish_dir" push origin HEAD:main; then
    printf 'INFO: main berubah saat publikasi; mencoba rebase satu kali.\n'
    if ! GIT_TERMINAL_PROMPT=0 git -C "$publish_dir" fetch --no-tags origin main ||
       ! git -C "$publish_dir" rebase FETCH_HEAD ||
       ! GIT_TERMINAL_PROMPT=0 git -C "$publish_dir" push origin HEAD:main; then
      rm -rf -- "$publish_tmp"; printf 'ERROR: publikasi gagal; report tetap lokal: %s\n' "$report" >&2; return 1
    fi
  fi
  rm -rf -- "$publish_tmp"
  printf 'INFO: report tersanitasi dipublikasikan: %s\n' "$relative_dir"
  printf 'INFO: local checkout Git metadata tidak digunakan untuk publikasi.\n'
}

printf 'Private report: %s\n' "$report"
if publish_report; then
  printf 'Audit selesai; tidak ada perubahan pada konfigurasi atau service sistem.\n'
else
  printf 'WARNING: publikasi gagal; report privat tetap tersedia.\n' >&2
  exit 1
fi
