#!/usr/bin/env bash
set -Eeuo pipefail

root="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
script="$root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-deploy-lockscreen-visual.sh"
source="$root/stages/stage-5-desktop-customization/workstreams/02-lock-screen/modules/lockscreen"

[[ -s $script ]] || { printf 'FAIL: deployment script missing.\n' >&2; exit 1; }
bash -n "$script"
for file in LockSurface.qml Content.qml Center.qml center/PasswordInput.qml; do
    [[ -s $source/$file ]] || { printf 'FAIL: missing visual source: %s\n' "$file" >&2; exit 1; }
done

tmp="$(mktemp -d)"
cleanup() { rm -rf -- "$tmp"; }
trap cleanup EXIT
home="$tmp/home"
mkdir -m 700 -- "$home"

env HOME="$home" bash "$script" --status | grep -Fq 'NOT DEPLOYED:'
env HOME="$home" bash "$script" --install
target="$home/.config/quickshell/k41/modules/lockscreen"
[[ -f $target/.k41-lockscreen-managed ]]
[[ -s $target/MANIFEST.sha256 ]]
(cd -- "$target" && sha256sum -c MANIFEST.sha256 >/dev/null)
for file in LockSurface.qml Content.qml Center.qml center/PasswordInput.qml; do
    cmp -s "$source/$file" "$target/$file"
done

env HOME="$home" bash "$script" --install | grep -Fq 'Already up to date:'
env HOME="$home" bash "$script" --status | grep -Fq 'ACTIVATION: NOT VERIFIED'

backup_root="$home/.local/state/k41/lockscreen/backups"
mapfile -t backups < <(find "$backup_root" -mindepth 1 -maxdepth 1 -type d -print | sort)
[[ ${#backups[@]} -eq 1 ]] || { printf 'FAIL: expected one backup, found %s.\n' "${#backups[@]}" >&2; exit 1; }
env HOME="$home" bash "$script" --rollback "${backups[0]}"
[[ ! -e $target ]] || { printf 'FAIL: rollback did not remove the first deployment.\n' >&2; exit 1; }

# Unknown pre-existing content must never be overwritten.
mkdir -p -- "$target"
printf 'user data\n' > "$target/do-not-overwrite"
if env HOME="$home" bash "$script" --install >/dev/null 2>&1; then
    printf 'FAIL: installer accepted an unmanaged target directory.\n' >&2
    exit 1
fi
[[ -f $target/do-not-overwrite ]]

printf 'PASS: deployment syntax, isolated install, checksums, idempotency, status, rollback, and unmanaged-target protection.\n'
printf 'NOTE: no Caelestia host integration or live Lock Screen rendering is tested.\n'
