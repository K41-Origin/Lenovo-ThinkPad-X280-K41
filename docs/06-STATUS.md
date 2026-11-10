# Status Proyek

**Terakhir diperbarui: 2026-11-11.** Dokumen ini adalah satu-satunya sumber status proyek aktif. Bila ringkasan di dokumen lain berbeda, gunakan dokumen ini dan perbarui ringkasan yang keliru.

## Status tahapan

| Tahap | Status | Catatan |
|---|---|---|
| 1. Live Readiness | IMPLEMENTED | Entry point kanonis: `stages/stage-1-live-readiness/scripts/k41-live-validation.sh`. |
| 2. Basic Arch Installation | IMPLEMENTED | Entry point kanonis: `stages/stage-2-basic-arch-install/scripts/k41-install-basic-arch.sh`; operasi destruktif. |
| 3. Desktop Installation | IMPLEMENTED | Entry point kanonis: `stages/stage-3-desktop-install/scripts/k41-install-desktop.sh`. |
| 4. Desktop Functional Validation | **COMPLETED / USER ACCEPTED** | Snapshot historis: 54 PASS, 3 WARN, 0 FAIL, 0 SKIP; exit 0. |
| 5. Desktop Customization | **IN PROGRESS — TOPBAR / BOTTOMBAR REWORK** | Cleanup Dashboard config script dan fixture test diperbarui; runtime X280 belum diverifikasi. |
| 6. Desktop & Hardware Optimization | PLANNED | Menunggu Stage 5 dan baseline X280 terbaru. |
| 7. Release | PLANNED | Menunggu seluruh gate dan regression lulus. |

## Prioritas aktif Stage 5

Keputusan terbaru pengguna pada 2026-11-11:
1. **Dashboard dinonaktifkan dari runtime Caelestia.** Penghapusan total halaman Dashboard dari Nexus belum dilakukan.
2. **Taskbar/Panel berganti nama menjadi Bottombar.** Arah desain yang dipertahankan adalah dock horizontal minimal di bawah dengan indikator workspace saja. Implementasi sebelumnya pernah diterima sebagai Taskbar/Panel; perubahan dan verifikasi baru belum diterima.
3. **Topbar akan dibuat.** Posisi atas dan orientasi horizontal telah diputuskan; daftar elemen, alignment, ukuran, dan perilaku visibility belum ditentukan.
4. **Dashboard cleanup:** `k41-cleanup-caelestia.sh` menetapkan `dashboard.enabled=false` pada global config dan file monitor yang memiliki override Dashboard. Script memvalidasi kandidat JSON sebelum perubahan dan membuat backup bertimestamp. Script tidak menghapus source QML, halaman Nexus, atau file package-owned. Pengujian runtime X280 belum dilakukan.

Dokumen pemilik:
- [Bottombar](../stages/stage-5-desktop-customization/docs/04-TASKBAR-PANEL.md)
- [Topbar](../stages/stage-5-desktop-customization/docs/05-TOPBAR.md)

## Status workstream lainnya

| Workstream | Status |
|---|---|
| 1. Boot Experience | **COMPLETED / USER ACCEPTED — 2026-11-10** |
| 2. Lock Screen | **COMPLETED / USER ACCEPTED — 2026-11-10** |
| 3. Bottombar | **REWORK PLANNED** (sebelumnya Taskbar/Panel diterima) |
| 4. Topbar | **PLANNED — REQUIREMENTS TO FINALIZE** |
| 5. Launcher | PLANNED |
| 6. Sidebar | PLANNED |
| 7. Utilities | PLANNED |

Guest Mode **NOT IMPLEMENTED / DEFERRED**. Spesifikasi konseptual ada di [03 — Guest Mode](../stages/stage-5-desktop-customization/docs/03-GUEST-MODE.md). Fitur ini bukan pekerjaan aktif dan tidak boleh diimplementasikan tanpa keputusan baru yang eksplisit.

## Keputusan proyek yang masih berlaku

1. Dashboard tidak menjadi workstream Stage 5; runtime dinonaktifkan melalui konfigurasi Caelestia.
2. Hasil Stage 5 menjadi input evaluasi/perbaikan tahap instalasi sebelumnya.
3. Refactoring integrasi instalasi dilakukan setelah Stage 5 cukup matang dan sebelum Stage 7 — Release.
4. Screenshot tidak digunakan, tidak diminta, dan bukan acceptance gate.
5. Design System menjadi spesifikasi visual lintas-komponen; status implementasi aktual dimiliki dokumen ini dan dokumen workstream pemilik.

## Bukti historis

Bukti Stage 4 historis tetap tersimpan pada commit arsip `02f6194ed04c8f13ea64eda35b7afb94f7006504`. Snapshot tersebut bukan laporan runtime terkini.
