#!/usr/bin/env bash
# Retrieve the latest main revision, require source review and a passing
# read-only readiness gate, then require explicit authorization to launch.
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
  docs/00-START-HERE.md
  docs/01-PROJECT.md
  docs/02-INSTALLATION.md
  docs/03-DESKTOP.md
  docs/04-TESTING.md
  docs/05-OPERATIONS.md
  docs/06-STATUS.md
  config/hardware/thinkpad-x280.conf
  scripts/bootstrap-archiso.sh
  stages/stage-2-basic-arch-install/scripts/k41-install-basic-arch.sh
  stages/stage-2-basic-arch-install/scripts/install-arch-x280.sh
  stages/stage-2-basic-arch-install/scripts/configure-arch-x280.sh
  stages/stage-1-live-readiness/scripts/k41-live-validation.sh
  scripts/k41-install-desktop.sh
  scripts/setup-desktop-x280.sh
  stages/stage-1-live-readiness/scripts/x280-install-readiness.sh
  stages/stage-1-live-readiness/scripts/live-validation.sh
  scripts/x280-first-boot-check.sh
  stages/stage-1-live-readiness/scripts/validate-live-storage.sh
  stages/stage-1-live-readiness/tests/test-x280-install-readiness.sh
  tests/run.sh
  tests/helpers/storage-fixtures.sh
  lib/common.sh
  lib/preflight.sh
  lib/inventory.sh
  lib/storage.sh
  lib/storage-topology.sh
  lib/storage-plan.sh
  lib/storage-prerequisites.sh
  lib/storage-confirmation.sh
  stages/stage-2-basic-arch-install/lib/base-system.sh
)

mapfile -t test_files < <(git -C "$repo_dir" ls-files 'tests/*.sh')
(( ${#test_files[@]} > 0 )) || die "No tracked test scripts found for source review."
review_files+=("${test_files[@]}")

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
  "${pager[@]}" "$file"
done

printf '\nResolved commit: %s\n' "$commit_sha" >&2
printf 'To run the read-only readiness gate, type exactly:\n' >&2
printf 'REVIEWED %s AND AUTHORIZE READ-ONLY READINESS CHECK\n> ' "$commit_sha" >&2
IFS= read -r acknowledgement </dev/tty
[[ $acknowledgement == "REVIEWED $commit_sha AND AUTHORIZE READ-ONLY READINESS CHECK" ]] ||
  die "Source review acknowledgement did not match; readiness check was not launched."

info "Source review acknowledged for commit $commit_sha. Running the read-only readiness gate."
if ! (cd "$repo_dir" && bash stages/stage-1-live-readiness/scripts/k41-live-validation.sh --readiness); then
  die "Read-only readiness failed. Review reports/live-readiness and reports/live-validation; the destructive installer was not launched."
fi

printf '\nRead-only readiness PASSED for commit %s.\n' "$commit_sha" >&2
printf 'To launch the destructive installer, type exactly:\n' >&2
printf 'READINESS PASSED FOR %s AND AUTHORIZE INSTALLER LAUNCH\n> ' "$commit_sha" >&2
IFS= read -r acknowledgement </dev/tty
[[ $acknowledgement == "READINESS PASSED FOR $commit_sha AND AUTHORIZE INSTALLER LAUNCH" ]] ||
  die "Installer-launch acknowledgement did not match; no disk operation was started."

info "Launching installer commit $commit_sha. A third, target-specific storage-plan confirmation is still required."
exec bash "$repo_dir/stages/stage-2-basic-arch-install/scripts/k41-install-basic-arch.sh"
