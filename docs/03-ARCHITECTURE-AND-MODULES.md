# Architecture and Modules

## Status
The repository contains a skeleton plus tested first-slice logging and read-only preflight helpers. Installer orchestration and installation behavior are not implemented end to end.

## Architecture decision
Use one project-owned interactive installer launched from the shell of an official, unmodified Arch Linux ISO booted from USB. The same interactive flow coordinates base Arch installation, desktop configuration, selected packages, validation, and reporting. Modules remain separate internally to keep responsibilities testable and failures easier to isolate.

## Repository layout
```text
.
├── installer
├── lib/
│   ├── common.sh
│   ├── preflight.sh
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
- `lib/preflight.sh`: first slice reports root status, boot-mode indicators, required-command availability, and network-link state; actual hardware/storage inventory and further preflight gates remain future work. No destructive changes.
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

### Storage module contract — PLANNED

**Owner:** `lib/storage.sh` is the sole owner of disk partitioning/formatting and the only module permitted to invoke destructive storage tools. The entry point may orchestrate storage stages but must not issue disk commands itself.

**Traceability:** `REQ-INSTALL-005` is the global gate; `REQ-DISK-003` defines target identification, full-plan review, and explicit confirmation; `REQ-DISK-002` supplies storage/encryption/swap/resume constraints; `REQ-DISK-006` blocks destructive work while bootloader/resume compatibility is unresolved; `REQ-RECOVERY-001` governs interrupted runs. Acceptance criteria are in `docs/02-REQUIREMENTS-AND-DECISIONS.md`; linked test cases are in `docs/11-TESTING-AND-ACCEPTANCE.md`.

**Proposed stage interface** (function names and data representation remain a design contract, not implemented behavior):
1. `storage::discover_candidates` — read-only disk discovery; return candidate identities and available stable identifiers.
2. `storage::build_plan <target_identity> <verified_storage_profile>` — construct a complete plan only after required storage and boot/resume design inputs are resolved.
3. `storage::render_plan <plan>` — display the selected physical target and the complete planned partition, encryption, filesystem, and swap/resume choices.
4. `storage::validate_target <target_identity> <plan>` — re-read identity and verify that the target still matches the plan.
5. `storage::confirm_plan <target_identity> <plan>` — obtain explicit user confirmation bound to the reviewed target and plan; cancellation is a non-success result.
6. `storage::execute_plan <validated_target> <confirmed_plan>` — sole stage permitted to invoke destructive storage tools; revalidate preconditions immediately before the first destructive command.
7. `storage::verify_result <plan>` — read-only verification after execution reports success.

**Common contract requirements:**
- Discovery, planning, display, validation, confirmation, execution, and verification must remain distinct testable stages.
- Ambiguous/missing identity, incomplete plan, failed prerequisite, changed target, cancellation, or unknown critical state must fail closed.
- Return statuses must distinguish success from safe abort/cancellation and critical failure. Missing output or unset state must never count as success.
- Never pass or log passphrases, recovery keys, or credentials. Keep privilege elevation limited to the stage that requires it.
- No exact partition layout, bootloader, encryption mapping, or resume mechanism is implied by this contract; those decisions remain blocked on verified design.
- Every abort path must be testable with mocks and assert zero destructive-tool invocations. Do not run automated tests against real disks.

**Stage ordering:** preflight success → discover candidates → build complete plan → render plan → validate target → explicit confirmation → immediate target/precondition revalidation → execute → verify result. Any failed gate exits before execution. Recovery after interruption must inspect current state and must not automatically repeat destructive work.


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
