# Implementation Status and Changelog

## Status

| Area | Status | Evidence / next action |
| --- | --- | --- |
| Repository baseline at initial commit | VERIFIED | Historical baseline inspection identified LICENSE and a minimal README.md in the initial commit. This does not verify the current repository as a whole. |
| AI development instructions | IMPLEMENTED | `AGENTS.md` defines repository inspection, focused changes, safety rules, test honesty, and verification/reporting requirements; content re-fetched after creation. |
| Requirements capture | IMPLEMENTED | Planning choices recorded in requirements/decision log. |
| Owner-reported X280 hardware baseline | IMPLEMENTED | `docs/13-X280-HARDWARE-BASELINE.md` records Windows-observed and owner-reported specifications, evidence limitations, and Linux verification checklist. |
| X280 target hardware profile | IMPLEMENTED | `config/hardware/thinkpad-x280.conf` stores the operational target values; values are not runtime detection or disk-selection authority. |
| Read-only host inventory | IMPLEMENTED | `lib/inventory.sh` collects CPU, memory, and DMI facts, validates required-fact availability and CPU consistency, and compares vendor/product/CPU/memory with the target profile. Actual X280 Linux detection remains NOT TESTED. |
| Documentation split | IMPLEMENTED | Domain documents are present on main. |
| Single interactive architecture | IMPLEMENTED | Decision and module responsibilities documented in this branch. |
| Diagnostic-only installer entry point | TESTED (mocked gate) | `installer --help` and `installer --preflight` are implemented; preflight now includes read-only host inventory and X280 profile comparison. Mocked gate covers inventory failure and keeps installation disabled; fixture test exercises the actual inventory adapter. Preflight always returns nonzero because installation is disabled. |
| Module file skeleton | IMPLEMENTED | Focused shell module placeholders added under `lib/`. |
| Common logging helpers | TESTED | `lib/common.sh` provides argument-checked stderr logging. First-slice tests passed against a temporary local copy whose Git blob hash matched the committed file. |
| Read-only preflight helpers | TESTED | `lib/preflight.sh` provides root-status, boot-mode, required-command, and network-link diagnostics. First-slice tests passed against a temporary local copy whose Git blob hash matched the committed file; no system changes are performed by these checks. |
| Test plan and focused test harnesses | IMPLEMENTED | Existing common/preflight/entry tests and new `tests/test-inventory.sh` are present. Inventory syntax and focused fixture tests passed on a temporary local reconstruction of fetched GitHub contents; actual X280 Linux detection remains NOT TESTED. Installer integration tests remain PLANNED. |
| Approved UEFI/LUKS2/ext4/hibernation design direction | IMPLEMENTED | Architecture direction recorded; systemd-boot asset placement, exact initramfs parameters, swap sizing, resume-offset lifecycle, VM and X280 validation remain PLANNED/NOT TESTED. |
| Native mkinitcpio UKI boot design | IMPLEMENTED | Decision documented: default UKI on 1 GiB ESP at `/efi/EFI/Linux/`, source kernel/configuration on encrypted root, systemd-boot discovery, no initial fallback UKI. Generation/update lifecycle and boot behavior remain PLANNED / NOT TESTED. |
| Storage module contract documentation | IMPLEMENTED | Proposed stage interface and requirement/test traceability are documented in `lib/storage.sh` comments and `docs/03-ARCHITECTURE-AND-MODULES.md`; this does not mean storage behavior is implemented. |
| Installer functionality | PLANNED | No actual installation/configuration logic implemented. |
| Static checks | TESTED | `bash -n` passed for the entry point, common/preflight modules, and both focused test scripts. ShellCheck and shfmt were unavailable. |
| X280 installation / hibernation | NOT TESTED | Requires controlled VM and actual hardware testing. |

## Changelog

### 2026-11-02 — Integrate read-only target inventory into preflight\n- `lib/preflight.sh` now loads the inventory module and exposes `preflight::check_target_inventory`, which collects procfs/sysfs facts, prints a summary, validates required facts, and compares the detected host with the X280 profile.\n- `installer --preflight` invokes this check; missing, inconsistent, or mismatched inventory blocks the preflight result. No disk enumeration or storage operation is introduced.\n- Updated the mocked preflight gate test to assert inventory invocation and failure handling. Validation is pending; do not mark this integration TESTED until local syntax and fixture/gate tests pass.\n\n### 2026-11-02 — Validate inventory completeness and consistency
- Added `inventory::validate_required_facts` for CPU model, numeric memory total, DMI vendor, and DMI product identity.
- Detects conflicting CPU model records rather than silently accepting the first model; profile comparison now checks DMI vendor as well as product, CPU, and memory.
- Bounds memory parsing and rejects malformed or unsupported numeric values before arithmetic. Added fixture tests for missing facts, invalid memory, CPU conflicts, and vendor mismatch.
- This remains read-only fixture validation; actual X280 hardware is NOT TESTED.

