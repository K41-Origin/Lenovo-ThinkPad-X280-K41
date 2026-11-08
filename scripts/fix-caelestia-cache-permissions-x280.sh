#!/usr/bin/env bash
set -Eeuo pipefail

# Narrow repair for the verified X280 issue: ~/.cache is root-owned.
# Default mode is a dry-run. Only --apply performs one non-recursive chown.

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/fix-caelestia-cache-permissions-x280.sh [--check|--apply]

  --check  Inspect and print the proposed change (default; no modifications).
  --apply  Change ownership of exactly "$HOME/.cache" to the invoking user.
USAGE
}

mode=check
case "${1:---check}" in
  --check) mode=check ;;
  --apply) mode=apply ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || { usage >&2; exit 2; }

if (( EUID == 0 )); then
  printf 'ERROR: run this script as the regular desktop user, not root.\n' >&2
  exit 1
fi

uid=$(id -u)
gid=$(id -g)
home=${HOME:?HOME is not set}
[[ $home == /* && -d $home ]] || {
  printf 'ERROR: HOME must be an existing absolute directory.\n' >&2
  exit 1
}
home_real=$(realpath -e -- "$home")
[[ $home_real == "$home" ]] || {
  printf 'ERROR: HOME must already be canonical (resolved: %s).\n' "$home_real" >&2
  exit 1
}

cache="$home/.cache"
[[ -d $cache && ! -L $cache ]] || {
  printf 'ERROR: expected a real directory at %s; refusing symlinks or missing paths.\n' "$cache" >&2
  exit 1
}

owner=$(stat -c '%u:%g' -- "$cache")
mode_bits=$(stat -c '%a' -- "$cache")
printf 'Target: %s\n' "$cache"
printf 'Current owner:group: %s\n' "$owner"
printf 'Mode: %s\n' "$mode_bits"
printf 'Expected owner:group: %s:%s\n' "$uid" "$gid"

if [[ $owner == "$uid:$gid" ]]; then
  printf 'PASS: cache directory is already owned by the current user; no change needed.\n'
  exit 0
fi

if [[ $owner != 0:0 ]]; then
  printf 'ERROR: unexpected ownership %s; only the verified root:root case is eligible.\n' "$owner" >&2
  exit 1
fi

if [[ $mode != apply ]]; then
  printf 'DRY RUN: would change ownership of this directory only (non-recursively).\n'
  printf 'No files, subdirectories, permissions, packages, or services will be changed.\n'
  printf 'Re-run with --apply to authorize this exact ownership change.\n'
  exit 0
fi

command -v sudo >/dev/null 2>&1 || {
  printf 'ERROR: sudo is required for the narrowly scoped ownership change.\n' >&2
  exit 1
}
sudo -v
sudo chown --no-dereference -- "$uid:$gid" "$cache"

new_owner=$(stat -c '%u:%g' -- "$cache")
if [[ $new_owner != "$uid:$gid" ]]; then
  printf 'ERROR: ownership verification failed; now %s, expected %s:%s.\n' "$new_owner" "$uid" "$gid" >&2
  exit 1
fi

printf 'PASS: ownership is now %s. Directory mode remains %s.\n' "$new_owner" "$(stat -c '%a' -- "$cache")"
printf 'No recursive changes were made. Re-run the Caelestia diagnostics and runtime test.\n'
