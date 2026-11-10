# Status Proyek

**Terakhir diperbarui: 2026-11-11.** Dokumen ini adalah satu-satunya sumber status proyek aktif. Bila ringkasan di dokumen lain berbeda, gunakan dokumen ini dan perbarui ringkasan yang keliru.

## Status tahapan

| Tahap | Status | Catatan |
|---|---|---|
| 1. Live Readiness | IMPLEMENTED | Entry point kanonis: `stages/stage-1-live-readiness/scripts/k41-live-validation.sh`. |
| 2. Basic Arch Installation | IMPLEMENTED | Entry point kanonis: `stages/stage-2-basic-arch-install/scripts/k41-install-basic-arch.sh`; operasi destruktif. Peta: [Stage 2](../stages/stage-2-basic-arch-install/README.md). |
| 3. Desktop Installation | IMPLEMENTED | Entry point kanonis: `stages/stage-3-desktop-install/scripts/k41-install-desktop.sh`. Catatan: pilihan skip Caelestia belum kompatibel dengan kontrak package Stage 4 saat ini. Peta: [Stage 3](../stages/stage-3-desktop-install/README.md). |
| 4. Desktop Functional Validation | **COMPLETED / USER ACCEPTED** | Snapshot historis: 54 PASS, 3 WARN, 0 FAIL, 0 SKIP; exit 0. Pengguna mengonfirmasi pairing Bluetooth berhasil. Peta: [Stage 4](../stages/stage-4-desktop-validation/README.md). |
| 5. Desktop Customization | **IN PROGRESS — WORKSTREAM 3** | Workstream 1, 2, dan 4 telah diterima pengguna. Workstream 3 — Dashboard kini menjadi pekerjaan aktif setelah pengguna menyetujui Taskbar/Panel. Peta fisik: [Stage 5](../stages/stage-5-desktop-customization/README.md). |
| 6. Desktop & Hardware Optimization | PLANNED | Audit/selector tools dipetakan di [Stage 6](../stages/stage-6-hardware-optimization/README.md); optimasi aktual menunggu Stage 5 diterima dan baseline X280 terbaru. |
| 7. Release | PLANNED | Menunggu seluruh gate dan regression lulus. |

## Keterbatasan integrasi yang diketahui

**Stage 3 → Stage 4: pilihan Caelestia belum konsisten.** Installer Stage 3 menawarkan dua jalur: memasang paket resmi `quickshell` tanpa Caelestia, atau memasang `quickshell-git` beserta `caelestia-shell` dan `caelestia-cli`. Source validator Stage 4 saat ini memiliki daftar paket wajib yang secara eksplisit mensyaratkan `quickshell-git`, `caelestia-shell`, dan `caelestia-cli`. Karena itu, memilih jalur Quickshell-only menyebabkan pemeriksaan paket Stage 4 gagal. Ini adalah keterbatasan integrasi yang terverifikasi dari source, bukan kegagalan yang sudah diuji pada perangkat. Untuk alur proyek yang sekarang, pilih Caelestia pada Stage 3. Dukungan Stage 4 untuk jalur Quickshell-only memerlukan perubahan kode dan test terpisah; belum diimplementasikan.

## Prioritas aktif

**Stage 5 — Workstream 3: Dashboard.** Pengguna telah menyetujui hasil Taskbar/Panel pada 2026-11-11. Dashboard kini menjadi workstream aktif dan dikerjakan sebelum Launcher.

- Desain: **C — Floating Password Card**.
- Implementasi repository: override QML `Content.qml`, `Center.qml`, `PasswordInput.qml`, dan `LockSurface.qml`, serta installer deployment source tree Caelestia tersedia.
- Installer: `stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-apply-lockscreen-design.sh`.
- Collector audit: `stages/stage-5-desktop-customization/workstreams/02-lock-screen/scripts/k41-lockscreen-audit.sh`.
- Static test: `stages/stage-5-desktop-customization/tests/test-lockscreen-design.sh`.
- Status proyek: **COMPLETED / USER ACCEPTED pada 2026-11-10**, berdasarkan konfirmasi eksplisit pengguna bahwa pekerjaan Lock Screen telah selesai.
- Status kode: IMPLEMENTED di repository. Penerimaan pengguna menutup workstream; status ini tidak dimaksudkan sebagai klaim baru bahwa setiap skenario runtime telah diuji ulang secara independen pada commit terkini.
- Jangan membuka kembali Workstream 2 hanya karena catatan status lama atau bukti historis belum mencatat seluruh skenario. Audit ulang hanya jika pengguna melaporkan regresi atau meminta perubahan.

Detail prosedur dan acceptance hanya berada di [Workstream 2 — Lock Screen](../stages/stage-5-desktop-customization/docs/02-LOCK-SCREEN.md).

## Status Workstream 1 — Boot Experience

**COMPLETED / USER ACCEPTED — 2026-11-10.**

Pengguna secara eksplisit menyatakan Workstream 1 selesai. Keputusan ini menutup pekerjaan workstream dan menjadi status proyek terkini. Catatan 2026-11-09 yang menyebut kebocoran visual adalah histori pada saat itu dan tidak lagi menjadi backlog aktif setelah keputusan penerimaan pengguna.

Penutupan ini tidak boleh diperluas menjadi klaim teknis yang tidak pernah dicatat, misalnya pengukuran ulang status TPM2 token, Secure Boot, atau semua konfigurasi firmware. Jika pengguna melaporkan masalah baru, lakukan audit baru sebagai pekerjaan baru; jangan membatalkan penutupan hanya dengan mengutip catatan lama.

Dokumen pemilik: [Workstream 1 — Boot Experience](../stages/stage-5-desktop-customization/docs/01-BOOT-EXPERIENCE.md).

## Workstream berikutnya

| Workstream | Status |
|---|---|
| 1. Boot Experience | **COMPLETED / USER ACCEPTED** |
| 2. Lock Screen | **COMPLETED / USER ACCEPTED** |
| 3. Dashboard | **IN PROGRESS — AUDIT / REQUIREMENTS** |
| 4. Taskbar/Panel | **COMPLETED / USER ACCEPTED — 2026-11-11** |
| 5. Launcher | PLANNED |
| 6. Sidebar | PLANNED |
| 7. Utilities | PLANNED |

Guest Mode **NOT IMPLEMENTED / DEFERRED**. Spesifikasi konseptual ada di [03 — Guest Mode](../stages/stage-5-desktop-customization/docs/03-GUEST-MODE.md). Fitur ini bukan pekerjaan aktif dan tidak boleh diimplementasikan tanpa keputusan implementasi baru yang eksplisit; penerimaan Lock Screen tidak otomatis mengaktifkannya.

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
