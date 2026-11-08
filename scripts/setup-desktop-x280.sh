#!/usr/bin/env bash
# Install a testable Hyprland + Quickshell + Caelestia session on an existing Arch system.
set -Eeuo pipefail
umask 077

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf 'INFO: %s\n' "$*" >&2; }
prompt_yes_no() {
  local __result=$1 label=$2 answer
  [[ -r /dev/tty && -w /dev/tty ]] || die 'Interactive terminal required.'
  IFS= read -r -p "$label [y/N]: " answer </dev/tty
  [[ $answer == [yY] ]] && printf -v "$__result" yes || printf -v "$__result" no
}

# Every invocation gets a private, timestamped report, including preflight failures.
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "$script_dir/.." && pwd -P)"
report_root="$repo_root/reports/desktop"
started_utc="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
mkdir -p -- "$report_root"
run_dir="$report_root/$timestamp"
suffix=0
while ! mkdir -- "$run_dir" 2>/dev/null; do
  suffix=$((suffix + 1))
  run_dir="$report_root/$timestamp-$suffix"
done
chmod 0700 "$run_dir"
setup_log="$run_dir/setup.log"
: >"$setup_log"
chmod 0600 "$setup_log"
exec > >(tee -a "$setup_log") 2>&1

write_system_snapshot() {
  {
    printf 'Captured (UTC): %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    printf 'Repository: %s\n' "$repo_root"
    printf 'Commit: '
    git -C "$repo_root" rev-parse HEAD 2>/dev/null || printf 'unknown\n'
    printf 'Working tree: '
    git -C "$repo_root" status --short 2>/dev/null || printf 'unavailable\n'
    printf 'Hostname: %s\n' "$(hostname 2>/dev/null || printf unknown)"
    printf 'Kernel: %s\n' "$(uname -sr 2>/dev/null || printf unknown)"
    printf 'Architecture: %s\n' "$(uname -m 2>/dev/null || printf unknown)"
    printf 'Arch release: '
    if [[ -r /etc/arch-release ]]; then cat /etc/arch-release; else printf 'unavailable\n'; fi
    printf 'Invoker: %s\n' "${SUDO_USER:-unknown}"
    printf 'Script: %s\n' "$script_dir/setup-desktop-x280.sh"
  } >"$run_dir/system-info.txt"
  chmod 0600 "$run_dir/system-info.txt"
}

capture_packages() {
  local destination=$1
  if command -v pacman >/dev/null 2>&1; then
    pacman -Q >"$destination" 2>&1 || printf 'ERROR: pacman -Q failed (exit %s)\n' "$?" >>"$destination"
  else
    printf 'pacman unavailable\n' >"$destination"
  fi
  chmod 0600 "$destination"
}

write_system_snapshot
capture_packages "$run_dir/packages-before.txt"
printf 'Desktop setup attempt started: %s\n' "$run_dir"
printf 'Setup log: %s\n' "$setup_log"

on_setup_error() {
  local rc=$1 line=$2 command=$3
  printf 'ERROR: command failed (exit %s) at line %s: %s\n' "$rc" "$line" "$command" >&2
  exit "$rc"
}
on_setup_exit() {
  local rc=$?
  trap - EXIT
  capture_packages "$run_dir/packages-after.txt"
  {
    printf '# Desktop setup attempt\n\n'
    printf -- '- Started (UTC): %s\n' "$started_utc"
    printf -- '- Finished (UTC): %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    printf -- '- Exit status: %s\n' "$rc"
    if ((rc == 0)); then printf -- '- Result: **PASS**\n'; else printf -- '- Result: **FAIL**\n'; fi
    printf -- '- Repository commit: '
    git -C "$repo_root" rev-parse HEAD 2>/dev/null || printf 'unknown\n'
    printf '%s\n' '- Log: setup.log'
    printf '%s\n' '- System snapshot: system-info.txt'
    printf '%s\n' '- Package snapshots: packages-before.txt, packages-after.txt'
    printf '\nA successful setup-script exit confirms only that this script completed. It does not prove a physical Hyprland session or hardware behavior. Review and redact reports before sharing.\n'
  } >"$run_dir/summary.md"
  chmod 0600 "$run_dir/summary.md"
  printf 'Desktop setup report: %s\n' "$run_dir"
  printf 'Desktop setup exit status: %s\n' "$rc"
  exit "$rc"
}
trap 'on_setup_error "$?" "$LINENO" "$BASH_COMMAND"' ERR
trap on_setup_exit EXIT

