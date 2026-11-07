# Implementation Status and Changelog

## Current verified baseline — 2026-11-07

- Repository head inspected: `main` at `8aa3a447ca1b5fa7cae52dd94759d83fab8aaf9a`.
- GitHub Actions run #185 (`42349907205`) completed successfully on that exact commit. Bash syntax, ShellCheck, configured shfmt checks, and the canonical 12-script test suite passed.
- Physical X280 observations from user-provided terminal photographs are documented in `docs/11-TESTING-AND-ACCEPTANCE.md` (Stages 8–9). They establish point-in-time raw system facts, not a successful run of the project's live validator.
- `scripts/validate-live-storage.sh` has not yet been run on the physical laptop. Native block-device behavior remains NOT TESTED; no real storage executor or installer workflow exists.

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
| Planned module placeholders | PLANNED | Nine domain files under `lib/` contain comments only; no base-system, bootloader, user, desktop, hardware, package, security, validation, or reporting implementation exists in them. |
| Common logging helpers | TESTED | `lib/common.sh` provides argument-checked stderr logging. First-slice tests passed against a temporary local copy whose Git blob hash matched the committed file. |
| Read-only preflight helpers | TESTED | `lib/preflight.sh` provides root-status, boot-mode, required-command, and network-link diagnostics. First-slice tests passed against a temporary local copy whose Git blob hash matched the committed file; no system changes are performed by these checks. |
| Test plan and focused test harnesses | IMPLEMENTED | Fixture-based tests cover the currently implemented diagnostic and storage-planning slices. `tests/run.sh` is the canonical test entry point; CI and developer instructions use it. No end-to-end installer or hardware test is implied. |
| Approved UEFI/LUKS2/ext4/hibernation design direction | IMPLEMENTED | Architecture direction recorded; systemd-boot asset placement, exact initramfs parameters, swap sizing, resume-offset lifecycle, VM and X280 validation remain PLANNED/NOT TESTED. |
| Native mkinitcpio UKI boot design | IMPLEMENTED | Decision documented: default UKI on 1 GiB ESP at `/efi/EFI/Linux/`, source kernel/configuration on encrypted root, systemd-boot discovery, no initial fallback UKI. Generation/update lifecycle and boot behavior remain PLANNED / NOT TESTED. |
| Read-only storage discovery and target validation | TESTED (mocked CI) | `lib/storage.sh` uses `lsblk`, `jq`, `swapon`, `readlink`, and `base64` to discover whole disks, require internal NVMe, compare supplied WWN/serial identities, reject duplicate IDs, removable/read-only disks, mounted descendants, and active swap descendants (including symlink aliases). GitHub Actions run #21 (commit `fdeb517d5fc552bcbba6532280d1eba5f5a3669d`) passed all fixture tests and Bash syntax checks. Real X280/disk behavior remains NOT TESTED; no destructive storage operations exist. |
| Storage module contract documentation | IMPLEMENTED | Proposed stage interface and requirement/test traceability are documented in `lib/storage.sh` comments and `docs/03-ARCHITECTURE-AND-MODULES.md`; this does not mean storage behavior is implemented. |
| Read-only storage topology validation | TESTED (fixture CI) | `lib/storage-topology.sh` is integrated into `storage::validate_target`; it walks partition and holder/slave dependencies, checks mounted devices and swap, and resolves loop-backed squashfs plus overlay lower/upper/work paths by backing filesystem major:minor. Synthetic fixtures and mocked integration pass in CI. Real Arch ISO/X280 sysfs behavior remains NOT TESTED. |
| Read-only GPT storage plan calculator | TESTED (fixture CI) | `lib/storage-plan.sh` calculates 1 MiB-aligned ESP/root sector boundaries from disk bytes and logical/physical sector sizes, reserves GPT metadata for 128 entries, and proposes RAM-plus-margin swap size with minimum root headroom. Geometry, capacity, overflow, and decimal-input fixtures pass CI. No disk commands are invoked. |
| Storage review, confirmation, and final revalidation | TESTED (fixture CI) | `lib/storage-confirmation.sh` renders the plan, binds typed confirmation to a stable review digest and target, consumes confirmation, and revalidates live prerequisites before producing an in-process ready gate. Run #107 passed the ten-script suite. |
| Storage execution dry-run model | TESTED (fixture CI) | `lib/storage-execution-dry-run.sh` builds an eight-step in-memory manifest and simulates stop-on-failure behavior. Run #108 passed on its own commit. This is not a production executor or a security boundary. |
| Storage execution boundary | TESTED (mock-only CI) | `lib/storage-execution-boundary.sh` re-probes target path, major:minor, capacity, and stable ID before each injected mock operation; rejects changed identity; and records partial-failure recovery state. Run #148 passed at audit baseline commit `719f537341b6d410ce2980144fee86237da01b42`. The gate binds path, major:minor, capacity, stable-ID kind/value, WWN, serial, transport, removable, and read-only attributes. It opens no device handle and does not close the real kernel TOCTOU window. |
| Native block-device handle acquisition (Stage 8 first slice) | IMPLEMENTED (read-only prototype) | `native/storage-handle.c` opens a supplied `/dev/<name>` read-only with exclusive/no-follow/close-on-exec flags, checks descriptor type and partition status, reads geometry/read-only state by ioctl, reports major:minor and optional diskseq, and retains the FD until stdin EOF. Compile/CLI checks pass in CI; real block-device behavior, stable-ID correlation, NVMe/removable validation, and end-to-end Bash lifecycle remain NOT TESTED / PLANNED. No storage write or installer integration exists. |
| Repository audit | IMPLEMENTED (report only) | `docs/15-REPOSITORY-AUDIT.md` is the current 2026-11-07 repository audit. It records the 58-file tree, current CI evidence, physical observation boundary, documentation corrections, and remaining readiness gates. |
| Installer functionality | PLANNED | No actual installation/configuration logic implemented. |
| Static checks | TESTED (CI) | GitHub Actions run #185 (`42349907205`) passed Bash syntax, ShellCheck, configured shfmt, and the canonical test suite at `main` commit `8aa3a447ca1b5fa7cae52dd94759d83fab8aaf9a`. This does not establish physical hardware behavior. |
| X280 raw Arch ISO observations | VERIFIED (limited, point-in-time) | User-provided terminal photographs document UEFI, live root, USB, NVMe identity/serial alias, partitions, visible mount tree, loop backing, and no active swap in captured snapshots. The project's live validator has not yet been run; installation and hibernation remain NOT TESTED. |

