#!/usr/bin/env bash
# Remove audited, inactive Caelestia lock-screen visual components from the
# user-local Caelestia checkout. The lock/authentication runtime is preserved.
# Default is dry-run. Run as the regular desktop user, never with sudo.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\n' "$*"; }
usage() { printf 'Usage: %s [--dry-run|--apply]\n' "$0"; }

mode=dry-run
case ${1:---dry-run} in
    --dry-run) [[ $# -le 1 ]] || { usage >&2; exit 2; } ;;
    --apply) [[ $# -le 1 ]] || { usage >&2; exit 2; }; mode=apply ;;
    *) usage >&2; exit 2 ;;
esac

(( EUID != 0 )) || die 'Run as the regular desktop user, never with sudo.'
[[ -n ${HOME:-} && $HOME == /* && -d $HOME ]] || die 'HOME is missing or invalid.'
for command_name in git python3 stat mkdir cp cmp date sha256sum mktemp rm dirname; do
    command -v "$command_name" >/dev/null 2>&1 || die "Required command is unavailable: $command_name"
done

host_root="$HOME/.config/quickshell/caelestia"
lock_root="$host_root/modules/lock"
state_root="$HOME/.local/state/k41/lockscreen/caelestia-visual-cleanup"
readonly upstream_url="https://github.com/caelestia-dots/shell.git"
readonly upstream_revision="d999d4878ee4cec134168e60d913714566a8cfa6"
readonly candidates=(
    Fetch.qml
    Media.qml
    Resources.qml
    NotifDock.qml
    NotifGroup.qml
    WeatherInfo.qml
    weather/BriefInfo.qml
    weather/Forecast.qml
    center/ProfilePic.qml
)

[[ -d "$host_root" && ! -L "$host_root" && -s "$host_root/shell.qml" ]] ||
    die "Expected user-local Caelestia checkout not found: $host_root"
[[ -d "$lock_root" && ! -L "$lock_root" ]] || die "Lock module directory missing: $lock_root"
[[ $(stat -c %u "$host_root") == "$EUID" ]] || die 'Caelestia checkout is not owned by this user.'
[[ $(git -C "$host_root" rev-parse --is-inside-work-tree 2>/dev/null || true) == true ]] ||
    die 'Caelestia source is not a Git checkout.'
[[ $(git -C "$host_root" remote get-url origin 2>/dev/null || true) == "$upstream_url" ]] ||
    die 'Caelestia origin differs from the audited upstream; refusing cleanup.'
[[ $(git -C "$host_root" rev-parse HEAD 2>/dev/null || true) == "$upstream_revision" ]] ||
    die "Caelestia revision differs from audited revision $upstream_revision; re-audit first."

# Never remove files with user modifications, staged changes, or untracked replacements.
for relative in "${candidates[@]}"; do
    path="$lock_root/$relative"
    [[ -f "$path" && ! -L "$path" && -s "$path" ]] ||
        die "Candidate is missing, empty, symlinked, or not a regular file: $relative"
    git -C "$host_root" ls-files --error-unmatch -- "modules/lock/$relative" >/dev/null 2>&1 ||
        die "Candidate is not tracked by the pinned upstream checkout: $relative"
    if ! git -C "$host_root" diff --quiet HEAD -- "modules/lock/$relative" ||
       ! git -C "$host_root" diff --cached --quiet -- "modules/lock/$relative"; then
        die "Candidate has local Git changes; refusing to remove: $relative"
    fi
    upstream_tmp="$(mktemp)"
    if ! git -C "$host_root" show "HEAD:modules/lock/$relative" > "$upstream_tmp"; then
        rm -f -- "$upstream_tmp"
        die "Cannot read pinned upstream baseline: $relative"
    fi
    if ! cmp -s "$upstream_tmp" "$path"; then
        rm -f -- "$upstream_tmp"
        die "Runtime file differs from pinned upstream baseline: $relative"
    fi
    rm -f -- "$upstream_tmp"
done

# Guard against direct QML component references in the lock module that would
# survive after the candidate files are removed. Dynamic QML loading still
# requires separate human review; this check is intentionally conservative.
python3 - "$lock_root" "${candidates[@]}" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
candidates = set(sys.argv[2:])
stems = {Path(item).stem: item for item in candidates}
problems = []
for source in root.rglob("*"):
    if not source.is_file() or source.suffix not in {".qml", ".js"}:
        continue
    relative = source.relative_to(root).as_posix()
    if relative in candidates:
        continue
    try:
        text = source.read_text(encoding="utf-8")
    except (OSError, UnicodeError):
        problems.append(f"UNREADABLE {relative}")
        continue
    for stem, candidate in stems.items():
        if re.search(rf"\\b{re.escape(stem)}\\s*\\{{", text):
            problems.append(f"REFERENCE {relative} -> {candidate}")
if problems:
    print("\n".join(problems), file=sys.stderr)
    raise SystemExit("Direct component references remain; refusing cleanup.")
print("PASS: no direct component-instantiation references found in remaining lock-module QML/JS.")
PY

info 'Audited cleanup candidates:'
printf '  %s\n' "${candidates[@]}"
info 'Preserved runtime/authentication files: Lock.qml, Pam.qml, LockSurface.qml, Content.qml, Center.qml, center/PasswordInput.qml, center/InputField.qml, center/Clock.qml, center/StateMessage.qml.'

if [[ $mode == dry-run ]]; then
    info 'Dry-run only; no files were changed.'
    info 'Use --apply only after reviewing the candidate list and understanding the Git/update impact.'
    exit 0
fi

# Back up every candidate outside the upstream checkout before deleting anything.
for path in "$HOME/.local" "$HOME/.local/state" "$HOME/.local/state/k41" "$HOME/.local/state/k41/lockscreen" "$state_root"; do
    [[ ! -L "$path" ]] || die "Refusing symlinked backup path: $path"
    if [[ -e "$path" ]]; then
        [[ -d "$path" && $(stat -c %u "$path") == "$EUID" ]] ||
            die "Backup path is not a user-owned directory: $path"
    fi
done
mkdir -p -- "$state_root"
stamp="$(date -u +'%Y%m%dT%H%M%SZ')"
backup="$state_root/$stamp"
suffix=0
while ! mkdir -- "$backup" 2>/dev/null; do
    suffix=$((suffix + 1))
    backup="$state_root/$stamp-$suffix"
done
mkdir -p -- "$backup/weather" "$backup/center"

restore_backup() {
    local relative
    for relative in "${candidates[@]}"; do
        [[ -s "$backup/$relative" ]] || continue
        mkdir -p -- "$(dirname -- "$lock_root/$relative")"
        cp -p -- "$backup/$relative" "$lock_root/$relative"
    done
}

for relative in "${candidates[@]}"; do
    mkdir -p -- "$backup/$(dirname -- "$relative")"
    cp -p -- "$lock_root/$relative" "$backup/$relative"
    cmp -s "$lock_root/$relative" "$backup/$relative" ||
        die "Backup verification failed for $relative"
done
(
    cd -- "$backup"
    sha256sum "${candidates[@]}" > MANIFEST.sha256
    sha256sum -c MANIFEST.sha256
)

cleanup_complete=0
rollback_on_exit() {
    local rc=$?
    if (( rc != 0 && cleanup_complete == 0 )); then
        info "Removal failed; restoring candidate files from $backup."
        restore_backup || printf 'CRITICAL: automatic restore failed; backup retained at %s\\n' "$backup" >&2
    fi
    return "$rc"
}
trap rollback_on_exit EXIT

for relative in "${candidates[@]}"; do
    rm -- "$lock_root/$relative"
done
for relative in "${candidates[@]}"; do
    [[ ! -e "$lock_root/$relative" && ! -L "$lock_root/$relative" ]] ||
        die "Post-cleanup verification failed; file still exists: $relative"
done

cleanup_complete=1
trap - EXIT
info "Removed ${#candidates[@]} inactive Caelestia visual component files."
info "Verified backup: $backup"
info 'The upstream Git checkout now intentionally contains tracked deletions.'
info 'Do not run git pull/update on this checkout until these files are restored or the update workflow explicitly accounts for the deletions.'
info 'No lock IPC, PAM/authentication, Wayland session-lock, K41-owned QML, Hyprland config, system XDG tree, or system service was modified.'
info 'Restart/reload Caelestia and perform a real lock/unlock acceptance test after cleanup.'
