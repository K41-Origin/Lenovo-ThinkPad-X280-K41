# Status Proyek

**Terakhir diperbarui: 2026-11-11.** Dokumen ini adalah satu-satunya sumber status proyek aktif. Bila ringkasan di dokumen lain berbeda, gunakan dokumen ini dan perbarui ringkasan yang keliru.

## Status tahapan

| Tahap | Status | Catatan |
|---|---|---|
| 1. Live Readiness | IMPLEMENTED | Entry point kanonis: `stages/stage-1-live-readiness/scripts/k41-live-validation.sh`. |
| 2. Basic Arch Installation | IMPLEMENTED | Entry point kanonis: `stages/stage-2-basic-arch-install/scripts/k41-install-basic-arch.sh`; operasi destruktif. |
| 3. Desktop Installation | IMPLEMENTED | Entry point kanonis: `stages/stage-3-desktop-install/scripts/k41-install-desktop.sh`. |
| 4. Desktop Functional Validation | **COMPLETED / USER ACCEPTED** | Snapshot historis: 54 PASS, 3 WARN, 0 FAIL, 0 SKIP; exit 0. |
| 5. Desktop Customization | **IN PROGRESS — TOPBAR / REMAINING COMPONENTS** | K41Dock berhasil dan diterima; Topbar menjadi pekerjaan berikutnya setelah penyelarasan fondasi K41-dots. |
| 6. Desktop & Hardware Optimization | PLANNED | Menunggu Stage 5 dan baseline X280 terbaru. |
| 7. Release | PLANNED | Menunggu seluruh gate dan regression lulus. |

## Prioritas aktif Stage 5

1. **Workstream 01 — Boot Experience: REOPENED — AUDIT REQUIRED.** Fokus adalah memperbaiki jalur boot dengan Plymouth sebagai satu-satunya renderer splash/animasi, 100% tanpa QML/Quickshell. Status COMPLETED / USER ACCEPTED pada 2026-11-10 adalah histori, bukan status implementasi saat ini. Audit source repository menemukan konflik Quickshell/QML splash; pemanggilan installer dan artefak QML legacy kini telah dihapus, test dialihkan ke kontrak Plymouth-only. Kondisi laptop belum diverifikasi. Audit read-only perangkat disiapkan melalui `workstreams/01-boot-experience/scripts/k41-audit-boot-experience.sh`. Jangan jalankan installer konfigurasi boot lama sebelum refactor dan review hasil audit perangkat. TPM/LUKS/bootloader/initramfs/UKI tetap tidak boleh diubah tanpa audit dan persetujuan eksplisit.
2. **Workstream 02 — Lock Screen: DESIGN COMPLETED / USER ACCEPTED; MIGRATION PLANNED.** Tampilan saat ini harus dipertahankan tanpa redesign. Pekerjaan dimulai ulang dari audit read-only menyeluruh atas source visual, aset, konfigurasi, dependency, dan titik integrasi; kemudian ekstraksi source terpilih, perancangan modul `~/.config/quickshell/k41/modules/lockscreen/`, migrasi, testing, dan cleanup source visual upstream hanya setelah hasil terbukti berfungsi serta diterima. Pengguna hanya melakukan `git pull` dan `git push`; assistant bertanggung jawab atas script, implementasi, test, dan dokumentasi. Pull/push tidak menjalankan script atau memverifikasi runtime, sehingga batasan eksekusi harus ditangani melalui desain otomatisasi dan klaim runtime tidak boleh dibuat tanpa bukti.
2. **Workstream 04 — Bottombar / K41Dock: COMPLETED / USER CONFIRMED SUCCESS.** Komponen telah berhasil digunakan. Source dan deployment saat ini masih berada pada struktur Caelestia lama; penyesuaian ke namespace K41 dilakukan sebagai bagian dari penyelarasan fondasi, tanpa mengubah desain yang sudah diterima.
3. **Fondasi K41-dots: PLANNED.** Menyusun audit fitur upstream yang read-only dan script penyiapan modul ke `~/.config/quickshell/k41/modules/<feature>/`.
4. **Workstream 05 — Topbar: PLANNED.** Posisi atas dan orientasi horizontal telah diputuskan; elemen, alignment, ukuran, dan visibility harus ditentukan sebelum implementasi.
5. **Workstream 06 — Launcher: PLANNED.**
6. **Workstream 07 — Sidebar: PLANNED.**
7. **Workstream 08 — Utilities: PLANNED.**
8. Guest Mode (ID 03) **NOT IMPLEMENTED / DEFERRED** dan bukan pekerjaan aktif.

## Prinsip Stage 5 dan K41-dots

- K41-dots adalah kumpulan modul Quickshell milik K41, bukan shell mandiri pada tahap ini.
- Runtime tujuan modul adalah `~/.config/quickshell/k41/modules/<feature>/`, misalnya `lockscreen/`.
- Script audit mengumpulkan informasi source, dependency, konfigurasi, dan titik integrasi yang relevan untuk satu fitur; audit tidak mengubah sistem.
- Script penyiapan mengambil hanya source/resource yang diperlukan dan menempatkannya pada namespace K41. Audit dan penyiapan adalah dua operasi terpisah.
- Caelestia tetap menjadi host/runtime; integrasi dilakukan seperlunya.
- Workstream 01 — Boot Experience dikecualikan dari K41-dots. Boot splash wajib hanya menggunakan Plymouth; QML/Quickshell tidak boleh menjadi bagian dari boot path. Lihat dokumen Workstream 01.
- Jangan membangun bootstrap, runtime, service, atau framework deployment mandiri tanpa kebutuhan yang terbukti.
- Status implementasi modul, runtime laptop, dan penerimaan pengguna harus dibedakan. Dokumentasi rencana tidak berarti migrasi sudah dilakukan.

## Keputusan proyek yang masih berlaku

1. Dashboard dinonaktifkan melalui konfigurasi runtime Caelestia; halaman Dashboard Nexus upstream belum dihapus.
2. Hasil Stage 5 menjadi input evaluasi/perbaikan tahap instalasi sebelumnya.
3. Refactoring integrasi instalasi dilakukan setelah Stage 5 cukup matang dan sebelum Stage 7 — Release.
4. Screenshot tidak digunakan, tidak diminta, dan bukan acceptance gate.
5. Design System menjadi spesifikasi visual lintas-komponen; status implementasi aktual dimiliki dokumen ini dan dokumen workstream pemilik.

## Bukti historis

Bukti Stage 4 historis tetap tersimpan pada commit arsip `02f6194ed04c8f13ea64eda35b7afb94f7006504`. Snapshot tersebut bukan laporan runtime terkini.
