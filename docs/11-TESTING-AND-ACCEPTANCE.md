# Testing and Acceptance

## Current status
An initial destructive installer is IMPLEMENTED on PR #9 branch `feature/base-system-bootstrap-2026-11-07`; it is not merged into `main`. The separate top-level `installer --preflight` remains diagnostic-only. CI runs #130 and #131 passed on commit `2aae853df0c74c8ae9a46e702d457884f1d91fd8` with the 15-script suite, including the disposable loop-device test. These runs predate the latest documentation-only commits and are not CI evidence for the current branch head. They do not prove a complete installation or boot. See `docs/12-IMPLEMENTATION-STATUS-AND-CHANGELOG.md` for the exact evidence ledger and `docs/15-ARCH-INSTALLER-INITIAL-EXECUTION.md` for installer scope and test gate.

The storage discovery/topology, planning, prerequisite, confirmation, and final-revalidation modules remain read-only. The PR #9 installer separately performs destructive storage operations. The approved layout and implemented boot contract are owned by `docs/04-INSTALLATION-AND-DISK.md`; resume remains deferred.

Stage 5 adds a dry-run operation manifest and deterministic failure-injection simulator. The manifest describes the intended order (GPT, partition creation/type assignment, LUKS2 format/open, ext4), while the simulator records attempted/completed steps and stops at an injected failure. It does not invoke an executor callback, shell command, block-device API, or privileged utility. A ready final gate must match the current plan's review digest and target identity; simulation consumes the gate. This is test infrastructure and architecture validation only, not a production storage executor.

## Historical Stage 6 — Storage execution safety audit (superseded by PR #9 installer)

The Stage 6 review inspected the actual `installer` entry point and all `lib/*.sh` modules in the current repository tree, with focused review of the storage planner, live prerequisite collector, confirmation gate, topology validator, and dry-run model.

Findings:
- The legacy top-level executable `installer` sources only `lib/common.sh` and `lib/preflight.sh`; it remains diagnostic-only and returns nonzero for preflight. The separate `scripts/install-arch-x280.sh` is the PR #9 destructive installer.
- The storage discovery, topology, planning, prerequisite, confirmation, and dry-run modules remain read-only. This finding described the earlier repository state before PR #9 introduced `scripts/install-arch-x280.sh`; it must not be read as a statement about the entire current branch.
- `lib/storage-execution-dry-run.sh` creates in-memory operation descriptors and result records only. It contains no external-command dispatch, command substitution, shell evaluation, or executor callback.
- The final gate and plan digest are in-process integrity checks, not a security boundary against a compromised process, arbitrary caller mutation, or malicious root code. They also do not lock the target or eliminate the time-of-check/time-of-use gap. Any future executor must revalidate the selected device immediately before the first mutation and define how it prevents or detects target replacement during execution. The dry-run simulator must not be treated as an authorization system.
- The Stage 5 test initially failed because its helper declared a local variable named `target`, shadowing the caller's final-revalidation output array. The helper's local target and nameref variables were renamed to avoid both output-array shadowing and a circular nameref; run #107 passed the complete suite without circular-nameref warnings.
- Static source inspection is not a formal proof of absence of side effects. Future executor work must introduce a separate injectable boundary, test zero destructive invocations on every failed gate, and undergo a new review before any real-disk execution is considered.

No real disk, package database, service, firmware setting, or network configuration was changed during this audit.

The prerequisite binder itself records caller assertions; the live collector is the component that performs the read-only checks and produces fresh evidence. Fixture-based tests mock discovery and topology behavior, so they do not establish that the actual X280 disk is unused or that hardware identity is correct at installation time.

## Historical Stage 7 — Mock execution boundary and target revalidation (mock-only module remains current)

Stage 7 adds `lib/storage-execution-boundary.sh`, a mock-only orchestration boundary. It accepts only callback names under the `storage::mock_*` namespace, requires a ready gate whose review digest matches the plan, builds the existing eight-operation manifest, and consumes the in-process gate before the first probe or callback.

Immediately before each mock operation, the boundary asks the injected probe to return the target path, kernel major:minor, capacity, stable-ID kind/value, WWN, serial, transport, removable flag, and read-only flag. The final gate now binds these target attributes to the plan; the boundary verifies gate/plan consistency before use. Any probe failure or mismatch aborts before that operation. The result ledger records attempted and completed operation IDs. If identity changes or an executor callback fails after one or more completed steps, the result marks `recovery_required=yes`; it does not attempt automatic rollback.

The final confirmation gate now also carries the target capacity, so the mock boundary can compare that field alongside path, major:minor, and stable ID.