(( EUID == 0 )) || die 'Run with sudo from the installed Arch system.'
[[ -f /etc/arch-release ]] || die 'This must run on the installed Arch Linux system, not the Arch ISO or a chroot.'
[[ $(uname -m) == x86_64 ]] || die 'Only x86_64 is supported.'
[[ -t 0 && -r /dev/tty && -w /dev/tty ]] || die 'An interactive local TTY is required.'
[[ -n ${SUDO_USER:-} && $SUDO_USER != root ]] || die 'Run as the regular desktop user, for example: sudo bash scripts/setup-desktop-x280.sh'
id "$SUDO_USER" >/dev/null 2>&1 || die 'SUDO_USER does not identify an existing account.'
id -nG "$SUDO_USER" | tr ' ' '\n' | grep -qx wheel || die 'The desktop account must belong to wheel.'
if [[ -n ${WAYLAND_DISPLAY:-} || -n ${DISPLAY:-} ]]; then die 'Run from a TTY, not from inside an active graphical session.'; fi

proceed='' install_caelestia=''
desktop_user=$SUDO_USER
desktop_home=$(getent passwd "$desktop_user" | cut -d: -f6)
[[ -n $desktop_home && -d $desktop_home ]] || die 'Could not resolve the desktop user home directory.'
[[ ! -e $desktop_home/.config/hypr/hyprland.conf ]] || die 'Existing Hyprland config found; refusing to overwrite it.'
[[ ! -e $desktop_home/.config/quickshell/caelestia ]] || die 'Existing Caelestia config found; refusing to overwrite it.'
[[ ! -e $desktop_home/.config/xdg-desktop-portal/hyprland-portals.conf ]] || die 'Existing Hyprland portal preference found; refusing to overwrite it.'

cat <<'NOTICE'
This setup installs a minimal Wayland desktop on the CURRENT installed system.
It does not repartition disks, change boot settings, enable a display manager,
auto-login, change firewall policy, enable Bluetooth, or configure hibernation.
The official Arch packages are installed first. Caelestia is an AUR package;
its PKGBUILD will be shown for manual review and built as the regular user.
NOTICE
prompt_yes_no proceed 'Install Hyprland, Quickshell, audio, portal, and desktop utilities'
[[ $proceed == yes ]] || die 'Cancelled without changes.'
prompt_yes_no install_caelestia 'Install Caelestia Shell and its reviewed AUR dependencies'

packages=(
  hyprland xdg-desktop-portal xdg-desktop-portal-hyprland
  xdg-desktop-portal-gtk pipewire pipewire-audio pipewire-pulse wireplumber
  polkit hyprpolkitagent hyprlock wofi foot thunar firefox
  grim slurp wl-clipboard cliphist swappy brightnessctl playerctl
  pavucontrol xdg-user-dirs xorg-xwayland mesa vulkan-intel
  noto-fonts noto-fonts-emoji ttf-dejavu
)
if [[ $install_caelestia == yes ]]; then
  # Caelestia's AUR metadata requires quickshell-git, which conflicts with
  # the official quickshell package. Build tools/runtime dependencies come
  # from configured signature-verified official repositories.
  packages+=(base-devel git ddcutil libnotify dart-sass gpu-screen-recorder fuzzel)
else
  packages+=(quickshell)
fi
info 'Installing packages only from configured, signature-verified Arch repositories.'
pacman -Syu --needed "${packages[@]}"

