# Architecture and Modules

## Status
PLANNED. These are constraints and candidate boundaries, not implemented code.

## Goals
- Small focused modules with explicit inputs, outputs, privileges, and failure behavior.
- Idempotency where practical; minimize privileged operations.
- Mockable tests for disk, package, network, and service operations.
- Central status/reporting with secret redaction; avoid duplicated package lists and competing services.

## Candidate layers
1. ISO bootstrap and safe retrieval of project code.
2. Preflight: boot mode, network, hardware inventory, disk identity, dependencies.
3. Interactive installation: plan and confirm storage before destructive work.
4. Base system: users, encryption, kernel, firmware, boot configuration.
5. Post-install: desktop, network, security baseline, packages, hardware policy.
6. Optional components: AUR, selected BlackArch, developer tools.
7. Validation: syntax/config checks and health checks.
8. Reporting and recovery: stage tracking, diagnostics, final report.

## Design constraints
Decide whether both an ISO installer and post-install tool are needed. Do not add frameworks without a clear requirement. Never pipe remote scripts into a shell or build AUR packages as root. Ambiguous disk identity or unverified boot/encryption design must stop the workflow. Interrupted runs must not automatically reformat disks.

## Candidate layout
README.md, docs/, install/, setup/, modules/, tests/, scripts/. Code directories are suggestions only; add them when justified by implementation.

## Module contract
Document purpose, non-goals, inputs, validation, privileges, changed files/services/packages, failure recovery, idempotency, tests, logging, dependencies, and upstream references.

## Implementation gate
Audit the repository, verify official upstream dependencies, agree on installation/post-install boundaries, and define acceptance tests before writing installer code.
