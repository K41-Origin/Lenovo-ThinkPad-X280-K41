#!/usr/bin/env bash
# Read-only K41 Topbar audit with isolated sanitized-report publication.
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
for path in "$HOME/.local" "$state_root" "$state_root/k41" "$state_root/k41/topbar" "$report_root"; do
    [[ ! -L $path ]] || die "Symlink report path ditolak: $path"
    [[ ! -e $path || -d $path ]] || die "Report path bukan direktori: $path"
    if [[ -e $path ]]; then
        [[ $(stat -c %u -- "$path") == "$EUID" ]] || die "Report path bukan milik user aktif: $path"
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
( set -o noclobber; : > "$report" ) 2>/dev/null || die 'Tidak dapat membuat report.'
chmod 0600 "$report"

export K41_AUDIT_HOME="$HOME"
export K41_AUDIT_REPO="$repo_root"
export K41_AUDIT_REPORT="$report"
export K41_AUDIT_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
export K41_AUDIT_STATE="$state_root"

python3 <<'PY'
import hashlib, os, pathlib, pwd, re, shutil, stat, subprocess
from datetime import datetime, timezone

home = pathlib.Path(os.environ["K41_AUDIT_HOME"]).resolve()
repo = pathlib.Path(os.environ["K41_AUDIT_REPO"]).resolve()
report = pathlib.Path(os.environ["K41_AUDIT_REPORT"])
config = pathlib.Path(os.environ["K41_AUDIT_CONFIG"])
state = pathlib.Path(os.environ["K41_AUDIT_STATE"])
out = []

def add(value=""): out.append(str(value))
def section(title):
    add(); add("=" * 88); add(title); add("=" * 88)
def clean(value):
    text = str(value)
    if str(home) != "/": text = text.replace(str(home), "~")
    if str(repo) != "/": text = text.replace(str(repo), "<REPOSITORY_CHECKOUT>")
    try:
        username = pwd.getpwuid(os.getuid()).pw_name
        if username:
            text = re.sub(r"(?<![A-Za-z0-9_.-])" + re.escape(username) + r"(?![A-Za-z0-9_.-])", "<USER>", text)
    except KeyError: pass
    text = re.sub(r"(?i)\b(password|passwd|token|secret|authorization|cookie|api[_-]?key)\b([=: ]+)[^\s,;]+", r"\1\2<REDACTED>", text)
    return text
def run(args, timeout=8):
    try:
        p = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           timeout=timeout, check=False, env={**os.environ, "GIT_OPTIONAL_LOCKS":"0"})
        return p.returncode, clean(p.stdout.strip())
    except (OSError, subprocess.TimeoutExpired) as exc:
        return 127, type(exc).__name__
def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""): h.update(block)
    return h.hexdigest()
def describe(path):
    try:
        if path.is_symlink(): return "SYMLINK_BLOCKED"
        if not path.exists(): return "MISSING"
        if not path.is_file() and not path.is_dir(): return "UNSUPPORTED_TYPE"
        st = path.stat()
        return f"{'DIR' if path.is_dir() else 'FILE'} | mode={stat.S_IMODE(st.st_mode):04o} | uid={st.st_uid} | bytes={st.st_size if path.is_file() else '-'}" + (f" | sha256={sha(path)}" if path.is_file() else "")
    except OSError as exc: return f"STAT_ERROR:{type(exc).__name__}"
def walk(root, suffixes=None, limit=4000):
    if root.is_symlink() or not root.is_dir(): return
    count = 0
    for base, dirs, names in os.walk(root, followlinks=False):
        dirs[:] = sorted(d for d in dirs if d not in {".git", "node_modules", "build", ".cache", "__pycache__", ".venv"})
        for name in sorted(names):
            p = pathlib.Path(base) / name
            if p.is_symlink() or not p.is_file(): continue
            if suffixes is None or p.suffix.lower() in suffixes or name == "qmldir":
                yield p
                count += 1
                if count >= limit: return