Important limitations:
- The callbacks are test-only mocks. This module does not open a block-device file descriptor, call ioctl, acquire an exclusive device lease, execute storage commands, or modify a disk.
- Rechecking a pathname immediately before a callback narrows the modeled detection window but does not eliminate the kernel-level TOCTOU race between the check and a future real operation. It is not real TOCTOU protection.
- A future real executor requires a separately reviewed native device-handle/identity design (including stable open-handle validation and a defined strategy for preventing/detecting target replacement), plus a recovery protocol. Do not infer that a Bash path check or in-process gate is sufficient.
- Partial storage operations are not generally safely reversible. The correct default after a partial failure is stop, preserve the operation ledger, and require explicit recovery inspection; do not blindly rerun or auto-rollback.

Fixture tests cover successful eight-step mock execution, target identity change before a later operation, failed initial probe with zero executor calls, injected partial failure and recovery flag, and rejection of a non-mock callback. These tests establish the orchestration contract only; no real block-device handle or physical disk is used.

## Documentation checks
- Verify expected files and relative links.
- Check consistent requirement IDs and status vocabulary.
- Ensure planned requirements are not described as implemented.

## Shell/module checks once code exists
- Run bash syntax checks, ShellCheck, and shfmt where available.
- Test argument validation, missing dependencies, privileges, error paths, and exit codes.
- Test idempotency where expected.
- Mock disk, package-manager, network, and service operations.

## Safety tests
- Bootstrap must not execute fetched installer code until the resolved source/commit and relevant code have passed the required pre-execution review.
- If source identity, integrity, or review status is uncertain or a required check fails, bootstrap stops without executing the installer or privileged installation code.
- Disk identity and stable identifiers are reported.
- Proposed partition plan appears before confirmation.
- Destructive operations require explicit confirmation.
- Ambiguous target identity stops execution.
- Failed preflight or incomplete/unverified storage profile blocks installation steps that depend on the target disk.
- Interrupted installation does not automatically repartition.
- Signature/integrity failures never bypass verification.
- Logs and reports contain no secrets.
- For every failed prerequisite, cancelled confirmation, ambiguous target, incomplete plan, changed target, or unknown critical state, tests explicitly assert that destructive storage commands were invoked zero times.

## Bootstrap pre-execution gate test cases

These planned tests verify the architecture's bootstrap review gate before any fetched project code is executed. Use fixtures and mocks; do not execute untrusted code as part of the test.

| Test ID | Requirement / contract | Setup and action | Expected result |
|---|---|---|---|
| TC-BOOT-001 | Bootstrap source/commit review | Provide a fetched-source fixture with an identifiable commit but mark the required code review as incomplete; attempt to continue bootstrap. | Bootstrap refuses to execute the installer; no installer or privileged installation code is invoked. |
| TC-BOOT-002 | Source/integrity uncertainty | Simulate an unavailable or failed required source/integrity check. | Bootstrap stops with a failure status; it does not treat the commit SHA alone as proof of safety or execute fetched code. |
| TC-BOOT-003 | Pre-execution privilege boundary | Mock the bootstrap flow and record execution/privilege transitions while the review gate is pending or failed. | No installer execution or elevated installation stage occurs before the review gate passes. |

## Diagnostic entry-point tests

The diagnostic-only entry point supports `--help` and `--preflight`. It sources only the common/preflight modules, uses a repository-relative module path, and never treats diagnostics as installation approval. `--preflight` intentionally returns nonzero because this legacy entry point has no installation workflow; the separate PR #9 script is documented elsewhere. The focused entry test covers help from another working directory, invalid arguments, non-success from preflight, explicit disabled status, and a static check that the entry point does not source installation modules or name common destructive/system-changing commands. Static checks are supplementary and do not prove the absence of every possible side effect.

Run with `bash tests/test-installer-entry.sh`.

The separate `tests/test-preflight-gate.sh` runs a temporary copy of the entry point with a deterministic mocked preflight module. It verifies that unresolved boot mode and required-command failures remain failures and that the entry point never claims installation success; it also verifies that optional network-diagnostic failure does not change the required-gate outcome. Since actual installation stages do not exist yet, this tests control flow rather than an end-to-end blocked installation.

The separate `tests/test-preflight-gate.sh` runs a temporary copy of the entry point with a deterministic mocked preflight module. It verifies that unresolved boot mode and required-command failures remain failures and that the entry point never claims installation success; it also verifies that optional network-diagnostic failure does not change the required-gate outcome. Because actual installation stages do not exist yet, this tests control flow and the absence of known stage markers, not an end-to-end blocked installation.

## Common and preflight first-slice tests

These cases define the first-slice coverage. The current script executes source-output/options/trap checks, logging checks, boot-mode fixtures, command-availability cases, and available/unavailable network-diagnostic cases. The broader no-side-effect boundary still also relies on code review; the current script does not instrument every possible filesystem or external-command access. Tests must run as an ordinary user and must not inspect or modify real target disks.

