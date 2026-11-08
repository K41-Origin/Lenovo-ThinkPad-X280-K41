# Testing and Acceptance

## Purpose and ownership

This document defines project-wide acceptance gates and the limits of test evidence. The executable test manifest, commands, test-by-test coverage, report formats, and live-validation procedures are maintained in the [Test Guide](../tests/README.md). Historical test plans and point-in-time observations are preserved in the [testing archive](archive/11-TESTING-AND-ACCEPTANCE-HISTORY-2026-11-08.md).

## Acceptance principles

- Every result applies only to the exact commit, environment, and test scope recorded with it.
- A passing automated suite does not prove a complete installation, successful boot, or physical hardware compatibility.
- Fixture and mock tests verify bounded logic and contracts; disposable loop-backed tests verify selected utility interfaces only.
- VM-based installer testing is out of scope (REQ-INSTALL-006). The destructive end-to-end installation and first-boot acceptance path is reserved for the actual ThinkPad X280, after all safety gates pass and the owner explicitly authorizes the exact target.
- A readiness PASS is evidence about a read-only snapshot, not authorization to erase a disk.
- A test that is skipped is not a pass. Missing evidence must remain NOT TESTED.

## Mandatory safety acceptance

A change affecting installation or storage is not acceptable unless the relevant tests demonstrate that:

1. The target is identified using the required stable identity and current topology evidence.
2. The complete proposed storage plan is displayed before final confirmation.
3. Cancellation, ambiguous identity, stale evidence, changed target, incomplete plan, or failed prerequisite stops the flow before destructive commands.
4. Tests explicitly assert zero destructive-command invocations for every failed safety gate.
5. A partial operation failure stops further execution, preserves diagnostic evidence, and does not trigger blind retry or automatic rollback.
6. Remote source code is reviewed before execution; a commit SHA alone is not proof of source safety.
7. Package signature/integrity checks remain enabled and logs/reports do not expose credentials or LUKS secrets.

## Boot and system acceptance

The initial installer is intended to create an encrypted Arch base system using the approved UEFI, systemd-boot, mkinitcpio UKI, LUKS2, and ext4 design. Acceptance must distinguish configuration generation from observed behavior.

- Verify the generated boot assets, kernel command line, ESP mount, fstab, encrypted-root unlock path, and post-install configuration.
- Verify kernel/UKI update behavior and recovery from a failed boot-artifact update.
- Verify wrong-passphrase, missing-device, and malformed boot-parameter failure paths.
- Verify swapfile mapping, resume device, and actual offset before describing hibernation as ready.
- Test suspend, hibernate, resume, Wi-Fi, audio, battery, thermal behavior, and desktop components on the physical X280. Do not infer success from configuration files or mock tests.

Detailed test IDs and planned UKI, encryption, resume, storage, bootstrap, and recovery cases remain in the archived test plan until they are implemented or deliberately promoted into the active test suite. The archive is historical planning material, not evidence that those tests currently run.

## Release acceptance gate

A release candidate requires:

- Approved requirements and architecture with no unresolved safety-critical conflict.
- Passing relevant Bash syntax, lint/format, and repository tests for the exact candidate commit.
- Reviewed source/package dependencies and documented upstream compatibility.
- Explicit evidence for every claim marked TESTED or VERIFIED.
- Documented limitations, failure handling, and operator recovery instructions.
- No unresolved critical safety failure.

Physical installer execution is TESTED: trial 4 completed with exit status 0 and generated the UKI. Successful boot from the internal SSD, firmware UKI discovery, LUKS unlock/root mount, First Boot/first login, LUKS recovery, suspend/resume/hibernation, and desktop/hardware integration remain NOT TESTED until observed and recorded on the actual laptop.

## How to run tests

From the repository root:

```bash
bash tests/run.sh
```

See the [Test Guide](../tests/README.md) for prerequisites, suite composition, report locations, live Arch ISO checks, first-boot evidence collection, and interpretation of PASS/FAIL/SKIP. Current CI commit-to-run mappings and implementation state belong only in [Implementation Status](12-IMPLEMENTATION-STATUS-AND-CHANGELOG.md).


## Project-stage acceptance order

Project acceptance follows the approved sequence in [Requirements and Decisions](02-REQUIREMENTS-AND-DECISIONS.md):

1. **Desktop functional validation — current priority.** Complete the physical X280 checklist for Hyprland/Caelestia interaction, display, keyboard, touchpad/TrackPoint, audio, Wi-Fi, required Bluetooth behavior, portals, lock/logout, and TTY recovery. Mark unavailable or untested functions honestly; setup-script success alone is insufficient.
2. **Optional software integration.** Validate only the optional components actually selected by the owner. BlackArch remains optional and must be limited to individually reviewed tools.
3. **Final hardware/system customization — deferred.** Only after stages 1 and 2 are accepted, conduct hardware/performance tuning, CPU/GPU/thermal and power/battery evaluation, suspend/hibernate/resume testing, and extended stability/regression testing.

The final-stage work must use a documented baseline and change one variable at a time. Capture before/after evidence, retain rollback instructions, and distinguish short functional checks from sustained stability tests. No hardware tuning, battery optimization, or suspend/resume campaign is part of the current stage. This ordering can change only through an explicit project decision.
