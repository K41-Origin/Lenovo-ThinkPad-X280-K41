# Stage 8 — Native Block-Device Handle Design

## Status

- Stage 8 design record: IMPLEMENTED.
- Native C helper: IMPLEMENTED as a standalone read-only prototype; compile/CLI test coverage exists, but real block-device runtime remains NOT TESTED.
- Installer's Bash descriptor path: separately IMPLEMENTED on PR #9 and exercised against a disposable loop-backed image by the pinned-device integration test.
- Native C helper integration: NOT IMPLEMENTED; the initial installer does not call this helper.
- Full storage executor safety and physical NVMe behavior: NOT TESTED.

This document owns the native C helper's design, identity, and lifecycle. It does not describe or authorize the separate Bash descriptor path in the initial installer. It does not authorize writes to any disk.

## Implemented first slice (read-only prototype)

`native/storage-handle.c` is a narrow acquisition prototype. It accepts only a simple `/dev/<name>` path, opens it with `O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_EXCL | O_NONBLOCK`, verifies the opened object with `fstat`, rejects non-block objects and sysfs partitions, and queries capacity, logical/physical sector sizes, and read-only state through ioctls on the retained descriptor. It reports major/minor and diskseq (or JSON `null` when unavailable), then retains the descriptor until stdin reaches EOF. The helper has no command channel, invokes no subprocess, and contains no write operation.

This is not yet a complete target-acquisition contract: stable WWN/serial correlation, actual removable-state parsing, NVMe/internal-device enforcement, expected-plan comparison, protocol integration with Bash, and robust lifecycle supervision remain PLANNED. The C helper's `O_EXCL` behavior, descriptor ioctls, and block-device lifecycle remain NOT TESTED on disposable or physical devices. The helper is not called by the installer or storage boundary.

## Problem statement

Stage 7 rechecks a mock target snapshot before each mock callback. It does not hold a kernel block-device reference. A pathname can be rebound after a check and before a later pathname-based operation. Pathname rechecks therefore do not close the kernel time-of-check/time-of-use window.

Bash remains responsible for orchestration, review, and status. The C helper is a prototype for retained-FD acquisition and descriptor-based identity inspection. Separately, the PR #9 installer opens whole-disk and partition descriptors in Bash and passes inherited /proc/self/fd paths to selected external tools. That path is not the C helper and must not be represented as C-helper integration.

## Verified Linux interface facts

These are documentation facts, not tests on the ThinkPad X280:

1. Linux open(2) returns a file descriptor referring to an open file description. That descriptor remains associated with the opened object if the pathname later changes. O_CLOEXEC controls inheritance across execve.
2. Linux supports the special use of O_EXCL without O_CREAT for block-device paths. An already-in-use block device (for example, mounted) can cause EBUSY. This must not be treated as proof that every kernel consumer, child partition, userspace process, or pathname-based utility is excluded.
3. fstat(2) on the retained descriptor provides file type and st_rdev. For a block special file, st_rdev identifies the device by major/minor. ioctl(2) operates on an open descriptor; Linux block-device ioctls expose size, sector geometry, read-only state, and disk sequence information.
4. The Linux kernel documents /sys/block/<disk>/diskseq as a monotonically assigned 64-bit sequence number. It can supplement detection of remove/re-add or device-number reuse when correlated with the descriptor's device number. It does not replace the retained descriptor.
5. Kernel-internal blkdev_get_by_path()/FMODE_EXCL documentation is not a userspace API. Do not call kernel-internal APIs from the userspace helper.

References:
- https://man7.org/linux/man-pages/man2/open.2.html
- https://man7.org/linux/man-pages/man7/inode.7.html
- https://man.archlinux.org/man/ioctl.2
- https://man.archlinux.org/man/blockdev.8
- https://www.kernel.org/doc/html/latest/admin-guide/abi-stable.html
- https://www.kernel.org/doc/html/v6.4/core-api/kernel-api.html (kernel-internal API reference only)

## Proposed design

Use a small, auditable native C helper for descriptor acquisition and identity inspection. It is a narrow capability holder, not a shell, command runner, or replacement installer. It must not accept arbitrary commands, shell fragments, ioctl numbers, or caller-supplied identity overrides.

### Acquisition lifecycle

1. Existing discovery, topology checks, complete plan review, and exact user confirmation remain mandatory.
2. After confirmation, the helper receives the candidate path as an acquisition locator and the expected identity snapshot from the validated plan.
3. The helper opens the candidate whole-disk block device with a tested exclusive-open request, O_CLOEXEC, and symlink rejection (O_NOFOLLOW where supported). It must never create a file. Exact access mode and flags remain to be proven in implementation tests.
4. Immediately after open, use fstat(fd) to require a block special file and read major/minor from st_rdev. Query supported properties through ioctls on that same descriptor, not by reopening the path.
5. Correlate descriptor identity with the plan and fresh read-only sysfs evidence: diskseq where available, whole-disk classification, capacity, sector geometry, read-only/removable state, transport, and stable identifier evidence. Missing or inconsistent critical facts fail closed.
6. Retain the descriptor for the complete protected session. The typed protocol must not allow the caller to substitute a new path or target identity after acquisition.
7. A future executor must prove each operation uses the retained target capability. Holding an FD while a utility independently reopens a pathname does not make that utility descriptor-bound.
8. On completion or abort, record final state and close the descriptor. If the helper crashes, the kernel releases its open when the process exits; a separate recovery record must still describe whether earlier operations may have changed device state.

