# X280 Desktop Customization

## Purpose

This is a dedicated stage that begins only after Desktop Functional Validation is accepted. Its purpose is to turn the working Hyprland and Caelestia/Quickshell environment into a visually polished, attractive, minimal desktop with a refined, premium impression.

## Approved visual direction

**Monochromatic, minimal, elegant, refined, and premium.** Use a restrained family of coordinated tones, deliberate contrast, clear hierarchy, and consistent details. Monochromatic must not mean low contrast, poor readability, or a flat interface without depth.

The overall result should feel intentional and cohesive rather than crowded or decorated for decoration's sake.

## Scope

- Establish a coherent monochrome palette: background, elevated surfaces, text, muted text, borders, and restrained accent treatment.
- Select typography and iconography with consistent weights, sizing, and visual rhythm.
- Define spacing, alignment, corner radii, borders, shadows, and surface depth consistently.
- Select a carefully composed wallpaper that supports the visual identity without competing with content.
- Style Caelestia panel, launcher, dashboard, widgets, notifications, and indicators as one system.
- Use subtle, purposeful transitions and animations; avoid excessive motion and visual noise.
- Maintain legibility and usable sizing on the X280's 1920×1080 internal display.
- Keep GTK/Qt application appearance reasonably consistent where supported and maintainable.

## Implementation principles

1. Finish functional desktop validation before beginning cosmetic changes.
2. Inspect current Hyprland, Caelestia, Quickshell, GTK, and Qt configuration and supported upstream options before editing.
3. Back up existing user configuration and preserve unrelated settings.
4. Keep theme tokens and component styling consistent; avoid duplicated or contradictory values.
5. Prefer supported configuration interfaces over brittle patches or undocumented internals.
6. Avoid unnecessary packages, duplicate background services, heavy blur/shadow effects, and animations that harm responsiveness.
7. Keep the manual TTY login and recovery path available until the customized session is stable.
8. Document each configuration change and provide a straightforward rollback.
9. Separate visual preferences from functional defects; styling must not conceal errors.

## Acceptance criteria

- A concise visual specification exists before bulk configuration changes.
- Palette, typography, iconography, spacing, and component treatment are coherent.
- Panel, launcher, dashboard, notifications, widgets, and indicators share the same visual language.
- Text, icons, focus states, and status indicators remain legible.
- Common interactions remain usable and desktop configuration reload/restart works.
- No new critical Hyprland, Quickshell, or Caelestia errors are introduced.
- Before/after screenshots are captured and reviewed on the physical X280.
- The owner completes and records the visual acceptance checklist.
- Changes are backed up, reproducible, and have documented rollback instructions.

## Out of scope

This stage does not include CPU/GPU tuning, thermal optimization, power/battery tuning, suspend/hibernate/resume testing, or extended system-stability campaigns. Those are reserved for the final hardware/system customization stage. Optional software integration follows this stage.

## Status

**PLANNED.** No visual customization is claimed as implemented or accepted by this document.
