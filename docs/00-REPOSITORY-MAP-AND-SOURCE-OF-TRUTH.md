# Repository Map and Evidence Integration

## Purpose

This is the navigation and traceability layer for the repository. It connects project decisions and requirements to their canonical documents, implementation files, automated tests, CI workflows, and operator evidence. It is an index, not a replacement for the owning documents or executable source.

**Repository:** `K41-Origin/Lenovo-ThinkPad-X280-K41`  
**Default branch:** `main`  
**Last tree inspection:** 2026-11-08  
**Observed tree:** 253 tracked files; recursive Git tree response was not truncated.

## Source-of-truth hierarchy

Use evidence in this order, according to the question being answered:

1. **Current code and configuration on the exact commit** — proves what is actually present, not that it works.
2. **Executed test/CI result tied to that exact commit and environment** — proves only the exercised scope.
3. **Physical X280 reports and operator observations** — evidence for the specific hardware state and time recorded.
4. **Canonical requirement/decision and domain documents** — authoritative project intent and approved constraints.
5. **Architecture/status/index documents** — explain relationships and summarize state; they must not override code, approved decisions, or newer evidence.
6. **Archive documents and older reports** — historical context only; never current status by default.
7. **Conversation history or AI memory** — leads for investigation only, never repository evidence.

A file's existence does not prove execution. A PASS in a mock/fixture test is not physical hardware proof. CI for an earlier SHA does not validate a later SHA. A readiness PASS does not authorize destructive disk operations.

## Canonical documentation ownership

| Topic | Canonical owner | Related implementation/evidence |
|---|---|---|
| Project purpose, scope, status vocabulary | [01 Project Charter](01-PROJECT-CHARTER.md) | README |
| Approved requirements and decisions | [02 Requirements and Decisions](02-REQUIREMENTS-AND-DECISIONS.md) | Requirement IDs referenced by domain docs/tests |
| Architecture, runtime flow, module contracts | [03 Architecture and Modules](03-ARCHITECTURE-AND-MODULES.md) | `installer`, `scripts/`, `lib/`, `native/` |
| Disk identity, partitioning, encryption, boot, swap/resume, recovery | [04 Installation and Disk](04-INSTALLATION-AND-DISK.md) | `scripts/install-arch-x280.sh`, `scripts/resume-arch-x280.sh`, storage/base-system/bootloader libraries |
| Security, account, network, desktop, hardware/power, packages, AUR, BlackArch policy | [05 Platform, Security, and Software](05-PLATFORM-SECURITY-AND-SOFTWARE.md) | `lib/security.sh`, `lib/desktop.sh`, `lib/hardware.sh`, `lib/packages.sh`, hardware config |
| Failure handling, logs, interrupted-run recovery | [10 Error Recovery and Reporting](10-ERROR-RECOVERY-AND-REPORTING.md) | installer/resume/report scripts and libraries |
| Project acceptance and evidence thresholds | [11 Testing and Acceptance](11-TESTING-AND-ACCEPTANCE.md) | [Test Guide](../tests/README.md) |
| Current implementation, CI, outstanding gates | [12 Implementation Status](12-IMPLEMENTATION-STATUS-AND-CHANGELOG.md) | exact commit-bound GitHub Actions and physical reports |
| Owner-reported X280 hardware baseline | [13 X280 Hardware Baseline](13-X280-HARDWARE-BASELINE.md) | `config/hardware/thinkpad-x280.conf`; runtime inventory |
| Native device-handle prototype only | [14 Stage 8](14-STAGE-8-NATIVE-DEVICE-ACCESS.md) | `native/storage-handle.c`, `tests/test-native-storage-handle.sh` |
| Initial destructive installer and checkpoint | [15 Stage 9](15-ARCH-INSTALLER-INITIAL-EXECUTION.md) | `scripts/install-arch-x280.sh`, `scripts/resume-arch-x280.sh` |
| ISO bootstrap and source-review gate | [16 Arch ISO Bootstrap](16-ARCHISO-BOOTSTRAP.md) | `scripts/bootstrap-archiso.sh`, readiness script |
| First boot evidence procedure | [17 X280 First Boot](17-X280-FIRST-BOOT-TEST.md) | `scripts/x280-first-boot-check.sh` |
| Dated repository audit | [18 Historical Audit](18-REPOSITORY-AUDIT-HISTORICAL.md) | historical only |
| Prior acceptance/changelog snapshots | [Archive](archive/) | historical only |

