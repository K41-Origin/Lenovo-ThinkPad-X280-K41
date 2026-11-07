# Repository-Wide Documentation and Implementation Audit

## Audit record

- Date: 2026-11-07
- Scope: branch `feature/base-system-bootstrap-2026-11-07` and PR #9.
- Method: inspect the GitHub tree, current source files, tests, documentation owners, and recorded GitHub Actions evidence.
- No local repository checkout, VM installation, physical disk operation, or X280 boot test was performed as part of this documentation audit.

## Executive summary

The repository contains two different installer paths that must never be conflated:
- Top-level `installer --preflight`: read-only diagnostic entry point.
- `scripts/install-arch-x280.sh`: separate initial destructive Arch base installer on PR #9.

The second path is implemented but is not a complete project installer and has not been tested end-to-end in a VM or on the physical X280. Current CI evidence covers static/fixture checks and selected storage utility interfaces on a disposable loop-backed image only.

The documentation previously contained contradictory statements that the installer did not exist, that no destructive execution was implemented, and that a retained descriptor C helper was used by the installer. Those claims described earlier stages or confused separate implementations. They have been reconciled in the canonical documents listed below.

## Canonical documentation map

| Topic | Canonical owner | Other documents should do |
|---|---|---|
| Project scope and status vocabulary | `docs/01-PROJECT-CHARTER.md` | Refer to definitions; do not redefine statuses |
| Approved requirements and decisions | `docs/02-REQUIREMENTS-AND-DECISIONS.md` | Link requirement IDs; do not restate full decisions |
| Architecture and module boundaries | `docs/03-ARCHITECTURE-AND-MODULES.md` | Describe domain details only where owned |
| Storage, encryption, boot, swap/resume, recovery | `docs/04-INSTALLATION-AND-DISK.md` | Link to canonical technical contract |
| Domain policies | `docs/05` through `docs/10` | Keep policies focused; do not duplicate installer procedure |
| Acceptance and evidence boundaries | `docs/11-TESTING-AND-ACCEPTANCE.md` | Reference test commands and status ledger |
| Current implementation and CI evidence | `docs/12-IMPLEMENTATION-STATUS-AND-CHANGELOG.md` | Keep exact commit/run facts here |
| Owner-reported hardware baseline | `docs/13-X280-HARDWARE-BASELINE.md` | Treat as planning data, not runtime detection |
| Native C descriptor prototype | `docs/14-STAGE-8-NATIVE-DEVICE-ACCESS.md` | Do not conflate with Bash installer descriptors |
| Initial destructive installer scope and gate | `docs/15-ARCH-INSTALLER-INITIAL-EXECUTION.md` | Link here; do not duplicate full operator procedure |
| Test commands, manifest, and artifacts | `tests/README.md` | Use this as the single test-running guide |

## Source/code findings

1. `installer` is diagnostic-only; it does not invoke the destructive installer.
2. `scripts/install-arch-x280.sh` performs the initial destructive workflow on the PR #9 branch: X280/SSD identity checks, target-bound plan and confirmation, final revalidation, GPT/LUKS2/ext4/ESP creation, guarded base bootstrap, target configuration, and initial systemd-boot UKI generation.
3. `scripts/configure-arch-x280.sh` configures hostname, user/password, timezone, locale, Intel microcode, sudo wheel access, swapfile, and NetworkManager from inside `arch-chroot`.
4. The implemented UKI configuration uses systemd-based `sd-encrypt` hooks and `rd.luks.name=<UUID>=cryptroot`; resume is not configured.
5. `lib/storage.sh` and associated storage modules own read-only discovery/planning/validation and a mock-only execution boundary. The PR #9 installer currently orchestrates destructive commands directly. This differs from the earlier planned architecture in which `lib/storage.sh` would be the sole destructive owner. The deviation is now explicit in architecture/storage docs and remains a review/refactor item.
6. `native/storage-handle.c` is a standalone read-only prototype and is not integrated into the installer. The installer uses Bash-held descriptors and inherited `/proc/self/fd/N` paths. The loop integration test is bounded evidence for selected utility interfaces, not proof that every race or physical controller failure is impossible.