| Test ID | Module / contract | Setup and action | Expected result |
|---|---|---|---|
| TC-COMMON-001 | `lib/common.sh` source safety | Source the module in a clean Bash subprocess while capturing stdout/stderr and command calls. | No output or shell-option/trap changes occur at source time; source-time code review confirms the modules contain only function definitions and no command invocations or filesystem operations. |
| TC-COMMON-002 | Logging interface | Call each public logging helper with ordinary diagnostic text and with invalid/missing arguments. | Output goes to stderr; invalid input returns nonzero; no hidden success or secret-bearing test value is used. |
| TC-PREFLIGHT-001 | `lib/preflight.sh` source safety | Source the module in a clean Bash subprocess with command calls monitored. | No checks run, no output appears, and shell options/traps remain unchanged at source time; source-time code review confirms no external command or filesystem operation is invoked. |
| TC-PREFLIGHT-002 | Required-command check | Use controlled command-availability fixtures for present and missing required commands. | Present commands pass; a missing required command returns failure with a clear diagnostic. |
| TC-PREFLIGHT-003 | Boot-mode detection | Provide mocked read-only indicators for UEFI, legacy, and unknown states. | UEFI and legacy are reported distinctly; unknown remains unknown and is not treated as verified. |
| TC-PREFLIGHT-004 | Network diagnostic | Mock an available diagnostic tool and run with the tool unavailable. | Reports available observations without changing interfaces or claiming external connectivity was verified. |
| TC-PREFLIGHT-005 | Read-only boundary | Monitor invoked commands and filesystem access while running every preflight check. | No package install, service change, network reconfiguration, target-disk probe, or destructive storage command is invoked. |

## Host inventory test cases

These are planned tests for the read-only `lib/inventory.sh` contract. Use temporary procfs/sysfs-shaped fixtures; do not depend on the host machine's actual hardware.

| Test ID | Module / contract | Setup and action | Expected result |
|---|---|---|---|
| TC-INVENTORY-001 | Source safety | Source `lib/inventory.sh` in a clean Bash subprocess while capturing output, shell options, traps, and monitored command calls. | No output, external command, filesystem write, trap change, or shell-option change occurs at source time. |
| TC-INVENTORY-002 | Host fact collection | Supply deterministic procfs/sysfs fixtures containing CPU, memory, and DMI values; call `inventory::collect_host`. | Documented associative-array keys contain the normalized fixture values; no shell code is emitted or evaluated. |
| TC-INVENTORY-003 | Missing/invalid optional facts | Omit optional DMI/CPU fields and provide malformed memory data. | Unavailable or invalid fields remain absent/unknown; no guessed defaults are inserted and optional omissions do not become verified facts. |
| TC-INVENTORY-004 | Interface validation | Pass a missing, indexed, or non-associative output variable and invalid fixture-root arguments. | The function returns the documented invalid-input status and does not modify unrelated caller variables. |
| TC-INVENTORY-005 | Read-only boundary | Monitor filesystem writes and invoked commands while collecting/rendering fixture data. | No writes, package/service/network operations, block-device reads, or destructive storage tools are invoked. |

### Storage contract implementation tests

The existing TC-DISK cases remain the requirement-level acceptance tests. Add these interface-level checks when `lib/storage.sh` is implemented:

- Validate associative-array arguments and schema versions; reject missing, indexed, or ordinary scalar variables without using `eval`.
- Use deterministic fixtures to prove canonical plan serialization/digest is stable for identical data and changes when any target, partition, encryption, filesystem, swap/resume, or prerequisite field changes.
- Prove a confirmation cannot be reused with a different target, modified plan, changed schema, or stale prerequisite evidence.
- Mock all destructive commands behind an injectable test boundary. For every invalid input, incomplete plan, failed prerequisite, changed identity, cancellation, stale confirmation, and interrupted/recovery state, assert an exact destructive-call count of zero.
- Test the execution boundary separately: only a valid, freshly revalidated target + complete plan + matching confirmation can reach mocked destructive operations.
- Verify post-operation checks are read-only and distinguish observed success, mismatch/failure, and unavailable/NOT TESTED results.
- Do not claim the plan digest is a cryptographic authorization mechanism; it is an integrity binding within the reviewed installer flow, not protection against a compromised process or malicious root code.

## Requirement-linked test cases

These are requirement-level acceptance cases for **REQ-DISK-003** in `docs/02-REQUIREMENTS-AND-DECISIONS.md`. The current implementation executes mocked tests for review rendering, exact confirmation, plan-change rejection, target-identity revalidation, and topology-failure handling (see the Storage review/confirmation section below). The remaining execution-boundary and end-to-end cases are still planned. Any future disk-operation tests must use mocks/fakes and must never operate on real disks.

