# K41 Horizontal Workspace Dock

## Scope

Installs a separate, bottom-edge workspace dock for the Caelestia/Quickshell
source checkout. The upstream vertical bar entries are disabled in the user's
runtime `shell.json`; the rest of the shell configuration is preserved.

The dock:
- displays workspaces belonging to the current monitor;
- highlights the active workspace and marks occupied workspaces;
- switches workspace on click;
- reveals on bottom-edge hover and remains visible while hovered;
- uses no exclusive zone, so it does not reserve workspace layout space;
- hides while the active workspace has a fullscreen toplevel.

## Install

From the project root:

```bash
bash stages/stage-5-desktop-customization/scripts/k41-install-caelestia-dock.sh --check
bash stages/stage-5-desktop-customization/scripts/k41-install-caelestia-dock.sh --install
```

The script refuses root execution. It requires the active source checkout at
`~/.config/quickshell/caelestia` and runtime config at
`~/.config/caelestia/shell.json`. Override the source path with
`K41_CAELSTIA_SOURCE=/path/to/caelestia` if needed.

Before the first write, it backs up:
- source `shell.qml`;
- source `modules/k41dock/K41Dock.qml` (or records that it did not exist);
- runtime `shell.json`.

Backups and logs are stored under
`$XDG_STATE_HOME/k41/backups/caelestia-dock/<timestamp>/` (or
`~/.local/state/k41/backups/caelestia-dock/`). The script prints the exact
backup directory. No sudo, package installation, service restart, Quickshell
reload, or automatic upload is performed.

## Rollback

Use the exact backup directory printed by the installer:

```bash
bash stages/stage-5-desktop-customization/scripts/k41-install-caelestia-dock.sh --rollback "$HOME/.local/state/k41/backups/caelestia-dock/<timestamp>"
```

Rollback restores only the three managed targets and removes the dock QML file
if it did not exist before installation.

## Important limitations

This is an initial implementation, not yet runtime-verified on the ThinkPad.
The dock uses Quickshell's PanelWindow/Hyprland APIs and needs validation against
the installed Quickshell version. The full-width transparent layer window has
no exclusive zone; pointer/click-through behavior and fullscreen behavior must
be checked on-device. Do not classify it as VERIFIED until those checks pass.
