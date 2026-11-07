# Arch ISO bootstrap and source-review gate

## Purpose

The script `scripts/bootstrap-archiso.sh` is the operator-facing bootstrap for the existing initial installer. It does not partition or format disks itself. It retrieves the latest `main` branch with Git over HTTPS, verifies the expected origin and a clean checkout, prints the resolved 40-character commit SHA, and opens the relevant source files in a pager for manual review. After source review, it runs the consolidated read-only live-readiness gate, including the canonical test suite and X280 SSD identity/topology check. It launches the destructive installer only if that gate passes and the operator separately authorizes launch.

The bootstrap requires an interactive root shell from the official Arch Linux ISO. It does not pipe remote content into a shell and does not execute the installer until source review, a passing read-only readiness gate, and a second exact launch acknowledgement are complete.

## Run from the official Arch ISO

First obtain and inspect the bootstrap source itself through Git; do not execute an unreviewed downloaded copy:

```bash
git clone --depth 1 --single-branch --branch main https://github.com/K41-Origin/Lenovo-ThinkPad-X280-K41.git k41-bootstrap-review
cd k41-bootstrap-review
git rev-parse HEAD
less scripts/bootstrap-archiso.sh
bash -n scripts/bootstrap-archiso.sh
```

After independently reviewing the bootstrap script and confirming its behavior, launch it:

```bash
sudo bash scripts/bootstrap-archiso.sh
```

The Arch ISO root shell may already be root; in that case run `bash scripts/bootstrap-archiso.sh` without `sudo`.

The bootstrap creates a private checkout under `/root/k41-archiso.XXXXXX/repository`. It then pages through README/agent instructions, storage/boot policy, the hardware profile, the destructive installer, target configuration, readiness/validation scripts, storage/preflight modules, the canonical test runner, and every tracked test script. Review each file. The commit SHA and checkout path are printed before the review. At the end, type exactly:

```text
REVIEWED <40-character-commit-SHA> AND AUTHORIZE READ-ONLY READINESS CHECK
```

The placeholder must be replaced by the SHA printed by the script. Any other input stops without running readiness. The bootstrap then runs `bash scripts/x280-install-readiness.sh`. This gate must pass; it records a report under `reports/live-readiness/`. If any check fails, the bootstrap stops without launching the installer. After a PASS, type exactly `READINESS PASSED FOR <40-character-commit-SHA> AND AUTHORIZE INSTALLER LAUNCH` to launch the installer.

## Two distinct authorization gates

1. **Source-review gate:** acknowledges that the operator reviewed the displayed commit and authorizes running the read-only readiness check only.
2. **Storage-plan gate:** the installer independently identifies the target, displays its exact storage plan, requires explicit plan-bound confirmation, and revalidates target identity and prerequisites before destructive operations.

Passing the first gate is not permission to erase a disk. Do not confirm the storage plan unless the live target identity, backups/recovery arrangements, and full plan are correct.

## Limitations

- Git HTTPS transport and a printed commit SHA provide source traceability, not independent proof that the code is safe or signed by a trusted maintainer.
- The bootstrap does not perform a cryptographic signature verification of the commit.
- Manual source review remains mandatory; do not acknowledge a revision you have not reviewed.
- The installer still only implements the initial encrypted Arch base system. Desktop integration, hibernation/resume, recovery-key handling, ThinkPad tuning, and selective BlackArch integration remain unimplemented.
- Physical destructive installation and first boot on the X280 remain NOT TESTED. Follow the physical-test gate in [Stage 9](15-ARCH-INSTALLER-INITIAL-EXECUTION.md).

`bash tests/test-bootstrap-archiso.sh` performs static contract checks only. It does not clone the repository, run the readiness gate, execute the installer, or touch a disk.
