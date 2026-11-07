#!/usr/bin/env bash
# Retrieve the latest main revision, expose its source for review, then launch
# the destructive installer only after an explicit source-review acknowledgement.
set -Eeuo pipefail
umask 077

readonly REPOSITORY_URL="https://github.com/K41-Origin/Lenovo-ThinkPad-X280-K41.git"

die() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

info() {
  printf 'INFO: %s\n' "$1" >&2
}

(( EUID == 0 )) || die "Run this bootstrap as root from the official Arch Linux ISO."
[[ -r /dev/tty && -w /dev/tty ]] || die "An interactive terminal is required."
command -v git >/dev/null 2>&1 || die "git is required; install it from the official Arch ISO environment."

work_dir="$(mktemp -d /root/k41-archiso.XXXXXX)" || die "Cannot create a private checkout directory."
repo_dir="$work_dir/repository"

info "Fetching the latest main branch over HTTPS. No downloaded script is piped to a shell."
git clone --depth 1 --single-branch --branch main "$REPOSITORY_URL" "$repo_dir" ||
  die "Git clone failed; no installer code was executed."

origin_url="$(git -C "$repo_dir" remote get-url origin)" ||
  die "Cannot verify the checkout origin."
[[ $origin_url == "$REPOSITORY_URL" ]] || die "Unexpected repository origin: $origin_url"

commit_sha="$(git -C "$repo_dir" rev-parse HEAD)" ||
  die "Cannot resolve the checked-out commit."
[[ $commit_sha =~ ^[0-9a-f]{40}$ ]] || die "Git returned an invalid commit SHA."
[[ -z "$(git -C "$repo_dir" status --porcelain)" ]] ||
  die "The retrieved checkout is not clean; refusing to continue."

printf '\nRepository: %s\nCommit:     %s\nCheckout:   %s\n\n' \
  "$REPOSITORY_URL" "$commit_sha" "$repo_dir"
printf '%s\n' \
  "Review every file below before allowing the installer to run." \
  "The installer is destructive and replaces the selected internal SSD." \
  "This review gate does not replace the installer's separate target-plan confirmation." \
  >&2

review_files=(
  README.md
  AGENTS.md
  scripts/install-arch-x280.sh
  scripts/configure-arch-x280.sh
  lib/common.sh
  lib/preflight.sh
  lib/inventory.sh
  lib/storage.sh
  lib/storage-topology.sh
  lib/storage-plan.sh
  lib/storage-prerequisites.sh
  lib/storage-confirmation.sh
  lib/base-system.sh
)

if command -v less >/dev/null 2>&1; then
  pager=(less -R)
elif command -v more >/dev/null 2>&1; then
  pager=(more)
else
  die "A pager (less or more) is required for the mandatory source review."
fi

for relative_path in "${review_files[@]}"; do
  file="$repo_dir/$relative_path"
  [[ -f $file ]] || die "Required review file is missing: $relative_path"
  printf '\n===== SOURCE REVIEW: %s =====\n' "$relative_path" >&2
  "${pager[@]}" -- "$file"
done

printf '\nResolved commit: %s\n' "$commit_sha" >&2
printf 'To launch the destructive installer, type exactly:\n' >&2
printf 'REVIEWED %s AND AUTHORIZE INSTALLER LAUNCH\n> ' "$commit_sha" >&2
IFS= read -r acknowledgement </dev/tty
[[ $acknowledgement == "REVIEWED $commit_sha AND AUTHORIZE INSTALLER LAUNCH" ]] ||
  die "Source review acknowledgement did not match; installer was not launched."

info "Source review acknowledged for commit $commit_sha."
info "Launching the installer. A second, target-specific storage-plan confirmation is still required."
exec bash "$repo_dir/scripts/install-arch-x280.sh"
