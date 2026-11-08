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
exec > >(tee -a "$setup_log") 2>&1
chmod 0600 "$setup_log"

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
  local rc=$? line=$1 command=$2
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
    printf -- '- Log: `setup.log`\n'
    printf -- '- System snapshot: `system-info.txt`\n'
    printf -- '- Package snapshots: `packages-before.txt`, `packages-after.txt`\n'
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

proceed='' install_caelestia='' approve_aur=''
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

packages=(
  hyprland quickshell xdg-desktop-portal xdg-desktop-portal-hyprland
  xdg-desktop-portal-gtk pipewire pipewire-audio pipewire-pulse wireplumber
  polkit hyprpolkitagent hyprlock wofi foot thunar firefox
  grim slurp wl-clipboard cliphist swappy brightnessctl playerctl
  pavucontrol xdg-user-dirs xorg-xwayland mesa vulkan-intel
  noto-fonts noto-fonts-emoji ttf-dejavu
)
info 'Installing packages only from configured, signature-verified Arch repositories.'
pacman -Syu --needed "${packages[@]}"

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

# AUR is never trusted implicitly: show the recipe, require an explicit review decision,
# and build/install as the unprivileged account (makepkg itself refuses root).
prompt_yes_no install_caelestia 'Fetch the stable caelestia-shell AUR recipe for review and build it'
if [[ $install_caelestia == yes ]]; then
  command -v git >/dev/null 2>&1 || pacman -S --needed git
  aur_dir="$desktop_home/.cache/k41-aur/caelestia-shell"
  [[ ! -e $aur_dir ]] || die "AUR checkout already exists at $aur_dir; inspect/remove it manually before retry."
  install -d -m 0755 -o "$desktop_user" -g "$(id -gn "$desktop_user")" "$(dirname "$aur_dir")"
  runuser -u "$desktop_user" -- git clone https://aur.archlinux.org/caelestia-shell.git "$aur_dir"
  [[ -f $aur_dir/PKGBUILD && -f $aur_dir/.SRCINFO ]] || die 'AUR checkout is missing PKGBUILD or .SRCINFO.'
  printf '\n===== AUR PKGBUILD (review before build) =====\n'
  sed -n '1,240p' "$aur_dir/PKGBUILD"
  printf '\n===== AUR .SRCINFO =====\n'
  sed -n '1,240p' "$aur_dir/.SRCINFO"
  prompt_yes_no approve_aur 'Do you approve this exact AUR recipe and its dependencies'
  [[ $approve_aur == yes ]] || die "AUR build declined. Official Hyprland/Quickshell foundation and config remain installed."
  runuser -u "$desktop_user" -- bash -lc "cd '$aur_dir' && makepkg --syncdeps --install"
else
  info 'Caelestia AUR installation skipped by choice; Hyprland + Quickshell remain available for validation.'
fi

if pacman -Qq caelestia-shell >/dev/null 2>&1; then
  printf '%s\n' 'exec-once = qs -c caelestia' >>"$desktop_home/.config/hypr/hyprland.conf"
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