# Build the AUR dependency chain explicitly. makepkg --syncdeps resolves
# dependencies from configured pacman repositories; it does not build AUR packages.
if [[ $install_caelestia == yes ]]; then
  aur_root="$desktop_home/.cache/k41-aur/$timestamp"
  install -d -m 0700 -o "$desktop_user" -g "$(id -gn "$desktop_user")" "$aur_root"

  check_aur_dependencies() {
    local package_name=$1 aur_dir=$2 dependency
    while IFS= read -r dependency; do
      dependency=${dependency%%[<=>]*}
      [[ -n $dependency ]] || continue
      if ! pacman -T "$dependency" >/dev/null 2>&1 && ! pacman -Si "$dependency" >/dev/null 2>&1; then
        die "AUR package $package_name has unresolved dependency '$dependency'; it is neither installed nor available from configured official repositories. Extend and review the AUR dependency order before proceeding."
      fi
    done < <(awk -F ' = ' '/^[[:space:]]*(depends|makedepends)(_[[:alnum:]_]+)? = / { print $2 }' "$aur_dir/.SRCINFO" | sort -u)
  }

  build_aur_package() {
    local package_name=$1 aur_dir="$aur_root/$1" commit
    runuser -u "$desktop_user" -- git clone "https://aur.archlinux.org/${package_name}.git" "$aur_dir"
    [[ -f $aur_dir/PKGBUILD && -f $aur_dir/.SRCINFO ]] || die "AUR checkout for $package_name is missing PKGBUILD or .SRCINFO."
    if [[ $package_name == caelestia-shell ]]; then
      grep -Eq '^[[:space:]]*depends = quickshell-git$' "$aur_dir/.SRCINFO" || die 'caelestia-shell AUR dependency metadata changed: quickshell-git is not declared; review/update the build order before proceeding.'
      grep -Eq '^[[:space:]]*depends = caelestia-cli$' "$aur_dir/.SRCINFO" || die 'caelestia-shell AUR dependency metadata changed: caelestia-cli is not declared; review/update the build order before proceeding.'
    fi
    commit=$(git -C "$aur_dir" rev-parse HEAD)
    printf '\n===== AUR package review: %s (commit %s) =====\n' "$package_name" "$commit"
    printf '\n===== PKGBUILD: %s =====\n' "$package_name"
    cat "$aur_dir/PKGBUILD"
    printf '\n===== .SRCINFO: %s =====\n' "$package_name"
    cat "$aur_dir/.SRCINFO"
    check_aur_dependencies "$package_name" "$aur_dir"
    prompt_yes_no approve_aur "Approve this exact $package_name recipe and dependency metadata"
    [[ $approve_aur == yes ]] || die "AUR package $package_name was not approved; stopping before its build."
    runuser -u "$desktop_user" -- bash -lc 'cd -- "$1" && makepkg --syncdeps --install' _ "$aur_dir"
  }

  # Refuse an unexpected dependency graph rather than silently omitting an AUR provider.
  for package_name in quickshell-git caelestia-cli caelestia-shell; do
    build_aur_package "$package_name"
  done
  pacman -Q quickshell-git caelestia-cli caelestia-shell
else
  info 'Caelestia AUR installation skipped; the official Quickshell package will be used.'
fi

install -d -m 0755 -o "$desktop_user" -g "$(id -gn "$desktop_user")" "$desktop_home/.config/hypr"
config_tmp=$(mktemp "$desktop_home/.config/hypr/.hyprland.conf.k41.XXXXXX")
cat >"$config_tmp" <<'HYPR'
# K41 minimal ThinkPad X280 Hyprland test configuration.
# Start manually from TTY with: Hyprland
$mainMod = SUPER
monitor = , preferred, auto, 1

input {
    kb_layout = us
    follow_mouse = 1
    touchpad {
        natural_scroll = true
        tap-to-click = true
        disable_while_typing = true
    }
}

general {
    gaps_in = 4
    gaps_out = 8
    border_size = 2
    layout = dwindle
}

decoration {
    rounding = 8
    active_opacity = 1.0
    inactive_opacity = 0.96
}

animations {
    enabled = true
    bezier = easeOutQuint, 0.23, 1, 0.32, 1
    animation = windows, 1, 4, easeOutQuint
    animation = workspaces, 1, 4, easeOutQuint
    animation = fade, 1, 4, easeOutQuint
}

