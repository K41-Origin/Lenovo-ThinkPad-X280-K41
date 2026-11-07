# Tests

The repository currently has fifteen test scripts covering common/preflight behavior, installer entry handling, the X280 Arch installer, target-configuration, and post-install configuration static safety contracts, host inventory, storage discovery/topology, storage-plan arithmetic, live prerequisite collection, explicit confirmation/final revalidation, the storage dry-run model, the mock-only execution boundary, and descriptor-pinned disk-tool integration on a disposable loop device. These tests do not constitute end-to-end installation or real-hardware validation. The topology fixture now allocates synthetic major:minor IDs separately from the host temporary-filesystem ID to avoid environment-dependent collisions.

Run the complete test suite from the repository root:

```bash
bash tests/run.sh
```

`tests/run.sh` is the canonical manifest used by both local development and GitHub Actions. It requires `bash`, `jq`, and `python3` for the fixture suite. The C compiler (`cc`) is optional and gates only `tests/test-native-storage-handle.sh`; when unavailable, that test is recorded as SKIP while the other tests still run. Missing required dependencies, missing test scripts, or failed tests make the run exit non-zero. Install `jq` and `python3` using the package manager for the environment before running locally; install a C compiler (for example via `base-devel` on Arch) to enable the native-helper test.


Storage-discovery tests mock `lsblk` and `swapon` and use JSON fixtures. The topology module is called by `storage::validate_target` using the selected disk's kernel major:minor and live `/sys`, `/proc/self/mountinfo`, and `/proc/swaps`. The discovery test stubs that integration boundary; the topology test builds a synthetic sysfs graph and mountinfo/swaps fixtures. Coverage includes partition descendants, device-mapper holder/slave relationships, mounted dependencies, swapfiles, active block swap, loop-backed squashfs, overlay lower/upper/work directories, unresolved paths, malformed mountinfo, and unsupported filesystem types. Backing paths are mapped using their actual `st_dev` major:minor; no mounts or block-device writes are created.

The storage-plan test checks GPT bounds, 1 MiB alignment, 512-byte and 4Kn logical sectors, capacity rejection, RAM-plus-margin swap sizing, overflow, decimal normalization, and the Linux LUKS GPT partition type. Prerequisite tests mock live collection and fail-closed paths. Confirmation tests cover exact confirmation, cancellation, modified plans, changed identity, and topology failure. The dry-run test checks the eight-step operation manifest, gate binding, stale-plan rejection, one-shot gate consumption, and injected failure stop behavior. The mock execution-boundary test re-probes path/major:minor/capacity/stable-ID kind/value/WWN/serial/transport/removable/read-only attributes before every mock step, rejects target changes, failed probes, and tampered gate metadata, and records partial failure/recovery state. Neither test executes storage commands or closes real TOCTOU races.

The legacy `installer` entry point remains diagnostic-only. The separate `scripts/install-arch-x280.sh` is a destructive, interactive installer path. Its static test checks syntax and key safety ordering, but does not execute disk commands. Tests use fixtures/mocks and do not inspect or modify host disks. Storage discovery requires `lsblk`, `jq`, `swapon`, `readlink`, and `base64`.

Inventory tests use temporary procfs/sysfs-shaped fixtures; they do not inspect actual hardware or require root. The mocked preflight gate verifies inventory failure blocks preflight success and that no installation/destructive marker is invoked.

Initial and future test layers:
- Bash syntax checks for all shell files.
- ShellCheck and shfmt when available; neither is currently included in CI.
- Unit tests with mocked commands for preflight, stage tracking, and error handling.
- Storage tests using mocks and, later, disposable loop devices only in isolated environments; never target a real disk.
- Integration tests in a disposable VM before any controlled ThinkPad X280 installation.
- Hardware-only checks (Wi-Fi, audio, suspend, hibernate/resume, lid behavior) remain NOT TESTED until run on the actual device.

Never treat a successful syntax check or mocked test as proof that installation works.

## Live Arch ISO / ThinkPad validation

From the repository root on the target machine, run:

```bash
bash scripts/live-validation.sh
```

The script performs read-only host/boot/storage/network inventory, validates Bash syntax, runs ShellCheck and shfmt when installed, executes the canonical `bash tests/run.sh` suite, and records installer help/preflight output. Missing optional inventory/lint tools are recorded as SKIPPED; failures in syntax, available static checks, or the canonical suite make the script exit non-zero.

