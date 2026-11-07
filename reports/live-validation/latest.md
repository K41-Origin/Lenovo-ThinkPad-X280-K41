# Live validation report

- Generated (UTC): 2026-11-07T05:27:30Z
- Repository: /tmp/Lenovo-ThinkPad-X280-K41
- Host: unknown
- Kernel: Linux 7.2.11-arch1-1 x86_64 GNU/Linux

> Read-only diagnostics and repository tests only. This script does not partition, format, mount, install packages, change services, or modify firmware. Review the report before sharing; hardware and network metadata may be environment-specific.

## Repository identity

- **Git repository status** — ## main...origin/main
?? reports/
PASS
- **Current commit** — 24624e8957ffda52c11f7ac6ded67cd20793b303
PASS
- **Current branch** — main
PASS
- **Tracked file inventory** — .github/workflows/bash-tests.yml
AGENTS.md
LICENSE
README.md
config/hardware/thinkpad-x280.conf
docs/01-PROJECT-CHARTER.md
docs/02-REQUIREMENTS-AND-DECISIONS.md
docs/03-ARCHITECTURE-AND-MODULES.md
docs/04-INSTALLATION-AND-DISK.md
docs/05-SECURITY-AND-AUTHENTICATION.md
docs/06-DESKTOP-AND-USER-EXPERIENCE.md
docs/07-HARDWARE-POWER-AND-NETWORK.md
docs/08-PACKAGE-AND-SOFTWARE-MANAGEMENT.md
docs/09-DEVELOPMENT-AND-BUG-BOUNTY.md
docs/10-ERROR-RECOVERY-AND-REPORTING.md
docs/11-TESTING-AND-ACCEPTANCE.md
docs/12-IMPLEMENTATION-STATUS-AND-CHANGELOG.md
docs/13-X280-HARDWARE-BASELINE.md
docs/14-STAGE-8-NATIVE-DEVICE-ACCESS.md
docs/15-REPOSITORY-AUDIT.md
installer
lib/base-system.sh
lib/bootloader.sh
lib/common.sh
lib/desktop.sh
lib/hardware.sh
lib/inventory.sh
lib/packages.sh
lib/preflight.sh
lib/report.sh
lib/security.sh
lib/storage-confirmation.sh
lib/storage-execution-boundary.sh
lib/storage-execution-dry-run.sh
lib/storage-plan.sh
lib/storage-prerequisites.sh
lib/storage-topology.sh
lib/storage.sh
lib/user-setup.sh
lib/validation.sh
scripts/live-validation.sh
scripts/validate-live-storage.sh
tests/README.md
tests/helpers/storage-fixtures.sh
tests/run.sh
tests/test-common-preflight.sh
tests/test-installer-entry.sh
tests/test-inventory.sh
tests/test-preflight-gate.sh
tests/test-storage-confirmation.sh
tests/test-storage-discovery.sh
tests/test-storage-execution-boundary.sh
tests/test-storage-execution-dry-run.sh
tests/test-storage-plan.sh
tests/test-storage-prerequisites.sh
tests/test-storage-topology.sh
PASS
- **Working-tree diff summary** — PASS
- **Untracked file inventory** — reports/live-validation/20261107T052730Z.md
PASS

## Host and boot environment

