# Architecture and Modules

## Status
The repository contains tested first-slice logging/read-only preflight helpers and a diagnostic-only entry point. Installer orchestration and installation behavior are not implemented end to end.

## Architecture decision
Use one project-owned interactive installer launched from the shell of an official, unmodified Arch Linux ISO booted from USB. The same interactive flow coordinates base Arch installation, desktop configuration, selected packages, validation, and reporting. Modules remain separate internally to keep responsibilities testable and failures easier to isolate.

## Repository layout
```text
.
├── installer
├── lib/
│   ├── common.sh
│   ├── preflight.sh
│   ├── inventory.sh
│   ├── storage.sh
│   ├── base-system.sh
│   ├── bootloader.sh
│   ├── user-setup.sh
│   ├── desktop.sh
│   ├── hardware.sh
│   ├── packages.sh
│   ├── security.sh
│   ├── validation.sh
│   └── report.sh
├── tests/
│   └── README.md
├── docs/
└── README.md
```

## Bootstrap and source policy
- The installer is not the official `archinstall` application; it is this project's own entry point.
- Boot from the official Arch ISO, establish connectivity, then use Git to retrieve this repository and invoke `installer` explicitly.
- Approved project policy: use the latest `main` branch for each installation attempt and display the resolved commit SHA.
- Do not use `curl | sh`, `wget | sh`, or equivalent remote-code piping.
- Latest-`main` execution is a deliberate supply-chain trade-off: the branch can change after review and a commit can contain unsafe privileged code. Showing the SHA provides traceability, but does not establish that the code is safe or correct.
- Before executing fetched project code, inspect/review the resolved commit and relevant scripts, especially any code that may run with elevated privileges. Do not start the installer with elevated privileges before this review. If the origin, integrity, or contents of the fetched code are uncertain, stop and do not execute it.
- Security review must happen before code execution, not merely before disk operations. A disk-operation gate cannot undo unsafe actions that may already have occurred while privileged code was running.
- Keep privilege elevation limited to the specific operation that requires it; never treat fetching Git code, displaying a commit SHA, or passing a review checklist as proof that the code is safe.

### Manual bootstrap and pre-execution review

The following is the intended safe retrieval/review sequence, not an installer and not permission to execute the retrieved code. It deliberately stops before invoking `installer`.

```bash
set -eu
workdir="$(mktemp -d)"
git clone --branch main --single-branch https://github.com/K41-Origin/Lenovo-ThinkPad-X280-K41.git "$workdir/repo"
cd "$workdir/repo"

printf '\\nResolved commit: '
git rev-parse HEAD
git status --short
git show --format=fuller --stat --no-renames HEAD
git log -5 --oneline --decorate
git ls-files '*.sh' installer
git grep -n -E 'sudo|mkfs|parted|sgdisk|fdisk|cryptsetup|pacman|systemctl|curl|wget|eval|bash' -- '*.sh' installer || true
```

Review the full contents of `installer` and every tracked shell file, plus the relevant commit changes, before any execution. The search above is only a review aid: it is not exhaustive and a lack of matches does not prove safety. Confirm the repository URL, resolved commit, working-tree state, privilege transitions, remote-code handling, package verification, secret handling, and all disk/system-changing paths. A clean working tree and commit SHA provide traceability, not proof of correctness or trustworthiness.

**Stop conditions:** if the source, commit, integrity, relevant code, or effect of any privileged operation cannot be understood and reviewed, do not execute the installer. Do not run the project entry point with `sudo` or as root merely to inspect it. The current `installer` is a placeholder and exits without installing anything. Any future bootstrap automation must preserve this pre-execution review gate and must have dedicated tests before it is used for installation.

