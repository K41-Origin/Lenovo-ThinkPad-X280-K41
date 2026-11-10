#!/usr/bin/env bash
# AUR dependency resolver for the separately invoked desktop setup.
# This file is sourced by stages/stage-3-desktop-install/scripts/setup-desktop-x280.sh; it is not an entry point.

aur_dependency_name() {
  local dependency=$1
  dependency=${dependency%%[<=>]*}
  printf '%s' "$dependency"
}

aur_metadata_matches() {
  local metadata=$1 package_name=$2
  awk -v target="$package_name" '
    $1 == "pkgname" && $2 == "=" && $3 == target { found = 1 }
    $1 == "provides" && $2 == "=" {
      provided = $3
      sub(/[<=>].*$/, "", provided)
      if (provided == target) found = 1
    }
    END { exit !found }
  ' "$metadata"
}

aur_metadata_supports_x86_64() {
  local metadata=$1
  awk '
    $1 == "arch" && $2 == "=" && ($3 == "x86_64" || $3 == "any") { supported = 1 }
    END { exit !supported }
  ' "$metadata"
}

aur_metadata_dependencies() {
  local metadata=$1
  awk -F ' = ' '
    /^[[:space:]]*(depends|makedepends)(_x86_64)? = / { print $2 }
  ' "$metadata" | sort -u
}

# Resolve official/installed dependencies first. AUR packages are cloned,
# recursively inspected, built in dependency order, and individually approved.
# The one known upstream compatibility alias is explicit and fail-closed:
# python-materialyoucolor3 provides the legacy name required by caelestia-cli.
declare -gA K41_AUR_STATE=()

resolve_and_build_aur_dependency() {
  local requested=$1 package_name aur_dir commit dependency
  [[ -n $requested ]] || return 0
  if pacman -T "$requested" >/dev/null 2>&1; then
    info "Dependency already satisfied: $requested"
    return 0
  fi
  requested=$(aur_dependency_name "$requested")

  package_name=$requested
  if [[ $requested == python-materialyoucolor ]]; then
    package_name=python-materialyoucolor3
  fi

  if pacman -Si "$package_name" >/dev/null 2>&1; then
    info "Dependency available from configured official repositories: $package_name"
    return 0
  fi

  if [[ ${K41_AUR_STATE[$package_name]-} == done ]]; then
    return 0
  fi
  if [[ ${K41_AUR_STATE[$package_name]-} == visiting ]]; then
    die "Circular AUR dependency detected while resolving '$requested' (package '$package_name')."
  fi

  aur_dir="$aur_root/$package_name"
  K41_AUR_STATE[$package_name]=visiting

  if [[ ! -d $aur_dir ]]; then
    runuser -u "$desktop_user" -- git clone "https://aur.archlinux.org/${package_name}.git" "$aur_dir"
  fi
  [[ -f $aur_dir/PKGBUILD && -f $aur_dir/.SRCINFO ]] ||
    die "AUR checkout for $package_name is missing PKGBUILD or .SRCINFO."
  aur_metadata_matches "$aur_dir/.SRCINFO" "$package_name" ||
    die "AUR metadata for $package_name does not declare that package or a matching provider."
  aur_metadata_supports_x86_64 "$aur_dir/.SRCINFO" ||
    die "AUR package $package_name does not declare support for x86_64 or any architecture."
  if [[ $requested == python-materialyoucolor ]]; then
    grep -Eq '^[[:space:]]*pkgname = python-materialyoucolor3$' "$aur_dir/.SRCINFO" ||
      die 'Material You compatibility provider must be package python-materialyoucolor3.'
    grep -Eq '^[[:space:]]*pkgver = 3\.' "$aur_dir/.SRCINFO" ||
      die 'Caelestia CLI requires Material You color v3; python-materialyoucolor3 metadata is not version 3.x.'
    grep -Eq '^[[:space:]]*provides = python-materialyoucolor([<=>].*)?$' "$aur_dir/.SRCINFO" ||
      die 'python-materialyoucolor3 must provide the legacy python-materialyoucolor dependency.'
  fi

  # Materialize the dependency list before recursion. Keeping the loop's
  # process-substitution stream on stdin leaks the next dependency line into
  # nested makepkg/pacman prompts (e.g. "libpipewire" is read as [Y/n]).
  local -a dependencies=()
  mapfile -t dependencies < <(aur_metadata_dependencies "$aur_dir/.SRCINFO")
  for dependency in "${dependencies[@]}"; do
    [[ -n $dependency ]] || continue
    resolve_and_build_aur_dependency "$dependency"
  done

  commit=$(git -C "$aur_dir" rev-parse HEAD)
  printf '\n===== AUR package review: %s (commit %s) =====\n' "$package_name" "$commit"
  printf '\n===== PKGBUILD: %s =====\n' "$package_name"
  cat "$aur_dir/PKGBUILD"
  printf '\n===== .SRCINFO: %s =====\n' "$package_name"
  cat "$aur_dir/.SRCINFO"
  prompt_yes_no approve_aur "Approve this exact $package_name recipe and dependency metadata"
  [[ $approve_aur == yes ]] ||
    die "AUR package $package_name was not approved; stopping before its build."

  # Recompute .SRCINFO from the reviewed PKGBUILD only after explicit approval.
  # PKGBUILD parsing runs as the unprivileged builder, never as root.
  local generated_srcinfo
  generated_srcinfo=$(mktemp "$aur_dir/.SRCINFO.generated.XXXXXX")
  runuser -u "$desktop_user" -- bash -lc 'cd -- "$1" && makepkg --printsrcinfo' _ "$aur_dir" </dev/null >"$generated_srcinfo"
  if ! cmp -s "$aur_dir/.SRCINFO" "$generated_srcinfo"; then
    diff -u "$aur_dir/.SRCINFO" "$generated_srcinfo" || true
    rm -f -- "$generated_srcinfo"
    die "Generated .SRCINFO does not match the reviewed metadata for $package_name; refusing to build."
  fi
  rm -f -- "$generated_srcinfo"

  # Build as the regular user. --syncdeps may install official repo dependencies;
  # all discovered AUR dependencies have already been built by the recursion.
  # shellcheck disable=SC2016 # The nested login shell must expand $1 after runuser.
  runuser -u "$desktop_user" -- bash -lc 'cd -- "$1" && makepkg --syncdeps --install' _ "$aur_dir" </dev/tty

  if [[ $requested == python-materialyoucolor ]]; then
    pacman -T python-materialyoucolor >/dev/null 2>&1 ||
      die 'python-materialyoucolor3 did not satisfy caelestia-cli dependency python-materialyoucolor.'
  fi
  K41_AUR_STATE[$package_name]=done
}