## Changelog

### 2026-11-03 — Repository-wide structural and documentation audit
- Audited the current `main` tree at baseline commit `719f537341b6d410ce2980144fee86237da01b42`: 51 tracked files, 17 Markdown files, 30 `.sh` files plus the `installer` Bash entry point, one GitHub Actions workflow, and one hardware profile.
- Confirmed no byte-identical tracked-file blobs, no duplicate function names among production Bash definitions, and no broken relative Markdown links in the 17 reviewed Markdown files.
- Recorded semantic documentation duplication, repeated test manifests/fixtures, placeholder-module clarity, hardware-profile drift risks, CI reproducibility/lint gaps, and a Bash nameref validation inconsistency in `docs/15-REPOSITORY-AUDIT.md`.
- Corrected literal escaped-newline formatting in this changelog and refreshed current CI references to run #148. The audit baseline CI run passed Bash syntax validation and all eleven test scripts; this is fixture CI, not hardware validation.
- Audit/reporting only: no production source, storage behavior, or tests were modified. No destructive operation was run.


### 2026-11-03 — Record Stage 8 native block-device access design
- Added `docs/14-STAGE-8-NATIVE-DEVICE-ACCESS.md` as the canonical design record for a narrow native C helper that retains a block-device file descriptor and validates identity from that descriptor.
- Recorded documented Linux interface facts and their limits: block-device O_EXCL behavior, fstat/st_rdev, descriptor-based ioctls, diskseq correlation, and the distinction between kernel-internal APIs and userspace interfaces.
- Explicitly documented the unresolved descriptor-to-tool boundary: retaining an FD does not make a pathname-based partitioning/LUKS/filesystem utility descriptor-bound. No /proc/self/fd shortcut or fallback to pathname rechecks is accepted without proof.
- Defined lifecycle, identity fields, fail-closed behavior, privilege/protocol boundaries, recovery requirements, and disposable-loop/VM acceptance tests.
- Documentation/design only. No C helper, device open, exclusive lock, loop-device test, destructive utility, or hardware test was performed. The installer remains diagnostic-only and destructive storage execution remains unimplemented.