- **Kernel** — Linux archiso 7.2.11-arch1-1 #1 SMP PREEMPT_DYNAMIC Fri, 16 Oct 2026 00:28:58 +0000 x86_64 GNU/Linux
PASS
- **CPU inventory** — Architecture:                            x86_64
CPU op-mode(s):                          32-bit, 64-bit
Address sizes:                           39 bits physical, 48 bits virtual
Byte Order:                              Little Endian
CPU(s):                                  8
On-line CPU(s) list:                     0-7
Vendor ID:                               GenuineIntel
Model name:                              Intel(R) Core(TM) i5-8250U CPU @ 1.60GHz
CPU family:                              6
Model:                                   142
Thread(s) per core:                      2
Core(s) per socket:                      4
Socket(s):                               1
Stepping:                                10
Microcode version:                       0xf6
CPU(s) scaling MHz:                      67%
CPU max MHz:                             3400.0000
CPU min MHz:                             400.0000
BogoMIPS:                                3600.00
Flags:                                   fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc art arch_perfmon pebs bts rep_good nopl xtopology nonstop_tsc cpuid aperfmperf pni pclmulqdq dtes64 monitor ds_cpl vmx est tm2 ssse3 sdbg fma cx16 xtpr pdcm pcid sse4_1 sse4_2 x2apic movbe popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm abm 3dnowprefetch cpuid_fault epb pti ssbd ibrs ibpb stibp tpr_shadow flexpriority ept vpid ept_ad fsgsbase tsc_adjust sgx bmi1 avx2 smep bmi2 erms invpcid mpx rdseed adx smap clflushopt intel_pt xsaveopt xsavec xgetbv1 xsaves dtherm ida arat pln pts hwp hwp_notify hwp_act_window hwp_epp vnmi md_clear flush_l1d arch_capabilities
Virtualization:                          VT-x
L1d cache:                               128 KiB (4 instances)
L1i cache:                               128 KiB (4 instances)
L2 cache:                                1 MiB (4 instances)
L3 cache:                                6 MiB (1 instance)
NUMA node(s):                            1
NUMA node0 CPU(s):                       0-7
Vulnerability Gather data sampling:      Mitigation; Microcode
Vulnerability Ghostwrite:                Not affected
Vulnerability Indirect target selection: Not affected
Vulnerability Itlb multihit:             KVM: Mitigation: Split huge pages
Vulnerability L1tf:                      Mitigation; PTE Inversion; VMX conditional cache flushes, SMT vulnerable
Vulnerability Mds:                       Mitigation; Clear CPU buffers; SMT vulnerable
Vulnerability Meltdown:                  Mitigation; PTI
Vulnerability Mmio stale data:           Mitigation; Clear CPU buffers; SMT vulnerable
Vulnerability Old microcode:             Not affected
Vulnerability Reg file data sampling:    Not affected
Vulnerability Retbleed:                  Mitigation; IBRS
Vulnerability Spec rstack overflow:      Not affected
Vulnerability Spec store bypass:         Mitigation; Speculative Store Bypass disabled via prctl
Vulnerability Spectre v1:                Mitigation; usercopy/swapgs barriers and __user pointer sanitization
Vulnerability Spectre v2:                Mitigation; IBRS; IBPB conditional; STIBP conditional; RSB filling; PBRSB-eIBRS Not affected; BHI Not affected
Vulnerability Srbds:                     Mitigation; Microcode
Vulnerability Tsa:                       Not affected
Vulnerability Tsx async abort:           Not affected
Vulnerability Vmscape:                   Mitigation; IBPB before exit to userspace
PASS
- **Memory inventory** —                total        used        free      shared  buff/cache   available
Mem:           7.5Gi       1.5Gi       5.8Gi       1.1Gi       1.5Gi       6.0Gi
Swap:             0B          0B          0B
PASS
- **UEFI firmware indicator** — scripts/live-validation.sh: line 48: -d: command not found
FAIL (exit 127)
- **DMI vendor** — LENOVO
PASS
- **DMI product** — 20KESC2Y00
PASS
- **DMI product version** — ThinkPad X280
PASS
- **BIOS version** — N20ET74W (1.59 )
PASS
- **PCI inventory** — 00:00.0 Host bridge [0600]: Intel Corporation Xeon E3-1200 v6/7th Gen Core Processor Host Bridge/DRAM Registers [8086:5914] (rev 08)
00:02.0 VGA compatible controller [0300]: Intel Corporation Kaby Lake-R GT2 [UHD Graphics 620] [8086:5917] (rev 07)
00:04.0 Signal processing controller [1180]: Intel Corporation Xeon E3-1200 v5/E3-1500 v5/6th Gen Core Processor Thermal Subsystem [8086:1903] (rev 08)
00:08.0 System peripheral [0880]: Intel Corporation Xeon E3-1200 v5/v6 / E3-1500 v5 / 6th/7th/8th Gen Core Processor Gaussian Mixture Model [8086:1911]
00:14.0 USB controller [0c03]: Intel Corporation Sunrise Point-LP USB 3.0 xHCI Controller [8086:9d2f] (rev 21)
00:14.2 Signal processing controller [1180]: Intel Corporation Sunrise Point-LP Thermal subsystem [8086:9d31] (rev 21)
00:16.0 Communication controller [0780]: Intel Corporation Sunrise Point-LP CSME HECI #1 [8086:9d3a] (rev 21)
00:1c.0 PCI bridge [0604]: Intel Corporation Sunrise Point-LP PCI Express Root Port #1 [8086:9d10] (rev f1)
00:1c.2 PCI bridge [0604]: Intel Corporation Sunrise Point-LP PCI Express Root Port #3 [8086:9d12] (rev f1)
00:1c.4 PCI bridge [0604]: Intel Corporation Sunrise Point-LP PCI Express Root Port #5 [8086:9d14] (rev f1)
00:1f.0 ISA bridge [0601]: Intel Corporation Sunrise Point LPC/eSPI Controller [8086:9d4e] (rev 21)
00:1f.2 Memory controller [0580]: Intel Corporation Sunrise Point-LP PMC [8086:9d21] (rev 21)
00:1f.3 Audio device [0403]: Intel Corporation Sunrise Point-LP HD Audio [8086:9d71] (rev 21)
00:1f.4 SMBus [0c05]: Intel Corporation Sunrise Point-LP SMBus [8086:9d23] (rev 21)
00:1f.6 Ethernet controller [0200]: Intel Corporation Ethernet Connection (4) I219-V [8086:15d8] (rev 21)
02:00.0 PCI bridge [0604]: Intel Corporation JHL6240 Thunderbolt 3 Bridge (Low Power) [Alpine Ridge LP 2016] [8086:15c0] (rev 01)
03:00.0 PCI bridge [0604]: Intel Corporation JHL6240 Thunderbolt 3 Bridge (Low Power) [Alpine Ridge LP 2016] [8086:15c0] (rev 01)
03:01.0 PCI bridge [0604]: Intel Corporation JHL6240 Thunderbolt 3 Bridge (Low Power) [Alpine Ridge LP 2016] [8086:15c0] (rev 01)
03:02.0 PCI bridge [0604]: Intel Corporation JHL6240 Thunderbolt 3 Bridge (Low Power) [Alpine Ridge LP 2016] [8086:15c0] (rev 01)
04:00.0 System peripheral [0880]: Intel Corporation JHL6240 Thunderbolt 3 NHI (Low Power) [Alpine Ridge LP 2016] [8086:15bf] (rev 01)
3a:00.0 USB controller [0c03]: Intel Corporation JHL6240 Thunderbolt 3 USB 3.1 Controller (Low Power) [Alpine Ridge LP 2016] [8086:15c1] (rev 01)
3b:00.0 Network controller [0280]: Intel Corporation Wireless 8265 / 8275 [8086:24fd] (rev 78)
3c:00.0 Non-Volatile memory controller [0108]: Sandisk Corp SanDisk Extreme Pro / WD Black SN750 / PC SN730 / Red SN700 NVMe SSD [15b7:5006]
PASS
- **USB inventory** — Bus 001 Device 001: ID 1d6b:0002 Linux Foundation 2.0 root hub
Bus 001 Device 002: ID 058f:6387 Alcor Micro Corp. Flash Drive
Bus 001 Device 003: ID 8087:0a2b Intel Corp. Bluetooth wireless interface
Bus 001 Device 004: ID 04ca:7070 Lite-On Technology Corp. Integrated Camera
Bus 001 Device 005: ID 06cb:009a Synaptics, Inc. Metallica MIS Touch Fingerprint Reader
Bus 002 Device 001: ID 1d6b:0003 Linux Foundation 3.0 root hub
Bus 002 Device 002: ID 0bda:0316 Realtek Semiconductor Corp. Card Reader
Bus 003 Device 001: ID 1d6b:0002 Linux Foundation 2.0 root hub
Bus 004 Device 001: ID 1d6b:0003 Linux Foundation 3.0 root hub
PASS