## Implementation file map

### Entry points and operator scripts

| File | Actual responsibility / boundary | Primary docs |
|---|---|---|
| `installer` | Legacy diagnostic entry point; `--help` and read-only `--preflight`; not the Arch installer | 03, 11, tests guide |
| `scripts/bootstrap-archiso.sh` | Retrieves/reviews main source and gates launch; itself is not the disk installer | 16, 04 |
| `scripts/x280-install-readiness.sh` | Read-only Arch ISO/UEFI, syntax, test-suite and live-storage readiness/report gate | 11, tests guide |
| `scripts/install-arch-x280.sh` | Initial destructive encrypted Arch base installer; exact target/plan confirmation required | 04, 15, 11 |
| `scripts/resume-arch-x280.sh` | Narrow continuation for the recorded post-pacstrap/pre-configuration checkpoint; no repartition/format/pacstrap | 10, 15, 17 |
| `scripts/configure-arch-x280.sh` | Configures the already-installed target's initial user/locale/timezone/base settings and boot artifacts | 04, 05, 15 |
| `scripts/live-validation.sh` | Read-only host/storage diagnostics and local validation report | 11, tests guide |
| `scripts/validate-live-storage.sh` | Read-only X280 target identity and live topology validation | 04, 11, 13 |
| `scripts/x280-archiso-test.sh` | Physical Arch ISO storage test procedure; inspect script and report before use | 04, 11, tests guide |
| `scripts/x280-first-boot-check.sh` | Read-only post-install evidence collector; not a repair script | 10, 11, 17 |

### Shell libraries

The installer sources libraries as functions; sourcing is not equivalent to executing every operation. The comments and function contracts in each current file remain authoritative.

| File | Responsibility indicated by implementation | Primary docs |
|---|---|---|
| `lib/common.sh` | Shared logging helpers; callers must not pass secrets | 10, AGENTS |
| `lib/preflight.sh` | Read-only live environment checks; composes inventory | 03, 04 |
| `lib/inventory.sh` | Runtime host inventory and comparison with declarative target profile | 05, 13 |
| `lib/storage.sh` | Read-only disk discovery and fresh target identity/topology validation | 04 |
| `lib/storage-topology.sh` | Read-only mounted/swap/backing-device dependency analysis | 04 |
| `lib/storage-plan.sh` | Pure storage geometry/planning and plan identity/digest binding | 04 |
| `lib/storage-prerequisites.sh` | Collects read-only prerequisite evidence bound to a plan | 04 |
| `lib/storage-confirmation.sh` | Displays/requires explicit plan-bound operator confirmation | 04 |
| `lib/storage-execution-boundary.sh` | Mock-oriented execution orchestration, per-operation identity probes and partial-failure ledger; not a real block-device executor | 03, 14 |
| `lib/storage-execution-dry-run.sh` | Dry-run boundary; must not be confused with real disk writes | 03, 11 |
| `lib/base-system.sh` | Guarded base package installation and fstab handling for an already mounted target | 04, 15 |
| `lib/bootloader.sh` | Bootloader/UKI configuration helpers; verify actual callers before claiming integration | 04, 15 |
| `lib/packages.sh` | Package policy/installation module; currently deferred unless status says otherwise | 05, 12 |
| `lib/user-setup.sh` | User/account setup helpers; check caller integration and current status | 05, 12 |
| `lib/security.sh` | Security configuration helpers; check caller integration and current status | 05, 12 |
| `lib/desktop.sh` | Desktop configuration module; Hyprland/Caelestia/Quickshell integration remains PLANNED | 05, 12 |
| `lib/hardware.sh` | Hardware configuration module; X280 tuning remains PLANNED pending real inventory and tests | 05, 13 |
| `lib/validation.sh` | Post-configuration validation helpers; distinguish implemented checks from unimplemented final acceptance | 10, 11 |
| `lib/report.sh` | Report-generation helpers; verify actual call sites before claiming final report workflow complete | 10, 12 |