## Module responsibilities
- `installer`: user-facing entry point, stage orchestration, cancellation, and high-level status. It must fail closed until implementation gates pass.
- `lib/common.sh`: shared logging without secrets, error contracts, stage tracking, privilege checks, and safe cleanup.
- `lib/preflight.sh`: first slice reports root status, boot-mode indicators, required-command availability, and network-link state; no destructive changes.
- `lib/inventory.sh`: read-only collection and presentation of host hardware facts needed for planning; does not discover/select disks or apply settings.
- `lib/storage.sh`: identify candidate disk, render full plan, validate target identity, obtain explicit confirmation, then perform storage operations only after design approval.
- `lib/base-system.sh`: install/configure the base Arch system after storage and prerequisites are validated.
- `lib/bootloader.sh`: implement only the boot/encryption/resume combination verified in advance.
- `lib/user-setup.sh`: validate user/host values and configure account/sudo without logging credentials.
- `lib/desktop.sh`: install/configure verified Hyprland, Caelestia Shell, Quickshell, portals, audio, and desktop integration.
- `lib/hardware.sh`: discover hardware and apply only compatible, evidence-backed settings.
- `lib/packages.sh`: manage official packages and explicitly selected optional tools; preserve package signature verification.
- `lib/security.sh`: apply approved security settings and validate configuration.
- `lib/validation.sh`: run checks and distinguish VERIFIED, FAILED, and NOT TESTED.
- `lib/report.sh`: generate the final report and manage temporary diagnostics with secret redaction.

## Module contract
Before implementing a module, document its purpose, non-goals, inputs, validation, privilege requirements, changed files/services/packages, failure recovery, idempotency, tests, logging, dependencies, and upstream references.

### Common and preflight module contracts — TESTED (first slice only)

These contracts define the first implementation slice. They are read-only foundations; they do not authorize package installation, network reconfiguration, service changes, or disk operations.

#### `lib/common.sh`

**Purpose:** provide small shared primitives for predictable return statuses and safe diagnostics.

- Must be safe to source: no output, external commands, privilege changes, filesystem writes, or system changes at source time.
- Logging helpers write messages to stderr and must not accept or emit secret values. Callers are responsible for never passing secrets into log arguments.
- Provide a stage/status helper only if it can remain deterministic and avoid implicit global traps or hidden control flow.
- Helpers return explicit nonzero statuses on invalid input or failure; do not silently convert errors into success.
- Do not install global `ERR`/signal traps or change shell options for the caller. The entry point owns process-level traps and shell policy.
- Keep interfaces Bash-only and dependency-free; quote arguments and avoid `eval`.

#### `lib/preflight.sh`

**Purpose:** perform explicitly requested, read-only checks of the current live environment before any target-disk-dependent stage.

- Must be safe to source and must not run checks automatically when sourced.
- Each check is a separately callable function with a stable return code and a concise human-readable result.
- Initial checks are limited to: running as root (informational requirement for the live Arch ISO workflow), detecting UEFI versus legacy boot from read-only system indicators, checking required commands, and reporting basic network-interface/link state when tools are available.
- Missing optional diagnostic tools must be reported as unknown/unavailable, not as proof of failure or success. Required-command checks may fail explicitly.
- Do not probe external URLs, install packages, change network settings, invoke `sudo`, inspect or modify target-disk contents, or call destructive storage tools in this first slice.
- Preflight results are diagnostic inputs, not proof that a particular disk is safe or that boot/encryption/resume compatibility is resolved.
- The caller decides whether a failed required check blocks a later stage; no later stage is implemented in this slice.

#### First-slice acceptance boundary

- Sourcing either module produces no output and performs no external command or system mutation.
- Functions are deterministic under controlled fixtures/mocks where practical.
- Failures are distinguishable from success; unknown states are never silently reported as verified.
- Tests run without root and without real disk access. No package, service, network, or disk changes are permitted.
- The initial helper implementation and focused unit tests exist; the test script and Bash syntax check passed against temporary copies matching the committed blobs. End-to-end installer integration remains PLANNED.

### Inventory module contract — PLANNED

**Purpose:** collect a deterministic, read-only snapshot of host hardware facts needed by the installation planner. This module does not configure hardware and does not discover, select, read contents from, or modify target disks.

