# Desktop Environment — Hyprland, Quickshell, Caelestia

Dokumen ini adalah handoff ringkas untuk desktop tahap 3–5. Detail yang memiliki prosedur khusus dimiliki dokumen terkait; jangan menjadikan catatan historis sebagai instruksi baru.

## Tahap 3 — Instalasi desktop

Jalankan dari Arch Linux yang telah terpasang, melalui TTY, sebagai user biasa:

```bash
sudo bash stages/stage-3-desktop-install/scripts/k41-install-desktop.sh
```

Jangan jalankan dari Arch ISO, chroot, atau sesi grafis. Entry point ini adalah wrapper kanonis untuk desktop setup. Peta implementasi Stage 3: [Stage 3 — Desktop Installation](../stages/stage-3-desktop-install/README.md).

## Tahap 4 — Functional validation

Jalankan dari terminal sesi Hyprland sebagai user biasa:

```bash
bash stages/stage-4-desktop-validation/scripts/k41-desktop-validation.sh
```

Jika hasil memuat WARN/FAIL, tinjau bukti dan gunakan `bash stages/stage-4-desktop-validation/scripts/k41-desktop-repair.sh` hanya untuk remediation yang didukung. Repair tidak menyediakan mode `--apply` dan tidak mengubah PAM, kernel parameters, SMT, atau firmware.

Penerimaan Stage 4 tercatat sebagai **54 PASS, 3 WARN, 0 FAIL, 0 SKIP** (PASS_WITH_WARNINGS, exit 0). Pengguna juga mengonfirmasi pairing Bluetooth berhasil. Ini adalah snapshot historis, bukan klaim bahwa kondisi perangkat hari ini identik. Peta implementasi, batas repair, laporan, dan cakupan acceptance: [Stage 4 — Desktop Functional Validation](../stages/stage-4-desktop-validation/README.md).

Bukti tersimpan dalam snapshot historis:
- [Desktop validation summary](https://github.com/K41-Origin/Lenovo-ThinkPad-X280-K41/blob/02f6194ed04c8f13ea64eda35b7afb94f7006504/reports/archive/2026-11/desktop-validation/20261109T081724Z/summary.md)
- [Desktop repair summary](https://github.com/K41-Origin/Lenovo-ThinkPad-X280-K41/blob/02f6194ed04c8f13ea64eda35b7afb94f7006504/reports/archive/2026-11/desktop-repair/20261109T081723Z/summary.md)
- [Manual acceptance record](https://github.com/K41-Origin/Lenovo-ThinkPad-X280-K41/blob/02f6194ed04c8f13ea64eda35b7afb94f7006504/reports/archive/2026-11/desktop-validation/20261109T081724Z/manual-acceptance.md)

## Tahap 5 — Desktop customization

Status terkini dan prioritas hanya dicatat di [06 — Status](06-STATUS.md).

Peta fisik implementasi: [Stage 5 — Desktop Customization](../stages/stage-5-desktop-customization/README.md).

Urutan resmi:
1. [Boot Experience](08-STAGE-5/01-BOOT-EXPERIENCE.md)
2. [Lock Screen](08-STAGE-5/02-LOCK-SCREEN.md)
3. [Dashboard](08-STAGE-5/03-DASHBOARD.md)
4. [Taskbar/Panel](08-STAGE-5/04-TASKBAR-PANEL.md)
5. [Launcher](08-STAGE-5/05-LAUNCHER.md)
6. [Sidebar](08-STAGE-5/06-SIDEBAR.md)
7. [Utilities](08-STAGE-5/07-UTILITIES.md)

Arah visual kanonis adalah **K41 Obsidian Minimalism / Graphite Monochrome**. Gunakan [Design System index](07-DESKTOP-DESIGN-SYSTEM.md) dan dokumen spesifiknya. Jangan menyalin ulang token atau keputusan desain ke dokumen workstream.

### Kebijakan review visual

Screenshot tidak digunakan, tidak diminta, dan bukan syarat acceptance. Pengguna melakukan review visual dan interaksi langsung pada display X280. Catat keputusan/hasil secara tekstual tanpa meminta gambar.

## Batas Stage 5

Stage 5 berfokus pada shell, tampilan, interaksi, dan integrasi aplikasi. Optimasi CPU/GPU, thermal/fan, baterai, power policy, dan suspend/resume merupakan Stage 6.

Guest Mode **NOT IMPLEMENTED** dan ditunda. Jangan menganggap collector audit Guest sebagai implementasi fitur.
