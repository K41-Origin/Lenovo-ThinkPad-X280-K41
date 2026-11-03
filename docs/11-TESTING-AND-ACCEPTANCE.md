# Testing and Acceptance

## Current status
The installer remains PLANNED and has not been tested end to end. The GitHub Actions workflow validates Bash syntax and runs eleven repository test scripts. Run #130 (`41618517486`) passed both steps at commit `cf7f221bdcd2707616720b6bb56ddedb3a2d4a7d`. This is fixture-based CI, not hardware validation. Passing these checks does not verify installation integration or behavior on the ThinkPad's physical storage device.

The storage foundation is IMPLEMENTED through read-only discovery/topology checks, target-bound GPT layout planning, live prerequisite collection, explicit human confirmation, and one-shot final revalidation. The approved profile describes GPT, a 1 GiB EFI System Partition, LUKS2, ext4, a swapfile, systemd-boot, and a UKI. Resume readiness remains deferred until the swapfile offset is verified. No partitioning, formatting, encryption, mounting, or other disk mutation is implemented.

Stage 5 adds a dry-run operation manifest and deterministic failure-injection simulator. The manifest describes the intended order (GPT, partition creation/type assignment, LUKS2 format/open, ext4), while the simulator records attempted/completed steps and stops at an injected failure. It does not invoke an executor callback, shell command, block-device API, or privileged utility. A ready final gate must match the current plan's review digest and target identity; simulation consumes the gate. This is test infrastructure and architecture validation only, not a production storage executor.

## Stage 6 — Storage execution safety audit

The Stage 6 review inspected the actual `installer` entry point and all `lib/*.sh` modules in the current repository tree, with focused review of the storage planner, live prerequisite collector, confirmation gate, topology validator, and dry-run model.

Findings:
- The executable entry point is `installer`, not `install.sh`. It sources only `lib/common.sh` and `lib/preflight.sh`; it remains diagnostic-only and returns nonzero for preflight because installation is disabled.
- The storage discovery, topology, planning, prerequisite, confirmation, and dry-run modules contain no active disk-writing workflow. The reviewed source contains no invocation path for partitioning, filesystem formatting, LUKS formatting/opening, package installation, mounting, or service mutation.
- `lib/storage-execution-dry-run.sh` creates in-memory operation descriptors and result records only. It contains no external-command dispatch, command substitution, shell evaluation, or executor callback.
- The final gate and plan digest are in-process integrity checks, not a security boundary against a compromised process, arbitrary caller mutation, or malicious root code. They also do not lock the target or eliminate the time-of-check/time-of-use gap. Any future executor must revalidate the selected device immediately before the first mutation and define how it prevents or detects target replacement during execution. The dry-run simulator must not be treated as an authorization system.
- The Stage 5 test initially failed because its helper declared a local variable named `target`, shadowing the caller's final-revalidation output array. The helper's local target and nameref variables were renamed to avoid both output-array shadowing and a circular nameref; run #107 passed the complete suite without circular-nameref warnings.
- Static source inspection is not a formal proof of absence of side effects. Future executor work must introduce a separate injectable boundary, test zero destructive invocations on every failed gate, and undergo a new review before any real-disk execution is considered.

No real disk, package database, service, firmware setting, or network configuration was changed during this audit.

The prerequisite binder itself records caller assertions; the live collector is the component that performs the read-only checks and produces fresh evidence. Fixture-based tests mock discovery and topology behavior, so they do not establish that the actual X280 disk is unused or that hardware identity is correct at installation time.

## Stage 7 — Mock execution boundary and target revalidation

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

The diagnostic-only entry point supports `--help` and `--preflight`. It sources only the common/preflight modules, uses a repository-relative module path, and never treats diagnostics as installation approval. `--preflight` intentionally returns nonzero because no installation workflow exists. The focused entry test covers help from another working directory, invalid arguments, non-success from preflight, explicit disabled status, and a static check that the entry point does not source installation modules or name common destructive/system-changing commands. Static checks are supplementary and do not prove the absence of every possible side effect.

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

## Results
On 2026-11-03, GitHub Actions run `41613718273` passed Bash syntax validation and all seven repository test scripts at commit `7779aa99943982d85033f8157a8d001998c2a7ad`. The storage-plan tests additionally verified completeness checks for geometry/profile/prerequisites, rejection of failed or missing prerequisites, prerequisite-evidence digest binding, canonical decimal validation, and ESP profile-size consistency. This validates the pure data/validation layer only; prerequisite values are still caller-supplied assertions and have not yet been integrated with live host discovery or a confirmation/execution gate.

On 2026-11-03, GitHub Actions run `41613051552` passed Bash syntax validation and all seven repository test scripts at commit `6ce3e9334f360ab59e78b865325360f3d76fa456`. The storage-plan tests confirmed target/profile binding, deterministic serialization and digest behavior, digest changes after target/profile mutation, rejection of missing stable identity, and rejection of multiline values. No real disk or system configuration was modified. The installer remains PLANNED; this CI result is not an end-to-end installation or hardware test.

The first-slice test command `bash tests/test-common-preflight.sh` passed with six test groups against temporary local copies whose blob hashes matched the committed files. `bash -n` also passed for both modules and the test script. ShellCheck and shfmt were unavailable. These results do not constitute an end-to-end installer test; no real disk, package, service, or network configuration was changed.


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


On 2026-11-03, GitHub Actions run #136 (`41618734278`) passed Bash syntax validation and all eleven test scripts at commit `3fcc970f58d76e5f62d6b76f767a4075cbe0a95b`. The mock execution-boundary cases passed, including successful eight-step execution, stable-identity change abort, read-only safety-attribute change abort, zero mock calls after an initial probe failure, partial-failure recovery marking, and callback rejection. The full topology suite also passed after its synthetic major:minor IDs were isolated from the host filesystem device ID. No real block-device handle was opened and no disk was modified.