**Ownership boundaries**
- `lib/preflight.sh` owns initial environment readiness checks, including boot-mode indicators and required-command checks.
- `lib/inventory.sh` owns host hardware facts such as CPU identity, physical memory total, and DMI system identity where available.
- `lib/storage.sh` exclusively owns block-device discovery, stable disk identity, storage planning, and all partitioning/formatting operations.
- `lib/hardware.sh` owns later application of approved, evidence-backed hardware settings; it must not duplicate inventory collection logic.
- Inventory data is descriptive evidence, not approval to install or proof that a proposed configuration is compatible.

**Proposed public interface** (not implemented):
1. `inventory::collect_host <output_assoc_array_name> [proc_root] [sys_root]`
   - Collect host facts from read-only procfs/sysfs paths.
   - The first argument names a caller-declared Bash associative array, populated through a validated nameref; do not emit data as shell code or use `eval`.
   - Optional roots exist for deterministic fixture-based tests; production defaults are `/proc` and `/sys`.
   - Stable keys: `cpu.vendor`, `cpu.model`, `cpu.family`, `cpu.model_id`, `cpu.cores`, `memory.total_bytes`, `dmi.sys_vendor`, `dmi.product_name`, and `dmi.product_version`.
   - A key is omitted when its source is unavailable or invalid. Empty or missing values must not be fabricated or silently treated as verified.
2. `inventory::render_host_summary <input_assoc_array_name>`
   - Render known values as human-readable diagnostics only; never interpret values as shell syntax or commands.
   - Missing fields are explicitly displayed as unknown/unavailable.

**Input validation and behavior**
- Validate argument count, associative-array variable name, and fixture-root paths before reading.
- Use Bash built-ins for file reads and parsing where practical; no package installation, network access, privilege escalation, service changes, or writes.
- Never read block-device contents. Disk candidates and their stable identifiers come only from `storage::discover_candidates`.
- Source-time behavior must be inert: no output, command execution, filesystem writes, traps, or shell-option changes.
- Return `0` only when collection/rendering completes according to its contract; return `2` for invalid arguments/output variable; return `1` for an operational failure. Missing optional hardware fields alone are not a failure, but must remain absent/unknown.
- Do not log serial numbers or other unique device identifiers by default. If later requirements need them, expose only the minimum necessary fields and obtain a separate privacy review.
- No inventory result may be used to infer an unverified bootloader, encryption, resume, wireless compatibility, or exact storage layout.

**Acceptance boundary:** implementation requires fixture tests for supported and missing procfs/sysfs fields, malformed values, invalid output-array arguments, safe sourcing, and a read-only boundary. Tests must not require root or inspect real target disks. This contract is PLANNED; no inventory implementation or hardware verification exists.

### Storage module contract — PLANNED

**Owner:** `lib/storage.sh` is the sole owner of disk partitioning/formatting and the only module permitted to invoke destructive storage tools. The entry point may orchestrate storage stages but must not issue disk commands itself.

**Traceability:** `REQ-INSTALL-005` is the global gate; `REQ-DISK-003` defines target identification, full-plan review, and explicit confirmation; `REQ-DISK-002` supplies storage/encryption/swap/resume constraints; `REQ-DISK-006` blocks destructive work while bootloader/resume compatibility is unresolved; `REQ-RECOVERY-001` governs interrupted runs. Acceptance criteria are in `docs/02-REQUIREMENTS-AND-DECISIONS.md`; linked test cases are in `docs/11-TESTING-AND-ACCEPTANCE.md`.

