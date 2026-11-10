# Status Proyek

**Terakhir diperbarui: 2026-11-11.** Dokumen ini adalah satu-satunya sumber status proyek aktif. Bila ringkasan di dokumen lain berbeda, gunakan dokumen ini dan perbarui ringkasan yang keliru.

## Status tahapan

| Tahap | Status | Catatan |
|---|---|---|
| 1. Live Readiness | IMPLEMENTED | Entry point kanonis: `stages/stage-1-live-readiness/scripts/k41-live-validation.sh`. |
| 2. Basic Arch Installation | IMPLEMENTED | Entry point kanonis: `stages/stage-2-basic-arch-install/scripts/k41-install-basic-arch.sh`; operasi destruktif. |
| 3. Desktop Installation | IMPLEMENTED | Entry point kanonis: `stages/stage-3-desktop-install/scripts/k41-install-desktop.sh`. |
| 4. Desktop Functional Validation | **COMPLETED / USER ACCEPTED** | Snapshot historis: 54 PASS, 3 WARN, 0 FAIL, 0 SKIP; exit 0. |
| 5. Desktop Customization | **IN PROGRESS — TOPBAR / REMAINING COMPONENTS** | Workstream 04 Bottombar/K41Dock berhasil dan diterima; Topbar menjadi pekerjaan berikutnya. |
| 6. Desktop & Hardware Optimization | PLANNED | Menunggu Stage 5 dan baseline X280 terbaru. |
| 7. Release | PLANNED | Menunggu seluruh gate dan regression lulus. |

## Prioritas aktif Stage 5

1. **Workstream 04 — Bottombar / K41Dock: COMPLETED / USER CONFIRMED SUCCESS.** Implementasi `K41Dock.qml` menjadi baseline komponen K41. Source kanonis berada di `workstreams/04-taskbar-panel/config/quickshell/caelestia/modules/k41dock/`; runtime laptop berada di `~/.config/quickshell/caelestia/modules/k41dock/`.
2. **Workstream 05 — Topbar: PLANNED.** Posisi atas dan orientasi horizontal telah diputuskan; elemen, alignment, ukuran, dan visibility harus ditentukan sebelum implementasi.
3. **Workstream 06 — Launcher: PLANNED.**
4. **Workstream 07 — Sidebar: PLANNED.**
5. **Workstream 08 — Utilities: PLANNED.**
6. Guest Mode (ID 03) **NOT IMPLEMENTED / DEFERRED** dan bukan pekerjaan aktif.

## Prinsip pengembangan Stage 5

- Setiap workstream dikerjakan satu per satu dengan audit, desain, implementasi, test, deployment, dan acceptance yang jelas.
- Repository adalah sumber kanonis source, installer, test, dan dokumentasi.
- Source/runtime Quickshell pada laptop berada di bawah `~/.config/quickshell/`; integrasi Caelestia saat ini berada di `~/.config/quickshell/caelestia/`.
- Kode K41 harus dipisahkan dalam namespace milik K41 dan dideploy melalui installer dengan preflight, backup, verifikasi, dan rollback.
- Hasil Stage 5 akan menjadi fondasi komponen, pola integrasi, dan deployment bagi proyek lanjutan **k41-shell**. Proyek k41-shell mandiri belum dimulai.

## Keputusan proyek yang masih berlaku

1. Dashboard dinonaktifkan melalui konfigurasi runtime Caelestia; halaman Dashboard Nexus upstream belum dihapus.
2. Hasil Stage 5 menjadi input evaluasi/perbaikan tahap instalasi sebelumnya.
3. Refactoring integrasi instalasi dilakukan setelah Stage 5 cukup matang dan sebelum Stage 7 — Release.
4. Screenshot tidak digunakan, tidak diminta, dan bukan acceptance gate.
5. Design System menjadi spesifikasi visual lintas-komponen; status implementasi aktual dimiliki dokumen ini dan dokumen workstream pemilik.

## Bukti historis

Bukti Stage 4 historis tetap tersimpan pada commit arsip `02f6194ed04c8f13ea64eda35b7afb94f7006504`. Snapshot tersebut bukan laporan runtime terkini.