## Storage and mount topology (read-only)

- **Block-device inventory** — NAME        PATH           TYPE   SIZE MODEL                          TRAN RM RO FSTYPE  MOUNTPOINTS
sda         /dev/sda       disk   7.5G Flash Disk                     usb   1  0 iso9660 
├─sda1      /dev/sda1      part   1.1G                                      1  0 iso9660 
└─sda2      /dev/sda2      part   109M                                      1  0 vfat    
sdb         /dev/sdb       disk     0B SD/MMC                         usb   1  0         
nvme0n1     /dev/nvme0n1   disk 238.5G WDC PC SN730 SDBQNTY-256G-1001 nvme  0  0         
├─nvme0n1p1 /dev/nvme0n1p1 part   100M                                nvme  0  0 vfat    
├─nvme0n1p2 /dev/nvme0n1p2 part    16M                                nvme  0  0         
├─nvme0n1p3 /dev/nvme0n1p3 part 237.8G                                nvme  0  0 ntfs    
└─nvme0n1p4 /dev/nvme0n1p4 part   530M                                nvme  0  0 ntfs    
PASS
- **Filesystem mounts** — TARGET                                        SOURCE     FSTYPE     OPTIONS
/                                             airootfs   overlay    rw,relatime,lowerdir=/run/archiso/airootfs,upperdir=/run/archiso/cowspace/persistent_/x86_64/upperdir,workdir=/run/archiso/cowspace/persistent_/x86_64/workdir,uuid=on
├─/proc                                       proc       proc       rw,nosuid,nodev,noexec,relatime
│ └─/proc/sys/fs/binfmt_misc                  systemd-1  autofs     rw,relatime,fd=44,pgrp=1,timeout=0,minproto=5,maxproto=5,direct,pipe_ino=6670
├─/sys                                        sys        sysfs      rw,nosuid,nodev,noexec,relatime
│ ├─/sys/firmware/efi/efivars                 efivarfs   efivarfs   rw,nosuid,nodev,noexec,relatime
│ ├─/sys/kernel/security                      securityfs securityfs rw,nosuid,nodev,noexec,relatime
│ ├─/sys/fs/cgroup                            cgroup2    cgroup2    rw,nosuid,nodev,noexec,relatime,nsdelegate,memory_recursiveprot,memory_hugetlb_accounting
│ ├─/sys/fs/pstore                            none       pstore     rw,nosuid,nodev,noexec,relatime
│ ├─/sys/fs/bpf                               bpf        bpf        rw,nosuid,nodev,noexec,relatime,mode=700
│ ├─/sys/fs/fuse/connections                  fusectl    fusectl    rw,nosuid,nodev,noexec,relatime
│ ├─/sys/kernel/tracing                       tracefs    tracefs    rw,nosuid,nodev,noexec,relatime
│ ├─/sys/kernel/debug                         debugfs    debugfs    rw,nosuid,nodev,noexec,relatime
│ └─/sys/kernel/config                        configfs   configfs   rw,nosuid,nodev,noexec,relatime
├─/dev                                        dev        devtmpfs   rw,nosuid,relatime,size=3858152k,nr_inodes=964538,mode=755,inode64,huge=advise
│ ├─/dev/shm                                  tmpfs      tmpfs      rw,nosuid,nodev,inode64,huge=advise,usrquota
│ ├─/dev/pts                                  devpts     devpts     rw,nosuid,noexec,relatime,gid=5,mode=600,ptmxmode=000
│ ├─/dev/hugepages                            hugetlbfs  hugetlbfs  rw,nosuid,nodev,relatime,pagesize=2M
│ └─/dev/mqueue                               mqueue     mqueue     rw,nosuid,nodev,noexec,relatime
├─/run                                        run        tmpfs      rw,nosuid,nodev,relatime,mode=755,inode64,huge=advise
│ ├─/run/archiso/copytoram                    copytoram  tmpfs      rw,relatime,size=5910016k,mode=755,inode64,huge=advise
│ ├─/run/archiso/cowspace                     cowspace   tmpfs      rw,relatime,size=262144k,mode=755,inode64,huge=advise
│ ├─/run/archiso/airootfs                     /dev/loop0 squashfs   ro,relatime,errors=continue,threads=single
│ ├─/run/credentials/systemd-journald.service none       tmpfs      ro,nosuid,nodev,noexec,relatime,nosymfollow,size=1024k,nr_inodes=1024,mode=700,inode64,huge=advise,noswap
│ ├─/run/credentials/systemd-resolved.service none       tmpfs      ro,nosuid,nodev,noexec,relatime,nosymfollow,size=1024k,nr_inodes=1024,mode=700,inode64,huge=advise,noswap
│ ├─/run/credentials/systemd-networkd.service none       tmpfs      ro,nosuid,nodev,noexec,relatime,nosymfollow,size=1024k,nr_inodes=1024,mode=700,inode64,huge=advise,noswap
│ ├─/run/credentials/getty@tty1.service       none       tmpfs      ro,nosuid,nodev,noexec,relatime,nosymfollow,size=1024k,nr_inodes=1024,mode=700,inode64,huge=advise,noswap
│ └─/run/user/0                               tmpfs      tmpfs      rw,nosuid,nodev,relatime,size=788000k,nr_inodes=197000,mode=700,inode64,huge=advise
├─/tmp                                        tmpfs      tmpfs      rw,nosuid,nodev,size=3940012k,nr_inodes=1048576,inode64,huge=advise,usrquota
└─/etc/pacman.d/gnupg                         tmpfs      tmpfs      rw,relatime,mode=755,inode64,huge=advise,noswap
PASS
- **Active swap** — PASS
- **Kernel block-device inventory** — nvme0n1
sdb
loop0
sda
PASS