## CI and hardware evidence

- GitHub Actions runs #130 and #131 passed on commit `2aae853df0c74c8ae9a46e702d457884f1d91fd8`, including Bash syntax, ShellCheck, and the 15-script suite with the disposable loop-device integration test.
- Those runs predate the latest documentation-only commits. Do not attribute their success to a later branch head without a fresh run.
- Earlier run #94 and the older main baseline run #185 are historical evidence for their own commits only.
- User-provided Arch ISO terminal observations establish point-in-time UEFI, USB, internal NVMe, partition, mount/overlay, and swap facts. They do not prove the repository's live validator passed.
- The zero-capacity removable SD/MMC discovery failure was addressed with regression fixtures. A successful rerun of `scripts/validate-live-storage.sh` on the physical X280 after that fix is still NOT TESTED.
- VM installation, physical SSD installation, successful UKI boot, LUKS unlock/root mount, recovery workflow, and hibernation remain NOT TESTED.

## Documentation synchronization result

Updated in this documentation pass:
- `README.md`: index and ownership links now include both Stage 9 installer and current audit; renamed anchors were checked and repaired.
- `AGENTS.md`: explicit canonical document ownership map.
- `docs/02-REQUIREMENTS-AND-DECISIONS.md`: indexed the approved report-only Intel microcode policy as REQ-HW-006.
- `docs/05-SECURITY-AND-AUTHENTICATION.md` and `docs/07-HARDWARE-POWER-AND-NETWORK.md`: linked security/hardware policy ownership and explicitly recorded the implementation deviation.
- `docs/08-PACKAGE-AND-SOFTWARE-MANAGEMENT.md`: clarified that Nano is in the current base package list, not the optional application bundle.
- `docs/09-DEVELOPMENT-AND-BUG-BOUNTY.md`: removed duplicated package/tool policy and linked to its owner.
- `docs/03-ARCHITECTURE-AND-MODULES.md`: actual two-entry-point model, module ownership, installer sequence, and architecture deviation.
- `docs/04-INSTALLATION-AND-DISK.md`: actual partition type, encryption/UKI parameters, swap/resume boundary, and recovery limitations.
- `docs/11-TESTING-AND-ACCEPTANCE.md`: old pre-installer audit findings marked historical; current evidence references centralized.
- `docs/12-IMPLEMENTATION-STATUS-AND-CHANGELOG.md`: status matrix and CI evidence corrected to distinguish tested commits from later edits.
- `docs/14-STAGE-8-NATIVE-DEVICE-ACCESS.md`: native C helper separated from Bash descriptor-path implementation.
- `docs/15-ARCH-INSTALLER-INITIAL-EXECUTION.md`: consolidated implementation scope, limitations, automated evidence, and physical-test gate.
- `tests/README.md`: consolidated the test manifest/procedures, removed repeated installer and live-validation instructions, and linked to canonical installer/storage/status documents.

Historical logs and timestamped reports are retained as immutable evidence. Failed reports are not edited to imply success. Detailed historical changelog entries remain historical; they are not current status.

## Remaining inconsistencies / gates

1. Obtain a fresh green CI run on the latest documentation commit.
2. Re-run the fixed read-only live storage validator on the physical X280 and preserve its report.
3. Complete an independent source review of installer failure paths, cleanup, descriptor semantics, and post-destructive recovery before considering physical execution.
4. Resolve the REQ-HW-006 deviation: current target configuration automatically installs Intel microcode despite the approved report-only policy.
5. Resolve or formally accept the architecture deviation that destructive orchestration currently lives in the installer script rather than a dedicated storage executor module.
6. Validate installation in a disposable VM before physical X280 testing where practical.
7. Verify actual UKI boot, LUKS unlock, root mount, account login, and recovery behavior. Hibernation/resume remains a separate later stage.

## Conclusion

The documentation set is now organized around explicit owners and a consistent distinction between approved design, implemented code, CI-tested behavior, and untested hardware behavior. This audit does not declare the installer ready for destructive laptop testing. The current gate is fresh CI plus successful read-only live validation and a final installer safety review.
