# Architecture and Modules

## Status
PLANNED. The repository now contains a file/directory skeleton only. Installer behavior is not implemented.

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
- Latest-`main` execution is a deliberate supply-chain trade-off: the branch can change after review and a commit can contain unsafe privileged code. Showing the SHA provides traceability but does not establish that code is safe. Before real disk operations, inspect/review the fetched code and do not proceed if its integrity or expected origin is uncertain.
- Never claim that fetching Git code alone proves correctness or safety.

## Module responsibilities
- `installer`: user-facing entry point, stage orchestration, cancellation, and high-level status. It must fail closed until implementation gates pass.
- `lib/common.sh`: shared logging without secrets, error contracts, stage tracking, privilege checks, and safe cleanup.
- `lib/preflight.sh`: inspect boot mode, network, actual hardware, available storage, and required commands; no destructive changes.
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