## Network diagnostics (no connectivity test)

- **Network link state** — lo               UNKNOWN        00:00:00:00:00:00 <LOOPBACK,UP,LOWER_UP> 
enp0s31f6        DOWN           f8:75:a4:30:dd:cc <NO-CARRIER,BROADCAST,MULTICAST,UP> 
wlan0            UP             40:74:e0:73:28:05 <BROADCAST,MULTICAST,UP,LOWER_UP> 
PASS
- **IP addresses** — lo               UNKNOWN        127.0.0.1/8 ::1/128 
enp0s31f6        DOWN           
wlan0            UP             192.168.8.133/24 metric 600 fe80::4274:e0ff:fe73:2805/64 
PASS

## Shell syntax validation

- **bash -n ./tests/test-storage-topology.sh** — PASS
- **bash -n ./tests/test-storage-prerequisites.sh** — PASS
- **bash -n ./tests/test-storage-plan.sh** — PASS
- **bash -n ./tests/test-storage-execution-dry-run.sh** — PASS
- **bash -n ./tests/test-storage-execution-boundary.sh** — PASS
- **bash -n ./tests/test-storage-discovery.sh** — PASS
- **bash -n ./tests/test-storage-confirmation.sh** — PASS
- **bash -n ./tests/test-preflight-gate.sh** — PASS
- **bash -n ./tests/test-inventory.sh** — PASS
- **bash -n ./tests/test-installer-entry.sh** — PASS
- **bash -n ./tests/test-common-preflight.sh** — PASS
- **bash -n ./tests/run.sh** — PASS
- **bash -n ./tests/helpers/storage-fixtures.sh** — PASS
- **bash -n ./scripts/live-validation.sh** — PASS
- **bash -n ./scripts/validate-live-storage.sh** — PASS
- **bash -n ./lib/validation.sh** — PASS
- **bash -n ./lib/user-setup.sh** — PASS
- **bash -n ./lib/storage.sh** — PASS
- **bash -n ./lib/storage-topology.sh** — PASS
- **bash -n ./lib/storage-prerequisites.sh** — PASS
- **bash -n ./lib/storage-plan.sh** — PASS
- **bash -n ./lib/storage-execution-dry-run.sh** — PASS
- **bash -n ./lib/storage-execution-boundary.sh** — PASS
- **bash -n ./lib/storage-confirmation.sh** — PASS
- **bash -n ./lib/security.sh** — PASS
- **bash -n ./lib/report.sh** — PASS
- **bash -n ./lib/preflight.sh** — PASS
- **bash -n ./lib/packages.sh** — PASS
- **bash -n ./lib/inventory.sh** — PASS
- **bash -n ./lib/hardware.sh** — PASS
- **bash -n ./lib/desktop.sh** — PASS
- **bash -n ./lib/common.sh** — PASS
- **bash -n ./lib/bootloader.sh** — PASS
- **bash -n ./lib/base-system.sh** — PASS
- **bash -n ./installer** — PASS

