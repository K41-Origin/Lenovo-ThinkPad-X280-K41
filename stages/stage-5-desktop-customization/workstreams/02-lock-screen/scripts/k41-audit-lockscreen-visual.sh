#!/usr/bin/env bash
# Appearance-only, read-only audit for the approved K41 Lock Screen design.
# Authentication, PAM, password handling and session policy are out of scope.
set -Eeuo pipefail
umask 077
die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
for cmd in git python3 date mkdir stat; do command -v "$cmd" >/dev/null 2>&1 || die "Missing command: $cmd"; done
(( EUID != 0 )) || die 'Run as the regular desktop user, without sudo.'
[[ -n ${HOME:-} && -d $HOME ]] || die 'HOME is invalid.'
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)" || die 'Run from a Git checkout.'
repo_root="$(cd -- "$repo_root" && pwd -P)"
[[ "$(git -C "$repo_root" branch --show-current)" == main ]] || die 'Audit only runs on main.'
[[ "$(stat -c '%u' -- "$repo_root")" == "$EUID" ]] || die 'Repository checkout is not owned by the current user.'
report_parent="$repo_root/reports"
report_root="$report_parent/lockscreen-visual-audit"
[[ ! -L "$report_parent" && ! -L "$report_root" ]] || die 'Symlink report path rejected.'
[[ ! -e "$report_parent" || -d "$report_parent" ]] || die 'reports is not a directory.'
[[ ! -e "$report_root" || -d "$report_root" ]] || die 'Audit report path is not a directory.'
mkdir -p -- "$report_root"
stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
run_dir="$report_root/$stamp"
n=0
while ! mkdir -- "$run_dir" 2>/dev/null; do
    [[ -e "$run_dir" ]] || die 'Cannot create report directory.'
    n=$((n + 1)); run_dir="$report_root/$stamp-$n"
done
report="$run_dir/lockscreen-visual-audit.log"
( set -o noclobber; : > "$report" ) 2>/dev/null || die 'Cannot create report.'
export K41_AUDIT_HOME="$HOME" K41_AUDIT_REPO="$repo_root" K41_AUDIT_REPORT="$report"
export K41_AUDIT_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"

python3 <<'PY'
import difflib, hashlib, os, pathlib, re, shutil, subprocess
from datetime import datetime, timezone

home = pathlib.Path(os.environ["K41_AUDIT_HOME"]).resolve()
repo = pathlib.Path(os.environ["K41_AUDIT_REPO"]).resolve()
report = pathlib.Path(os.environ["K41_AUDIT_REPORT"])
config = pathlib.Path(os.environ["K41_AUDIT_CONFIG"])
legacy = repo / "stages/stage-5-desktop-customization/workstreams/02-lock-screen/k41-dots/modules/lock"
out = []
def add(x=""): out.append(str(x))
def section(x): add(); add("=" * 84); add(x); add("=" * 84)
def clean(x):
    s = str(x)
    return s.replace(str(home), "~") if str(home) != "/" else s
def run(args, timeout=10):
    try:
        p = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
        return p.returncode, p.stdout.strip()
    except (OSError, subprocess.TimeoutExpired) as e: return 127, type(e).__name__
def sha(p):
    h = hashlib.sha256()
    with p.open("rb") as f:
        for b in iter(lambda: f.read(1024 * 1024), b""): h.update(b)
    return h.hexdigest()
def read(p):
    try: return p.read_text(encoding="utf-8")
    except (OSError, UnicodeError): return ""
def walk(root, suffixes=None):
    suffixes = suffixes or set()
    for base, dirs, names in os.walk(root, followlinks=False):
        dirs[:] = [d for d in dirs if d not in {".git", "node_modules", "build", ".cache", "__pycache__"}]
        for name in names:
            p = pathlib.Path(base) / name
            if not p.is_symlink() and p.is_file() and (not suffixes or p.suffix.lower() in suffixes):
                yield p
