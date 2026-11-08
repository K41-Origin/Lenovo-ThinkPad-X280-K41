# Error Recovery and Reporting

## Progress and diagnostics
Report the current stage and meaningful progress. Show ETA only when credibly estimable. Temporary diagnostics may include stage, timestamp, package/operation, error, exit status, and retry attempted. Redact secrets; never log passwords, LUKS keys, tokens, or credentials.

## Network failures
Check DNS, HTTPS, and Arch repository connectivity before package installation. Diagnose/retry recoverable failures. If connectivity remains unavailable beyond the planned five-minute recovery window, attempt reconnecting for up to five minutes, then stop with manual recovery instructions. After reconnecting, re-check connectivity and relevant integrity/status.

## Failure policy
Critical failures may be auto-repaired only by a known verified procedure; otherwise stop for manual intervention. Non-critical issues must be fixed safely or require an explicit user exception before completion. Never bypass signature checks or blindly repeat destructive disk operations. A new full physical trial is allowed only after preserving evidence, rebooting from the official Arch ISO, revalidating the target, and obtaining fresh plan-bound authorization.

## Interrupted installation and physical-trial reset
For every failed or interrupted physical installer/First Boot trial, preserve logs and evidence, then reboot into the official Arch Linux ISO and restart the complete installer from its first stage. Do not resume from a checkpoint and do not invoke `scripts/resume-arch-x280.sh`. Before a new attempt, inspect the actual disk/system state, repeat read-only live validation and exact target identity checks, review the complete storage plan, and obtain explicit plan-bound authorization. Never automatically wipe, retry, or continue a destructive operation. If the state or target identity is uncertain, stop for manual inspection before any write.

## Final report
Generate AFTER-INSTALL-X280-K41.txt in English on the desktop after final health checks, once only. Include date/time, system details, package names/versions/sources, enabled services, main configuration, diagnostics, and statuses VERIFIED, FAILED, or NOT TESTED. Never include secrets. Remove temporary logs after the report.

## Health checks
Check boot/encryption configuration, filesystem/mount state, network, audio, desktop, services, and hibernation readiness where safely testable. Readiness is not proof of real hibernation.

## Acceptance
- [ ] Actionable failure stage and diagnostics.
- [ ] Secrets excluded.
- [ ] Failed physical trials preserve evidence and restart from the official Arch ISO using the full installer from its first stage; no checkpoint continuation.
- [ ] Report distinguishes verified, failed, and untested behavior.

## Initial installer diagnostic logs

The full destructive installer `scripts/install-arch-x280.sh` captures stdout/stderr inside the repository checkout:

```text
reports/installer/<UTC timestamp>/installer.log
```

The run directory is root-owned mode 0700 and the log file root-owned mode 0600. Logging fails closed unless the script is running from the official Arch ISO and the repository checkout resolves to an `overlay` or `tmpfs` filesystem. There is no fallback to `/var/log` or `/run`; failure to create the repository-local log stops execution before preflight or storage operations. The script prints the exact log path at exit. Copy the report directory to persistent storage before reboot if the ISO session is ephemeral.

The log records start/end time, kernel/architecture, checkout path and commit when available, stage markers, stdout/stderr, exit status, and the last stage reached. Storage final-revalidation and live-prerequisite modules report a non-sensitive failure-stage identifier (for example, `target_stable_identity_changed` or `target_topology_validation`) instead of returning only a generic failure.

Shell xtrace is not enabled. LUKS passphrases and account passwords must be entered through their interactive terminal prompts; they are not command arguments and must never be copied into logs. Logs can still contain hardware identifiers and storage topology from the reviewed plan, so inspect and redact them before sharing. Root-only permissions reduce exposure but do not make a log safe to publish.

A failure at `final-revalidation` occurs before the installer's first destructive `wipefs` operation in the current code path. A failure at a `pre-operation-check:` stage means that particular operation was not invoked. A failure at or after a `disk-operation:` stage requires stopping and inspecting the actual disk and mount state; earlier disk-operation stages in the same run may already have changed the disk. Never rerun blindly. The log is diagnostic evidence, not independent proof of disk state.


## Historical continuation checkpoint — 2026-11-08 (superseded)

An earlier physical attempt reached `pacstrap` and failed during fstab generation. That checkpoint is historical evidence only; it does not describe the current disk state and is not an instruction to resume that installation.

`scripts/resume-arch-x280.sh` remains in the repository solely as a legacy compatibility artifact. It is **not an approved recovery path** and must not be run for any current physical installer or First Boot trial. The required workflow is to preserve evidence, boot the official Arch ISO, repeat read-only validation and target identification, then run the complete installer from its first stage after fresh plan-bound confirmation.