## Static analysis

- **ShellCheck (severity error)** — SKIPPED (missing command: shellcheck)
- **shfmt formatting check (runner and shared fixture helper)** — SKIPPED (missing command: shfmt)

## Canonical repository test suite

- **bash tests/run.sh** — 
== tests/test-common-preflight.sh ==
PASS: module sourcing has no output or shell-option/trap changes
PASS: logging helpers validate arguments and write to stderr
PASS: boot-mode detection distinguishes UEFI, legacy candidate, and unknown
PASS: required-command check handles present, missing, and invalid names
PASS: network check reports link state without claiming internet access
PASS: network check reports unavailable diagnostics as unknown
All common/preflight tests passed.

== tests/test-installer-entry.sh ==
PASS: entry point resolves modules relative to itself and documents its limits
PASS: unsupported arguments fail closed
PASS: preflight cannot return success or claim installation approval
PASS: entry point has no storage/install module or privileged/system-changing command path
All installer-entry tests passed.

== tests/test-inventory.sh ==
inventory tests: PASS

== tests/test-storage-discovery.sh ==
PASS: discovers disks and records identity and safety facts
PASS: accepts unchanged internal NVMe with matching WWN and serial and invokes topology validation
PASS: blocks target when topology validation fails
PASS: rejects mounted descendants
PASS: rejects active swap descendants
PASS: rejects active swap device aliases
PASS: rejects removable USB target
PASS: rejects duplicate WWN
PASS: rejects changed secondary identity
PASS: rejects unknown safety state
PASS: fails closed when swap discovery fails
PASS: fails closed when lsblk fails
PASS: rejects invalid output array
All storage discovery tests passed.