def emit_excerpt(path, label, max_bytes=48*1024):
    try:
        raw = path.read_bytes()
        add(f"--- {label} | bytes={len(raw)} | sha256={hashlib.sha256(raw).hexdigest()} ---")
        if b"\0" in raw: add("<BINARY OMITTED>")
        else:
            value = raw[:max_bytes].decode("utf-8", "replace")
            add(clean(value.rstrip()))
            if len(raw) > max_bytes: add(f"<TRUNCATED after {max_bytes} bytes>")
        add(f"--- END {label} ---")
    except OSError as exc: add(f"<READ_ERROR:{type(exc).__name__}>")
def inventory(label, root, suffixes=None, excerpts=False):
    add(f"{label}: {clean(root)} | {describe(root)}")
    if root.is_dir() and not root.is_symlink():
        for p in walk(root, suffixes):
            rel = clean(p.relative_to(root))
            add(f"  {rel} | {describe(p)}")
            if excerpts and p.suffix.lower() in {".qml", ".js", ".mjs"}:
                emit_excerpt(p, f"{label}/{rel}")

ws = repo / "stages/stage-5-desktop-customization/workstreams/04-topbar"
section("AUDIT IDENTITY, SCOPE AND SAFETY")
add("Purpose: collect evidence for K41 Topbar technical design and implementation planning.")
add("Mode: read-only. No runtime/config/package/service/source/Git checkout mutation is performed.")
add("Private report: ~/.local/state/k41/topbar/audits/<timestamp>/topbar-audit.txt")
add("Publication: sanitized copy via fresh independent clone; active checkout Git metadata is not used.")
add("Captured UTC: " + datetime.now(timezone.utc).isoformat())
add("Host/kernel: <HOST-REDACTED> / " + os.uname().release)
add("Local UID/GID: <REDACTED>")
add("Repository: " + clean(repo))
for args, title in [
    (["git","-C",str(repo),"rev-parse","HEAD"],"HEAD"),
    (["git","-C",str(repo),"branch","--show-current"],"branch"),
    (["git","-C",str(repo),"status","--short","--branch"],"status"),
    (["git","-C",str(repo),"diff","--quiet"],"tracked worktree"),
    (["git","-C",str(repo),"diff","--cached","--quiet"],"index"),
]:
    rc, value = run(args)
    if title in ("tracked worktree","index"):
        value = "CLEAN" if rc == 0 else "MODIFIED" if rc == 1 else "UNKNOWN"
    add(f"Checkout {title}: {value or ('clean' if rc == 0 else 'UNKNOWN')}")

section("WORKSTREAM SOURCE, HISTORICAL IMPLEMENTATION AND DOCUMENTATION")
for rel in ("modules","scripts","tests","docs"):
    inventory(f"WS04 {rel}", ws / rel, excerpts=(rel in {"modules","scripts"}))
for rel in (
    "stages/stage-5-desktop-customization/docs/04-TOPBAR.md",
    "stages/stage-5-desktop-customization/docs/03-BOTTOMBAR.md",
    "stages/stage-5-desktop-customization/docs/02-LOCK-SCREEN.md",
    "stages/stage-5-desktop-customization/workstreams/03-bottombar/modules",
    "stages/stage-5-desktop-customization/workstreams/02-lock-screen/modules",
):
    p = repo / rel
    if p.is_file() and not p.is_symlink(): emit_excerpt(p, rel, 96*1024)
    elif p.is_dir(): inventory(f"Reference {rel}", p, {".qml",".js",".mjs",".sh",".md"})