### 2026-11-02 — Restrict storage target validation to internal NVMe and detect active swap
- Recorded the owner-approved scope: full replacement of the internal SSD; Windows and recovery partitions are not retained; removable and non-NVMe targets are rejected.
- Extended read-only discovery to require successful `swapon` output, correlate active swap block devices with descendants after resolving symlink aliases, and fail closed when safety fields or required tools are unavailable.
- Target revalidation now requires internal NVMe transport and checks every stable identity supplied by the caller; discovery rejects duplicate WWN or serial identifiers.
- Expanded mocked fixtures for mounted mapper descendants, active swap and aliases, removable media, duplicate WWN, changed serial, missing safety state, and command failures.
- CI run #21 on commit `fdeb517d5fc552bcbba6532280d1eba5f5a3669d` passed the full repository suite, including the active-swap symlink-alias regression.
- No real disk was queried or modified. This is fixture-tested logic, not real-hardware verification.


### 2026-11-02 — Add repository-native automated Bash validation
- Added `.github/workflows/bash-tests.yml` for pushes to `main`, pull requests targeting `main`, and manual dispatch.
- The workflow checks Bash syntax for discovered `.sh` files and the `installer` entry point, then executes all four required test scripts on an Ubuntu GitHub-hosted runner. Permissions are limited to `contents: read`; the job has a 10-minute timeout.
- Updated `tests/README.md` to document the CI gate and distinguish implementation from a successful run.
- Workflow file was re-fetched from GitHub and its contents verified. The Actions run has not yet been confirmed; no claim is made that the full suite passed.


### 2026-11-02 — Integrate read-only target inventory into preflight
- `lib/preflight.sh` now loads the inventory module and exposes `preflight::check_target_inventory`, which collects procfs/sysfs facts, prints a summary, validates required facts, and compares the detected host with the X280 profile.
- `installer --preflight` invokes this check; missing, inconsistent, or mismatched inventory blocks the preflight result. No disk enumeration or storage operation is introduced.
- Updated the mocked preflight gate test to assert inventory invocation and failure handling. Validation is pending; do not mark this integration TESTED until local syntax and fixture/gate tests pass.

### 2026-11-02 — Validate inventory completeness and consistency
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

### 2026-11-02 — Mocked preflight gate test
- Added `tests/test-preflight-gate.sh` using an isolated copy of the entry point and a deterministic mocked preflight module.
- Covers unresolved boot mode, required-command failure, optional network diagnostic failure, and the invariant that preflight never returns installation success.
- This exercises orchestration control flow only; there are no installation stages to invoke or block yet. Execution results must be recorded after running the fetched test file locally.

### 2026-11-02 — Diagnostic-only entry point
- Replaced the placeholder output with explicit `--help` and read-only `--preflight` handling using module paths relative to the entry point.
- Preflight reports unresolved boot mode and required-command failures, treats network-link diagnostics as optional, and never returns success because installation remains disabled.
- Added `tests/test-installer-entry.sh` for argument handling, invocation from another working directory, diagnostic-only status, and a static entry-point safety boundary.
- Syntax and focused tests were run against temporary local copies matching fetched GitHub blobs. This is not an end-to-end installer test; no disk, package, service, or network configuration was changed.


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


