# ThinkPad X280 Hardware Baseline

## Purpose and status

This document records the user-reported hardware baseline for the physical Lenovo ThinkPad X280 targeted by this project. It is a planning and review reference for architecture, package selection, hardware discovery, and acceptance testing.

- **Captured:** 2026-11-02
- **Evidence source:** command output and a Windows battery report supplied by the device owner.
- **Status:** IMPLEMENTED as documentation; **not yet independently verified from Arch Linux**.
- **Rule:** installer code must discover the running machine at execution time. Do not hard-code this baseline as detected hardware or assume every X280 has this exact configuration.

## Device identity

| Field | Recorded value | Evidence / confidence |
|---|---|---|
| Manufacturer / product | Lenovo ThinkPad X280 | User identified device |
| System product name | `LENOVO 20KESC2Y00` | Windows battery report |
| Machine Type Model (as supplied) | `20KESC2Y00` | User-reported system model; Lenovo MTM formatting/variant should be cross-checked if needed |
| BIOS/UEFI | `N20ET49W (1.34)` | WMIC and battery report |
| BIOS date | 2019-11-13 | Windows battery report |

Do not record or display the battery serial number or unrelated device-unique identifiers in routine logs. Exception for this owner-specific installation target: the internal SSD serial is intentionally retained in `scripts/validate-live-storage.sh` and the live-validation evidence because it is part of the explicit target identity check. Do not generalize this identifier to other machines.

## Core hardware

| Component | Recorded value | Evidence / confidence |
|---|---|---|
| CPU | Intel Core i5-8250U | User-supplied hardware specification |
| Memory | 8 GB | User-supplied hardware specification; exact installed/usable bytes not yet measured in Linux |
| GPU | Intel UHD Graphics 620 | `Win32_VideoController` |
| Active display mode | 1920 × 1080 | `Win32_VideoController` |
| Touch input | Non-touchscreen, per owner | Owner confirmation |
| Internal panel identity | Windows monitor ID `LEN40E6` / Generic PnP Monitor | PowerShell PnP output; panel technology and exact panel FRU remain unknown |

The active display mode does not establish the panel's native resolution, IPS/TN technology, brightness, refresh rate, or color characteristics. Verify through EDID and Linux DRM/sysfs where available.

## Storage

| Component | Recorded value | Evidence / confidence |
|---|---|---|
| Internal SSD model | `WDC PC SN730 SDBQNTY-256G-1001` | `wmic diskdrive get model,size,interfacetype` |
| Reported capacity | 256,052,966,400 bytes (approximately 256.05 GB / 238.47 GiB) | WMIC |
| Windows InterfaceType | `SCSI` | WMIC classification only; **not** proof of a physical SCSI device or transport protocol |
| Likely device family | WD PC SN730 NVMe SSD | Model-family identification; confirm actual Linux transport/controller using `lsblk`, `nvme list`, and sysfs before storage design |

Windows also listed `Generic- SD/MMC USB Device`; treat it as a removable card-reader device, not the internal SSD. Never identify or select a destructive target using model/capacity alone. The installer must independently enumerate stable disk identity and require target-specific review and confirmation.

## Network and connectivity

| Component | Recorded value | Evidence / confidence |
|---|---|---|
| Wi-Fi | Intel Dual Band Wireless-AC 8265 | `netsh wlan show drivers` |
| Windows Wi-Fi driver | `20.70.3.3`, dated 2018-03-09 | Windows driver output; not used by Linux |
| Wi-Fi capabilities | 802.11a/b/g/n/ac | Windows driver output |
| Bluetooth | `Intel(R) Wireless Bluetooth(R)` | Windows PnP device name; chipset/USB ID not independently confirmed |
| Ethernet | Intel Ethernet Connection (4) I219-V | Windows PnP device name |

Linux verification targets: PCI/USB IDs, bound kernel drivers, firmware availability, interface names, and actual link operation. Expected Linux driver names must be treated as hypotheses until observed on the machine.

## Audio, camera, and battery

| Component | Recorded value | Evidence / confidence |
|---|---|---|
| Audio | Realtek High Definition Audio; Windows also lists High Definition Audio Device | PowerShell `Get-PnpDevice -Class MEDIA`; exact codec/controller ID unknown |
| Camera | Integrated Camera (Windows PnP status `OK`) | PowerShell `Get-PnpDevice -Class Camera`; sensor/USB ID and Linux support unknown |
| Battery model | `01AV470` | Windows battery report |
| Battery manufacturer / chemistry | LGC / LiP | Windows battery report |
| Design capacity | 47,880 mWh (47.88 Wh) | Windows battery report |
| Full charge capacity | 43,760 mWh (43.76 Wh) | Windows battery report |
| Estimated capacity retention | 91.4% (full-charge ÷ design capacity) | Calculated from Windows report; firmware estimate, not laboratory measurement |
| Cycle count | 16 | Windows battery report |

The battery serial number is intentionally omitted. Capacity and cycle count can change; re-read them on the installed Linux system. Do not treat the Windows battery report's runtime estimates as guaranteed battery life.

## Project implications (planning only)

- **CPU/GPU:** validate Intel graphics acceleration and Wayland/Hyprland operation using the installed kernel and Mesa stack; do not add proprietary graphics drivers by assumption.
- **Memory:** use the measured installed memory when sizing swap/hibernation. The reported 8 GB is a planning input, not a hard-coded installer constant.
- **Storage:** verify NVMe transport, namespace/device identity, firmware, capacity, and SMART/NVMe health before constructing a disk plan. No destructive action is authorized by this document.
- **Wi-Fi/Bluetooth/Ethernet:** verify PCI/USB IDs, kernel modules, firmware, and real connectivity on the Arch ISO. Windows driver versions are not Linux dependencies.
- **Audio/camera:** discover codec and device IDs and test actual capture/playback; Windows friendly names alone are insufficient for driver decisions.
- **Battery/power:** inspect Linux power-supply and platform capabilities before choosing a single power-management service or charge thresholds. Avoid competing daemons and undocumented ThinkPad tweaks.
- **Display:** confirm EDID, native mode, panel properties, and touch capability from Linux before applying display-specific configuration.

## Linux verification checklist

- [ ] Confirm DMI manufacturer, product name, product version, and BIOS version/date.
- [ ] Confirm CPU model, topology, and installed/usable memory.
- [ ] Confirm GPU PCI ID, kernel driver, Mesa renderer, and hardware acceleration.
- [ ] Confirm internal SSD model, transport (NVMe/SATA), capacity, health, and stable identifiers.
- [ ] Confirm Wi-Fi, Bluetooth, and Ethernet PCI/USB IDs, bound drivers, firmware, and connectivity.
- [ ] Confirm audio codec/controller and playback/capture.
- [ ] Confirm camera device ID and capture operation.
- [ ] Read display EDID/native mode and verify non-touch input devices.
- [ ] Read battery model, energy-full/design values, cycle count, and charge-threshold support.
- [ ] Test suspend, resume, thermals, fan behavior, and power consumption on the actual laptop.

## Data handling

This document intentionally excludes the Windows computer name, battery serial number, MAC addresses, Windows user path, and unrelated identifiers. The target SSD serial is deliberately retained in the project-specific validation script and Stage 8–9 evidence because it is needed to distinguish this laptop's intended internal SSD from removable/other devices. The GitHub repository is currently public, so that serial is publicly visible; retaining it is an owner-directed project choice and an acknowledged privacy exposure. Update this baseline only when new evidence is available; preserve the distinction between owner-reported facts, Windows observations, Linux observations, and assumptions.
