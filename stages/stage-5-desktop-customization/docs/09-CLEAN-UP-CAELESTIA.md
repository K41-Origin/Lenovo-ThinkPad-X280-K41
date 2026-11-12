# Workstream 09 — Clean up Caelestia

**Status: PLANNED — DILAKSANAKAN PALING AKHIR SETELAH SELURUH WORKSTREAM STAGE 5 SELESAI DAN DITERIMA.**

## Tujuan

Membersihkan sisa fitur, integrasi, konfigurasi, dan komponen Caelestia yang tidak lagi digunakan setelah seluruh workstream Stage 5 selesai. Workstream ini menjadi tahap konsolidasi akhir, bukan pekerjaan yang berjalan bersamaan dengan implementasi komponen.

Caelestia tetap menjadi shell host/runtime. Cleanup tidak berarti menghapus Caelestia atau dependency upstream yang masih diperlukan oleh komponen K41.

## Aturan urutan

- Workstream ini selalu menjadi pekerjaan terakhir Stage 5.
- Jangan mulai selama Workstream 01/02/03/05/06/07/08 masih memiliki pekerjaan aktif, acceptance tertunda, atau dependency yang belum diputuskan.
- Sebelum mulai, audit ulang konfigurasi dan runtime Caelestia aktual pada ThinkPad X280. Audit lama tidak cukup untuk menentukan target cleanup.
- Buat daftar target dan dampak per target, lalu minta persetujuan sebelum tindakan yang mengubah atau menghapus file.
- Jangan menggabungkan cleanup ini ke installer atau script milik workstream komponen.

## Ruang lingkup yang akan dievaluasi

- Fitur Caelestia bawaan yang telah digantikan komponen K41, termasuk Taskbar/bar lama yang telah digantikan Bottombar.
- Integrasi legacy, import QML, entry konfigurasi, keybind, halaman navigasi, dan referensi yang tidak lagi digunakan.
- File modul upstream yang tidak lagi diperlukan, hanya jika provenance dan seluruh dependency telah diperiksa.
- Konfigurasi global dan override monitor yang masih mengaktifkan fitur yang sudah digantikan.
- Konsistensi source repository, user checkout Caelestia, dan runtime yang benar-benar dimuat.

Daftar ini adalah kandidat area audit, bukan izin untuk menghapus seluruh item tersebut. Komponen upstream yang masih menjadi dependency Lock Screen, Bottombar, Topbar, Launcher, Sidebar, Utilities, atau fitur lain wajib dipertahankan.

## Tahapan wajib

1. **Read-only audit:** inventarisasi versi/origin Caelestia, package ownership, checkout status, runtime process, konfigurasi global/monitor, QML/JS/JSON references, keybind, entry navigasi, dependency statis/dinamis, serta seluruh modul K41 yang masih diintegrasikan.
2. **Dependency map:** klasifikasikan setiap target sebagai aktif/dipakai, legacy/tidak dipakai dengan bukti, tidak diketahui, atau package-owned.
3. **Cleanup proposal:** dokumentasikan target path yang tepat, alasan, provenance, checksum, risiko, backup, rollback, dan acceptance per target.
4. **Approval gate:** tidak ada perubahan sampai pengguna menyetujui daftar target dan rencana.
5. **Controlled cleanup:** default dry-run; apply hanya pada target allowlist yang cocok dengan hasil audit. Backup dan manifest wajib tersedia sebelum perubahan.
6. **Verification:** cek konfigurasi, referensi, dependency, startup Caelestia, seluruh komponen K41, serta rollback pada fixture terisolasi.
7. **Acceptance:** catat hasil aktual, target yang sengaja dipertahankan, dan residual yang belum aman dibersihkan.

## Batas keamanan

- Tidak menghapus package Caelestia, package-owned files, dependency upstream aktif, atau seluruh direktori modul secara massal.
- Tidak menggunakan wildcard deletion atau recursive deletion pada root Caelestia.
- Tidak menghapus file hanya karena pencarian teks tidak menemukan referensi; dynamic Loader, path-based lookup, plugin, dan dependency runtime harus dipertimbangkan.
- Tidak mengubah PAM, session-lock, autentikasi, service sistem, atau boot path.
- Tidak menjalankan sudo kecuali ada kebutuhan system-level yang teridentifikasi dan disetujui secara terpisah.
- Setiap target yang provenance, ownership, atau dependency-nya tidak jelas harus dipertahankan.
- Backup, manifest, verifikasi pascaperubahan, dan rollback wajib untuk setiap operasi mutatif.

## Acceptance criteria

- Seluruh workstream komponen Stage 5 telah selesai/diterima atau pengecualiannya disetujui pengguna.
- Audit aktual X280 dan dependency map tersedia.
- Setiap target cleanup memiliki bukti dan persetujuan eksplisit.
- Cleanup hanya menyentuh target allowlist; komponen Caelestia yang masih dibutuhkan tetap utuh.
- Automated fixture menguji dry-run, mismatch hash/provenance, backup, apply, verification, dan rollback.
- Startup/runtime Caelestia serta fungsi semua komponen K41 yang sudah diterima tidak mengalami regression.
- Dokumentasi dan status repository mencerminkan hasil yang benar-benar diverifikasi.

**Catatan:** Penghapusan manual K41Dock oleh pengguna merupakan tindakan terpisah yang telah dilakukan di luar repository. Workstream ini tetap akan mengaudit sisa Taskbar/Caelestia dan tidak menganggap penghapusan manual tersebut sebagai bukti bahwa seluruh legacy integration telah bersih.
