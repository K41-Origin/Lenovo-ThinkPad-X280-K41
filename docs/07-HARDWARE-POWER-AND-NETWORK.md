# Hardware, Power, and Network

## Hardware discovery
The owner-reported Windows hardware baseline and evidence limitations are recorded in [X280 Hardware Baseline](13-X280-HARDWARE-BASELINE.md). Treat it as a planning reference, not runtime detection. Verify actual hardware from the Arch ISO/Linux system and discover Wi-Fi/Bluetooth devices before device-specific changes. Do not hard-code the baseline into installer behavior.

## Firmware and thermals
Install official firmware only when required for detected hardware and basic functionality. REQ-HW-006 owns the approved policy: report Intel microcode rather than install it automatically. The initial target-configuration script reports the `intel-ucode` recommendation but does not install it automatically, in accordance with REQ-HW-006. Use firmware/kernel thermal and fan control; no third-party fan controller. Monitor sensors only if supported and avoid undocumented tweaks.

## Power policy
Target a fixed Balanced profile without automatic AC/battery switching. Use power-profiles-daemon only if compatible. Avoid competing power managers and use one verified source of truth for suspend, hibernate, and lid actions.

## Network
NetworkManager is primary; Wi-Fi enabled by default. Bluetooth disabled by default and manually enabled. Before package installation check DNS, HTTPS, and official Arch repository connectivity. Diagnose/retry recoverable failures. If disconnected beyond the planned five-minute recovery window, attempt reconnecting for up to five minutes, then stop with instructions. Re-check connectivity and integrity after recovery.

Encrypted DNS failure must notify the user and wait for a manual decision; no automatic plaintext fallback. Automatic time synchronization is not planned.

## Suspend and hibernate
Short-break target: suspend; longer-idle target: hibernate only when configured and verified. Readiness checks do not replace manual hibernation testing.

## Acceptance
- [ ] Hardware inventory captured.
- [ ] One compatible power-management approach active.
- [ ] Wi-Fi/Bluetooth defaults match the plan.
- [ ] No unsupported fan controller.
- [ ] Power and hibernation claims have evidence.
- [ ] Intel microcode is recommendation-only as required by REQ-HW-006.