def emit(p, label=None):
    try:
        raw = p.read_bytes()
        name = label or clean(p)
        add(f"--- FILE {name} | bytes={len(raw)} | sha256={hashlib.sha256(raw).hexdigest()} ---")
        add("<BINARY CONTENT OMITTED>" if b"\0" in raw else raw.decode("utf-8", "replace").rstrip())
        add(f"--- END FILE {name} ---")
    except OSError as e: add(f"<READ ERROR {clean(p)}: {type(e).__name__}>")

section("PURPOSE, SCOPE AND REPOSITORY")
add("Goal: reproduce the currently approved Lock Screen APPEARANCE in K41-dots.")
add("Included: visual QML, layout, components, typography, palette, shapes, effects, animations, icons, imagery, fonts, visual config and local visual dependencies.")
add("Excluded: PAM, authentication, password processing, fingerprint/Howdy, lock policy, session management, Hyprland binds and security configuration.")
add("Read-only apart from writing this report; no package/config/service/Git changes.")
add("Captured UTC: " + datetime.now(timezone.utc).isoformat())
add("Host label: " + clean(os.uname().nodename) + " | kernel: " + os.uname().release)
add("UID: " + str(os.getuid()) + " | repo: " + clean(repo) + " | config: " + clean(config))
rc, v = run(["git", "-C", str(repo), "rev-parse", "HEAD"]); add("Repository HEAD: " + (v if rc == 0 else "unknown"))
rc, v = run(["git", "-C", str(repo), "status", "--short"]); add("Repository status: " + (v or ("clean" if rc == 0 else "unknown")))

section("CAELESTIA SOURCE ROOTS AND PROVENANCE")
roots = [
 ("USER_CONFIG", config / "quickshell/caelestia"),
 ("USER_DEFAULT_CONFIG", home / ".config/quickshell/caelestia"),
 ("SYSTEM_XDG", pathlib.Path("/etc/xdg/quickshell/caelestia")),
 ("SYSTEM_SHARE", pathlib.Path("/usr/share/quickshell/caelestia")),
 ("SYSTEM_LIB", pathlib.Path("/usr/lib/quickshell/caelestia")),
 ("LEGACY_K41", legacy)]
available, seen = [], set()
for label, root in roots:
    try: key = str(root.resolve())
    except OSError: key = str(root)
    if key in seen: continue
    seen.add(key)
    if root.is_dir() and not root.is_symlink():
        available.append((label, root)); add(f"{label}: PRESENT {clean(root)}")
        if (root / ".git").exists():
            for args, title in [
              (["git","-C",str(root),"remote","get-url","origin"],"origin"),
              (["git","-C",str(root),"rev-parse","HEAD"],"HEAD"),
              (["git","-C",str(root),"status","--short"],"working tree")]:
                rc, v = run(args); add(f"  Git {title}: {v if v else ('clean' if rc == 0 else 'unavailable')}")
    else: add(f"{label}: ABSENT {clean(root)}")