| Test ID | Requirement / criterion | Setup and action | Expected result |
|---|---|---|---|
| TC-DISK-003-01 | REQ-DISK-003 / AC-1 | Provide a disk fixture with stable identity details; request the target summary. | The selected device and available identity details are shown before any destructive command is invoked. |
| TC-DISK-003-02 | REQ-DISK-003 / AC-1, AC-4 | Provide two candidates whose identity cannot be distinguished safely, or omit essential identity data; attempt selection. | The installer reports ambiguity or insufficient identity and stops; no destructive command is invoked. |
| TC-DISK-003-03 | REQ-DISK-003 / AC-2 | Provide a valid target and complete storage-plan fixture; advance to review. | The full plan, including partition layout, encryption, filesystem, and swap/resume-related choices, is displayed before the confirmation prompt. |
| TC-DISK-003-04 | REQ-DISK-003 / AC-3 | At the final confirmation prompt, choose cancel or enter a non-confirming response. | The operation is cancelled safely; no destructive command is invoked. |
| TC-DISK-003-05 | REQ-DISK-003 / AC-3 | Confirm the displayed target and plan using the designed explicit confirmation flow. | Execution may proceed only if all prerequisites and target revalidation also pass. The test uses mocks, never a real disk. |
| TC-DISK-003-06 | REQ-DISK-003 / AC-4 | Change the selected target's identity between review/confirmation and the execution gate. | Revalidation detects the mismatch and aborts before any destructive command. |
| TC-DISK-003-07 | REQ-DISK-003 / AC-2, AC-4 | Make plan generation fail or omit a required plan field. | The plan is treated as incomplete; confirmation/execution is not allowed and no destructive command is invoked. |
| TC-DISK-003-08 | REQ-DISK-003 / AC-5 | Exercise review, validation, confirmation, execution, and post-operation verification through separate mocked stage boundaries. | Each stage can be tested independently; execution is unreachable when an earlier gate fails, and post-operation verification runs only after mocked execution succeeds. |
| TC-RECOVERY-001-01 | REQ-RECOVERY-001 / related to REQ-DISK-003 | Simulate a previously interrupted run with partially changed storage state and restart the installer. | The installer inspects/reports current state and does not automatically wipe or repartition again. |

### Test implementation rules
- Assert destructive-tool invocations explicitly, including an expected call count of **zero** whenever a prerequisite or safety gate fails, confirmation is cancelled, target identity is ambiguous or changed, the plan is incomplete, or a critical state is unknown.
- Test that failed preflight or unresolved storage/boot-resume inputs prevent entry into any target-disk-dependent installation stage.
- Keep fixtures deterministic and avoid relying on unstable device-path ordering or real hardware discovery in unit tests.
- Do not treat a passing mock test as proof of correct real-disk behavior; validate integration separately in an isolated environment.
- If an implementation cannot expose a stage safely for testing, document the design limitation and resolve it before enabling destructive operations.

## Boot, encryption, and hibernation acceptance tests — PLANNED

These tests validate the approved design direction. They must use disposable VM images/mocks first; no test may repartition a user's real disk. A VM pass does not establish ThinkPad X280 hardware compatibility.

- **TC-BOOT-001 — UEFI/systemd-boot asset visibility:** verify the firmware is in UEFI mode, systemd-boot entries resolve to files on the ESP or supported XBOOTLDR partition, and no entry depends on reading kernel/initramfs from encrypted root.
- **TC-BOOT-002 — Kernel update lifecycle:** install/update the official Arch `linux` package and verify the selected boot-asset mechanism regenerates/copies the required kernel, initramfs or UKI files and leaves a bootable entry. Verify fallback behavior and ESP free-space handling.
- **TC-CRYPT-001 — Encrypted root unlock:** with LUKS2 + ext4 on the mapped root, verify the initramfs contains required modules/tools, prompts for the passphrase, unlocks the expected device, and mounts the intended root. Wrong passphrase, missing device, and malformed parameters must fail safely.
- **TC-RESUME-001 — Swapfile mapping:** verify the swapfile is inside the unlocked ext4 mapper filesystem and the `resume=` parameter identifies that unlocked device, not the raw LUKS partition.
- **TC-RESUME-002 — Offset correctness:** calculate the actual ext4 swapfile physical offset using the supported method and verify the generated `resume_offset=` matches it. Test recreated, resized, and relocated swapfiles; stale/missing offset must be detected and must not be reported as hibernation-ready.
- **TC-RESUME-003 — Capacity policy:** test swap sizing against measured RAM, disk free space, and documented hibernation assumptions; insufficient capacity must block the hibernation-ready status rather than silently shrinking or overcommitting.
- **TC-RESUME-004 — End-to-end hibernation:** manually hibernate and resume in a disposable VM where supported, then on the actual X280 with explicit authorization. Record VERIFIED/FAILED/NOT TESTED separately; do not infer successful resume from configuration alone.
- **TC-BOOT-003 — ESP integrity and limitation:** verify the installer reports that Secure Boot is disabled and that an unencrypted ESP is not authenticated against offline tampering by LUKS alone.