### 2026-11-02 — Add standalone storage topology and layout planning modules
- Added `lib/storage-topology.sh` to analyze a sysfs block-device graph, include partition descendants, traverse `holders`/`slaves`, compare mounted filesystem major:minor values, and map active swapfiles to their containing mount. Unresolved inputs fail closed.
- Added `tests/test-storage-topology.sh` with synthetic sysfs, mountinfo, and swap fixtures for unrelated mounts, device-mapper dependencies, mounted target partitions, swapfile backing, unresolved swapfile mounts, and invalid target IDs.
- Added `lib/storage-plan.sh`, a pure arithmetic GPT planner for 1 MiB alignment, a 1 GiB ESP, 128-entry GPT metadata bounds, remaining root partition, and RAM-plus-margin swap proposal. It does not invoke partitioning or filesystem tools.
- Added `tests/test-storage-plan.sh` for 512-byte and 4Kn logical sectors, alignment, capacity, and invalid geometry. Added both test scripts to GitHub Actions and updated `tests/README.md`.
- IMPORTANT LIMITATION: these modules are standalone and are not yet integrated into `storage::validate_target` or an installer workflow. The topology analyzer has not been tested against a real running kernel/sysfs tree; the planner has not been validated against a real target SSD. GitHub Actions run is pending at the time of this entry. No disk was queried or modified.

### 2026-11-02 — Integrate storage topology gate and harden planner bounds
- Integrated `storage::topology_check_target` into `storage::validate_target`; target discovery now requires the kernel major:minor identifier from `lsblk` and checks the live sysfs graph, mountinfo, and active swaps before accepting an internal NVMe target.
- Added a fail-closed filesystem-type check for mountinfo records. Known kernel pseudo-filesystems are allowed; filesystems with unresolved or potentially multi-device backing (including btrfs and overlay) are rejected rather than guessed.
- Added fixture coverage for btrfs, overlay, malformed mountinfo, topology-gate invocation/failure, and planner integer overflow.
- The storage discovery integration test mocks the topology call; the topology algorithm test uses synthetic sysfs/mountinfo/swaps. GitHub Actions run #39 on commit `13d61ea1925f1b6add50bfb957a15e4ed40460fe` completed successfully: Bash syntax validation and all seven test scripts passed.
- LIMITATIONS: no live X280 kernel/sysfs or real Arch ISO mount topology has been tested. Loop-device backing files and overlay lower-layer paths are not resolved; because these are not proven independent of the target, the current gate can reject a normal live ISO environment. Do not treat target validation as ready for destructive installation until that gap is addressed and verified. No disk was queried or modified.

### 2026-11-02 — Resolve loop and overlay backing dependencies
- Extended `lib/storage-topology.sh` to resolve loop-backed squashfs mounts through the sysfs loop `backing_file` attribute and compare the backing file's `st_dev` major:minor against the target dependency closure.
- Added overlay mount handling for `lowerdir`, `upperdir`, and `workdir`; each path must exist and resolve to a filesystem outside the target dependency closure. Unresolved paths remain fail-closed.
- Added full mountinfo-dispatch fixtures for safe/unsafe loop-backed squashfs and overlay mounts, plus active block-swap dependency detection. Tests use temporary files and synthetic sysfs; no mounts, loop devices, or real block-device writes are created.
- GitHub Actions run #53 on commit `b8d90d44f71b494079baff4edb74d95614430070` completed successfully. Bash syntax checks and all seven repository test scripts passed.
- LIMITATIONS: no real Arch ISO boot environment or ThinkPad X280 kernel/sysfs tree has been tested. Mountinfo overlay option escaping and kernel-specific loop sysfs behavior still require validation on the actual Arch ISO. Storage operations remain unimplemented; no disk was queried or modified.