section("DEPLOYMENT PREFLIGHT DIAGNOSTICS — FOUR K41 VISUAL TARGETS")
# These values intentionally mirror the deployment script's audited pin.
expected_origin = "https://github.com/caelestia-dots/shell.git"
expected_revision = "d999d4878ee4cec134168e60d913714566a8cfa6"
visual_source = repo / "stages/stage-5-desktop-customization/workstreams/02-lock-screen/modules/lockscreen"
target_files = [
    "LockSurface.qml",
    "Content.qml",
    "Center.qml",
    "center/PasswordInput.qml",
]
for label, root in available:
    if label != "USER_CONFIG" or not (root / ".git").exists():
        continue
    add(f"Deployment candidate root: {clean(root)}")
    rc, actual_origin = run(["git", "-C", str(root), "remote", "get-url", "origin"])
    actual_origin = actual_origin if rc == 0 else "<unavailable>"
    rc, actual_revision = run(["git", "-C", str(root), "rev-parse", "HEAD"])
    actual_revision = actual_revision if rc == 0 else "<unavailable>"
    rc, tree_status = run(["git", "-C", str(root), "status", "--short", "--untracked-files=all"])
    add(f"Expected origin: {expected_origin}")
    add(f"Actual origin:   {actual_origin}")
    add(f"Origin matches:  {actual_origin == expected_origin}")
    add(f"Expected HEAD:   {expected_revision}")
    add(f"Actual HEAD:     {actual_revision}")
    add(f"HEAD matches:    {actual_revision == expected_revision}")
    add("Full checkout status: " + (tree_status or ("clean" if rc == 0 else "<unavailable>")))
    for relative in target_files:
        installed = root / "modules/lock" / relative
        source = visual_source / relative
        add()
        add(f"TARGET: modules/lock/{relative}")
        for title, candidate in (("Installed", installed), ("K41 source", source)):
            if candidate.is_symlink():
                add(f"  {title}: SYMLINK — rejected by deployment")
            elif candidate.is_file():
                st = candidate.stat()
                add(f"  {title}: PRESENT | bytes={st.st_size} | mode={st.st_mode & 0o777:04o} | uid={st.st_uid} | sha256={sha(candidate)}")
            else:
                add(f"  {title}: MISSING")
        rc, status = run(["git", "-C", str(root), "status", "--short", "--untracked-files=all", "--", f"modules/lock/{relative}"])
        add("  Git path status: " + (status or ("clean" if rc == 0 else "<unavailable>")))
        upstream = None
        try:
            p = subprocess.run(
                ["git", "-C", str(root), "show", f"HEAD:modules/lock/{relative}"],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=10
            )
            if p.returncode == 0:
                upstream = p.stdout
                add(f"  Pinned HEAD blob: PRESENT | bytes={len(upstream)} | sha256={hashlib.sha256(upstream).hexdigest()}")
            else:
                add("  Pinned HEAD blob: MISSING/UNTRACKED")
        except (OSError, subprocess.TimeoutExpired) as e:
            add(f"  Pinned HEAD blob: UNAVAILABLE ({type(e).__name__})")
        installed_bytes = None
        try:
            if installed.is_file() and not installed.is_symlink():
                installed_bytes = installed.read_bytes()
        except OSError:
            pass
        source_bytes = None
        try:
            if source.is_file() and not source.is_symlink():
                source_bytes = source.read_bytes()
        except OSError:
            pass
        add(f"  Installed equals pinned HEAD: {installed_bytes is not None and upstream is not None and installed_bytes == upstream}")
        add(f"  Installed equals K41 source:  {installed_bytes is not None and source_bytes is not None and installed_bytes == source_bytes}")
        for title, left, right in (
            ("DIFF: pinned HEAD -> installed", upstream, installed_bytes),
            ("DIFF: installed -> K41 source", installed_bytes, source_bytes),
        ):
            add(f"  {title}:")
            if left is None or right is None:
                add("    <comparison unavailable>")
                continue
            if left == right:
                add("    <identical>")
                continue
            try:
                diff_lines = difflib.unified_diff(
                    left.decode("utf-8", "replace").splitlines(),
                    right.decode("utf-8", "replace").splitlines(),
                    fromfile=title.split(" -> ")[0],
                    tofile=title.split(" -> ")[1],
                    lineterm="",
                )
                rendered = list(diff_lines)
                add("\\n".join("    " + line for line in rendered) if rendered else "    <no textual diff>")
            except Exception as e:
                add(f"    <diff failed: {type(e).__name__}>")
    break
else:
    add("No user-local Git Caelestia checkout found; deployment provenance cannot be evaluated.")

section("LOCK-SCREEN VISUAL ENTRY POINTS")
initial, index = [], {}
for label, root in available:
    for p in walk(root):
        if p.suffix.lower() in {".qml", ".js", ".mjs"}:
            index.setdefault(p.stem, []).append((label, p))
            if any(t in p.relative_to(root).as_posix().lower() for t in ("lock","screenlock","lockscreen")):
                initial.append((label,p))
for label,p in sorted(initial,key=lambda x:(x[0],str(x[1]))):
    add(f"{label}: {clean(p)} | bytes={p.stat().st_size} | sha256={sha(p)}")
