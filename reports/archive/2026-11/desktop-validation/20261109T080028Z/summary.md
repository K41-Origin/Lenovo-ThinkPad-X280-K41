# K41 ThinkPad X280 automated desktop validation

- Captured (UTC): 2026-11-09T08:00:35Z
- Repository commit: 89269214c405344ae25879e98ce2f756e8654f65
- Result: **PASS_WITH_WARNINGS**
- Checks: 53 PASS, 3 WARN, 0 FAIL, 0 SKIP

## Findings requiring review

- **WARN** — Journal: user-journal: Actionable application, firmware, Bluetooth, PAM, or CPU-security warning found; inspect saved journal and repair report
- **WARN** — Journal: system-journal: Actionable application, firmware, Bluetooth, PAM, or CPU-security warning found; inspect saved journal and repair report
- **WARN** — Journal: kernel-journal: Actionable application, firmware, Bluetooth, PAM, or CPU-security warning found; inspect saved journal and repair report

## Interpretation

This is automated software/runtime/log validation only. It cannot prove that the panel, launcher, widgets, keyboard, TrackPoint, touchpad, speakers, microphone, brightness keys, Wi-Fi reconnect, screenshot flow, or lock screen behave correctly in real interaction. No physical or visual test is claimed. A PASS means only that no configured automated failure condition was detected in this snapshot.

## Report files

- checks.tsv: machine-readable PASS/WARN/FAIL/SKIP results
- validation.log: command output and detailed diagnostic collection
- diagnostics.tsv and diagnostics.log: focused read-only hardware, package, firmware, service, and kernel evidence
- cpu-*.txt, bluetooth-*.txt, pam-*.txt, and caelestia-pam-assets.txt: targeted Stage 4 evidence
- *.txt at report root: individual focused diagnostic captures
- environment.txt: host/session metadata
- desktop/ and caelestia/: supplemental diagnostic collectors
- *-journal*.txt: recent journal evidence; may be permission-limited

Review/redact all reports before pushing. Reports may contain usernames, hostnames, device identifiers, network state, paths, and log messages.