### 2026-11-02 — Harden inventory profile parsing and fixtures
- Restricted parsing to four whitelisted single-quoted fields; rejects malformed and duplicate fields and validates decimal memory bounds without sourcing/evaluating the profile.
- Rejects readonly associative arrays as inventory output targets.
- Added fixture cases for mismatched identity, missing facts, malformed/duplicate profile values, shell-syntax non-execution, and readonly output arrays.
- Actual ThinkPad X280 Linux hardware detection remains NOT TESTED.
- Validation on a temporary local reconstruction of the fetched file contents: `bash -n lib/inventory.sh`, `bash -n tests/test-inventory.sh`, and `bash tests/test-inventory.sh` all passed. This is not a repository checkout, GitHub Actions run, or actual-hardware test.

### 2026-11-02 — Add X280 target profile and runtime inventory (initial implementation)
- Added `config/hardware/thinkpad-x280.conf` with the owner-confirmed X280 target values. The profile is project configuration, not runtime detection or disk-selection authority.
- Added `lib/inventory.sh` to collect CPU identity/logical thread count, memory, and DMI facts from read-only procfs/sysfs, render a summary, and compare observed DMI product, CPU model, and memory range against the target profile. The profile parser reads only whitelisted literal fields and does not source/evaluate the file.
- Added fixture-based `tests/test-inventory.sh`; updated architecture, README, and test instructions. Inventory test execution and syntax validation are pending; actual Linux hardware discovery on the X280 remains NOT TESTED.
- No disk discovery, partitioning, package installation, service changes, or hardware tuning was added.

### 2026-11-02 — Record owner-reported ThinkPad X280 hardware baseline
- Added `docs/13-X280-HARDWARE-BASELINE.md` with the supplied model, CPU, memory, graphics, display, SSD, network, audio, camera, firmware, and battery details.
- Recorded evidence source and confidence; omitted the battery serial number and other unnecessary identifiers. Clarified that Windows `SCSI` InterfaceType does not establish physical storage transport and that Linux driver/device IDs remain to be verified.
- Linked the baseline from the README and hardware/power/network documentation. Updated the requirements log to distinguish captured baseline data from outstanding Linux-side verification.
- Documentation-only. Repository writes were re-fetched for verification; no Linux hardware, installer, syntax, or automated tests were run.

### 2026-11-02 — Finalized native mkinitcpio UKI boot design
- Approved a single default mkinitcpio-generated UKI on the 1 GiB FAT32 ESP at `/efi/EFI/Linux/`, with the source kernel and mkinitcpio configuration on encrypted ext4 root and systemd-boot discovering the UKI.
- A fallback UKI is not required in the initial profile; the official Arch ISO USB is the recovery path. Reconsider fallback only after measuring artifact sizes and ESP update headroom.
- Recorded kernel-update/ESP-mount and known-good-artifact preservation requirements, plus dedicated UKI acceptance tests. The supplied 8 GiB RAM and 256 GB SSD are planning inputs; swap sizing and target partitioning are still separate unresolved decisions.
- Documentation-only. No code, mkinitcpio preset, UKI, boot entry, VM, or hardware test was performed; this design is not yet implemented or verified.

### 2026-11-02 — Approved storage/boot design direction
- Recorded the approved direction: UEFI/GPT, FAT32 ESP (approximately 1 GiB initial proposal), systemd-boot, LUKS2-encrypted ext4 root, swapfile inside encrypted root, official Arch `linux`, and mkinitcpio with systemd-based `sd-encrypt` as the candidate early-unlock path.
- Documented the mandatory systemd-boot boot-asset placement decision, swap sizing from actual RAM/storage constraints, resume mapper/offset requirements, Secure Boot limitation, and planned VM/hardware acceptance tests.
- Documentation-only. No installer code, partitioning, bootloader configuration, hibernation setup, syntax tests, VM tests, or hardware tests were performed.