$terminal = foot
$fileManager = thunar
bind = $mainMod, RETURN, exec, $terminal
bind = $mainMod, E, exec, $fileManager
bind = $mainMod, Q, killactive
bind = $mainMod, M, exit
bind = $mainMod, F, fullscreen
bind = $mainMod, V, togglefloating
bind = $mainMod, SPACE, exec, wofi --show drun
bind = $mainMod, L, exec, hyprlock
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

# Start the shell only when its package is installed.
exec-once = systemctl --user start pipewire.socket pipewire-pulse.socket wireplumber.service
exec-once = systemctl --user start hyprpolkitagent.service
HYPR
chmod 0644 "$config_tmp"
chown "$desktop_user:$(id -gn "$desktop_user")" "$config_tmp"
mv -- "$config_tmp" "$desktop_home/.config/hypr/hyprland.conf"

if [[ $install_caelestia == yes ]]; then
  command -v caelestia >/dev/null 2>&1 || die 'Caelestia package is installed but its CLI executable is missing.'
  printf '%s\n' 'exec-once = caelestia shell -d' >>"$desktop_home/.config/hypr/hyprland.conf"
fi

# Validate files and binaries without starting a graphical session or changing the login target.
for binary in start-hyprland Hyprland qs foot thunar; do
  command -v "$binary" >/dev/null 2>&1 || die "Required desktop executable missing after package install: $binary"
done
[[ -s $desktop_home/.config/hypr/hyprland.conf ]] || die 'Hyprland configuration was not written.'
chown -R "$desktop_user:$(id -gn "$desktop_user")" "$desktop_home/.config/hypr"
portal_dir="$desktop_home/.config/xdg-desktop-portal"
install -d -m 0755 -o "$desktop_user" -g "$(id -gn "$desktop_user")" "$portal_dir"
portal_tmp=$(mktemp "$portal_dir/.hyprland-portals.conf.k41.XXXXXX")
cat >"$portal_tmp" <<'PORTALS'
[preferred]
default=gtk
org.freedesktop.impl.portal.Screenshot=hyprland
org.freedesktop.impl.portal.ScreenCast=hyprland
PORTALS
chmod 0644 "$portal_tmp"
chown "$desktop_user:$(id -gn "$desktop_user")" "$portal_tmp"
mv -- "$portal_tmp" "$portal_dir/hyprland-portals.conf"
info 'Desktop setup completed. No graphical session was started and no automatic TTY launch was configured.'
info 'Log out to TTY1, sign in as the regular user, then run: start-hyprland'
 "$aur_dir/.SRCINFO" || die 'caelestia-shell AUR dependency metadata changed: quickshell-git is not declared; review/update the build order before proceeding.'
      grep -Eq '^[[:space:]]*depends = caelestia-cli$(git -C "$aur_dir" rev-parse HEAD)
    printf '\n===== AUR package review: %s (commit %s) =====\n' "$package_name" "$commit"
    printf '\n===== PKGBUILD: %s =====\n' "$package_name"
    cat "$aur_dir/PKGBUILD"
    printf '\n===== .SRCINFO: %s =====\n' "$package_name"
    cat "$aur_dir/.SRCINFO"
    prompt_yes_no approve_aur "Approve this exact $package_name recipe and dependency metadata"
    [[ $approve_aur == yes ]] || die "AUR package $package_name was not approved; stopping before its build."
    runuser -u "$desktop_user" -- bash -lc 'cd -- "$1" && makepkg --syncdeps --install' _ "$aur_dir"
  }

  # Refuse an unexpected dependency graph rather than silently omitting an AUR provider.
  for package_name in quickshell-git caelestia-cli caelestia-shell; do
    build_aur_package "$package_name"
  done
  pacman -Q quickshell-git caelestia-cli caelestia-shell
else
  info 'Caelestia AUR installation skipped; the official Quickshell package will be used.'
fi