## UKI-specific acceptance tests — PLANNED

The approved boot design uses a native mkinitcpio UKI on the ESP, with the source kernel/configuration on encrypted root. These tests must run against disposable VM disks or mocks first. They do not authorize testing on a user's real disk.

- **TC-UKI-001 — Preset output:** verify the installed official `linux` package and mkinitcpio preset produce the expected default UKI under `/efi/EFI/Linux/`; verify the UKI contains the intended kernel, initramfs, and kernel command line.
- **TC-UKI-002 — systemd-boot discovery:** verify systemd-boot discovers and boots the default UKI from the ESP in UEFI mode without reading kernel/initramfs from encrypted root.
- **TC-UKI-003 — Encrypted-root boot:** verify the UKI's initramfs uses the approved systemd-based `sd-encrypt` path and unlocks/mounts the intended LUKS2 + ext4 root. Wrong passphrase, unavailable device, and malformed parameters must fail safely.
- **TC-UKI-004 — Kernel update with ESP mounted:** update the official `linux` package and verify the package/mkinitcpio preset lifecycle regenerates the UKI, and systemd-boot still discovers it.
- **TC-UKI-005 — ESP not mounted:** simulate or arrange a safe test environment where the ESP is not mounted at `/efi`; verify the update process detects the missing mount and does not silently write into the root filesystem's ordinary `/efi` directory or report a fresh UKI.
- **TC-UKI-006 — Generation failure / known-good artifact:** force UKI generation to fail; verify the failure is visible and the previous known-good UKI is not deleted or overwritten by an incomplete artifact.
- **TC-UKI-007 — Capacity and fallback policy:** verify the 1 GiB ESP has sufficient measured headroom for the required default UKI and update operation. No fallback UKI is required initially; if later enabled, test its measured capacity impact and update lifecycle.
- **TC-UKI-008 — Recovery path:** verify the official Arch ISO USB can be used to recover/rebuild the UKI after a failed boot-artifact update. This is a recovery test, not proof that the installed system boots.

## Integration and hardware validation
Use isolated VMs where suitable; VM tests do not fully validate X280 hardware. Test on the actual X280 only with authorization and verified target. Check boot, encryption, filesystem, network, audio, desktop, and services. Actual hibernation must be tested manually.

## Acceptance gates
A release candidate requires reviewed requirements and architecture, passing static checks, mocked safety/error paths, verified package/upstream dependencies, docs consistent with behavior, and evidence for hardware claims. Disclose known failures and untested items.

## Test execution evidence

Chronological GitHub Actions run identifiers and commit-to-run mappings are maintained in [Implementation Status and Changelog](12-IMPLEMENTATION-STATUS-AND-CHANGELOG.md). This document owns test strategy, coverage, acceptance criteria, and limitations—not the historical CI ledger.

For a new change, use `bash tests/run.sh` and inspect the GitHub Actions result for the exact commit. A previous successful run does not validate a later commit. Fixture tests do not establish live X280 hardware behavior.

## Live storage prerequisite integration — IMPLEMENTED and CI TESTED

`lib/storage-prerequisites.sh` adds `storage::plan_collect_live_prerequisites PLAN TARGET_OUT PREREQ_OUT`. It performs read-only live checks before a plan may carry passed prerequisite states:

- Required command availability: `lsblk`, `jq`, `swapon`, `base64`, `readlink`, `stat`, `sha256sum`, and `date`.
- UEFI firmware indicator through `/sys/firmware/efi`; missing/ambiguous state fails closed.
- Fresh whole-disk discovery from `lsblk` and active-swap inspection.
- Selected device must match the plan's path, major:minor, capacity, NVMe transport, removable/read-only flags, and stable WWN/serial identity.
- A second discovery via `storage::validate_target` checks that identity again and invokes the full sysfs dependency-closure + `/proc/self/mountinfo` + `/proc/swaps` topology check.
- Any mounted descendant, active swap dependency, changed identity, unknown topology, missing tool, or non-UEFI state prevents a prerequisite snapshot from being bound to the plan.
- Evidence ID incorporates a nanosecond UTC timestamp, plan digest, and observed target identity. It is an audit/binding identifier, not an authorization token or proof against a compromised root process.

The collector is read-only. It does not partition, format, mount, unlock, install packages, or alter firmware settings. It requires the caller to source `common.sh`, `preflight.sh`, `storage.sh`, `storage-plan.sh`, and then `storage-prerequisites.sh`.

The new `tests/test-storage-prerequisites.sh` exercises successful collection/binding and fail-closed behavior for missing tools, non-UEFI, discovery failure, topology failure, and changed stable identity using controlled function fixtures. These tests validate the orchestration contract; the existing discovery/topology tests separately cover the underlying parsers and read-only topology logic. They do not establish a live pass on the ThinkPad or authorize disk erasure.

