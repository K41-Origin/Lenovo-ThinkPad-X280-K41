# Desktop and User Experience

## Session
Target Hyprland with Caelestia Shell / Quickshell, subject to verified upstream requirements. TTY login followed by automatic desktop launch only after integration is confirmed. No graphical login manager is planned.

## Interaction and appearance
- Dark theme and soft, balanced animations.
- Dynamic workspaces and keyboard shortcuts.
- Three-finger gestures only if hardware and software support are verified.
- Minimal startup: required desktop components, audio, network, notifications, and explicitly approved features.

## Utilities
Prefer supported built-in Caelestia/Hyprland features and verify dependencies before alternatives: power menu for shutdown/restart/suspend; hibernate only if configured and verified; built-in battery and screenshot support if available; lightweight file manager; required Wayland screen-sharing portal; Wayland-compatible clipboard manager with non-persistent history cleared at logout/reboot; recommended notifications without duplicate daemons; ZIP/TAR/GZIP/7z/RAR support where trusted packages exist. No default PDF reader or unrequested startup apps.

## Lid and power
Target suspend for short breaks and hibernate for longer idle. Verify a technically sound policy; a lid event alone cannot know how long the laptop will remain idle. Configure and test hibernation independently.

## Applications and privacy
Firefox is the main browser; do not install extensions or set default-app associations automatically. Bitwarden is preferred; verify distribution source and let the user sign in manually. Avoid creating project/work directories automatically.

## Acceptance
- [ ] Desktop launch follows verified upstream guidance.
- [ ] No duplicate portal, notification, clipboard, or power daemons.
- [ ] Unsupported features are not advertised.
- [ ] Locking/authentication after suspend and hibernate are checked.
- [ ] Hibernate menu entry appears only when readiness is verified.