if not initial: add("No lock-named QML/JS files found; source discovery incomplete.")

section("LEGACY K41 VISUAL SOURCE")
if legacy.is_dir() and not legacy.is_symlink():
    for p in sorted(walk(legacy,{".qml",".js",".mjs",".json",".jsonc",".svg",".css",".scss"})): emit(p)
else: add("Legacy K41 source directory absent.")

section("QML MODULE DECLARATIONS")
qmldirs = []
for label,root in available:
    for p in walk(root,{"qmldir"}): qmldirs.append((label,p)); emit(p,f"{label}: {clean(p)}")

section("LOCAL VISUAL DEPENDENCY GRAPH")
# Conservative closure: quoted relative imports, literal local resource paths,
# and custom QML type names matched to source filenames. Qt plugins/modules
# that cannot be resolved from source filenames are documented as limitations.
queue = [p for _,p in initial if p.suffix.lower()==".qml"]
visited, resources, edges = set(), set(), set()
type_re = re.compile(r"(?m)^\s*([A-Z][A-Za-z0-9_]*)\s*\{")
while queue:
    p = queue.pop(0)
    try: p = p.resolve(strict=True)
    except OSError: continue
    if p in visited or not p.is_file(): continue
    visited.add(p); src = read(p)
    for m in re.finditer(r'(?m)^\s*import\s+"([^"]+)"',src):
        target=(p.parent/m.group(1)).resolve()
        if target.is_dir():
            for q in walk(target,{".qml"}): edges.add((str(p),str(q),"relative-import")); queue.append(q)
        else: add(f"UNRESOLVED RELATIVE IMPORT {clean(p)} -> {m.group(1)}")
    for m in re.finditer(r"""(?:source|sourceComponent|path|url)\s*:\s*["']([^"']+)["']""",src):
        value=m.group(1)
        if "://" in value or value.startswith(("qrc:","image://")) or "$" in value: continue
        q=(p.parent/value).resolve()
        if q.is_file(): resources.add(q); edges.add((str(p),str(q),"literal-resource"))
        elif not value.startswith(("/","~")): add(f"UNRESOLVED RESOURCE {clean(p)} -> {value}")
    for name in set(type_re.findall(src)):
        for _,q in index.get(name,[]):
            if q.resolve()!=p: edges.add((str(p),str(q),"QML-type")); queue.append(q)
for a,b,kind in sorted(edges): add(f"{kind}: {clean(a)} -> {clean(b)}")
add(f"Resolved QML files: {len(visited)}")
for p in sorted(visited,key=str): add(f"QML {clean(p)} | bytes={p.stat().st_size} | sha256={sha(p)}")

section("FULL SOURCE OF RESOLVED VISUAL QML")
for p in sorted(visited,key=str): emit(p)

section("VISUAL RESOURCE AND ASSET INVENTORY")
asset_ext={".svg",".png",".jpg",".jpeg",".webp",".gif",".avif",".ttf",".otf",".woff",".woff2"}
assets=set(resources)
for label,root in available:
    for p in walk(root,asset_ext):
        hint=p.relative_to(root).as_posix().lower()
        if label=="LEGACY_K41" or any(t in hint for t in ("lock","wallpaper","background","avatar","profile","icon","font")):
            assets.add(p)
for p in sorted(assets,key=str):
    try: add(f"{clean(p)} | bytes={p.stat().st_size} | sha256={sha(p)}")
    except OSError: add(f"{clean(p)} | metadata unavailable")

section("DESIGN SYSTEM: COLORS, TOKENS, FONTS, SHAPES AND ANIMATION")
design=re.compile(r"palette|colou?r|token|typography|font|round|shape|shadow|blur|gradient|animation|duration|easing|wallpaper|background",re.I)
design_files=set()
for label,root in available:
    if label=="LEGACY_K41": continue
    for p in walk(root,{".qml",".js",".mjs",".json",".jsonc",".css",".scss"}):
        if design.search(p.relative_to(root).as_posix()) or p.stem.lower() in {"tokens","colours","colors","theme","animations"}:
            design_files.add(p)