The GitHub Actions suite now includes the new test. Run `41614921278` passed Bash syntax validation and all eight test scripts at commit `ab2a6ee0aa80df234bf3edc554829cf4e714927c`. The previously failing full squashfs mount topology fixture also passed in this run. The new prerequisite test confirmed successful live-check orchestration and fail-closed behavior for the injected failures. This remains fixture-based CI evidence, not a live pass on the ThinkPad hardware.


On 2026-11-03, GitHub Actions run `41614921278` completed successfully at commit `ab2a6ee0aa80df234bf3edc554829cf4e714927c`: Bash syntax validation passed for all shell files and all eight test scripts passed, including `tests/test-storage-prerequisites.sh`. The topology suite's full squashfs-loop case passed in this run. No real disk was modified and no live hardware prerequisite result was collected in this CI environment.


## Storage review, explicit confirmation, and final revalidation — IMPLEMENTED and CI TESTED

`lib/storage-confirmation.sh` adds three read-only gate functions:

- `storage::plan_review_digest PLAN` calculates a stable SHA-256 review fingerprint over the plan while excluding only volatile `prereq_*` evidence fields. Target identity, geometry, and installation profile remain included.
- `storage::plan_render_review PLAN` validates and prints the target path/model/capacity/stable identity, partition geometry, encryption/filesystem, swap/resume policy, boot artifact, Secure Boot setting, prerequisite status, and review digest.
- `storage::plan_confirm_interactive PLAN CONFIRMATION_OUT` requires the user to type the exact challenge `ERASE <device-path> <first-12-review-digest-characters>`. Empty, cancelled, or mismatched input does not create a confirmation record.
- `storage::plan_final_revalidate PLAN CONFIRMATION TARGET_OUT PREREQ_OUT GATE_OUT` consumes the confirmation before checking, rejects plan changes, calls the live prerequisite collector again, revalidates target identity/topology, and returns a `ready` gate record only if the stable review digest and all target identity fields still match.

A failed final check consumes the confirmation; a new review and explicit confirmation are required. A successful gate is an in-process state record only. It is not a security boundary against compromised root code, is not persistent across process restarts, and does not itself authorize or execute any disk operation. No partitioning, formatting, encryption, mounting, package installation, or firmware changes were added. The installer entry point remains diagnostics-only.

`tests/test-storage-confirmation.sh` covers cancellation, incorrect phrase, successful exact confirmation, successful final revalidation, one-shot use, modified-plan rejection, changed stable identity, and topology failure. GitHub Actions run `41615793341` passed Bash syntax validation and all nine repository test scripts at commit `4ab82207fa682e8e2ec8bab760f8c42d8e745717`. The test run also passed the complete squashfs/overlay topology fixtures. These are CI fixture results, not a live confirmation or installation test on the ThinkPad X280.