**Proposed stage interface** (Bash associative-array records; design contract only, not implemented behavior):
1. `storage::discover_candidates <output_assoc_array_name>` — read-only block-device discovery; return candidate records with current device locator and available stable identity evidence. Enumeration order or device path alone must not resolve an ambiguous target.
2. `storage::build_plan <target_assoc_array_name> <profile_assoc_array_name> <output_plan_assoc_array_name>` — validate input schemas and resolved requirements, then build a complete plan. Unknown critical storage/boot/encryption/resume inputs block plan completion.
3. `storage::render_plan <plan_assoc_array_name>` — display the physical target and every proposed partition, encryption, filesystem, mount, swap, and resume choice before confirmation.
4. `storage::validate_target <target_assoc_array_name> <plan_assoc_array_name>` — re-discover and compare stable identity evidence and relevant device attributes against the plan snapshot. A changed device path is acceptable only when stable identity proves continuity; path equality alone is insufficient.
5. `storage::confirm_plan <target_assoc_array_name> <plan_assoc_array_name> <output_confirmation>` — obtain explicit final confirmation after review. The result binds the exact target identity and deterministic canonical plan digest; cancellation returns status 10.
6. `storage::execute_plan <target_assoc_array_name> <plan_assoc_array_name> <confirmation>` — sole stage permitted to invoke destructive storage tools. Immediately before the first destructive command, revalidate target, plan completeness/digest, prerequisites, boot/resume design, and confirmation.
7. `storage::verify_result <plan_assoc_array_name>` — read-only verification of resulting partition, encryption, filesystem, mount, and swap/resume state; report observed facts only.

**Data and status conventions**
- Interfaces use validated names of caller-declared Bash associative arrays (namerefs); never use `eval`, source serialized plans, or interpret plan values as shell code.
- Candidate records retain raw stable identifiers for comparison but must not log or display full serial numbers by default. Show only the minimum identifying details needed for safe target distinction.
- Plans have an explicit schema version and contain target identity snapshot, boot mode, ordered partition definitions, encryption/filesystem/mount details, swap/resume design, prerequisite evidence, and unresolved-decision state. No secrets or shell fragments are permitted in records.
- Confirmation is invalidated by any target identity, plan, schema, or required-evidence change. Digest serialization must be deterministic and safely testable before implementation.
- Status: `0` success; `1` operational/critical failure; `2` invalid arguments/schema; `10` cancellation/safe stop. Only `0` advances orchestration.

**Common contract requirements:**
- Discovery, planning, display, validation, confirmation, execution, and verification must remain distinct testable stages.
- Ambiguous/missing identity, incomplete plan, failed prerequisite, changed target, cancellation, or unknown critical state must fail closed.
- Return statuses must distinguish success from safe abort/cancellation and critical failure. Missing output or unset state must never count as success.
- Never pass or log passphrases, recovery keys, or credentials. Keep privilege elevation limited to the stage that requires it.
- No exact partition layout, bootloader, encryption mapping, or resume mechanism is implied by this contract; those decisions remain blocked on verified design.
- Every abort path must be testable with mocks and assert zero destructive-tool invocations. Do not run automated tests against real disks.

**Stage ordering:** preflight success → discover candidates → build complete plan → render plan → validate target → explicit confirmation → immediate target/precondition revalidation → execute → verify result. Any failed gate exits before execution. Recovery after interruption must inspect current state and must not automatically repeat destructive work.

### Installer orchestration contract — PLANNED

**Purpose:** define the responsibilities and gate order for the single user-facing `installer` entry point. This is a design contract only; no orchestration stage beyond the existing diagnostic preflight is implemented.

**Entry-point responsibilities**
- Own the interactive session, stage order, cancellation propagation, high-level status, and safe shutdown.
- Call focused module interfaces; do not duplicate module logic or perform storage, package, service, or network changes directly.
- Never source or invoke a later-stage module until its prerequisites and the applicable pre-execution review gate have passed.
- Treat missing, malformed, stale, or unknown stage output as a failure to establish the next gate; never infer success from empty output.
- Keep secrets out of arguments where practical, logs, temporary plan files, and reports. Secret collection and handling must be designed by the owning module.
- Do not elevate the entire entry point merely for convenience. Each module must declare the narrow privilege boundary for its operations.