### 2026-11-03 — Storage execution safety audit (Stage 6)
- Audited the actual `installer` entry point and the repository shell modules. Confirmed the entry point sources only common/preflight modules and remains diagnostic-only; there is no `install.sh` file.
- Reviewed storage discovery, topology, planning, live prerequisite collection, confirmation/final-revalidation, and the Stage 5 dry-run model. No active disk-writing or system-configuration execution path was found in these modules.
- Confirmed the dry-run model builds in-memory descriptors/results only; it has no external command dispatch, command substitution, shell evaluation, or executor callback.
- Corrected a Stage 5 test-helper defect: a local variable shadowed the caller's final-revalidation output array. The helper variable is now `bound_target`.
- GitHub Actions run #107 (`41617706958`) passed Bash syntax validation and all ten test scripts at commit `0526112b092b0a0a1e06c4c7eadaee9245af9ac7`; the topology and dry-run fixtures passed without circular-nameref warnings.
- Updated testing and acceptance documentation. No physical disk or host system configuration was changed.
- LIMITATION: static review and fixture CI do not establish real-hardware safety. The in-process gate/digest is not a security boundary against compromised root code and does not close the time-of-check/time-of-use gap. A future executor must define immediate target revalidation and protection against target replacement. Real storage execution remains PLANNED and disabled.


### 2026-11-03 — Storage execution boundary and TOCTOU design (Stage 7)
- Added `lib/storage-execution-boundary.sh` as a mock-only orchestration boundary. Callback names are restricted to `storage::mock_*`; the final gate and plan digest must match before the gate is consumed.
- Added a fresh mock identity probe immediately before each of the eight logical operations. The compared snapshot includes device path, kernel major:minor, capacity, stable-ID kind/value, WWN, serial, transport, removable flag, and read-only flag. The final gate binds these attributes and the boundary checks gate/plan consistency.
- Extended the final gate with target capacity so the execution model compares the complete currently recorded target identity.
- Added an operation ledger and explicit `recovery_required` state for target changes or failures after partial mock completion. No automatic rollback is attempted.
- Added `tests/test-storage-execution-boundary.sh` and configured CI for eleven test scripts. Test and acceptance documentation now states clearly that pathname rechecks do not close the real kernel TOCTOU window.
- GitHub Actions run #136 (`41618734278`) passed Bash syntax validation and all eleven test scripts at commit `3fcc970f58d76e5f62d6b76f767a4075cbe0a95b`. The added read-only-attribute mismatch test also passed. No real block-device handle was opened, no device lock was acquired, and no disk or host configuration was changed.
- LIMITATION: this is an orchestration test seam, not a production executor, authorization boundary, or real TOCTOU defense. A native open-handle/identity and recovery design must be separately reviewed before any destructive executor.


### Stage 7 validation follow-up — stabilize topology fixtures
- CI exposed a pre-existing fixture assumption: hard-coded synthetic major:minor values could collide with the GitHub runner's actual temporary-filesystem device ID. This made the full squashfs-loop test environment-dependent.
- Updated `tests/test-storage-topology.sh` to derive the backing filesystem ID and allocate a separate synthetic major range for all fixture devices/mount records. This removes the host-device collision observed in failed runs #128/#129.
- Run #130 passed the complete topology suite and all eleven repository tests. This is a test-fixture determinism correction, not a change to live topology behavior.


### Stage 7 target-identity completeness follow-up
- Extended the final gate to bind stable-ID kind, WWN, serial, transport, removable, and read-only attributes in addition to path, major:minor, and capacity.
- The mock execution boundary now checks gate-to-plan consistency and compares all of those fields before every mock operation.
- Added a fixture where the device becomes read-only between steps; the next mock operation is blocked.
- Run #140 passed all eleven tests and Bash syntax validation. Real-device locking and TOCTOU closure remain NOT IMPLEMENTED.


### Stage 7 gate consistency validation
- Added a test that mutates a target safety attribute in the in-process gate while leaving the plan unchanged. The execution boundary rejects the mismatch before consuming the gate or invoking any mock operation.
- GitHub Actions run #140 (`41618904994`) passed Bash syntax validation and all eleven repository test scripts at commit `30562c35a043f4fa10bf23d6153ba051b823350e`.


### 2026-11-07 — Stage 8 native acquisition first slice
- Added native/storage-handle.c, a read-only prototype for opening a candidate block device with O_RDONLY | O_EXCL | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK, checking the descriptor with fstat, rejecting partition devices, and reading geometry/read-only state via descriptor ioctls.
- The helper reports major:minor and optional diskseq, and retains the descriptor until stdin EOF. It exposes no command channel and does not invoke storage utilities.
- Added isolated compile/CLI validation to the canonical test manifest and CI compiler dependency.
- Not implemented: stable WWN/serial correlation, actual removable-state value, internal NVMe enforcement, expected-plan matching, Bash protocol supervision, disposable loop-device tests, and real executor integration. No real block device was opened during this change; installer remains diagnostic-only.


