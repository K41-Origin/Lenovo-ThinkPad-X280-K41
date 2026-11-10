# K41-Dots Lock Screen

## Ownership

This directory is the canonical repository source for the K41-owned lock-screen overrides. It separates K41 implementation from the Caelestia upstream source tree.

## Source layout

```text
k41-dots/
└── modules/lock/
    ├── LockSurface.qml
    ├── Content.qml
    ├── Center.qml
    └── center/
        └── PasswordInput.qml
```

## Runtime integration

The installer deploys these files into the pinned Caelestia user source tree:

`~/.config/quickshell/caelestia/modules/lock/`

The files intentionally use Caelestia/Quickshell APIs and upstream components (`qs.*`, `Caelestia.Config`, PAM service objects, session-lock protocol). This is a K41-owned component integrated with Caelestia, **not a standalone lock manager or an independent shell**.

The installer must preserve the pinned upstream shell, authentication flow, PAM policy, fingerprint/Howdy policy, and session-lock protocol. It must only replace the four explicitly managed QML overrides after preflight and backup.

## Design contract

- Keep the upstream wallpaper/screencopy background and blur.
- Keep the outer lock surface transparent.
- Keep the password input as its own rounded surface.
- Center clock, date, password input, and state message as one group.
- Preserve upstream PAM and keyboard/focus handling.
- Do not change authentication policy for visual reasons.

## Validation

Run the Stage 5 static test:

```bash
bash stages/stage-5-desktop-customization/tests/test-lockscreen-design.sh
```

Run the read-only Caelestia audit as the regular desktop user:

```bash
bash stages/stage-5-desktop-customization/scripts/k41-audit-caelestia.sh
```

The audit compares these canonical files with the active user-local Caelestia lock module and records MATCH/MISMATCH/MISSING states. It does not deploy, modify, restart, or unlock anything.

QML loading, lock/unlock, wrong-password handling, wake/resume, and visual acceptance still require validation on the X280.