install -d -m 0755 -o "$desktop_user" -g "$(id -gn "$desktop_user")" "$desktop_home/.config/hypr"
config_tmp=$(mktemp "$desktop_home/.config/hypr/.hyprland.conf.k41.XXXXXX")
cat >"$config_tmp" <<'HYPR'
# K41 minimal ThinkPad X280 Hyprland test configuration.
# Start manually from TTY with: Hyprland
$mainMod = SUPER
monitor = , preferred, auto, 1

input {
    kb_layout = us
    follow_mouse = 1
    touchpad {
        natural_scroll = true
        tap-to-click = true
        disable_while_typing = true
    }
}

general {
    gaps_in = 4
    gaps_out = 8
    border_size = 2
    layout = dwindle
}

decoration {
    rounding = 8
    active_opacity = 1.0
    inactive_opacity = 0.96
}

animations {
    enabled = true
    bezier = easeOutQuint, 0.23, 1, 0.32, 1
    animation = windows, 1, 4, easeOutQuint
    animation = workspaces, 1, 4, easeOutQuint
    animation = fade, 1, 4, easeOutQuint
}

$terminal = foot
$fileManager = thunar
bind = $mainMod, RETURN, exec, $terminal
bind = $mainMod, E, exec, $fileManager
bind = $mainMod, Q, killactive
bind = $mainMod, M, exit
bind = $mainMod, F, fullscreen
bind = $mainMod, V, togglefloating
bind = $mainMod, SPACE, exec, wofi --show drun
bind = $mainMod, L, exec, hyprlock
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

# Start the shell only when its package is installed.
exec-once = systemctl --user start pipewire.socket pipewire-pulse.socket wireplumber.service
exec-once = systemctl --user start hyprpolkitagent.service
HYPR
chmod 0644 "$config_tmp"
chown "$desktop_user:$(id -gn "$desktop_user")" "$config_tmp"
mv -- "$config_tmp" "$desktop_home/.config/hypr/hyprland.conf"

if pacman -Qq caelestia-shell >/dev/null 2>&1; then
  printf '%s\n' 'exec-once = caelestia shell -d' >>"$desktop_home/.config/hypr/hyprland.conf"
fi

# Validate files and binaries without starting a graphical session or changing the login target.
for binary in start-hyprland Hyprland qs foot thunar; do
  command -v "$binary" >/dev/null 2>&1 || die "Required desktop executable missing after package install: $binary"
done
[[ -s $desktop_home/.config/hypr/hyprland.conf ]] || die 'Hyprland configuration was not written.'
chown -R "$desktop_user:$(id -gn "$desktop_user")" "$desktop_home/.config/hypr"
portal_dir="$desktop_home/.config/xdg-desktop-portal"
install -d -m 0755 -o "$desktop_user" -g "$(id -gn "$desktop_user")" "$portal_dir"
portal_tmp=$(mktemp "$portal_dir/.hyprland-portals.conf.k41.XXXXXX")
cat >"$portal_tmp" <<'PORTALS'
[preferred]
default=gtk
org.freedesktop.impl.portal.Screenshot=hyprland
org.freedesktop.impl.portal.ScreenCast=hyprland
PORTALS
chmod 0644 "$portal_tmp"
chown "$desktop_user:$(id -gn "$desktop_user")" "$portal_tmp"
mv -- "$portal_tmp" "$portal_dir/hyprland-portals.conf"
info 'Desktop setup completed. No graphical session was started and no automatic TTY launch was configured.'
info 'Log out to TTY1, sign in as the regular user, then run: start-hyprland'
 "$aur_dir/.SRCINFO" || die 'caelestia-shell AUR dependency metadata changed: caelestia-cli is not declared; review/update the build order before proceeding.'
    fi
    commit=$(git -C "$aur_dir" rev-parse HEAD)
    printf '\n===== AUR package review: %s (commit %s) =====\n' "$package_name" "$commit"
    printf '\n===== PKGBUILD: %s =====\n' "$package_name"
    cat "$aur_dir/PKGBUILD"
    printf '\n===== .SRCINFO: %s =====\n' "$package_name"
    cat "$aur_dir/.SRCINFO"
    prompt_yes_no approve_aur "Approve this exact $package_name recipe and dependency metadata"
    [[ $approve_aur == yes ]] || die "AUR package $package_name was not approved; stopping before its build."
    runuser -u "$desktop_user" -- bash -lc 'cd -- "$1" && makepkg --syncdeps --install' _ "$aur_dir"
  }

  # Refuse an unexpected dependency graph rather than silently omitting an AUR provider.
  for package_name in quickshell-git caelestia-cli caelestia-shell; do
    build_aur_package "$package_name"
  done
  pacman -Q quickshell-git caelestia-cli caelestia-shell