section("CAELESTIA / QUICKSHELL CONFIGURATION ROOTS")
roots = [
    ("XDG_QUICKSHELL", config / "quickshell"),
    ("HOME_QUICKSHELL", home / ".config/quickshell"),
    ("SYSTEM_XDG_QUICKSHELL", pathlib.Path("/etc/xdg/quickshell")),
    ("SYSTEM_SHARE_QUICKSHELL", pathlib.Path("/usr/share/quickshell")),
]
seen = set()
host_roots = []
for label, root in roots:
    key = str(root.resolve(strict=False))
    if key in seen: continue
    seen.add(key)
    inventory(label, root, {".qml",".js",".mjs",".json",".conf"}, excerpts=True)
    candidate = root / "caelestia"
    if candidate.is_dir() and not candidate.is_symlink(): host_roots.append((label + "/caelestia", candidate))
    for config_file in (root / "caelestia/shell.qml", root / "caelestia/shell.json"):
        if config_file.is_file() and not config_file.is_symlink():
            emit_excerpt(config_file, f"{label}/{config_file.name}", 128*1024)

section("CAELESTIA PACKAGE, PROCESS AND SOURCE PROVENANCE")
for binary in ("caelestia","qs","quickshell","hyprctl","qmllint","qmlformat","qsb"):
    path = shutil.which(binary)
    add(f"{binary}: {clean(path) if path else 'NOT_FOUND'}")
    if path and binary in {"caelestia","qs","quickshell","hyprctl"}:
        rc, value = run([path,"--version"])
        add(f"  --version exit={rc}: {value[:2000]}")
for package in ("caelestia-shell","quickshell","quickshell-git","hyprland","qt6-base","qt6-declarative","qt6-wayland"):
    rc, value = run(["pacman","-Qi",package], timeout=10)
    if rc == 0:
        keys = ("Name","Version","Description","Architecture","URL","Packager","Build Date","Install Date")
        add(f"[{package}]")
        add("\n".join(line for line in value.splitlines() if any(line.startswith(k+" :") for k in keys)))
    else: add(f"{package}: NOT_INSTALLED_OR_PACMAN_UNAVAILABLE")
for root_label, root in host_roots:
    git_dir = root / ".git"
    add(f"{root_label} Git metadata: {describe(git_dir)}")
    if git_dir.exists():
        for args, title in (
            (["git","-C",str(root),"remote","get-url","origin"],"origin (redacted)"),
            (["git","-C",str(root),"rev-parse","HEAD"],"revision"),
            (["git","-C",str(root),"status","--short"],"working tree"),
        ):
            rc, value = run(args)
            if title.startswith("origin"): value = "<ORIGIN_CONFIGURED>" if rc == 0 else "UNAVAILABLE"
            add(f"  {title}: {value or ('clean' if rc == 0 else 'UNAVAILABLE')}")

section("ACTIVE QUICKSHELL / CAELESTIA / NOTIFICATION PROCESSES")
patterns = re.compile(r"(quickshell|\bqs\b|caelestia|dunst|mako|swaync|fnott|xfce4-notifyd)", re.I)
observed = 0
for proc in pathlib.Path("/proc").glob("[0-9]*"):
    try:
        raw = (proc/"cmdline").read_bytes().replace(b"\0",b" ").decode("utf-8","replace").strip()
        if raw and patterns.search(raw):
            add(f"pid={proc.name}: {clean(raw[:1000])}")
            observed += 1
            if observed >= 80: break
    except (OSError, PermissionError): pass
if not observed: add("No matching process command lines observed (not proof packages are absent).")
for binary in ("notify-send","gdbus","busctl"):
    add(f"{binary}: {clean(shutil.which(binary) or 'NOT_FOUND')}")
rc, value = run(["systemctl","--user","--no-pager","--plain","list-units","--type=service","--state=running"], timeout=10)
add(f"user running services exit={rc}:\n{value[:12000]}")

section("NOTIFICATION PROVIDER, DBUS AND API EVIDENCE")
for args, title in (
    (["busctl","--user","--no-pager","list"],"user D-Bus names"),
    (["gdbus"," introspect"],"placeholder"),
):
    if title == "placeholder": continue
    rc, value = run(args, timeout=10)
    if title == "user D-Bus names":
        lines = [line for line in value.splitlines() if re.search(r"notification|dunst|mako|swaync",line,re.I)]
        add(f"{title} exit={rc}:\n" + ("\n".join(lines[:80]) if lines else "No matching bus names observed."))
