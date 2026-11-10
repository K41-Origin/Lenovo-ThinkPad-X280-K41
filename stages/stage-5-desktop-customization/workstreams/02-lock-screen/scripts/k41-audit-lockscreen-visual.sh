#!/usr/bin/env bash
# Comprehensive, read-only audit of the currently approved Caelestia lock-screen
# visuals and their integration dependencies. Does not deploy or modify the system.
set -Eeuo pipefail

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
have() { command -v "$1" >/dev/null 2>&1; }

(( EUID != 0 )) || die 'Jalankan sebagai user desktop biasa, tanpa sudo.'
for cmd in git python3 date mkdir stat uname; do
  have "$cmd" || die "Perintah wajib tidak tersedia: $cmd"
done
[[ -n ${HOME:-} && -d $HOME ]] || die 'HOME tidak valid.'
[[ -n ${XDG_CONFIG_HOME:-$HOME/.config} ]] || die 'XDG_CONFIG_HOME tidak valid.'

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)" ||
  die 'Script harus dijalankan dari Git checkout.'
repo_root="$(cd -- "$repo_root" && pwd -P)"
[[ "$(git -C "$repo_root" branch --show-current)" == main ]] ||
  die 'Audit hanya berjalan pada branch main.'
[[ "$(stat -c '%u' -- "$repo_root")" == "$EUID" ]] ||
  die 'Checkout bukan milik user aktif; jangan gunakan sudo/chown.'

report_parent="$repo_root/reports"
report_root="$report_parent/lockscreen-visual-audit"
[[ ! -L "$report_parent" && ! -L "$report_root" ]] ||
  die 'Symlink pada jalur report ditolak.'
[[ ! -e "$report_parent" || -d "$report_parent" ]] || die 'reports bukan direktori.'
[[ ! -e "$report_root" || -d "$report_root" ]] || die 'Direktori audit bukan direktori.'
mkdir -p -- "$report_root"
stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
run_dir="$report_root/$stamp"
n=0
while ! mkdir -- "$run_dir" 2>/dev/null; do
  [[ -e "$run_dir" ]] || die 'Tidak dapat membuat direktori report.'
  n=$((n + 1))
  run_dir="$report_root/$stamp-$n"
done
report="$run_dir/lockscreen-visual-audit.log"
( set -o noclobber; : > "$report" ) 2>/dev/null || die 'Tidak dapat membuat report baru.'

export K41_AUDIT_HOME="$HOME"
export K41_AUDIT_REPO="$repo_root"
export K41_AUDIT_REPORT="$report"
export K41_AUDIT_RUN_DIR="$run_dir"
export K41_AUDIT_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"

python3 <<'PY'
import hashlib
import json
import os
import pathlib
import re
import subprocess
from datetime import datetime, timezone

home = pathlib.Path(os.environ["K41_AUDIT_HOME"]).resolve()
repo = pathlib.Path(os.environ["K41_AUDIT_REPO"]).resolve()
report = pathlib.Path(os.environ["K41_AUDIT_REPORT"])
run_dir = pathlib.Path(os.environ["K41_AUDIT_RUN_DIR"])
config = pathlib.Path(os.environ["K41_AUDIT_CONFIG"])
out = []

def add(text=""):
    out.append(str(text))

def redact(value):
    s = str(value)
    hs = str(home)
    return s.replace(hs, "~") if hs and hs != "/" else s

def section(title):
    add()
    add("=" * 88)
    add(title)
    add("=" * 88)

def command(args, timeout=8):
    try:
        p = subprocess.run(args, text=True, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, timeout=timeout, check=False)
        return p.returncode, p.stdout.strip()
    except (OSError, subprocess.TimeoutExpired) as exc:
        return 127, type(exc).__name__