### 2026-11-07 — Documentation synchronization after repository audit
- Updated README and architecture status to distinguish the implemented Stage 8 read-only native prototype from untested block-device runtime behavior and the absent real executor.
- Updated testing/status records to cite CI run #185 at the exact `main` commit and to distinguish raw physical observations from execution of the project's live validator.
- Preserved the X280 SSD model and serial in the hardware validation path because they are deliberate target-specific identity evidence for this single-laptop project. The repository is currently public; publication of a device-unique serial is an explicit exposure trade-off, not a claim that it is non-sensitive.
- No installer, storage, native helper, hardware profile, or destructive behavior was changed in this documentation synchronization.

### 2026-11-07 — Live storage discovery: zero-capacity removable reader
- Fixed `storage::discover_candidates` to skip a whole-disk record only when its capacity is explicitly numeric zero and `RM=true`. Zero-capacity non-removable disks and missing/invalid sizes remain fatal; the target validation rules are unchanged.
- Added discovery fixtures for zero-capacity removable readers, zero-capacity non-removable disks, and unknown sizes. Reset the output associative array between repeated discovery calls so the fixtures exercise the intended code paths.
- Moved the original failed X280 Arch ISO report from the malformed top-level path ` reports` to `reports/x280-archiso-storage-test-20261107T082432Z.log`; the report contents were preserved.
- Recorded the observed failure and explicit follow-up validation status in `docs/11-TESTING-AND-ACCEPTANCE.md`.
- **TESTED:** GitHub Actions run #191 (`42356761102`) passed on commit `6e784d08927996b7bb9af3c144e9fd3dbc5555ac`, including Bash syntax, ShellCheck, configured shfmt, and all 12 repository test scripts. The added fixtures explicitly passed for zero-capacity removable skip, zero-capacity non-removable rejection, and unknown-size rejection. The physical X280 validator remains pending; the fix has not yet been verified on the laptop.
- No disk-writing operation, package installation, or hardware configuration change was performed.


### 2026-11-07 — Stage 9 base-system bootstrap first slice
- Replaced the lib/base-system.sh placeholder with a guarded bootstrap module for an already-prepared target: it requires an ext4 root mounted from an unlocked /dev/mapper/* device and a separate vfat ESP mounted at ROOT/efi.
- Added the minimal base package transaction using pacstrap -K and UUID-based genfstab -U generation. Existing non-empty target fstab files are preserved; incomplete generated fstab output is rejected.
- The module does not partition, format, open LUKS, mount, configure boot, or run automatically from the installer entry point. It requires exact caller confirmation tokens and root privileges for package installation/fstab generation.
- Added fixture coverage for module source safety, valid/invalid mount layouts, refusal to target the live root, and invalid confirmation.
- IMPLEMENTED: module code and focused fixture tests committed on feature/base-system-bootstrap-2026-11-07.
- NOT TESTED: no local shell execution or GitHub Actions run has yet validated this change. No pacstrap transaction or target filesystem write was performed.
- Next: wire this stage into the interactive installer only after a safe storage preparation/mount workflow is available; complete boot configuration and end-to-end VM install remain outstanding.


### 2026-11-07 — Persistent test evidence
- Updated `tests/run.sh` to create a unique `reports/test-runs/<UTC timestamp>/` directory for each run.
- Each test script receives its own stdout/stderr log; the run also writes `combined.log` and `summary.md` with checkout metadata and per-test exit status.
- Reports remain local artifacts and are not committed automatically; inspect for environment-specific information before staging.
- **IMPLEMENTED:** persistent evidence generation in the canonical test runner and corresponding test documentation.
- **NOT TESTED:** the updated runner has not yet been executed locally or in CI. No test result is claimed by this change.
