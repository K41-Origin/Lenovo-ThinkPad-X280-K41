#!/usr/bin/env bash
# Read-only K41 Bottombar audit: repository source, K41 runtime, and host integration.
set -Eeuo pipefail
umask 077
export GIT_OPTIONAL_LOCKS=0

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
have() { command -v "$1" >/dev/null 2>&1; }

(( EUID != 0 )) || die 'Jalankan sebagai user desktop biasa, tanpa sudo.'
[[ -n ${HOME:-} && $HOME == /* && -d $HOME ]] || die 'HOME tidak valid.'
for cmd in git python3 date mkdir stat chmod mktemp; do
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
report_root="$state_root/k41/bottombar/audits"
for path in "$HOME/.local" "$state_root" "$state_root/k41" "$state_root/k41/bottombar" "$report_root"; do
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
report="$run_dir/bottombar-audit.txt"
( set -o noclobber; : > "$report" ) 2>/dev/null || die 'Tidak dapat membuat report.'
chmod 0600 "$report"

export K41_AUDIT_HOME="$HOME"
export K41_AUDIT_REPO="$repo_root"
export K41_AUDIT_REPORT="$report"
export K41_AUDIT_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"

python3 <<'PY'
import hashlib, json, os, pathlib, pwd, re, shutil, stat, subprocess
from datetime import datetime, timezone

home = pathlib.Path(os.environ["K41_AUDIT_HOME"]).resolve()
repo = pathlib.Path(os.environ["K41_AUDIT_REPO"]).resolve()
report = pathlib.Path(os.environ["K41_AUDIT_REPORT"])
config_home = pathlib.Path(os.environ["K41_AUDIT_CONFIG"])
out = []

def add(value=""): out.append(str(value))
def section(title):
    add(); add("=" * 88); add(title); add("=" * 88)
def clean(value):
    text = str(value)
    if str(home) != "/": text = text.replace(str(home), "~")
    try:
        username = pwd.getpwuid(os.getuid()).pw_name
        if username:
            text = re.sub(r"(?<![A-Za-z0-9_.-])" + re.escape(username) + r"(?![A-Za-z0-9_.-])", "<USER>", text)
    except KeyError: pass
    text = re.sub(r"(?i)\b(password|passwd|token|secret|authorization|cookie|api[_-]?key)\b([=: ]+)[^\s,;]+", r"\1\2<REDACTED>", text)
    return text
def run(args, timeout=10, cwd=None):
    try:
        p = subprocess.run(args, cwd=cwd, text=True, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, timeout=timeout, check=False)
        return p.returncode, clean(p.stdout.strip())
    except (OSError, subprocess.TimeoutExpired) as exc:
        return 127, type(exc).__name__
def sha(raw): return hashlib.sha256(raw).hexdigest()
def file_sha(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""): h.update(block)
    return h.hexdigest()
def safe_file(path, limit=1024 * 1024):
    try: return not path.is_symlink() and path.is_file() and path.stat().st_size <= limit
    except OSError: return False
def emit_file(path, label=None, limit=256 * 1024):
    try:
        raw = path.read_bytes()
        name = label or clean(path)
        add(f"--- BEGIN FILE {name} | bytes={len(raw)} | sha256={sha(raw)} ---")
        if b"\0" in raw: add("<BINARY CONTENT OMITTED>")
        else:
            add(clean(raw[:limit].decode("utf-8", "replace").rstrip()))
            if len(raw) > limit: add(f"<TRUNCATED after {limit} bytes>")
        add(f"--- END FILE {name} ---")
    except OSError as exc: add(f"<READ ERROR {clean(path)}: {type(exc).__name__}>")
def walk(root, suffixes=None):
    if root.is_symlink() or not root.is_dir(): return
    for base, dirs, names in os.walk(root, followlinks=False):
        dirs[:] = sorted(d for d in dirs if d not in {".git", "node_modules", "build", ".cache", "__pycache__"})
        for name in sorted(names):
            p = pathlib.Path(base) / name
            if p.is_symlink() or not p.is_file(): continue
            if suffixes is None or p.suffix.lower() in suffixes or name == "qmldir":
                yield p
def describe(path):
    if path.is_symlink(): return "SYMLINK_BLOCKED"
    if not path.exists(): return "MISSING"
    if not path.is_file() and not path.is_dir(): return "UNSUPPORTED_TYPE"
    st = path.stat()
    kind = "DIR" if path.is_dir() else "FILE"
    digest = f" | sha256={file_sha(path)}" if path.is_file() else ""
    return f"{kind} | mode={stat.S_IMODE(st.st_mode):04o} | uid={st.st_uid} | bytes={st.st_size if path.is_file() else '-'}{digest}"

workstream = repo / "stages/stage-5-desktop-customization/workstreams/03-bottombar"
canonical_source = workstream / "modules/bottombar/Dock.Qml"
legacy_source = repo / "stages/stage-5-desktop-customization/workstreams/04-taskbar-panel/config/quickshell/caelestia/modules/k41dock/K41Dock.qml"
implementer = workstream / "scripts/k41-implement-bottombar.sh"
audit_script = workstream / "scripts/k41-audit-bottombar.sh"
tests = repo / "stages/stage-5-desktop-customization/tests"
xdg_config = config_home
home_config = home / ".config"

# Explicit K41 module roots and host roots. Duplicate physical roots are reported once.
k41_roots = [
    ("K41_XDG_CONFIG", xdg_config / "quickshell/k41"),
    ("K41_HOME_CONFIG", home_config / "quickshell/k41"),
    ("K41_SYSTEM_XDG", pathlib.Path("/etc/xdg/quickshell/k41")),
    ("K41_SYSTEM_SHARE", pathlib.Path("/usr/share/quickshell/k41")),
]
host_roots = [
    ("CAELESTIA_XDG_CONFIG", xdg_config / "quickshell/caelestia"),
    ("CAELESTIA_HOME_CONFIG", home_config / "quickshell/caelestia"),
    ("CAELESTIA_SYSTEM_XDG", pathlib.Path("/etc/xdg/quickshell/caelestia")),
    ("CAELESTIA_SYSTEM_SHARE", pathlib.Path("/usr/share/quickshell/caelestia")),
]
seen = set()
def unique_roots(entries):
    result = []
    for label, path in entries:
        try: key = str(path.resolve(strict=False))
        except OSError: key = str(path)
        if key in seen: continue
        seen.add(key); result.append((label, path))
    return result
k41_roots = unique_roots(k41_roots)
host_roots = unique_roots(host_roots)

section("AUDIT IDENTITY, SCOPE AND SAFETY")
add("Purpose: establish implementation inputs for K41 Bottombar module deployment.")
add("Mode: read-only. No runtime/config/package/service/source/Git mutations are performed.")
add("Private report: ~/.local/state/k41/bottombar/audits/<timestamp>/bottombar-audit.txt")
add("Publication: sanitized copy via a fresh independent clone; active checkout Git metadata is not used.")
add("Captured UTC: " + datetime.now(timezone.utc).isoformat())
add("Host label: <HOST-REDACTED> | kernel: " + os.uname().release)
add("UID/GID: <LOCAL-IDENTITY-REDACTED>")
add("Repository: " + clean(repo))
for args, title in [
    (["git", "-C", str(repo), "rev-parse", "HEAD"], "HEAD"),
    (["git", "-C", str(repo), "branch", "--show-current"], "branch"),
    (["git", "-C", str(repo), "status", "--short", "--branch"], "status"),
    (["git", "-C", str(repo), "diff", "--quiet"], "tracked worktree"),
    (["git", "-C", str(repo), "diff", "--cached", "--quiet"], "index"),
]:
    rc, value = run(args)
    if title in ("tracked worktree", "index"):
        value = "CLEAN" if rc == 0 else "MODIFIED" if rc == 1 else "UNKNOWN"
    add(f"Repository {title}: {value or ('clean' if rc == 0 else 'UNKNOWN')}")

section("CANONICAL REPOSITORY SOURCE AND LEGACY SOURCE")
for label, path in (("CANONICAL MODULE SOURCE", canonical_source), ("LEGACY MODULE SOURCE", legacy_source),
                    ("IMPLEMENTATION SCRIPT", implementer), ("AUDIT SCRIPT", audit_script)):
    add(f"{label}: {clean(path.relative_to(repo))} | {describe(path)}")
    if path.is_file() and not path.is_symlink():
        emit_file(path, label, 192 * 1024 if path == canonical_source else 256 * 1024)
if canonical_source.is_file() and not canonical_source.is_symlink():
    qml = canonical_source.read_text(encoding="utf-8", errors="replace")
    imports = re.findall(r'(?m)^\s*import\s+([^\n]+)', qml)
    add("Canonical QML imports: " + ("; ".join(imports) if imports else "NONE"))
    rel_imports = re.findall(r'(?m)^\s*import\s+"([^"]+)"', qml)
    for rel in rel_imports:
        candidate = canonical_source.parent / rel
        add(f"Canonical relative import {rel}: {describe(candidate)}")
else:
    add("BLOCKER: canonical module source missing, symlinked, or not a regular file.")

section("K41 RUNTIME NAMESPACE — REQUIRED DEPLOYMENT TARGET")
for label, root in k41_roots:
    add(f"{label}: {clean(root)} | {describe(root)}")
    for rel in ("shell.qml", "qmldir", "modules/qmldir", "modules"):
        entry = root / rel
        add(f"  K41 entry {rel}: {clean(entry)} | {describe(entry)}")
        if rel == "shell.qml" and safe_file(entry):
            lines = entry.read_text(encoding="utf-8", errors="replace").splitlines()
            for i, line in enumerate(lines, 1):
                if re.search(r"import\\s+|bottombar|Dock\\.Qml|ShellRoot\\s*\\{", line, re.I):
                    add(f"    {i}: {clean(line[:500])}")
    target = root / "modules/bottombar/Dock.Qml"
    add(f"  Bottombar target: {clean(target)} | {describe(target)}")
    module_dir = root / "modules/bottombar"
    if module_dir.is_dir() and not module_dir.is_symlink():
        for p in walk(module_dir):
            add(f"  Existing module file: {clean(p.relative_to(root))} | {describe(p)}")
            if p.suffix.lower() in {".qml", ".js", ".mjs"}: emit_file(p, f"{label} {p.relative_to(root)}", 128 * 1024)
    elif module_dir.is_symlink():
        add("  BLOCKER: K41 bottombar module directory is a symlink.")

section("QUICKSHELL HOST RUNTIMES AND ENTRY-POINT DISCOVERY")
available_hosts = []
for label, root in host_roots:
    add(f"{label}: {clean(root)} | {describe(root)}")
    if root.is_symlink() or not root.is_dir(): continue
    available_hosts.append((label, root))
    for rel in ("shell.qml", "modules/k41dock/K41Dock.qml", "modules/bottombar/Dock.Qml",
                "modules/bar/Bar.qml", "shell.json"):
        p = root / rel
        add(f"  {rel}: {describe(p)}")
    shell = root / "shell.qml"
    if safe_file(shell):
        lines = shell.read_text(encoding="utf-8", errors="replace").splitlines()
        hits = [(i, line) for i, line in enumerate(lines, 1)
                if re.search(r"import\s+|k41|bottombar|dock|ShellRoot\s*\{|Bar\s*\{", line, re.I)]
        add(f"  ENTRY POINT {clean(shell)}")
        for i, line in hits[:160]: add(f"    {i}: {clean(line[:500])}")
    git_dir = root / ".git"
    if git_dir.exists():
        for args, title in [
            (["git", "-C", str(root), "remote", "get-url", "origin"], "origin"),
            (["git", "-C", str(root), "rev-parse", "HEAD"], "HEAD"),
            (["git", "-C", str(root), "status", "--short"], "working tree"),
        ]:
            rc, value = run(args)
            add(f"  Host Git {title}: {value if value else ('clean' if rc == 0 else 'unavailable')}")
    else: add("  Host Git metadata: absent")

section("QUICKSHELL CONFIGURATION ROOTS AND ACTIVE PROCESS")
for label, root in (("XDG_CONFIG_HOME", xdg_config), ("HOME_CONFIG", home_config),
                    ("SYSTEM_XDG", pathlib.Path("/etc/xdg"))):
    qs_root = root / "quickshell"
    add(f"{label} Quickshell root: {clean(qs_root)} | {describe(qs_root)}")
    if qs_root.is_dir() and not qs_root.is_symlink():
        try:
            names = sorted(p.name for p in qs_root.iterdir() if p.is_dir() and not p.is_symlink())
            add("  Named configurations: " + (", ".join(names[:100]) if names else "NONE"))
        except OSError as exc: add(f"  Directory listing failed: {type(exc).__name__}")
# Process command lines can establish which named configuration is active; do not read process environments.
processes = []
for proc in pathlib.Path("/proc").glob("[0-9]*"):
    try:
        cmdline = (proc / "cmdline").read_bytes().replace(b"\0", b" ").decode("utf-8", "replace").strip()
        if cmdline and re.search(r"(^|/)(qs|quickshell)(\s|$)", cmdline):
            processes.append((proc.name, cmdline))
    except (OSError, PermissionError): pass
if processes:
    for pid, cmdline in processes[:30]: add(f"Quickshell process pid={pid}: {clean(cmdline[:1200])}")
else: add("Quickshell process: NOT_OBSERVED (not proof that Quickshell is not installed)")

section("K41 HOST INTEGRATION AND MODULE REFERENCE SCAN")
reference_count = 0
for label, root in available_hosts:
    for p in walk(root, {".qml", ".js", ".mjs"}):
        try: text = p.read_text(encoding="utf-8", errors="replace")
        except OSError: continue
        matches = [(i, line.strip()) for i, line in enumerate(text.splitlines(), 1)
                   if re.search(r"k41|bottombar|Dock\.Qml|K41Dock|modules/k41", line, re.I)]
        if matches:
            reference_count += len(matches)
            add(f"Host reference file: {label}:{clean(p.relative_to(root))}")
            for i, line in matches[:80]: add(f"  {i}: {clean(line[:500])}")
if reference_count == 0: add("No K41/Bottombar references found in scanned host QML/JS files.")
add("Important: a file in ~/.config/quickshell/k41 is not automatically loaded merely because it exists.")
add("The host must import/reference the module, or Quickshell must be explicitly launched with a configuration that loads it.")
add("This audit observes current references; it does not modify host entry points.")

section("CAELESTIA JSON CONFIGURATION")
config_candidates = [
    ("XDG Caelestia config", xdg_config / "caelestia/shell.json"),
    ("HOME Caelestia config", home_config / "caelestia/shell.json"),
]
for label, path in config_candidates:
    add(f"{label}: {clean(path)} | {describe(path)}")
    if safe_file(path):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            bar = data.get("bar") if isinstance(data, dict) else None
            if isinstance(bar, dict):
                add("  bar keys: " + ", ".join(sorted(map(str, bar.keys()))))
                entries = bar.get("entries")
                if isinstance(entries, list):
                    for i, item in enumerate(entries):
                        if isinstance(item, dict):
                            allowed = {k: item.get(k) for k in ("id", "name", "enabled", "type") if k in item}
                            add(f"  bar.entries[{i}]: {json.dumps(allowed, ensure_ascii=False, sort_keys=True)}")
                else: add("  bar.entries: MISSING_OR_INVALID")
            else: add("  bar object: MISSING_OR_INVALID")
        except (OSError, ValueError) as exc: add(f"  JSON parse: FAILED ({type(exc).__name__})")

section("DEPENDENCY, VERSION, PACKAGE AND VALIDATION TOOL EVIDENCE")
for binary in ("qs", "quickshell", "caelestia", "hyprctl", "qmllint", "qmlformat", "shellcheck"):
    path = shutil.which(binary)
    add(f"{binary}: {clean(path) if path else 'NOT_FOUND'}")
    if path and binary in ("qs", "quickshell", "caelestia", "hyprctl"):
        rc, value = run([path, "--version"], timeout=8)
        add(f"  --version exit={rc}: {value[:1800]}")
for package in ("quickshell", "quickshell-git", "caelestia-shell", "hyprland", "qt6-base", "qt6-declarative"):
    rc, value = run(["pacman", "-Qi", package], timeout=8)
    if rc == 0:
        keep = ("Name", "Version", "Description", "Architecture", "URL", "Packager", "Build Date", "Install Date")
        add(f"[{package}]")
        add("\n".join(line for line in value.splitlines() if any(line.startswith(k + " :") for k in keep)))
    else: add(f"{package}: NOT_INSTALLED_OR_PACMAN_UNAVAILABLE")
for args, title in ((["qs", "--help"], "qs --help"), ("[", "placeholder")):
    if title == "placeholder": continue
    rc, value = run(args, timeout=8)
    add(f"{title} exit={rc}: {value[:5000]}")

section("TESTS, IMPLEMENTATION SCRIPT AND WORKSTREAM INVENTORY")
for path in (tests / "test-bottombar-module-install.sh", tests / "run.sh",
             workstream / "scripts/k41-implement-bottombar.sh",
             workstream / "docs/README.md",
             repo / "stages/stage-5-desktop-customization/docs/03-BOTTOMBAR.md"):
    add(f"{clean(path.relative_to(repo))}: {describe(path)}")
    if safe_file(path): emit_file(path, str(path.relative_to(repo)), 128 * 1024)
for relative in ("modules", "scripts", "tests", "docs"):
    root = workstream / relative
    if root.is_dir() and not root.is_symlink():
        for p in walk(root):
            add(f"Workstream inventory: {clean(p.relative_to(repo))} | bytes={p.stat().st_size} | sha256={file_sha(p)}")

section("IMPLEMENTATION HANDOFF — FACTS, BLOCKERS AND UNKNOWNs")
blockers = []
if not safe_file(canonical_source): blockers.append("Canonical source is missing/unsafe.")
if not safe_file(implementer): blockers.append("Implementation script is missing/unsafe.")
target_seen = False
for label, root in k41_roots:
    target = root / "modules/bottombar/Dock.Qml"
    if root.is_dir() and not root.is_symlink():
        target_seen = True
        if target.is_symlink(): blockers.append(f"{label} target is a symlink.")
        elif target.exists() and not target.is_file(): blockers.append(f"{label} target is not a regular file.")
if not target_seen: add("No K41 runtime root currently exists; installer must explicitly create the user-level root after validating its parent.")
if reference_count == 0:
    add("HOST INTEGRATION STATUS: no current host reference detected. Module copy alone will not make Bottombar active.")
else:
    add(f"HOST INTEGRATION STATUS: {reference_count} matching reference line(s) observed; review exact import/type contract above.")
for item in blockers: add("BLOCKER: " + item)
if not blockers: add("Static filesystem preflight blockers: none detected by this audit.")
add("Readiness is not implied: verify target path ownership/permissions and decide host import/loading contract before deployment.")
add("This audit does not run QML compilation, mutate runtime files, reload Quickshell, or test visual/workspace behavior.")
add("Report contains local observations, not upstream compatibility guarantees.")
add("Private local report: " + clean(report))
report.write_text("\n".join(out) + "\n", encoding="utf-8")
print(f"Bottombar audit report created: {report}")
print(f"Report size: {report.stat().st_size} bytes")
PY

[[ -s "$report" ]] || die 'Audit tidak menghasilkan report valid.'

published_report="$run_dir/published-report.txt"
python3 - "$report" "$published_report" <<'PY'
from pathlib import Path
import os, pwd, re, sys
source, destination = map(Path, sys.argv[1:3])
text = source.read_bytes().decode("utf-8", errors="replace")
home = os.environ.get("HOME", "")
repo = os.environ.get("K41_AUDIT_REPO", "")
if home and home != "/": text = text.replace(home, "<HOME>")
if repo: text = text.replace(repo, "<REPOSITORY_CHECKOUT>")
try:
    username = pwd.getpwuid(os.getuid()).pw_name
    if username: text = re.sub(r"(?<![A-Za-z0-9_.-])" + re.escape(username) + r"(?![A-Za-z0-9_.-])", "<USER>", text)
except KeyError: pass
text = re.sub(r"(?m)^Host label:.*$", "Host label: <HOST-REDACTED>", text)
text = re.sub(r"(?m)^UID/GID:.*$", "UID/GID: <LOCAL-IDENTITY-REDACTED>", text)
text = re.sub(r"\b(uid|gid)=\d+\b", r"\1=<REDACTED>", text)
text = re.sub(r"(?i)(https?://)[^/@\s]+@", r"\1<REDACTED>@", text)
text = re.sub(r"(?i)\b(password|passwd|token|secret|authorization|cookie|api[_-]?key)\b([=: ]+)[^\s,;]+", r"\1\2<REDACTED>", text)
text = re.sub(r"(?i)(\bSSID\s*[:=]\s*)(?:'[^']*'|\"[^\"]*\"|[^\s,;)]+)", r"\1<SSID-REDACTED>", text)
text = re.sub(r"\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b", "<IP-REDACTED>", text)
text = re.sub(r"\b(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}\b", "<MAC-REDACTED>", text)
text = "".join(ch for ch in text if ch in "\n\r\t" or ord(ch) >= 32)
destination.write_text(text, encoding="utf-8")
if destination.stat().st_size == 0: raise SystemExit("ERROR: sanitized report is empty")
print(f"Sanitized publication copy: PASS ({destination.stat().st_size} bytes)")
PY
chmod 0600 "$published_report"

cat >"$run_dir/README.txt" <<EOF
K41 Bottombar audit
===================
Run from the repository checkout on branch main as the regular desktop user:

  bash stages/stage-5-desktop-customization/workstreams/03-bottombar/scripts/k41-audit-bottombar.sh

The collector is read-only with respect to runtime configuration, packages,
services, source files, and the active Git checkout. Full evidence remains
private under ~/.local/state/k41/bottombar/audits/.
A sanitized report is published through a fresh independent clone to:

  reports/stage-5-desktop-customization/03-bottombar/audits/<timestamp>/

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
    publish_tmp="$(mktemp -d "${TMPDIR:-/tmp}/k41-bottombar-audit-publish.XXXXXX")" || return 1
    publish_dir="$publish_tmp/repository"
    if ! GIT_TERMINAL_PROMPT=0 git clone --quiet --no-tags --single-branch --branch main "$remote_url" "$publish_dir"; then
        rm -rf -- "$publish_tmp"
        printf 'ERROR: isolated clone gagal; report privat tetap tersedia.\n' >&2
        return 1
    fi
    relative_dir="reports/stage-5-desktop-customization/03-bottombar/audits/${run_dir##*/}"
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
       ! git -C "$publish_dir" config user.name "K41 Bottombar Audit" ||
       ! git -C "$publish_dir" config user.email "k41-bottombar-audit@users.noreply.github.com"; then
        rm -rf -- "$publish_tmp"
        printf 'ERROR: persiapan clone gagal; report privat tetap tersedia.\n' >&2
        return 1
    fi
    if ! git -C "$publish_dir" add -- "$relative_dir" ||
       ! git -C "$publish_dir" commit -m "Add K41 Bottombar runtime audit"; then
        rm -rf -- "$publish_tmp"
        printf 'ERROR: commit report gagal; report privat tetap tersedia.\n' >&2
        return 1
    fi
    if ! GIT_TERMINAL_PROMPT=0 git -C "$publish_dir" push origin HEAD:main; then
        printf 'INFO: main berubah saat push; mencoba rebase satu kali pada clone terisolasi.\n'
        if ! GIT_TERMINAL_PROMPT=0 git -C "$publish_dir" fetch --no-tags origin main ||
           ! git -C "$publish_dir" rebase FETCH_HEAD ||
           ! GIT_TERMINAL_PROMPT=0 git -C "$publish_dir" push origin HEAD:main; then
            rm -rf -- "$publish_tmp"
            printf 'ERROR: publikasi gagal; report privat: %s\n' "$report" >&2
            return 1
        fi
    fi
    rm -rf -- "$publish_tmp"
    printf 'INFO: sanitized report published: %s\n' "$relative_dir"
    printf 'INFO: active checkout Git metadata was not used.\n'
}

printf 'Private audit report: %s\n' "$report"
if publish_report; then
    printf 'Automated publication succeeded.\n'
else
    printf 'WARNING: publication failed; private report retained locally.\n' >&2
    exit 1
fi
printf 'Runtime and active checkout state were not modified.\n'