== tests/test-storage-plan.sh ==
PASS: calculates aligned GPT layout and RAM-plus-margin swap proposal
PASS: supports 4Kn logical sectors with 1 MiB alignment
PASS: rejects insufficient capacity
PASS: rejects unsupported logical sector geometry
PASS: rejects capacity not divisible by logical sector size
PASS: rejects arithmetic input outside signed 64-bit range
PASS: rejects malformed, missing, indexed, and readonly output variables before nameref creation
PASS: rejects swap-size arithmetic overflow
PASS: normalizes decimal inputs with leading zeros without octal interpretation
PASS: binds target/profile and produces deterministic serialization and digest
PASS: target identity and profile changes alter the plan digest
PASS: refuses target without stable identity
PASS: rejects ambiguous multiline serialization values
PASS: accepts complete geometry, target, profile, and prerequisite state
PASS: rejects failed prerequisites and inconsistent profile/partition geometry
PASS: refuses missing prerequisite evidence and incomplete plans
PASS: refuses non-UEFI prerequisite state
PASS: prerequisite evidence changes alter the canonical plan digest
PASS: rejects non-canonical numeric fields before arithmetic evaluation
PASS: rejects ESP profile size inconsistent with planned partition geometry

== tests/test-storage-prerequisites.sh ==
PASS: live UEFI, tool, target identity, unused-state, and topology evidence is bound to the plan
PASS: failed live checks never produce a passed prerequisite snapshot
PASS: changed stable identity cannot bind live prerequisites

== tests/test-storage-confirmation.sh ==
PASS: cancellation and incorrect confirmation are rejected
PASS: explicit confirmation is bound to the exact plan digest and target
PASS: final live revalidation creates a one-shot ready gate
PASS: confirmation cannot be reused
PASS: modified plan invalidates confirmation and fails closed
PASS: changed target identity fails final revalidation
PASS: topology failure leaves the final gate closed

== tests/test-storage-execution-dry-run.sh ==
PASS: manifest has deterministic GPT, partition, LUKS2, ext4 ordering
PASS: stale plan is rejected before manifest creation
PASS: execution planning is blocked without a ready gate
PASS: simulated failure halts subsequent operations and consumes the gate
PASS: consumed gate cannot be reused
PASS: complete dry-run simulation records all operations without system execution

