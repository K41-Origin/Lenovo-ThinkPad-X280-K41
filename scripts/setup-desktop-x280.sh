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

(( EUID == 0 )) || die 'Run with sudo from the installed Arch system.'
[[ -f /etc/arch-release ]] || die 'This must run on the installed Arch Linux system, not the Arch ISO or a chroot.'
[[ $(uname -m) == x86_64 ]] || die 'Only x86_64 is supported.'
[[ -t 0 && -r /dev/tty && -w /dev/tty ]] || die 'An interactive local TTY is required.'
[[ -n ${SUDO_USER:-} && $SUDO_USER != root ]] || die 'Run as the regular desktop user, for example: sudo bash scripts/setup-desktop-x280.sh'
id "$SUDO_USER" >/dev/null 2>&1 || die 'SUDO_USER does not identify an existing account.'
id -nG "$SUDO_USER" | tr ' ' '\n' | grep -qx wheel || die 'The desktop account must belong to wheel.'
if [[ -n ${WAYLAND_DISPLAY:-} || -n ${DISPLAY:-} ]]; then die 'Run from a TTY, not from inside an active graphical session.'; fi

desktop_user=$SUDO_USER
desktop_home=$(getent passwd "$desktop_user" | cut -d: -f6)
[[ -n $desktop_home && -d $desktop_home ]] || die 'Could not resolve the desktop user home directory.'
[[ ! -e $desktop_home/.config/hypr/hyprland.conf ]] || die 'Existing Hyprland config found; refusing to overwrite it.'
[[ ! -e $desktop_home/.config/quickshell/caelestia ]] || die 'Existing Caelestia config found; refusing to overwrite it.'

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
  polkit hyprpolkitagent foot thunar firefox
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
bind = $mainMod, SPACE, exec, caelestia shell drawers
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
exec-once = /usr/lib/polkit-kde-authentication-agent-1
exec-once = hyprpolkitagent
exec-once = qs -c caelestia
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

# Validate files and binaries without starting a graphical session or changing the login target.
for binary in Hyprland qs foot thunar; do
  command -v "$binary" >/dev/null 2>&1 || die "Required desktop executable missing after package install: $binary"
done
[[ -s $desktop_home/.config/hypr/hyprland.conf ]] || die 'Hyprland configuration was not written.'
chown -R "$desktop_user:$(id -gn "$desktop_user")" "$desktop_home/.config/hypr"
info 'Desktop setup completed. No graphical session was started and no automatic TTY launch was configured.'
info 'Log out to TTY1, sign in as the regular user, then run: Hyprland'