for p in sorted(design_files,key=str): emit(p)

section("VISUAL CONFIGURATION: FILTERED KEYS ONLY")
candidates=[
 config/"caelestia/shell.json",config/"caelestia/shell.jsonc",
 config/"quickshell/caelestia/shell.json",config/"quickshell/caelestia/shell.jsonc",
 config/"quickshell/caelestia/config.json",config/"quickshell/caelestia/config.jsonc"]
key_re=re.compile(r"lock|wallpaper|background|theme|colou?r|font|round|shape|blur|animation|clock|date|profile|avatar|weather",re.I)
for p in candidates:
    if not p.is_file() or p.is_symlink(): continue
    raw=read(p); add(f"CONFIG {clean(p)} | bytes={p.stat().st_size} | sha256={sha(p)}")
    try:
        import json
        data=json.loads(raw)
        def visit(obj,prefix=""):
            if isinstance(obj,dict):
                for k,v in obj.items():
                    name=f"{prefix}.{k}" if prefix else str(k)
                    if key_re.search(name):
                        add(f"  {name} = {str(v)[:400]}" if isinstance(v,(str,int,float,bool)) or v is None else f"  {name} = <{type(v).__name__}>")
                    visit(v,name)
            elif isinstance(obj,list):
                for i,v in enumerate(obj): visit(v,f"{prefix}[{i}]")
        visit(data)
    except Exception:
        for n,line in enumerate(raw.splitlines(),1):
            if key_re.search(line) and not re.search(r"password|secret|credential",line,re.I): add(f"  line {n}: {line.strip()[:400]}")
if not any(p.is_file() and not p.is_symlink() for p in candidates): add("No conventional visual config file found.")

section("VISUAL PACKAGE VERSION EVIDENCE")
for binary in ("qs","quickshell","caelestia"):
    exe=shutil.which(binary)
    if not exe: add(f"{binary}: not found"); continue
    rc,v=run([exe,"--version"]); add(f"{binary}: {clean(exe)} | {v if rc==0 else 'version unavailable'}")
for package in ("caelestia-shell","quickshell","quickshell-git"):
    rc,v=run(["pacman","-Qi",package])
    if rc==0:
        keep=("Name","Version","Description","Architecture","URL","Packager","Build Date","Install Date")
        add(f"[{package}]"); add("\n".join(line for line in v.splitlines() if any(line.startswith(k+" :") for k in keep)))
    else: add(f"{package}: not installed or pacman unavailable")

section("LIMITATIONS AND IMPLEMENTATION HANDOFF")
add("This audit is deliberately limited to appearance and visual dependencies.")
add("It does not inspect authentication, PAM, password handling, fingerprint/Howdy, lock policy, session state, keybinds, or lock invocation.")
add("Dependency discovery covers quoted relative imports, literal local resources and uppercase QML type names matched to filenames; it is not a complete Qt/QML linker.")
add("Qt modules, C++ plugins, singleton registration, qmldir type aliases, dynamic Loader URLs and runtime-generated resources may need additional upstream inspection.")
add("The report does not prove which tree is currently rendered on screen; source provenance and runtime visual comparison remain separate.")
add("Binary assets are represented by path, size and SHA-256, not embedded.")
add("Report contains local source text, paths, package versions and host label; review/redact before publishing.")
add("No system configuration, package, service, authentication, permission or Git state was modified.")
add("Report path: "+clean(report))
report.write_text("\n".join(out)+"\n",encoding="utf-8")
print(f"Appearance-only audit report created: {report}")
print(f"Report size: {report.stat().st_size} bytes")
PY

[[ -s "$report" ]] || die 'Audit did not produce a valid report.'
printf '\nAudit complete: %s\n' "$report"
printf 'Scope: Lock Screen appearance and visual dependencies only; authentication/PAM/session policy excluded.\n'
printf 'Review and redact report before publishing; it contains local source and host metadata.\n'
