# Stage 6 — Desktop & Hardware Optimization

**Status: PLANNED.** The tools below are diagnostic collectors and a bounded power-profile selector. They do not constitute a completed hardware optimization or an X280 acceptance result.

## Canonical ownership

- `scripts/audit-x280-hardware.sh`: read-only hardware, battery, thermal, graphics, network, and power snapshot.
- `scripts/audit-x280-power-management.sh`: read-only power-policy, service, sysfs, and daemon snapshot.
- `scripts/set-x280-power-profile.sh`: `--show` is read-only; `--apply` changes the active profile only when the installed daemon exposes the requested allowlisted profile.
- `tests/`: static safety and CLI contract tests, invoked by the root `bash tests/run.sh` manifest.

Root-level script names remain relative symlinks for compatibility. New documentation and automation should use the Stage 6 paths.

## Safety and acceptance boundary

No tuning is automatically applied. Before optimization, collect a fresh X280 baseline and verify the actual hardware, firmware, kernel, power daemon, battery interfaces, and thermal sensors. Change one variable at a time, record rollback, and compare measurements under repeatable workloads.

Acceptance requires evidence for battery behavior, thermal stability, CPU/GPU performance, suspend/resume, and regression checks on the physical X280. A passing static test or a generated report is not hardware acceptance.

Runtime reports are written under `reports/stage-6-hardware-optimization/`. No Stage 6 optimization policy, configuration profile, or hardware-specific tuning is declared VERIFIED by this organizational move.