### 2026-11-02 — Mocked preflight gate test\n- Added `tests/test-preflight-gate.sh` using an isolated copy of the entry point and a deterministic mocked preflight module.\n- Covers unresolved boot mode, required-command failure, optional network diagnostic failure, and the invariant that preflight never returns installation success.\n- This exercises orchestration control flow only; there are no installation stages to invoke or block yet. Execution results must be recorded after running the fetched test file locally.\n\n### 2026-11-02 — Diagnostic-only entry point\n- Replaced the placeholder output with explicit `--help` and read-only `--preflight` handling using module paths relative to the entry point.\n- Preflight reports unresolved boot mode and required-command failures, treats network-link diagnostics as optional, and never returns success because installation remains disabled.\n- Added `tests/test-installer-entry.sh` for argument handling, invocation from another working directory, diagnostic-only status, and a static entry-point safety boundary.\n- Syntax and focused tests were run against temporary local copies matching fetched GitHub blobs. This is not an end-to-end installer test; no disk, package, service, or network configuration was changed.\n

### 2026-11-02 — Common/preflight first-slice validation
- Ran `bash -n` on `lib/common.sh`, `lib/preflight.sh`, and `tests/test-common-preflight.sh`; all passed.
- Ran `bash tests/test-common-preflight.sh` against temporary local copies. Their Git blob hashes matched the committed GitHub files; all six test groups passed, including the unavailable-network-tool case.
- ShellCheck and shfmt were unavailable. The installer was not run; no real disk, package, service, or network configuration was changed.

### 2026-11-02 — Common and read-only preflight first slice
- Defined first-slice contracts and acceptance cases for `lib/common.sh` and `lib/preflight.sh`.
- Implemented side-effect-free logging helpers and explicitly invoked, read-only preflight diagnostics; added `tests/test-common-preflight.sh`.
- Added a documented command for running the tests. Initial test execution and syntax-check results are recorded in the following validation entry; no installer, package, service, network, or disk changes were performed.

### 2026-11-02 — Manual bootstrap review procedure
- Added a documented Git retrieval and pre-execution review sequence to the architecture, including resolved-commit display, working-tree/log inspection, and shell-code review aids.
- Updated the README workflow to require review before any project code is invoked.
- Explicitly states that the commands stop before invoking the installer and that SHA/clean-tree checks do not prove code safety.
- Documentation-only change. No installer behavior or tests were run.

### 2026-11-02 — Bootstrap safety and installation-gate documentation
- Clarified that the resolved project commit must be inspected before fetched installer code is executed, and that a commit SHA alone does not establish safety.
- Tightened REQ-INSTALL-005 to require passing prerequisites, displaying the complete storage plan for the identified target, and explicit user confirmation before target-disk-dependent installation or destructive storage actions.
- Added planned bootstrap pre-execution gate test cases and strengthened assertions that failed safety gates result in zero destructive storage calls.
- These are documentation and contract changes only. They do not implement installer behavior. No installer, syntax, automated, disk, VM, or hardware tests were run.

### 2026-11-02 — Storage module contract and traceability
- Documented the planned `lib/storage.sh` stage interface and its fail-closed safety boundary; no executable storage behavior was added.
- Linked the storage contract to REQ-INSTALL-005, REQ-DISK-002, REQ-DISK-003, REQ-DISK-006, and REQ-RECOVERY-001, plus the mapped test cases in `docs/11-TESTING-AND-ACCEPTANCE.md`.
- Recorded the change as documentation/contract work only. No syntax, automated, disk, VM, or hardware tests were run.

### 2026-11-01 — AI development instructions
- Added `AGENTS.md` with repository inspection, change-scope, safety, testing, verification, and reporting rules for AI-assisted work.
- Linked the instructions from `README.md`.
- Re-fetched the new file from the target branch and checked required sections. No installer logic was added and no tests were run because this change is documentation-only.

### 2026-11-01 — Interactive installer skeleton
- Added the safe `installer` placeholder and module placeholders under `lib/`.
- Added the initial test strategy.
- Recorded the decision to use one interactive flow from the Arch ISO shell and retrieve latest `main` via Git while displaying the resolved commit SHA.
- No disk, package, service, or system configuration operations were implemented.
- No syntax, static-analysis, integration, or hardware tests were run in this change.

### 2026-11-01 — Documentation split
- Added project charter, requirements/decisions, architecture outline, installation/disk, security/authentication, desktop UX, hardware/power/network, package/software management, development/bug bounty, recovery/reporting, testing/acceptance, and implementation status.
- README is the project entry point and documentation index.
- No installer behavior was tested or verified by the documentation change.

## Status evidence and reporting

Use the status definitions in `docs/01-PROJECT-CHARTER.md`; this document does not redefine project-status meanings.

For each test, record the exact test/command, date, outcome, and limitations. Writing a configuration file alone does not verify behavior.