# Read-only introspection of the standard freedesktop notification interface.
rc, value = run(["gdbus","introspect","--session","--dest","org.freedesktop.Notifications","--object-path","/org/freedesktop/Notifications"], timeout=8)
add(f"org.freedesktop.Notifications introspection exit={rc}:\n{value[:6000]}")
add("Do not send test notifications: this audit does not invoke Notify or alter daemon state.")

section("MONITORS, HYPRLAND, LAYER-SHELL AND BATTERY OBSERVATIONS")
for args, title in (
    (["hyprctl","monitors","-j"],"Hyprland monitors JSON"),
    (["hyprctl","-j","activeworkspace"],"Hyprland active workspace"),
    (["hyprctl","-j","layers"],"Hyprland layer surfaces"),
    (["hyprctl","configerrors"],"Hyprland config errors"),
):
    rc, value = run(args, timeout=8)
    add(f"{title} exit={rc}:\n{value[:14000]}")
for path in sorted(pathlib.Path("/sys/class/power_supply").glob("*")):
    if path.is_symlink(): continue
    fields = {}
    for name in ("type","status","capacity","online","voltage_now","power_now","energy_now","energy_full"):
        item = path/name
        try:
            if item.is_file() and not item.is_symlink(): fields[name] = item.read_text(encoding="ascii",errors="replace").strip()
        except OSError: pass
    add(f"Power supply {path.name}: " + (", ".join(f"{k}={v}" for k,v in fields.items()) if fields else "no readable standard attributes"))

section("QML BAR, PANEL, TRAY AND RESOURCE REFERENCE SCAN")
scan_roots = []
for label, root in host_roots: scan_roots.append((label,root))
for label, root in (("K41 WS04",ws),("K41 WS03",repo/"stages/stage-5-desktop-customization/workstreams/03-bottombar")):
    scan_roots.append((label,root))
terms = re.compile(r"(PanelWindow|WlrLayershell|exclusiveZone|layer\s*:|anchors\.(top|bottom)|bar|topbar|bottombar|notification|Notif|tray|battery|power|cpu|memory|ram|monitor|fullscreen|HyprlandMonitor|Screens)",re.I)
matches = 0
for label, root in scan_roots:
    for p in walk(root,{".qml",".js",".mjs",".json"},limit=2500):
        try: lines = p.read_text(encoding="utf-8",errors="replace").splitlines()
        except (OSError,UnicodeError): continue
        found = [(i,line.strip()) for i,line in enumerate(lines,1) if terms.search(line)]
        if found:
            add(f"References in {label}/{clean(p.relative_to(root))}:")
            for i,line in found[:120]:
                add(f"  {i}: {clean(line[:700])}")
                matches += 1
if not matches: add("No matching QML/JS references found in bounded scan.")
add("Static text scan is not a QML dependency/linker analysis; dynamic loaders, generated types, plugins and runtime behavior may be missed.")

section("CONFIGURATION, KEYBINDS, SYSTEMD AND RELEVANT FILE INVENTORY")
for root in (config/"hypr", home/".config/hypr", config/"caelestia", home/".config/caelestia",
             pathlib.Path("/etc/xdg/caelestia"), pathlib.Path("/usr/share/caelestia")):
    if root.is_dir() and not root.is_symlink():
        inventory("Config " + clean(root),root,{".conf",".conf.d",".lua",".json",".qml",".ini"},excerpts=False)
for root in (pathlib.Path("/etc/systemd/user"), home/".config/systemd/user"):
    if root.is_dir() and not root.is_symlink():
        for p in walk(root,{".service",".target",".timer"}):
            add(f"User service definition: {clean(p)} | {describe(p)}")
add("No configuration or service file is modified or reloaded by this audit.")

