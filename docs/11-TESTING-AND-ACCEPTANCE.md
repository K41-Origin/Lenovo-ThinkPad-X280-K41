# Testing and Acceptance

## Current status
PLANNED. This documentation change does not implement or test installer behavior.

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
- Disk identity and stable identifiers are reported.
- Proposed partition plan appears before confirmation.
- Destructive operations require explicit confirmation.
- Ambiguous target identity stops execution.
- Interrupted installation does not automatically repartition.
- Signature/integrity failures never bypass verification.
- Logs and reports contain no secrets.

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
- Assert destructive-tool invocations explicitly, including an expected call count of **zero** for every abort, cancellation, ambiguity, incomplete-plan, and changed-target case.
- Keep fixtures deterministic and avoid relying on unstable device-path ordering or real hardware discovery in unit tests.
- Do not treat a passing mock test as proof of correct real-disk behavior; validate integration separately in an isolated environment.
- If an implementation cannot expose a stage safely for testing, document the design limitation and resolve it before enabling destructive operations.

## Integration and hardware validation
Use isolated VMs where suitable; VM tests do not fully validate X280 hardware. Test on the actual X280 only with authorization and verified target. Check boot, encryption, filesystem, network, audio, desktop, and services. Actual hibernation must be tested manually.

## Acceptance gates
A release candidate requires reviewed requirements and architecture, passing static checks, mocked safety/error paths, verified package/upstream dependencies, docs consistent with behavior, and evidence for hardware claims. Disclose known failures and untested items.

## Results
No installer tests were run for this documentation-only change. Published docs and links should be checked after commit; do not report this as an installer test pass.
