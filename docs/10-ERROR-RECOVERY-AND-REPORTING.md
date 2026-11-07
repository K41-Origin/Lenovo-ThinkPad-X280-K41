# Error Recovery and Reporting

## Progress and diagnostics
Report the current stage and meaningful progress. Show ETA only when credibly estimable. Temporary diagnostics may include stage, timestamp, package/operation, error, exit status, and retry attempted. Redact secrets; never log passwords, LUKS keys, tokens, or credentials.

## Network failures
Check DNS, HTTPS, and Arch repository connectivity before package installation. Diagnose/retry recoverable failures. If connectivity remains unavailable beyond the planned five-minute recovery window, attempt reconnecting for up to five minutes, then stop with manual recovery instructions. After reconnecting, re-check connectivity and relevant integrity/status.

## Failure policy
Critical failures may be auto-repaired only by a known verified procedure; otherwise stop for manual intervention. Non-critical issues must be fixed safely or require an explicit user exception before completion. Never bypass signature checks or repeat destructive disk operations just because a prior run was interrupted.

## Interrupted installation
Inspect actual disk/system state, show the last recorded stage, explain uncertainty, and ask before resuming potentially destructive actions. Do not assume local status survived if the target disk was formatted.

## Final report
Generate AFTER-INSTALL-X280-K41.txt in English on the desktop after final health checks, once only. Include date/time, system details, package names/versions/sources, enabled services, main configuration, diagnostics, and statuses VERIFIED, FAILED, or NOT TESTED. Never include secrets. Remove temporary logs after the report.

## Health checks
Check boot/encryption configuration, filesystem/mount state, network, audio, desktop, services, and hibernation readiness where safely testable. Readiness is not proof of real hibernation.

## Acceptance
- [ ] Actionable failure stage and diagnostics.
- [ ] Secrets excluded.
- [ ] Interrupted runs inspect state instead of reformatting.
- [ ] Report distinguishes verified, failed, and untested behavior.

## Initial installer diagnostic logs

`scripts/install-arch-x280.sh` captures stdout and stderr to a timestamped run directory before host preflight or storage operations:

```text
/var/log/x280-installer/<UTC timestamp>/installer.log
```

The directory is root-owned mode 0700 and the log file root-owned mode 0600. The installer falls back to `/run/x280-installer/<UTC timestamp>/installer.log` if `/var/log` cannot be used; that fallback is always temporary and disappears at reboot. The installer prints the exact log path at exit. Because the Arch ISO may keep `/var/log` on an ephemeral overlay too, copy the log to a mounted persistent medium before reboot regardless of which path was used.

The log records start/end time, kernel/architecture, checkout path and commit when available, stage markers, stdout/stderr, exit status, and the last stage reached. Storage final-revalidation and live-prerequisite modules report a non-sensitive failure-stage identifier (for example, `target_stable_identity_changed` or `target_topology_validation`) instead of returning only a generic failure.

Shell xtrace is not enabled. LUKS passphrases and account passwords must be entered through their interactive terminal prompts; they are not command arguments and must never be copied into logs. Logs can still contain hardware identifiers and storage topology from the reviewed plan, so inspect and redact them before sharing. Root-only permissions reduce exposure but do not make a log safe to publish.

A failure at `final-revalidation` occurs before the installer's first destructive `wipefs` operation in the current code path. A failure at a `pre-operation-check:` stage means that particular operation was not invoked. A failure at or after a `disk-operation:` stage requires stopping and inspecting the actual disk and mount state; earlier disk-operation stages in the same run may already have changed the disk. Never rerun blindly. The log is diagnostic evidence, not independent proof of disk state.
