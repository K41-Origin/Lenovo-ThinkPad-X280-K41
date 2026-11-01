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