else
  info 'Caelestia AUR installation skipped; the official Quickshell package will be used.'
fi

install -d -m 0755 -o "$desktop_user" -g "$(id -gn "$desktop_user")" "$desktop_home/.config/hypr"
config_tmp=$(mktemp "$desktop_home/.config/hypr/.hyprland.conf.k41.XXXXXX")
cat >"$config_tmp" <<'HYPR'
# K41 minimal ThinkPad X280 Hyprland test configuration.
# Start manually from TTY with: Hyprland
$mainMod = SUPER
monitor = , preferred, auto, 1

input {
    kb_layout = us
    follow_mouse = 1
    touchpad {
        natural_scroll = true
        tap-to-click = true
        disable_while_typing = true
    }
}

general {
    gaps_in = 4
    gaps_out = 8
    border_size = 2
    layout = dwindle
}

decoration {
    rounding = 8
    active_opacity = 1.0
    inactive_opacity = 0.96
}

animations {
    enabled = true
    bezier = easeOutQuint, 0.23, 1, 0.32, 1
    animation = windows, 1, 4, easeOutQuint
    animation = workspaces, 1, 4, easeOutQuint
    animation = fade, 1, 4, easeOutQuint
}

$terminal = foot
$fileManager = thunar
bind = $mainMod, RETURN, exec, $terminal
bind = $mainMod, E, exec, $fileManager
bind = $mainMod, Q, killactive
bind = $mainMod, M, exit
bind = $mainMod, F, fullscreen
bind = $mainMod, V, togglefloating
bind = $mainMod, SPACE, exec, wofi --show drun
bind = $mainMod, L, exec, hyprlock
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

# Start the shell only when its package is installed.
exec-once = systemctl --user start pipewire.socket pipewire-pulse.socket wireplumber.service
exec-once = systemctl --user start hyprpolkitagent.service
HYPR
chmod 0644 "$config_tmp"
chown "$desktop_user:$(id -gn "$desktop_user")" "$config_tmp"
mv -- "$config_tmp" "$desktop_home/.config/hypr/hyprland.conf"

if pacman -Qq caelestia-shell >/dev/null 2>&1; then
  printf '%s\n' 'exec-once = caelestia shell -d' >>"$desktop_home/.config/hypr/hyprland.conf"
fi

# Validate files and binaries without starting a graphical session or changing the login target.
for binary in start-hyprland Hyprland qs foot thunar; do
  command -v "$binary" >/dev/null 2>&1 || die "Required desktop executable missing after package install: $binary"
done
[[ -s $desktop_home/.config/hypr/hyprland.conf ]] || die 'Hyprland configuration was not written.'
chown -R "$desktop_user:$(id -gn "$desktop_user")" "$desktop_home/.config/hypr"
portal_dir="$desktop_home/.config/xdg-desktop-portal"
install -d -m 0755 -o "$desktop_user" -g "$(id -gn "$desktop_user")" "$portal_dir"
portal_tmp=$(mktemp "$portal_dir/.hyprland-portals.conf.k41.XXXXXX")
cat >"$portal_tmp" <<'PORTALS'
[preferred]
default=gtk
org.freedesktop.impl.portal.Screenshot=hyprland
org.freedesktop.impl.portal.ScreenCast=hyprland
PORTALS
chmod 0644 "$portal_tmp"
chown "$desktop_user:$(id -gn "$desktop_user")" "$portal_tmp"
mv -- "$portal_tmp" "$portal_dir/hyprland-portals.conf"
info 'Desktop setup completed. No graphical session was started and no automatic TTY launch was configured.'
info 'Log out to TTY1, sign in as the regular user, then run: start-hyprland'