== tests/test-storage-execution-boundary.sh ==
PASS: mock boundary re-probes full target identity immediately before all eight operations
PASS: changed identity blocks the next mock operation and records partial-state recovery
PASS: changed read-only safety attribute blocks the next operation
PASS: failed initial identity probe produces zero mock executor calls
PASS: partial executor failure is recorded and recovery is required without automatic rollback
PASS: non-mock executor callback is rejected before execution
PASS: gate/plan target-attribute mismatch blocks before gate consumption and mock execution

== tests/test-storage-topology.sh ==
PASS: unrelated mounted disk does not block target
storage: target topology is mounted at / (device 65000:3)
PASS: rejects mounted LUKS/device-mapper dependent
storage: target topology is mounted at /mnt/data (device 65000:2)
PASS: rejects mounted target partition
storage: target topology is mounted at / (device 65000:3)
PASS: rejects swapfile on target-backed filesystem
PASS: fails closed when swapfile backing mount is unresolved
PASS: rejects malformed target identity
storage: cannot prove backing-device topology for filesystem type btrfs
PASS: fails closed on btrfs backing topology
PASS: fails closed on overlay backing topology
PASS: rejects malformed mountinfo
PASS: resolves loop backing file on an unrelated filesystem
PASS: rejects loop backing file on target dependency
PASS: resolves overlay lower, upper, and work paths outside target dependency
PASS: rejects overlay paths on target dependency
PASS: fails closed on unresolved overlay backing path
PASS: accepts squashfs loop mount backed by an unrelated filesystem
PASS: complete topology check rejects squashfs loop backing on target
PASS: accepts overlay mount backed by unrelated filesystem
PASS: complete topology check rejects overlay path on target
storage: target topology backs active swap /dev/null (device 1:3)
PASS: complete topology check rejects active block swap dependency

== tests/test-preflight-gate.sh ==
PASS: resolved diagnostics still leave installation disabled
PASS: inventory mismatch blocks preflight success
PASS: unresolved boot mode blocks preflight success
PASS: required-command failure blocks preflight success
PASS: optional network diagnostic failure does not change required gate result
All preflight-gate tests passed.

All 11 repository test scripts passed.
PASS

## Installer diagnostics

- **installer --help** — Usage: ./installer [--help | --preflight]

  --help       Show this help.
  --preflight  Run read-only environment diagnostics only.

Installation is not implemented. This entry point never installs packages,
changes services or network settings, or reads/writes target-disk contents.
PASS

### installer --preflight (informational)

Expected project behavior: non-zero while installation is disabled. Actual output and exit code follow.

INFO: Starting read-only diagnostics; this is not an installation approval.
INFO: Running with effective UID 0 (root).
INFO: Detected host inventory (read-only):
cpu.vendor               GenuineIntel
cpu.model                Intel(R) Core(TM) i5-8250U CPU @ 1.60GHz
cpu.family               6
cpu.model_id             142
cpu.threads              8
cpu.model_conflict       unknown/unavailable
memory.total_bytes       8069140480
dmi.sys_vendor           LENOVO
dmi.product_name         20KESC2Y00
dmi.product_version      ThinkPad X280
dmi.bios_version         N20ET74W (1.59 )
dmi.bios_date            08/26/2025
OK: system vendor matches LENOVO.
OK: target product matches 20KESC2Y00.
OK: CPU matches Intel(R) Core(TM) i5-8250U.
OK: memory is within the configured target range.
INFO: Target hardware profile matches the detected host.
INFO: Boot mode: UEFI (firmware interface directory detected).
INFO: All requested commands are available.
INFO: Observed network link state (not proof of internet connectivity):
lo               UNKNOWN        00:00:00:00:00:00 <LOOPBACK,UP,LOWER_UP> 
enp0s31f6        DOWN           f8:75:a4:30:dd:cc <NO-CARRIER,BROADCAST,MULTICAST,UP> 
wlan0            UP             40:74:e0:73:28:05 <BROADCAST,MULTICAST,UP,LOWER_UP> 
INFO: Read-only diagnostics completed, but installation remains disabled.

Preflight exit code: 2

## Result summary

- Checks counted: 59
- Failures: 1
- Optional checks skipped: 2
- Overall repository validation: FAIL

This report is evidence for this exact checkout and host at the recorded time. It is not proof of successful installation, safe disk erasure, hardware compatibility beyond observed inventory, or correctness of untested behavior.
