# Testing and Acceptance

## Current status
The installer remains PLANNED and has not been tested end to end. The common/preflight and diagnostic-entry test scripts have been run against temporary local copies matching fetched GitHub blobs. This does not verify installation integration or hardware behavior.

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

## Diagnostic entry-point tests\n\nThe diagnostic-only entry point supports `--help` and `--preflight`. It sources only the common/preflight modules, uses a repository-relative module path, and never treats diagnostics as installation approval. `--preflight` intentionally returns nonzero because no installation workflow exists. The focused entry test covers help from another working directory, invalid arguments, non-success from preflight, explicit disabled status, and a static check that the entry point does not source installation modules or name common destructive/system-changing commands. Static checks are supplementary and do not prove the absence of every possible side effect.\n\nRun with `bash tests/test-installer-entry.sh`.\n\nThe separate `tests/test-preflight-gate.sh` runs a temporary copy of the entry point with a deterministic mocked preflight module. It verifies that unresolved boot mode and required-command failures remain failures and that the entry point never claims installation success; it also verifies that optional network-diagnostic failure does not change the required-gate outcome. Because actual installation stages do not exist yet, this tests control flow and the absence of known stage markers, not an end-to-end blocked installation.\n\n## Common and preflight first-slice tests

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

## Requirement-linked test cases

These are **planned test cases**, not executed tests. They map directly to the acceptance criteria for **REQ-DISK-003** in `docs/02-REQUIREMENTS-AND-DECISIONS.md`. When implementation begins, destructive commands must be replaced with mocks/fakes in automated tests; these cases must not operate on real disks.

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

## Integration and hardware validation
Use isolated VMs where suitable; VM tests do not fully validate X280 hardware. Test on the actual X280 only with authorization and verified target. Check boot, encryption, filesystem, network, audio, desktop, and services. Actual hibernation must be tested manually.

## Acceptance gates
A release candidate requires reviewed requirements and architecture, passing static checks, mocked safety/error paths, verified package/upstream dependencies, docs consistent with behavior, and evidence for hardware claims. Disclose known failures and untested items.

## Results
The first-slice test command `bash tests/test-common-preflight.sh` passed with six test groups against temporary local copies whose blob hashes matched the committed files. `bash -n` also passed for both modules and the test script. ShellCheck and shfmt were unavailable. These results do not constitute an end-to-end installer test; no real disk, package, service, or network configuration was changed.