**Top-level stage sequence**
1. **Preflight** — run required read-only environment checks. A failed required check blocks dependent stages; optional diagnostics remain informational.
2. **Inventory** — collect the hardware, firmware, and candidate-storage facts required for planning. Inventory is read-only. Unknown critical facts remain unresolved, not guessed.
3. **Plan** — build a complete installation plan from approved requirements and verified inventory. Do not silently substitute defaults for unresolved hardware, storage, boot, encryption, or resume decisions.
4. **Review** — present the relevant installation choices and the complete storage target/partition/encryption/filesystem/swap-resume plan in human-readable form.
5. **Confirm** — obtain the explicit final confirmation required by `REQ-INSTALL-005` and `REQ-DISK-003`, bound to the displayed target and plan. Cancellation exits safely.
6. **Execute** — invoke the owning modules in dependency order. The entry point coordinates but does not issue destructive storage commands. `lib/storage.sh` remains the sole owner of partitioning/formatting. Storage identity and critical preconditions must be revalidated immediately before the first destructive operation.
7. **Verify** — run read-only post-operation checks through the appropriate validation interfaces. Report each result as VERIFIED, FAILED, or NOT TESTED; do not claim success when a check was skipped or inconclusive.

**Gate and failure behavior**
- No target-disk-dependent installation stage may run until required preflight checks, inventory, planning, review, and the target/plan confirmation have succeeded.
- No destructive storage command may run if the target identity is ambiguous or changed, the plan is incomplete, a required prerequisite fails, confirmation is cancelled, or a critical state is unknown.
- A stage failure stops all dependent later stages. Independent diagnostics may be reported only if they are read-only and cannot obscure the original failure.
- Cancellation is a safe stop, not success. Critical failures stop for manual intervention. Recovery must inspect current system state and must not automatically repeat destructive work.
- The orchestrator must preserve the original failing stage and status in its final diagnostic; cleanup errors must not overwrite the primary failure.
- Automated tests must mock all disk/system-changing operations and assert zero destructive invocations for every blocked or cancelled path.

**Status convention (proposed; implementation pending):**
- `0` — stage completed successfully.
- `1` — operational or critical failure; dependent stages must stop.
- `2` — invalid invocation or invalid stage input.
- `10` — user cancellation or deliberate safe stop; this is not success and dependent stages must stop.

These values are an internal Bash interface proposal, not yet implemented. Modules must document any richer diagnostic detail separately without changing the rule that only status `0` advances the orchestration.

**Acceptance boundary:** the contract is considered implemented only when the entry point has deterministic stage sequencing, explicit module interfaces, cancellation/failure propagation, and mocked tests proving that blocked paths cannot reach destructive operations. Documentation alone does not satisfy this boundary.

## Safety and recovery boundaries
- Storage is the only module permitted to own partitioning/formatting logic; other modules must not call destructive disk tools directly.
- Disk discovery, proposed plan, target validation, explicit confirmation, execution, and post-operation verification are separate stages.
- An interrupted run must inspect the real current state and must never automatically wipe the disk again.
- Unknown critical failures stop for manual intervention.
- Never log secrets, bypass package signatures, or build AUR packages as root.

## Implementation gates
1. Verify current official Arch installation guidance and upstream desktop dependencies.
2. Finalize UEFI, partition, LUKS, bootloader, swapfile, and resume design.
3. Define exact module interfaces and privilege boundaries.
4. Add syntax/static checks and mocked tests before implementing destructive actions.
5. Test in an isolated VM before controlled testing on the ThinkPad X280.

## Testing
Syntax checks do not prove behavior. VM tests do not replace hardware checks for Wi-Fi, audio, suspend, hibernation/resume, lid behavior, and power management.


## Diagnostic entry-point slice — TESTED (limited scope)

The `installer` entry point supports `--help` and `--preflight` only. It resolves `lib/common.sh` and `lib/preflight.sh` relative to its own location, reports root status, boot-mode indicators, required-command availability, and optional network-link diagnostics. An unresolved boot mode or missing required command is reported as a preflight failure. Network diagnostics are optional and do not gate the diagnostic command.

**Important:** `--preflight` always exits nonzero because installation is not implemented. A successful set of read-only diagnostics is not an installation approval. The entry point does not source installation modules or invoke package, service, network-configuration, or storage operations. This boundary is checked by focused tests and code review; static text checks are not a proof against every possible side effect.

Validation covered Bash syntax and focused entry-point tests on temporary local copies matching the fetched GitHub blobs. No VM, hardware, installation, or real-disk tests were performed.