### Hardware profile and native prototype

- `config/hardware/thinkpad-x280.conf` is declarative metadata, not runtime detection and not disk-selection authority. Its own comments state that only a whitelist of values is currently consumed by `lib/inventory.sh`; other fields remain owner-reported reference data.
- `native/storage-handle.c` is a standalone read-only prototype. It is not integrated into the destructive installer. See [Stage 8](14-STAGE-8-NATIVE-DEVICE-ACCESS.md).

### Tests and CI

- `tests/run.sh` is the single editable test manifest. At the last tree inspection it listed 20 test scripts.
- `tests/helpers/storage-fixtures.sh` supplies test-only storage fixtures.
- `tests/test-*.sh` are per-module/static/fixture/integration checks. Read the individual test before interpreting coverage; the table in `tests/README.md` is the user-facing coverage summary.
- `.github/workflows/ci.yml` runs repository syntax, selected ShellCheck and the canonical suite.
- `.github/workflows/bash-tests.yml` runs Bash syntax, ShellCheck, selected shfmt and the canonical suite.
- Workflow definitions describe intended CI; only GitHub Actions run records for the exact commit establish result.

## Evidence and report directories

| Path | Meaning | Trust boundary |
|---|---|---|
| `reports/test-runs/<timestamp>/` | Local canonical test runner summaries and per-test logs | Exact checkout/host only; inspect for sensitive host data before sharing |
| `reports/live-readiness/<timestamp>/` | Read-only readiness summary and diagnostics | PASS is not install authorization; review redaction before publication |
| `reports/live-validation/` | Live validation snapshots | Dated host evidence; not necessarily current |
| `reports/first-boot/` | Expected destination for first-boot evidence | No physical first-boot report was present in the inspected tree |
| `reports/x280-archiso-storage-test-*.log` | Output of the physical Arch ISO storage test | Historical evidence; must be tied to exact environment and reviewed |
| `docs/archive/` | Historical document snapshots | Never treat as current requirements, CI state, or procedure |

Generated reports are evidence artifacts, not canonical specifications. Do not copy old PASS values into current status without checking timestamp, commit SHA, test scope, and actual report content. Avoid duplicating SSD serials, battery serials, secrets, or unrelated unique identifiers into summary documentation.

## Current known implementation boundaries

- Diagnostic-only `installer --preflight` and destructive `scripts/install-arch-x280.sh` are separate entry paths.
- Bootstrap/readiness checks do not erase the disk. Only the separately reviewed installer enters destructive storage operations after the required gates.
- The checkpoint continuation is specific to the recorded partial installation; inspect the physical disk before selecting any path.
- Native C descriptor prototype is not the installer's storage executor.
- The repository contains modules for desktop, hardware, package, security, user setup, validation, and reporting; module presence alone does not establish end-to-end integration.
- Hyprland/Caelestia/Quickshell, hardware tuning, hibernation lifecycle, selective BlackArch, and physical first-boot acceptance must remain PLANNED/NOT TESTED until implementation and evidence exist.

## How to update this map

When files or ownership change:
1. Inspect the exact source and current tests on `main`.
2. Update the owning domain document first.
3. Update this map only for changed paths/interfaces/relationships.
4. Update README navigation and `docs/12` only when the user-visible status or current evidence changes.
5. Verify links and fetch every changed file after writing.
6. Record exact test/CI commit IDs; do not extrapolate results across commits.

## Related indexes

- [README](../README.md) — operator-facing project overview.
- [Architecture](03-ARCHITECTURE-AND-MODULES.md) — module interfaces and runtime flow.
- [Implementation Status](12-IMPLEMENTATION-STATUS-AND-CHANGELOG.md) — what exists and what remains untested.
- [Test Guide](../tests/README.md) — executable tests and evidence.