On 2026-11-03, GitHub Actions run `41617706958` (#107) passed Bash syntax validation and all ten repository test scripts at commit `0526112b092b0a0a1e06c4c7eadaee9245af9ac7`. The run includes the corrected Stage 5 test helper; the dry-run and full topology fixtures passed, with no circular-nameref warnings. This is fixture-based CI evidence only; no physical disk or ThinkPad hardware was tested.


On 2026-11-03, GitHub Actions run #136 (`41618734278`) passed Bash syntax validation and all eleven test scripts at commit `3fcc970f58d76e5f62d6b76f767a4075cbe0a95b`. The mock execution-boundary cases passed, including successful eight-step execution, stable-identity change abort, read-only safety-attribute change abort, zero mock calls after an initial probe failure, partial-failure recovery marking, and callback rejection, and rejection of tampered gate metadata before gate consumption. The full topology suite also passed after its synthetic major:minor IDs were isolated from the host filesystem device ID. No real block-device handle was opened and no disk was modified.


## Stage 8 — ThinkPad X280 Arch ISO live-environment observations

**Date:** 2026-11-07 (user-provided terminal photographs; manually reviewed)  
**Environment:** Arch Linux ISO `2026.11.01`, running on the physical ThinkPad X280.

Observed read-only results:

| Check | Observed result | Evidence / status |
|---|---|---|
| Firmware boot mode | UEFI | `/sys/firmware/efi` exists and the terminal printed `UEFI MODE`. VERIFIED |
| Live root | `/dev/loop0` / `archiso` overlay | `findmnt /` shows an overlay root with archiso lower/upper/work paths. VERIFIED |
| Active swap | None listed | `swapon --show` returned no rows. VERIFIED for this snapshot |
| Installer USB | `/dev/sda`, 7.5G, model `Flash Disk`, removable=1, read-only=1 | `lsblk` output. VERIFIED |
| Internal SSD | `/dev/nvme0n1`, 238.5G, model `WDC PC SN730 SDBQNTY-256G-1001`, transport NVMe, removable=0, read-only=0 | `lsblk` output. VERIFIED |
| Internal SSD serial alias | `nvme-WDC_PC_SN730_SDBQNTY-256G-1001_193839803177` | `/dev/disk/by-id/` symlink resolves to `../../nvme0n1`. VERIFIED |
| Additional SSD aliases | Partition aliases `...-part1` through `...-part4`; an NVMe EUI alias is also present | `/dev/disk/by-id/` output. VERIFIED; full EUI string not transcribed because the photograph is not sufficiently clear |
| Existing SSD partition table | Four partitions: 100M EFI/FAT, 16M reserved (no filesystem shown), 237.8G NTFS, 530M NTFS | `lsblk` output. VERIFIED as observed |

Safety interpretation:
- The kernel names observed in this boot are `/dev/sda` for the removable Arch USB and `/dev/nvme0n1` for the internal WDC NVMe. These names are runtime observations, not permanent identifiers.
- The WDC model and serial-based by-id alias agree across the two terminal snapshots. This is strong identification evidence, but target selection must still bind to fresh kernel major:minor, capacity, transport, WWN/serial, removable/read-only state, and topology at execution time.
- The SSD is reported writable (`RO=0`) and still contains the Windows partition layout. No partition, filesystem, encryption, mount, or package mutation was performed during these observations.
- An empty `swapon --show` is expected in this live session; it does not establish that the target disk is unused.
- The live root is an overlay. The target-safety decision is **NOT YET VERIFIED**: the complete mount dependency graph, loop backing relationship, overlay lower/upper/work backing devices, and active swap relationship must pass the repository topology validator before a target may be considered eligible.
- The repository's `storage::discover_candidates` and `storage::validate_target` functions have not yet been executed on this physical host. The photographs validate raw system observations only, not the project's implementation.

**Stage 8 result:** UEFI boot and device identity observations VERIFIED. Physical-disk topology exclusion, live candidate discovery, plan calculation, confirmation flow, and any destructive executor remain NOT TESTED. No permission to erase or repartition is implied by this record.


## Stage 9 — Live storage topology observations

**Date:** 2026-11-07 (user-provided terminal photograph; manually reviewed)  
**Environment:** Physical ThinkPad X280, Arch Linux ISO 2026.11.01. All commands in this stage are observational/read-only.

Observed results:

| Check | Result | Status |
|---|---|---|
| USB installer | `/dev/sda`, 7.5G, USB, model Flash Disk; partitions `/dev/sda1` (1.1G) and `/dev/sda2` (109M) | VERIFIED |
| Additional device | `/dev/sdb`, 0B, SD/MMC reader, removable=1 | VERIFIED; not the internal SSD |
| Internal SSD | `/dev/nvme0n1`, 238.5G, WDC PC SN730 SDBQNTY-256G-1001, serial `193839803177`, NVMe; partitions p1 100M FAT, p2 16M, p3 237.8G NTFS, p4 530M NTFS | VERIFIED |
| NVMe mountpoints | No mountpoints shown for the NVMe disk or its partitions in this `lsblk` snapshot | VERIFIED for this snapshot |
| Mount tree | Root is `overlay` from `/run/archiso/airootfs`; visible system mounts are proc, sysfs, devtmpfs, tmpfs, and related virtual filesystems | VERIFIED from displayed `findmnt -R /` |
| Loop device | `/dev/loop0` backs `/run/archiso/copytoram/airootfs.sfs` and is mounted at `/run/archiso/airootfs` as squashfs | VERIFIED |
| Swap | `/proc/swaps` contains only its header; no active swap entries | VERIFIED for this snapshot |

Topology assessment:
- The displayed overlay upper/work paths are under `/run/archiso/cowspace`; `findmnt` shows `/run` backed by tmpfs. The displayed loop backing file is under `/run/archiso/copytoram`. These observations indicate the Live Environment's shown root/loop path is RAM-backed rather than located on the internal NVMe SSD.
- No NVMe partition appears as a mount source in the displayed mount tree, and no active swap entry is shown.
- These are point-in-time command observations from a photograph. They do not replace a complete programmatic dependency walk over mountinfo, sysfs block-device holders/slaves, loop backing files, and swap sources. Therefore the project's target-exclusion/topology validator has **NOT YET BEEN RUN** on this host, and SSD eligibility remains **NOT VERIFIED**.
- The extra `/dev/sdb` SD/MMC reader is recorded to avoid confusing it with either the USB installer (`/dev/sda`) or internal NVMe (`/dev/nvme0n1`).

**Stage 9 result:** Raw live topology observations recorded; no SSD mount or active swap was visible. Repository discovery/validation functions have not yet been executed on hardware. No disk mutation occurred and no destructive authorization is implied.


## Stage 10 — One-command live storage validation

The read-only hardware check is packaged as `scripts/validate-live-storage.sh` so operators do not need to type or maintain a long inline Bash block. Run it from any directory after cloning the project:

```bash
bash scripts/validate-live-storage.sh
```

The script requires UEFI boot and the expected X280 internal SSD identity (model family `WDC PC SN730`, serial `193839803177`). It discovers all whole disks, prints their safety-relevant properties, requires exactly one identity match, and calls the repository's live target/topology validator. It fails closed if dependencies, identity, or topology cannot be verified. It performs no partitioning, formatting, encryption, mounting, or disk writes. Do not treat a successful read-only check as authorization to erase the disk or as proof that a future destructive executor is safe.

**Status:** IMPLEMENTED in the repository. Bash syntax and fixture checks have CI coverage on earlier commits. Physical-device execution is NOT TESTED. The next required evidence is a successful run on the X280 Arch Live environment after the zero-capacity removable-reader fix. Preserve its complete output; earlier photographs do not validate the project script or its programmatic topology walk.


## Historical evidence boundary before PR #9 — 2026-11-07

- **CI VERIFIED:** run #185 passed at `8aa3a447ca1b5fa7cae52dd94759d83fab8aaf9a`; this covers repository automation only.
- **Physical observations VERIFIED from user-provided terminal photographs:** UEFI boot, Arch ISO environment, USB installer identity, internal WDC NVMe model/serial alias, current partition listing, visible mount tree, loop-backed live root, and no active swap in the captured snapshots (Stages 8–9). These are point-in-time observations, not continuous guarantees.
- **Project live validator NOT TESTED on hardware:** `scripts/validate-live-storage.sh` has not yet been run on the laptop. In particular, its complete programmatic mount/sysfs/loop/swap dependency walk has not been evidenced on the X280.
- **Native helper NOT TESTED on a real block device:** CI validates compilation and CLI behavior; exclusive-open behavior, ioctl behavior, hot-unplug, and descriptor lifecycle against disposable/physical block devices remain outstanding.
- **Historical status only:** destructive execution was not implemented in the pre-PR #9 snapshot. The current branch has a separate initial destructive installer; its physical behavior remains NOT TESTED.

## 2026-11-07 — Physical Arch ISO live-validator attempt

The first run of `scripts/x280-archiso-test.sh` on the physical X280 passed the Arch ISO, UEFI, Lenovo vendor, and ThinkPad X280 DMI checks. The raw inventory showed the internal NVMe and Windows partitions, the installer USB, and an SD/MMC reader reported as a removable whole disk with zero capacity. No active swap was listed.

The project validator then failed during `storage::discover_candidates` with `jq: invalid size`. The failure was traced to treating every whole-disk record with a zero capacity as a fatal discovery error. The SD/MMC reader is not a usable storage candidate, but its presence should not prevent discovery of the actual SSD.

The follow-up change now skips **only** a whole-disk record where `lsblk` reports a numeric size of zero and `RM=true`. A zero-sized non-removable disk, negative/unknown/non-numeric size, or unknown removable state remains a fail-closed error. Regression fixtures cover the removable-zero case, non-removable-zero rejection, and unknown-size rejection.

The original report is stored at `reports/x280-archiso-storage-test-20261107T082432Z.log`. It is preserved as evidence of the failed attempt; it is not rewritten to imply success.

**Validation status at the time of this historical entry:** GitHub Actions run #191 (`42356761102`) passed on commit `6e784d08927996b7bb9af3c144e9fd3dbc5555ac`: Bash syntax, ShellCheck, configured shfmt, and 12 test scripts passed. Later PR #9 CI evidence is recorded in `docs/12-IMPLEMENTATION-STATUS-AND-CHANGELOG.md`. The physical X280 validator has **not** yet been evidenced as passing after the fix. No disk mutation was performed or authorized.


## Current installer and validation references

The authoritative description of the PR #9 destructive installer, configuration stages, limitations, and physical-test gate is [Stage 9 — Initial Interactive Arch Installer](15-ARCH-INSTALLER-INITIAL-EXECUTION.md). The canonical storage/boot contract is [Installation and Disk](04-INSTALLATION-AND-DISK.md). Do not duplicate those procedures here.

The canonical test command, test manifest, persistent report format, and test-layer limitations are maintained in [tests/README.md](../tests/README.md). Current branch status, exact commit references, and CI run evidence are maintained in [Implementation Status and Changelog](12-IMPLEMENTATION-STATUS-AND-CHANGELOG.md).

**Current acceptance boundary:** fixture/static CI and the disposable loop-device integration test do not establish full VM installation, physical X280 installation, firmware boot, LUKS unlock, root mount, recovery behavior, or hibernation. The physical live storage validator still requires successful execution evidence on the actual X280. Never treat a successful read-only validator as authorization to erase a disk.