section("AUDIT HANDOFF, OPEN QUESTIONS AND LIMITATIONS")
add("Design baseline: CPU, RAM, Notifications, Battery, Clock from left to right.")
add("Visual baseline: top horizontal, 32-36 px target, dark translucent, minimal radius, subtle shadow, K41 typography.")
add("Visibility baseline: always visible, all monitors; fullscreen visibility is intent pending compositor/runtime proof.")
add("Notification interaction baseline: clickable icon opens a notification tray/panel; tray is not permanently open.")
add("Technical decisions still open: active data providers, daemon ownership, tray API, QML integration point, data formats, locale/timezone, exclusive zone, focus/fullscreen, monitor hotplug/scaling.")
add("Audit is observational. It does not compile QML, change packages/services/configuration, send notifications, reload shells, or validate visual behavior.")
add("Review the private report and sanitized public report; automated redaction cannot guarantee removal of all sensitive information.")
add("Private report: " + clean(report))
report.write_text("\n".join(out)+"\n",encoding="utf-8")
print(f"Topbar audit report created: {report}")
print(f"Report size: {report.stat().st_size} bytes")
PY

[[ -s "$report" ]] || die 'Audit tidak menghasilkan report valid.'

published_report="$run_dir/published-report.txt"
python3 - "$report" "$published_report" <<'PY'
from pathlib import Path
import os, pwd, re, sys
source, destination = map(Path,sys.argv[1:3])
text = source.read_bytes().decode("utf-8","replace")
home = os.environ.get("HOME","")
repo = os.environ.get("K41_AUDIT_REPO","")
if home and home != "/": text = text.replace(home,"<HOME>")
if repo: text = text.replace(repo,"<REPOSITORY_CHECKOUT>")
try:
    username = pwd.getpwuid(os.getuid()).pw_name
    if username: text = re.sub(r"(?<![A-Za-z0-9_.-])"+re.escape(username)+r"(?![A-Za-z0-9_.-])","<USER>",text)
except KeyError: pass
text = re.sub(r"(?m)^Host/kernel:.*$","Host/kernel: <HOST-REDACTED>",text)
text = re.sub(r"(?m)^Local UID/GID:.*$","Local UID/GID: <REDACTED>",text)
text = re.sub(r"\b(uid|gid)=\d+\b",r"\1=<REDACTED>",text)
text = re.sub(r"(?i)(https?://)[^/@\s]+@",r"\1<REDACTED>@",text)
text = re.sub(r"(?i)\b(password|passwd|token|secret|authorization|cookie|api[_-]?key)\b([=: ]+)[^\s,;]+",r"\1\2<REDACTED>",text)
text = re.sub(r"(?i)(\bSSID\s*[:=]\s*)(?:'[^']*'|\"[^\"]*\"|[^\s,;)]+)",r"\1<SSID-REDACTED>",text)
text = re.sub(r"\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b","<IP-REDACTED>",text)
text = re.sub(r"\b(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}\b","<MAC-REDACTED>",text)
text = "".join(ch for ch in text if ch in "\n\r\t" or ord(ch)>=32)
destination.write_text(text,encoding="utf-8")
if destination.stat().st_size == 0: raise SystemExit("ERROR: sanitized report is empty")
print(f"Sanitized publication copy: PASS ({destination.stat().st_size} bytes)")
PY
chmod 0600 "$published_report"

cat >"$run_dir/README.txt" <<EOF
K41 Topbar audit
================
Run from repository checkout on branch main as the regular desktop user:

  bash stages/stage-5-desktop-customization/workstreams/04-topbar/scripts/k41-audit-topbar.sh

The collector is read-only with respect to runtime configuration, packages,
services, source files, and the active Git checkout. Full evidence remains
private under ~/.local/state/k41/topbar/audits/.
A sanitized report is published through a fresh independent clone to:

  reports/stage-5-desktop-customization/04-topbar/audits/<timestamp>/

