#!/usr/bin/env bash
# Read-only Bottombar audit. Report data is kept outside the Git checkout.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
have() { command -v "$1" >/dev/null 2>&1; }

(( EUID != 0 )) || die 'Jalankan sebagai user desktop biasa, tanpa sudo.'
[[ -n ${HOME:-} && $HOME == /* && -d $HOME ]] || die 'HOME tidak valid.'
for cmd in git python3 date mkdir stat chmod; do
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

# Reports are private and deliberately outside the checkout. This avoids
# untracked-file collisions when the user later pulls or switches branches.
state_root="${XDG_STATE_HOME:-$HOME/.local/state}"
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
(( (8#$report_mode & 8#077) == 0 )) || die "Report directory permissions are too broad: $report_mode (expected private 0700)."
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
import difflib, hashlib, json, os, pathlib, pwd, re, shutil, stat, subprocess
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
    if str(home) != "/":
        text = text.replace(str(home), "~")
    try:
        username = pwd.getpwuid(os.getuid()).pw_name
        text = re.sub(r"(?<![A-Za-z0-9_.-])" + re.escape(username) + r"(?![A-Za-z0-9_.-])", "<USER>", text)
    except KeyError:
        pass
    text = re.sub(r"(?i)\b(password|passwd|token|secret|authorization|cookie|api[_-]?key)\b([=: ]+)[^\s,;]+", r"\1\2<REDACTED>", text)
    return text
def run(args, timeout=12, cwd=None):
    try:
        p = subprocess.run(args, cwd=cwd, text=True, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, timeout=timeout, check=False)
        return p.returncode, clean(p.stdout.strip())
    except (OSError, subprocess.TimeoutExpired) as exc:
        return 127, type(exc).__name__
def sha_bytes(raw): return hashlib.sha256(raw).hexdigest()
def sha_file(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()
def safe_file(path):
    try:
        return not path.is_symlink() and path.is_file() and path.stat().st_size <= 512 * 1024
    except OSError:
        return False
def emit_file(path, label=None, limit=512 * 1024):
    try:
        raw = path.read_bytes()
        name = label or clean(path)
        add(f"--- BEGIN FILE {name} | bytes={len(raw)} | sha256={sha_bytes(raw)} ---")
        if b"\0" in raw:
            add("<BINARY CONTENT OMITTED>")
        else:
            text = raw[:limit].decode("utf-8", "replace")
            add(clean(text.rstrip()))
            if len(raw) > limit: add(f"<TRUNCATED after {limit} bytes>")
        add(f"--- END FILE {name} ---")
    except OSError as exc:
        add(f"<READ ERROR {clean(path)}: {type(exc).__name__}>")
def walk(root, suffixes=None):
    if not root.is_dir() or root.is_symlink(): return
    for base, dirs, names in os.walk(root, followlinks=False):
        dirs[:] = sorted(d for d in dirs if d not in {".git", "node_modules", "build", ".cache", "__pycache__"})
        for name in sorted(names):
            path = pathlib.Path(base) / name
            if path.is_symlink() or not path.is_file(): continue
            if suffixes is None or path.suffix.lower() in suffixes or name == "qmldir":
                yield path

source_root = repo / "stages/stage-5-desktop-customization/workstreams/04-taskbar-panel"
source_qml = source_root / "config/quickshell/caelestia/modules/k41dock/K41Dock.qml"
installer = repo / "stages/stage-5-desktop-customization/scripts/k41-install-caelestia-dock.sh"
runtime_roots = [
    ("XDG_CONFIG", config_home / "quickshell/caelestia"),
    ("HOME_CONFIG", home / ".config/quickshell/caelestia"),
    ("SYSTEM_XDG", pathlib.Path("/etc/xdg/quickshell/caelestia")),
    ("SYSTEM_SHARE", pathlib.Path("/usr/share/quickshell/caelestia")),
]
config_files = [
    config_home / "caelestia/shell.json",
    home / ".config/caelestia/shell.json",
]
shell_files = []

section("PURPOSE, SCOPE AND SAFETY")
add("Goal: collect implementation inputs for Workstream 03 Bottombar/K41Dock.")
add("Mode: read-only audit; no runtime/config/package/service/source/Git mutations.")
add("Report location is outside the checkout under ~/.local/state/k41/bottombar/audits/.")
add("No Git fetch, checkout, reset, clean, stash, add, commit, push or index operation is performed.")
add("Captured UTC: " + datetime.now(timezone.utc).isoformat())
add("Host label: " + clean(os.uname().nodename) + " | kernel: " + os.uname().release)
add("UID/GID: " + str(os.getuid()) + "/" + str(os.getgid()))
add("Repository: " + clean(repo))
rc, value = run(["git", "-C", str(repo), "rev-parse", "HEAD"])
add("Repository HEAD: " + (value if rc == 0 else "UNKNOWN"))
rc, value = run(["git", "-C", str(repo), "status", "--short", "--branch"])
add("Repository status before/at audit: " + (value or ("clean" if rc == 0 else "UNKNOWN")))
rc, value = run(["git", "-C", str(repo), "diff", "--quiet"])
add("Tracked worktree diff: " + ("CLEAN" if rc == 0 else "MODIFIED" if rc == 1 else "UNKNOWN"))
rc, value = run(["git", "-C", str(repo), "diff", "--cached", "--quiet"])
add("Index diff: " + ("CLEAN" if rc == 0 else "MODIFIED" if rc == 1 else "UNKNOWN"))

section("REPOSITORY SOURCE INVENTORY")
if source_root.is_dir() and not source_root.is_symlink():
    files = list(walk(source_root))
    add(f"Legacy source directory: PRESENT | files={len(files)}")
    for path in files:
        add(f"{clean(path.relative_to(repo))} | bytes={path.stat().st_size} | sha256={sha_file(path)}")
else:
    add("Legacy source directory: MISSING_OR_UNSAFE")
if source_qml.is_file() and not source_qml.is_symlink():
    emit_file(source_qml, "LEGACY K41Dock.qml")
else:
    add("BLOCKER: canonical historical K41Dock.qml is missing or symlinked.")

section("RUNTIME CAELESTIA ROOTS AND PROVENANCE")
available_roots = []
seen = set()
for label, root in runtime_roots:
    try: identity = str(root.resolve())
    except OSError: identity = str(root)
    if identity in seen: continue
    seen.add(identity)
    if root.is_symlink():
        add(f"{label}: BLOCKED_SYMLINK {clean(root)}")
        continue
    if not root.is_dir():
        add(f"{label}: NOT_PRESENT {clean(root)}")
        continue
    available_roots.append((label, root))
    add(f"{label}: PRESENT {clean(root)}")
    for relative in ("shell.qml", "modules/k41dock/K41Dock.qml", "modules/bar/Bar.qml"):
        p = root / relative
        if p.is_symlink(): add(f"  {relative}: SYMLINK")
        elif p.is_file():
            st = p.stat()
            add(f"  {relative}: FILE | bytes={st.st_size} | mode={stat.S_IMODE(st.st_mode):04o} | uid={st.st_uid} | sha256={sha_file(p)}")
        else: add(f"  {relative}: MISSING")
    if (root / ".git").exists():
        for args, title in [
            (["git", "-C", str(root), "remote", "get-url", "origin"], "origin"),
            (["git", "-C", str(root), "rev-parse", "HEAD"], "HEAD"),
            (["git", "-C", str(root), "status", "--short"], "working tree"),
        ]:
            rc, value = run(args)
            add(f"  Git {title}: {value if value else ('clean' if rc == 0 else 'unavailable')}")
    else:
        add("  Git metadata: absent (possibly package-managed or exported tree)")

section("ACTIVE SHELL ENTRY POINTS AND CONFIGURATION")
for label, root in available_roots:
    shell = root / "shell.qml"
    if shell.is_file() and not shell.is_symlink():
        shell_files.append((label, shell))
        text = shell.read_text(encoding="utf-8", errors="replace")
        lines = text.splitlines()
        matches = [(i, line) for i, line in enumerate(lines, 1)
                   if re.search(r"k41dock|K41Dock|modules/bar|Bar\s*\{|import\s+", line, re.I)]
        add(f"{label} shell.qml: {clean(shell)} | bytes={shell.stat().st_size} | sha256={sha_file(shell)}")
        for i, line in matches[:100]:
            add(f"  {i}: {clean(line[:500])}")
    else:
        add(f"{label} shell.qml: MISSING_OR_UNSAFE")
for cfg in config_files:
    if cfg.is_symlink():
        add(f"CONFIG {clean(cfg)}: SYMLINK_BLOCKED")
    elif cfg.is_file():
        add(f"CONFIG {clean(cfg)} | bytes={cfg.stat().st_size} | sha256={sha_file(cfg)}")
        try:
            data = json.loads(cfg.read_text(encoding="utf-8"))
            bar = data.get("bar") if isinstance(data, dict) else None
            if isinstance(bar, dict):
                add("  bar keys: " + ", ".join(sorted(map(str, bar.keys()))))
                entries = bar.get("entries")
                if isinstance(entries, list):
                    for i, item in enumerate(entries):
                        if isinstance(item, dict):
                            # Values are restricted to non-secret bar metadata.
                            allowed = {k: item.get(k) for k in ("id", "name", "enabled", "type") if k in item}
                            add(f"  bar.entries[{i}]: {json.dumps(allowed, ensure_ascii=False, sort_keys=True)}")
                else: add("  bar.entries: MISSING_OR_UNEXPECTED_TYPE")
            else: add("  bar object: MISSING_OR_UNEXPECTED_TYPE")
        except (OSError, ValueError) as exc:
            add(f"  JSON parse: FAILED ({type(exc).__name__})")
    else:
        add(f"CONFIG {clean(cfg)}: NOT_PRESENT")

section("LEGACY INSTALLER SOURCE AND BEHAVIOR")
if safe_file(installer):
    emit_file(installer, "HISTORICAL INSTALLER", 256 * 1024)
else:
    add("Historical installer missing, unsafe, or larger than the audit bound.")
if installer.is_file() and not installer.is_symlink():
    content = installer.read_text(encoding="utf-8", errors="replace")
    for token in ("--check", "--install", "--rollback", "backup", "manifest", "shell.qml", "shell.json", "sudo", "quickshell"):
        add(f"Installer marker {token!r}: {'PRESENT' if token in content else 'ABSENT'}")

section("LOCAL QML DEPENDENCY AND INTEGRATION SCAN")
qml_files = []
for label, root in available_roots:
    for path in walk(root, {".qml", ".js", ".mjs"}):
        qml_files.append((label, path))
for label, root in available_roots:
    qml_dir = root / "modules/k41dock"
    if qml_dir.is_dir() and not qml_dir.is_symlink():
        for path in walk(qml_dir):
            emit_file(path, f"RUNTIME {label}: {path.relative_to(root)}", 128 * 1024)
if source_qml.is_file() and not source_qml.is_symlink():
    text = source_qml.read_text(encoding="utf-8", errors="replace")
    for number, line in enumerate(text.splitlines(), 1):
        if re.search(r"^\s*import\s+|PanelWindow|WlrLayershell|Hyprland|Hypr\.|Screens\.|Variants|ScriptModel|Loader|QtObject|Timer|Region|HoverHandler|MouseArea|exclusiveZone", line):
            add(f"QML API {number}: {line.strip()[:400]}")
    imports = re.findall(r'(?m)^\s*import\s+([^\n]+)', text)
    add("Direct QML imports: " + ("; ".join(imports) if imports else "NONE FOUND"))
    for rel in re.findall(r'(?m)^\s*import\s+"([^"]+)"', text):
        target = (source_qml.parent / rel).resolve()
        add(f"Relative import {rel}: {'PRESENT' if target.exists() else 'MISSING'} ({clean(target)})")
    type_names = sorted(set(re.findall(r'(?m)^\s*([A-Z][A-Za-z0-9_]*)\s*\{', text)))
    add("Potential instantiated QML types: " + ", ".join(type_names))
else:
    add("Cannot analyze QML imports/API: source file unavailable.")

section("VERSION, PACKAGE AND TOOL EVIDENCE")
for binary in ("qs", "quickshell", "caelestia", "hyprctl"):
    path = shutil.which(binary)
    if not path:
        add(f"{binary}: NOT FOUND")
        continue
    add(f"{binary}: {clean(path)}")
    if binary in ("qs", "quickshell", "caelestia"):
        rc, value = run([path, "--version"], timeout=8)
        add(f"  --version exit={rc}: {value[:2000]}")
for package in ("quickshell", "quickshell-git", "caelestia-shell", "hyprland", "qt6-base", "qt6-declarative"):
    rc, value = run(["pacman", "-Qi", package], timeout=8)
    if rc == 0:
        keep = ("Name", "Version", "Description", "Architecture", "URL", "Packager", "Build Date", "Install Date")
        add(f"[{package}]")
        add("\n".join(line for line in value.splitlines() if any(line.startswith(k + " :") for k in keep)))
    else:
        add(f"{package}: NOT_INSTALLED_OR_PACMAN_UNAVAILABLE")
for binary in ("qmllint", "qmlformat", "shellcheck"):
    add(f"{binary}: {shutil.which(binary) or 'NOT_FOUND'}")

section("TEST, DOCUMENTATION AND RELATED IMPLEMENTATION INVENTORY")
for relative in (
    "tests", "stages/stage-5-desktop-customization/tests",
    "stages/stage-5-desktop-customization/workstreams/03-bottombar",
    "stages/stage-5-desktop-customization/workstreams/04-taskbar-panel",
):
    root = repo / relative
    if root.is_dir() and not root.is_symlink():
        add(f"{relative}:")
        for path in walk(root):
            add(f"  {clean(path.relative_to(repo))} | bytes={path.stat().st_size} | sha256={sha_file(path)}")
    else:
        add(f"{relative}: NOT_PRESENT")
for relative in (
    "stages/stage-5-desktop-customization/docs/03-BOTTOMBAR.md",
    "stages/stage-5-desktop-customization/docs/03-BOTTOMBAR-IMPLEMENTATION.md",
):
    p = repo / relative
    if safe_file(p): emit_file(p, relative, 96 * 1024)

section("IMPLEMENTATION HANDOFF SUMMARY")
add("This report is evidence for designing the separate audit/implementation/cleanup workflow.")
add("It does not decide the target runtime namespace, host-loading contract, or whether Caelestia bar config should be changed.")
add("The QML scan is static and heuristic; it is not a Qt/QML linker or runtime compatibility proof.")
add("Package metadata and executable --version output are observations from this machine, not upstream compatibility guarantees.")
add("No QML compile, shell reload, workspace interaction, multi-monitor, fullscreen, or resource benchmark was executed.")
add("Review this private report before sharing: source excerpts and host/package metadata may be sensitive.")
add("No Git write command was invoked; report is outside the checkout and cannot create an untracked file in the repository.")
add("Report: " + clean(report))
report.write_text("\n".join(out) + "\n", encoding="utf-8")
print(f"Bottombar audit report created: {report}")
print(f"Report size: {report.stat().st_size} bytes")
PY

[[ -s "$report" ]] || die 'Audit tidak menghasilkan report valid.'
printf '\nAudit selesai: %s\n' "$report"
printf 'Mode: read-only; report privat berada di luar Git checkout.\n'
printf 'Review/redaksi report sebelum dibagikan.\n'