## Critical unresolved compatibility boundary

A retained FD alone does not make an external partitioning, LUKS, or filesystem utility descriptor-safe. Many tools accept a pathname and may open the device again. PR #9 passes inherited /proc/self/fd/N paths to a selected set of utilities; the disposable loop-device integration test demonstrates that those tools accept this interface in that test environment. It does not establish that each utility reuses the same open file description, that the kernel grants an exclusive capability to every operation, or that all races/hot-unplug cases are closed. Treat this as bounded interface evidence, not proof of race-free physical-device execution. A future executor still needs a reviewed, documented descriptor-to-operation contract and broader failure testing.

Before designing a real executor, determine whether the selected partitioning and LUKS interfaces can operate through the retained descriptor or whether a dedicated helper must own the relevant library calls. If this cannot be demonstrated, do not proceed. Do not silently fall back to pathname checks, flock, or a second independent open.

## Identity and access policy

The internal record must include file type, fstat st_rdev major/minor, diskseq when exposed, whole-disk classification, capacity, logical/physical sector sizes where supported, read-only/removable state, transport, and correlated WWN/serial evidence. The pathname is diagnostic provenance only after acquisition.

A missing diskseq must remain unknown, not be fabricated. Define a conservative policy for kernels without it; if remaining evidence cannot establish continuity, fail closed. Redact serial/WWN in routine logs. Verify the object is the intended internal NVMe whole disk, not a partition, loop, mapper, removable, or unsupported device.

Keep all existing topology and active-use checks. Exclusive open is an additional gate, not a replacement for mounted-descendant, active-swap, holder/slave, overlay, and dependency checks. Do not assume opening the whole disk exclusively proves all child partitions and holders are unused; test this on disposable devices. Treat EBUSY, permission errors, unsupported flags, hot-unplug, I/O errors, and identity mismatch as safe aborts. Do not treat flock or a lockfile as equivalent to kernel block-device exclusive-open semantics.

## Process and privilege boundary

- Short-lived, single-purpose process with minimum privilege; no setuid installation is approved.
- Fixed, versioned, typed request/response protocol. Validate lengths, ranges, enums, schema, and message order. Never parse shell syntax or eval input.
- O_CLOEXEC by default. Do not leak the target FD to unrelated child processes; any deliberate transfer must be explicit and tested.
- No shell invocation, arbitrary callbacks, remote fetch, package installation, credentials, or full serials in logs.
- The Stage 7 Bash mock boundary remains a test harness, not a security boundary.

## Failure and recovery

Descriptor loss, hot-unplug, identity mismatch, I/O error, protocol violation, helper crash, or future executor failure stops the session. Preserve an operation ledger and require recovery review whenever any operation may have completed. No automatic rollback or retry. Recovery must inspect current device state from a fresh session and require human review before new authorization. Never automatically reopen the old pathname as though continuity were proven.

## Acceptance criteria

Stage 8 is not complete until all applicable criteria are implemented and evidenced:

1. Native helper opens only an explicitly supplied candidate, rejects symlinks/non-block objects, and retains the FD for a defined session.
2. fstat and block ioctls use the retained FD; major/minor, capacity, and geometry are checked against the plan.
3. Stable identity and diskseq evidence are correlated with a documented fail-closed policy.
4. Exclusive-open behavior is tested using disposable loop devices (not VMs): already-open device, mounted/active child, partition opener, and competing process.
5. Symlink substitution, path replacement, remove/re-add, major/minor reuse where reproducible, permissions, unsupported ioctls, and helper termination are tested.
6. FD lifetime, close-on-exec, explicit transfer if any, and cleanup are tested.
7. Acquisition/inspection performs no writes and invokes no storage utilities.
8. Compiler warnings, static analysis, and memory/undefined-behavior checks are enabled where available; CI builds/tests the helper in isolation.
9. Security review confirms no pathname-based destructive utility bypasses the retained-FD boundary.

Mocks alone do not satisfy these criteria. Loop-device tests do not establish X280 hardware compatibility.

## Explicit non-goals

No partitioning, formatting, LUKS operations, filesystem creation, mounting, swap creation, package installation, or production storage executor is added by this native helper. No claim that O_EXCL, an FD, diskseq, sysfs, or a stable serial alone proves a disk is safe to erase. The legacy top-level `installer --preflight` remains diagnostic-only; this document does not describe or change the separate PR #9 destructive installer.

## Next gate

After read-only helper acquisition and identity behavior is implemented and tested, perform a security review of the descriptor-to-operation path and determine whether selected partition/LUKS APIs can use the retained capability. Only then may a separate stage specify a real storage executor. Destructive execution remains PLANNED and disabled.
