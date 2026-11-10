# Status Proyek

**Terakhir diperbarui: 2026-11-10.** Dokumen ini adalah satu-satunya sumber status proyek aktif. Bila ringkasan di dokumen lain berbeda, gunakan dokumen ini dan perbarui ringkasan yang keliru.

## Status tahapan

| Tahap | Status | Catatan |
|---|---|---|
| 1. Live Readiness | IMPLEMENTED | Entry point kanonis: `stages/stage-1-live-readiness/scripts/k41-live-validation.sh`. |
| 2. Basic Arch Installation | IMPLEMENTED | Entry point kanonis: `scripts/k41-install-basic-arch.sh`; operasi destruktif. Peta: [Stage 2](../stages/stage-2-basic-arch-install/README.md). |
| 3. Desktop Installation | IMPLEMENTED | Entry point kanonis: `stages/stage-3-desktop-install/scripts/k41-install-desktop.sh`. Peta: [Stage 3](../stages/stage-3-desktop-install/README.md). |
| 4. Desktop Functional Validation | **COMPLETED / USER ACCEPTED** | Snapshot historis: 54 PASS, 3 WARN, 0 FAIL, 0 SKIP; exit 0. Pengguna mengonfirmasi pairing Bluetooth berhasil. Peta: [Stage 4](../stages/stage-4-desktop-validation/README.md). |
| 5. Desktop Customization | **IN PROGRESS — WORKSTREAM 2** | Workstream 1 selesai dan diterima pengguna; Workstream 2 aktif. |
| 6. Desktop & Hardware Optimization | PLANNED | Menunggu Stage 5 diterima dan baseline aktual. |
| 7. Release | PLANNED | Menunggu seluruh gate dan regression lulus. |

## Prioritas aktif

**Stage 5 — Workstream 2: Lock Screen.**

- Desain: **C — Floating Password Card**.
- Implementasi repository: override QML `Content.qml`, `Center.qml`, `PasswordInput.qml`, dan `LockSurface.qml`, serta installer deployment source tree Caelestia tersedia.
- Installer: `stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-apply-lockscreen-design.sh`.
- Collector audit: `stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-lockscreen-audit.sh`.
- Static test: `tests/test-lockscreen-design.sh`.
- Status: **IMPLEMENTED; NOT TESTED / NOT VERIFIED pada X280 untuk implementasi terbaru**.
- Belum ada bukti yang cukup bahwa source tree lokal terbaru aktif, runtime QML berhasil, lock/unlock dan wake lulus, atau tampilan diterima pengguna.
- Gate berikutnya: terapkan perubahan dari checkout terbaru, periksa source aktif, jalankan test aman yang tersedia, uji lock/unlock dan wake pada X280, lalu minta keputusan visual pengguna secara langsung. Tidak menggunakan screenshot.

Detail prosedur dan acceptance hanya berada di [Workstream 2 — Lock Screen](08-STAGE-5/02-LOCK-SCREEN.md).

## Status Workstream 1 — Boot Experience

**COMPLETED / USER ACCEPTED — 2026-11-10.**

Pengguna secara eksplisit menyatakan Workstream 1 selesai. Keputusan ini menutup pekerjaan workstream dan menjadi status proyek terkini. Catatan 2026-11-09 yang menyebut kebocoran visual adalah histori pada saat itu dan tidak lagi menjadi backlog aktif setelah keputusan penerimaan pengguna.

Penutupan ini tidak boleh diperluas menjadi klaim teknis yang tidak pernah dicatat, misalnya pengukuran ulang status TPM2 token, Secure Boot, atau semua konfigurasi firmware. Jika pengguna melaporkan masalah baru, lakukan audit baru sebagai pekerjaan baru; jangan membatalkan penutupan hanya dengan mengutip catatan lama.

Dokumen pemilik: [Workstream 1 — Boot Experience](08-STAGE-5/01-BOOT-EXPERIENCE.md).

## Workstream berikutnya

| Workstream | Status |
|---|---|
| 1. Boot Experience | **COMPLETED / USER ACCEPTED** |
| 2. Lock Screen | **IN PROGRESS** |
| 3. Dashboard | PLANNED |
| 4. Taskbar/Panel | PLANNED |
| 5. Launcher | PLANNED |
| 6. Sidebar | PLANNED |
| 7. Utilities | PLANNED |

Guest Mode **NOT IMPLEMENTED / DEFERRED**. Spesifikasi konseptual ada di [03 — Guest Mode](08-STAGE-5/03-GUEST-MODE.md). Fitur ini bukan pekerjaan aktif dan tidak boleh diimplementasikan sebelum lock screen diterima serta ada keputusan implementasi baru.

## Keputusan proyek yang masih berlaku

1. Stage 5 diselesaikan secara berurutan.
2. Hasil Stage 5 nantinya menjadi input untuk evaluasi dan perbaikan tahap instalasi sebelumnya.
3. Refactoring dan integrasi tahap instalasi dilakukan setelah Stage 5 cukup matang, tetapi sebelum Stage 7 — Release. Ini PLANNED, bukan implementasi aktif.
4. Screenshot tidak digunakan, tidak diminta, dan bukan acceptance gate.
5. Design System menjadi spesifikasi desain lintas-komponen; status implementasi aktual tetap dicatat di dokumen ini dan dokumen workstream pemilik.

## Bukti historis

- [Stage 4 desktop validation — 54 PASS / 3 WARN](https://github.com/K41-Origin/Lenovo-ThinkPad-X280-K41/blob/02f6194ed04c8f13ea64eda35b7afb94f7006504/reports/archive/2026-11/desktop-validation/20261109T081724Z/summary.md)
- [Stage 4 desktop repair](https://github.com/K41-Origin/Lenovo-ThinkPad-X280-K41/blob/02f6194ed04c8f13ea64eda35b7afb94f7006504/reports/archive/2026-11/desktop-repair/20261109T081723Z/summary.md)
- [Stage 4 manual acceptance](https://github.com/K41-Origin/Lenovo-ThinkPad-X280-K41/blob/02f6194ed04c8f13ea64eda35b7afb94f7006504/reports/archive/2026-11/desktop-validation/20261109T081724Z/manual-acceptance.md)

Bukti tersebut adalah snapshot historis pada commit arsip, bukan laporan runtime saat ini. Jangan menganggapnya mewakili kondisi perangkat terkini.