def file_hash(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def safe_read(path):
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        return f"<READ ERROR: {type(exc).__name__}>"

def add_file_content(path, label):
    try:
        raw = path.read_bytes()
        digest = hashlib.sha256(raw).hexdigest()
        add(f"--- BEGIN SOURCE: {label} | bytes={len(raw)} | sha256={digest} ---")
        if b"\0" in raw:
            add("<BINARY FILE: content omitted; metadata and hash retained>")
        else:
            text = raw.decode("utf-8", errors="replace")
            add(text.rstrip("\n"))
        add(f"--- END SOURCE: {label} ---")
    except OSError as exc:
        add(f"<READ ERROR: {type(exc).__name__}>")

def rel(path):
    try:
        return redact(path.resolve().as_posix())
    except OSError:
        return redact(path.as_posix())

section("AUDIT METADATA")
add("Audit: K41-dots Lock Screen Visual Source Audit")
add("Captured UTC: " + datetime.now(timezone.utc).isoformat())
add("Purpose: identify approved visual source, assets, QML dependencies and integration points.")
add("Mode: READ-ONLY. No package/config/service/PAM/permission/Git changes are performed.")
add("Host: " + redact(os.uname().nodename))
add("Kernel: " + os.uname().release)
add("User UID: " + str(os.getuid()))
add("Repository: " + redact(repo))
rc, branch = command(["git", "-C", str(repo), "branch", "--show-current"])
add("Git branch: " + (branch if rc == 0 else "UNKNOWN"))
rc, head = command(["git", "-C", str(repo), "rev-parse", "HEAD"])
add("Git HEAD: " + (head if rc == 0 else "UNKNOWN"))
rc, status = command(["git", "-C", str(repo), "status", "--short"])
add("Git working tree: " + (status if status else ("clean" if rc == 0 else "UNKNOWN")))
add("XDG_CONFIG_HOME: " + redact(config))

section("SESSION AND INSTALLED COMPONENTS")
for key in ("XDG_SESSION_TYPE", "XDG_CURRENT_DESKTOP", "DESKTOP_SESSION"):
    add(f"{key}: {os.environ.get(key, 'unset')}")
for key in ("WAYLAND_DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE", "XDG_RUNTIME_DIR"):
    add(f"{key}: {'present' if os.environ.get(key) else 'absent'} (value intentionally omitted)")
for binary in ("qs", "quickshell", "caelestia", "hyprctl", "loginctl", "pacman"):
    rc, value = command(["bash", "-lc", f"command -v {binary}"])
    add(f"{binary}: {value if rc == 0 else 'not found'}")
    if rc == 0 and binary in ("qs", "quickshell", "caelestia", "hyprctl"):
        vrc, version = command([value, "--version"])
        add(f"  version: {version if version else 'no version output'}")
rc, packages = command(["pacman", "-Q", "caelestia-shell", "caelestia-cli",
                        "quickshell", "quickshell-git", "hyprland", "hyprlock",
                        "fprintd", "pam_fprintd", "howdy"])
add("Package query:")
add(packages if packages else "Unavailable or packages not installed.")

section("SOURCE ROOT DISCOVERY")
legacy_repo = repo / "stages/stage-5-desktop-customization/workstreams/02-lock-screen/k41-dots/modules/lock"
roots = [
    ("USER_CA ELESTIA", config / "quickshell/caelestia"),
    ("USER_QUICKSHELL_CA ELESTIA", home / ".config/quickshell/caelestia"),
    ("SYSTEM_XDG_CA ELESTIA", pathlib.Path("/etc/xdg/quickshell/caelestia")),
    ("USR_SHARE_CA ELESTIA", pathlib.Path("/usr/share/quickshell/caelestia")),
    ("USR_LIB_CA ELESTIA", pathlib.Path("/usr/lib/quickshell/caelestia")),
    ("LEGACY_K41_OVERLAY", legacy_repo),
]
unique = []
seen = set()
for label, root in roots:
    try:
        key = str(root.resolve())
    except OSError:
        key = str(root)
    if key in seen:
        continue
    seen.add(key)
    if root.is_dir() and not root.is_symlink():
        unique.append((label, root))
        add(f"{label}: PRESENT {rel(root)}")
    else:
        add(f"{label}: ABSENT {rel(root)}")

section("LOCK-SCREEN PATH INVENTORY")
lock_dirs = []
for label, root in unique:
    candidates = []
    for base, dirs, files in os.walk(root, followlinks=False):
        dirs[:] = [d for d in dirs if d not in (".git", "node_modules", "build", ".cache")]
        current = pathlib.Path(base)
        relative = current.relative_to(root)
        path_tokens = (str(relative) + "/" + current.name).lower()
        if any(t in path_tokens for t in ("lock", "screenlock", "lockscreen")):
            lock_dirs.append((label, current))
        for name in files:
            p = current / name
            if any(t in name.lower() for t in ("lock", "screenlock", "lockscreen")):
                candidates.append(p)
    add(f"\n[{label}] lock-named files:")
    if not candidates:
        add("  none found by filename")
    for p in sorted(set(candidates)):
        try:
            st = p.lstat()
            kind = "SYMLINK" if p.is_symlink() else "FILE"
            add(f"  {kind} {rel(p)} size={st.st_size} mode={oct(st.st_mode & 0o777)}")
            if p.is_file() and not p.is_symlink():
                add(f"    sha256={file_hash(p)}")
        except OSError as exc:
            add(f"  STAT ERROR {rel(p)}: {type(exc).__name__}")

section("LEGACY K41 VISUAL SOURCE — FULL TEXT")
if legacy_repo.is_dir() and not legacy_repo.is_symlink():
    for p in sorted(legacy_repo.rglob("*")):
        if p.is_symlink() or not p.is_file():
            continue
        if p.suffix.lower() in (".qml", ".js", ".mjs", ".json", ".jsonc", ".scss",
                                ".css", ".svg", ".md", ".txt"):
            add_file_content(p, rel(p))
else:
    add("Legacy K41 overlay directory not found.")

section("UPSTREAM LOCK-SCREEN QML SOURCE — FULL TEXT")
upstream_files = set()
for label, root in unique:
    if label == "LEGACY_K41_OVERLAY":
        continue
    for base, dirs, files in os.walk(root, followlinks=False):
        dirs[:] = [d for d in dirs if d not in (".git", "node_modules", "build", ".cache")]
        current = pathlib.Path(base)
        rel_dir = current.relative_to(root).as_posix().lower()
        for name in files:
            p = current / name
            low = name.lower()
            if p.suffix.lower() not in (".qml", ".js", ".mjs", ".json", ".jsonc", ".scss", ".css"):
                continue
            if any(t in low or t in rel_dir for t in ("lock", "screenlock", "lockscreen")):
                if not p.is_symlink() and p.is_file():
                    upstream_files.add((label, p))
for label, p in sorted(upstream_files, key=lambda x: (x[0], str(x[1]))):
    add_file_content(p, f"{label}: {rel(p)}")
if not upstream_files:
    add("No lock-named upstream source files discovered. This may indicate source is package-managed or uses generic filenames.")

section("VISUAL ASSET INVENTORY")
asset_ext = {".svg", ".png", ".jpg", ".jpeg", ".webp", ".gif", ".avif",
             ".ttf", ".otf", ".woff", ".woff2"}
for label, root in unique:
    add(f"\n[{label}] assets in lock-related directories:")
    found = 0
    for base, dirs, files in os.walk(root, followlinks=False):
        dirs[:] = [d for d in dirs if d not in (".git", "node_modules", "build", ".cache")]
        current = pathlib.Path(base)
        rel_dir = current.relative_to(root).as_posix().lower()
        if not any(t in rel_dir or t in current.name.lower() for t in ("lock", "screenlock", "lockscreen")):
            continue
        for name in sorted(files):
            p = current / name
            if p.suffix.lower() in asset_ext and not p.is_symlink():
                try:
                    add(f"  {rel(p)} size={p.stat().st_size} sha256={file_hash(p)}")
                    found += 1
                except OSError:
                    add(f"  {rel(p)} unreadable")
    if not found:
        add("  no assets discovered by directory naming")

section("QML/JS REFERENCES TO LOCK SCREEN")
pattern = re.compile(r"lock|screenlock|lockscreen|Pam|PasswordInput|StateMessage", re.I)
for label, root in unique:
    add(f"\n[{label}]")
    count = 0
    for base, dirs, files in os.walk(root, followlinks=False):
        dirs[:] = [d for d in dirs if d not in (".git", "node_modules", "build", ".cache")]
        for name in files:
            p = pathlib.Path(base) / name
            if p.suffix.lower() not in (".qml", ".js", ".mjs") or p.is_symlink():
                continue
            try:
                lines = p.read_text(encoding="utf-8").splitlines()
            except (OSError, UnicodeError):
                continue
            matches = [(i, line.strip()) for i, line in enumerate(lines, 1) if pattern.search(line)]
            if matches:
                add(f"  FILE {rel(p)}")
                for line_no, line in matches:
                    add(f"    {line_no}: {line[:500]}")
                count += 1
    if count == 0:
        add("  no textual references found")

section("QML IMPORTS AND LOCAL COMPONENT REFERENCES")
for label, p in sorted(upstream_files, key=lambda x: (x[0], str(x[1]))):
    if p.suffix.lower() != ".qml":
        continue
    text = safe_read(p)
    imports = [line.strip() for line in text.splitlines()
               if re.match(r"\s*import\s+", line)]
    refs = [line.strip() for line in text.splitlines()
            if re.search(r"(?:source|Loader|\.qml|\.svg|\.png|\.jpg|\.webp)", line, re.I)]
    add(f"\nFILE {rel(p)}")
    add("  imports:")
    add("\n".join("    " + x for x in imports) if imports else "    none")
    add("  local/resource references:")
    add("\n".join("    " + x[:500] for x in refs) if refs else "    none")

section("CAELESTIA CONFIGURATION — SAFE LOCK-RELATED FIELDS")
config_candidates = [
    config / "caelestia/shell.json",
    config / "caelestia/shell.jsonc",
    config / "quickshell/caelestia/shell.json",
    config / "quickshell/caelestia/shell.jsonc",
]
for p in config_candidates:
    if not p.is_file() or p.is_symlink():
        continue
    add(f"\nCONFIG {rel(p)} size={p.stat().st_size} sha256={file_hash(p)}")
    try:
        data = json.loads(p.read_text(encoding="utf-8"))
        def walk(obj, prefix=""):
            if isinstance(obj, dict):
                for key, value in obj.items():
                    here = f"{prefix}.{key}" if prefix else key
                    if re.search(r"lock|wallpaper|background", here, re.I):
                        if isinstance(value, (str, int, float, bool)) or value is None:
                            v = str(value)
                            add(f"  {here} = {v[:300]}")
                        else:
                            add(f"  {here} = <{type(value).__name__}>")
                    walk(value, here)
            elif isinstance(obj, list):
                for i, value in enumerate(obj):
                    walk(value, f"{prefix}[{i}]")
        walk(data)
    except Exception as exc:
        add(f"  JSON parse unavailable/failed: {type(exc).__name__}")
if not any(p.is_file() and not p.is_symlink() for p in config_candidates):
    add("No conventional shell.json/shell.jsonc config candidate found.")

section("AUTHENTICATION AND SESSION-LOCK BOUNDARY — METADATA ONLY")
add("PAM file contents/options are intentionally NOT collected.")
for p in (pathlib.Path("/etc/pam.d/hyprlock"), pathlib.Path("/etc/pam.d/caelestia"),
          pathlib.Path("/etc/pam.d/login"), pathlib.Path("/etc/pam.d/system-auth")):
    if p.is_file():
        add(f"PAM file present: {p}")
        try:
            for line in p.read_text(errors="replace").splitlines():
                s = line.strip()
                if s and not s.startswith("#") and s.split()[0] == "auth":
                    parts = s.split()
                    add("  auth module: " + (parts[2] if len(parts) > 2 else "<unspecified>"))
        except OSError:
            add("  unreadable")
    else:
        add(f"PAM file absent: {p}")
for proc in ("qs", "quickshell", "caelestia", "Hyprland", "hyprlock", "swaylock"):
    rc, value = command(["pgrep", "-x", proc])
    add(f"process {proc}: {'running' if rc == 0 else 'not detected/pgrep unavailable'}")
rc, value = command(["loginctl", "show-session", "self", "-p", "Type", "-p", "Class", "-p", "State"])
add("loginctl session properties (selected):")
add(value if rc == 0 else "unavailable")

section("HYPRLAND LOCK-RELATED INTEGRATION")
rc, instances = command(["hyprctl", "instances"])
add("hyprctl instances:")
add(instances if rc == 0 else "unavailable")
if rc == 0:
    rc, binds = command(["hyprctl", "-j", "binds"])
    if rc == 0:
        try:
            entries = json.loads(binds)
            selected = []
            for b in entries if isinstance(entries, list) else []:
                serialized = json.dumps(b).lower()
                if any(t in serialized for t in ("lock", "hyprlock", "caelestia")):
                    selected.append({k: b.get(k) for k in
                                     ("key", "keycode", "modmask", "dispatcher", "arg",
                                      "description", "locked", "release") if k in b})
            add("Lock-related keybind candidates:")
            add(json.dumps(selected, indent=2, ensure_ascii=False))
        except Exception as exc:
            add("bind JSON parse failed: " + type(exc).__name__)
    else:
        add("hyprctl bind query unavailable.")

section("REPORT FILES AND AUDIT LIMITATIONS")
add("This report contains local source text and host/package metadata; review before publishing.")
add("No passwords, tokens, process command-line arguments, environment values, or full PAM lines are collected.")
add("The collector does not install packages, edit configuration, modify PAM, change permissions, restart services, or alter Git state.")
add("The collector does not infer the visually active implementation solely from filenames. Runtime review remains necessary.")
add("Wallpaper identity, actual lock invocation, visual layout, failed-password feedback, fingerprint/Howdy, wake/resume, and unlock behavior require runtime validation.")
add("Source discovery is limited to the listed common Caelestia locations and the legacy K41 overlay; additional custom paths may need to be added after reviewing this report.")
add("Binary assets are inventoried by path, size, and SHA-256; binary payloads are not embedded.")
add("Report location: " + redact(report))
add("Report run directory: " + redact(run_dir))

report.write_text("\n".join(out) + "\n", encoding="utf-8")
print(f"Audit report created: {report}")
print(f"Report size: {report.stat().st_size} bytes")
print("No system configuration or Git state was modified.")
PY

[[ -s "$report" ]] || die 'Audit tidak menghasilkan report yang valid.'
printf '\nAudit selesai: %s\n' "$report"
printf 'Report mencakup inventory, hash, source QML terkait, aset, referensi, konfigurasi terpilih, dan batas autentikasi.\n'
printf 'Periksa dan redaksi report sebelum dipublikasikan; report dapat memuat source proprietary/custom dan metadata host.\n'
printf 'Tidak ada deployment, cleanup, package operation, service operation, atau perubahan autentikasi.\n'