Evidence is saved automatically under `reports/live-validation/`:
- `YYYYMMDDTHHMMSSZ.md` — timestamped report; existing reports are never overwritten.
- `latest.md` — convenience copy of the most recent report.

Reports are local working-tree artifacts, not automatically committed or uploaded. Review them for sensitive environment details before sharing or committing. Keep timestamped reports as historical evidence and consult `latest.md` before repeating checks. A report applies only to its recorded checkout/commit and host snapshot; it does not prove installation works or authorize disk changes. Re-run after changing code, booting a different environment, changing hardware/storage state, or when fresh evidence is required.

The script is non-destructive: it does not partition, format, mount, install packages, alter services, or change firmware. The installer preflight's non-zero exit is recorded as informational because installation remains intentionally disabled.


The native Stage 8 helper test compiles `native/storage-handle.c` with strict compiler warnings and checks help/argument rejection in a temporary directory. It does not open a block device; exclusive-open contention, descriptor ioctls, diskseq, descriptor lifetime, hot-unplug, and loop-device behavior remain NOT TESTED until isolated disposable-device tests are added.

## Persistent test output

Every invocation of `bash tests/run.sh` creates a unique directory under `reports/test-runs/` and preserves:
- `summary.md` — branch, commit, host/kernel metadata and PASS/FAIL status for each test script.
- `combined.log` — combined stdout/stderr from the test scripts.
- `<test-name>.log` — individual stdout/stderr for each test script.

The runner returns non-zero if a required dependency, test script, or test fails. Reports are generated locally and are not committed automatically. After a run, inspect the summary and logs, then stage the specific report directory together with any relevant code changes. Review reports for environment-specific information before pushing them. A passing fixture suite is not proof of a successful installation or safe disk erasure.

The broader `scripts/live-validation.sh` also creates timestamped host-validation Markdown reports under `reports/live-validation/` and calls the canonical test runner; its report captures the test-run output and the runner separately preserves per-test logs under `reports/test-runs/`.


## Initial X280 Arch installer

The initial destructive installer is `scripts/install-arch-x280.sh`. It must be run only from the official Arch ISO in UEFI mode, as root, after reviewing the exact SSD identity and backing up all data. It requires the host inventory to match the ThinkPad X280 profile and requires the selected disk to match the verified WDC PC SN730 model, capacity, and serial. The script requires an exact plan-bound confirmation before the first write. It creates GPT, a 1 GiB EFI System Partition, a LUKS2 root partition, ext4 root, installs the minimal Arch base, generates UUID-based fstab, and configures a systemd-boot UKI.

The installer currently does **not** configure a regular user, locale, timezone, hostname, swapfile/resume, Caelestia/Hyprland/Quickshell, X280 power/thermal tuning, or BlackArch. It does not disable unrelated swap devices. External utilities independently open device pathnames; per-step identity rechecks do not eliminate the device-rebinding/TOCTOU race. This limitation is explicit and unresolved. Do not use the installer on irreplaceable data or regard its first run as routine deployment. The static installer test is not a substitute for a disposable VM test, a successful physical installation, or a verified boot.


The target configuration stage `scripts/configure-arch-x280.sh` runs inside the installed system through `arch-chroot`. It interactively configures hostname, initial administrator username/password, timezone, locale, Intel microcode, sudo wheel access, and the planned swapfile. Password input is interactive and is not written to the report. Resume/hibernation is deliberately not enabled because the swapfile resume offset has not yet been derived and verified.

The target configuration stage prompts for hostname, initial username/password, timezone, and locale; installs Intel microcode; configures sudo for the wheel group; and creates the swapfile in a temporary path before atomically renaming it into place. Hibernation remains disabled until a tested resume-offset workflow is implemented.


The descriptor-pinned integration test uses a temporary sparse image attached as a loop device. It holds whole-disk and partition descriptors open in Bash and invokes wipefs, sgdisk, partprobe, mkfs.fat, cryptsetup, and mkfs.ext4 through inherited /proc/self/fd paths. It formats only the temporary loop-backed image and detaches it during cleanup. This validates the procfs descriptor-path interface for these tools on the CI Linux kernel; it does not test the physical NVMe controller, unplug behavior, or full installer transaction on the ThinkPad.