The active checkout's HEAD, branch, index, FETCH_HEAD, and worktree metadata are
not used for publication. Review the public report for residual sensitive data;
automated redaction cannot guarantee removal of every secret.
EOF
chmod 0600 "$run_dir/README.txt"

publish_report() {
    local remote_url publish_tmp publish_dir relative_dir publish_target
    remote_url="$(git -C "$repo_root" remote get-url origin 2>/dev/null)" ||
        { printf 'ERROR: tidak dapat membaca Git origin; report tetap lokal.\n' >&2; return 1; }
    case "$remote_url" in
        https://github.com/K41-Origin/Lenovo-ThinkPad-X280-K41|https://github.com/K41-Origin/Lenovo-ThinkPad-X280-K41.git|git@github.com:K41-Origin/Lenovo-ThinkPad-X280-K41.git|ssh://git@github.com/K41-Origin/Lenovo-ThinkPad-X280-K41.git) ;;
        *) printf 'ERROR: Git origin bukan repository K41 yang diizinkan; report tetap lokal.\n' >&2; return 1 ;;
    esac
    publish_tmp="$(mktemp -d "${TMPDIR:-/tmp}/k41-topbar-audit-publish.XXXXXX")" || return 1
    publish_dir="$publish_tmp/repository"
    if ! GIT_TERMINAL_PROMPT=0 git clone --quiet --no-tags --single-branch --branch main "$remote_url" "$publish_dir"; then
        rm -rf -- "$publish_tmp"
        printf 'ERROR: isolated clone gagal; report privat tetap tersedia.\n' >&2
        return 1
    fi
    relative_dir="reports/stage-5-desktop-customization/04-topbar/audits/${run_dir##*/}"
    publish_target="$publish_dir/$relative_dir"
    if ! mkdir -p -- "$publish_target" ||
       ! cp -- "$published_report" "$publish_target/report.txt" ||
       ! cp -- "$run_dir/README.txt" "$publish_target/README.txt"; then
        rm -rf -- "$publish_tmp"
        printf 'ERROR: staging report gagal; report privat tetap tersedia.\n' >&2
        return 1
    fi
    if ! chmod 0644 "$publish_target/report.txt" "$publish_target/README.txt" ||
       ! chmod 0755 "$publish_target" ||
       ! git -C "$publish_dir" -c user.name="K41 Topbar Audit" -c user.email="k41-topbar-audit@users.noreply.github.com" add -- "$relative_dir" ||
       ! git -C "$publish_dir" -c user.name="K41 Topbar Audit" -c user.email="k41-topbar-audit@users.noreply.github.com" commit -m "Add K41 Topbar runtime audit"; then
        rm -rf -- "$publish_tmp"
        printf 'ERROR: staging/commit report gagal; report privat tetap tersedia.\n' >&2
        return 1
    fi
    if ! GIT_TERMINAL_PROMPT=0 git -C "$publish_dir" push origin HEAD:main; then
        printf 'INFO: main berubah saat push; mencoba fetch/rebase satu kali pada clone terisolasi.\n'
        if ! GIT_TERMINAL_PROMPT=0 git -C "$publish_dir" fetch --no-tags origin main ||
           ! git -C "$publish_dir" rebase origin/main ||
           ! GIT_TERMINAL_PROMPT=0 git -C "$publish_dir" push origin HEAD:main; then
            rm -rf -- "$publish_tmp"
            printf 'ERROR: publikasi gagal; report privat tetap tersedia: %s\n' "$report" >&2
            return 1
        fi
    fi
    rm -rf -- "$publish_tmp"
    printf 'INFO: sanitized report published: %s\n' "$relative_dir"
    printf 'INFO: active checkout Git metadata was not used for publication.\n'
}

printf 'Private audit report: %s\n' "$report"
if publish_report; then
    printf 'Automated publication succeeded.\n'
else
    printf 'WARNING: publication failed; private report retained locally.\n' >&2
    exit 1
fi
printf 'Runtime and active checkout state were not modified.\n'
