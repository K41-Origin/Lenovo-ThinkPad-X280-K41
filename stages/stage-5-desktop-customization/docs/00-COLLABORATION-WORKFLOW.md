# Stage 5 — Alur Kolaborasi dan Verifikasi

## Tujuan

Dokumen ini menetapkan alur kerja Stage 5. Hasil yang relevan menjadi fondasi **K41-dots**, kumpulan modul Quickshell milik K41, bukan shell mandiri pada tahap ini. Workstream 01 — Boot Experience dikecualikan karena boot/splash menggunakan Plymouth.

## Pembagian tanggung jawab

| Pihak | Tanggung jawab |
|---|---|
| Assistant | Memeriksa repository dan upstream; membuat serta memelihara source, script audit/migrasi/implementasi, test, dan dokumentasi; memverifikasi perubahan GitHub; melaporkan bukti, batasan, dan risiko. |
| Pengguna | Hanya melakukan `git pull` dan `git push` untuk sinkronisasi perubahan sesuai alur yang disepakati. |

Pengguna tidak diminta mengedit file, menulis kode, menjalankan perintah manual, atau mengubah konfigurasi secara manual.

**Batasan penting:** pull/push Git tidak mengeksekusi script dan tidak memverifikasi perilaku runtime pada laptop. Untuk pekerjaan yang memerlukan eksekusi lokal, desain otomatisasi harus ditentukan terlebih dahulu dan tidak boleh diam-diam menambahkan langkah manual kepada pengguna. Jika validasi tidak dapat dilakukan dalam batasan ini, laporkan sebagai BLOCKED/NOT VERIFIED dengan alasan teknis yang jelas. Jangan mengklaim hasil yang tidak memiliki bukti.

## Source dan runtime

- Repository adalah sumber kanonis source yang direview, script, test, dan dokumentasi.
- Runtime modul K41 berada di `~/.config/quickshell/k41/modules/<feature>/`.
- Contoh Lock Screen: `~/.config/quickshell/k41/modules/lockscreen/`.
- Caelestia tetap menjadi host/runtime selama belum ada keputusan baru.
- Namespace K41 dipisahkan dari `~/.config/quickshell/caelestia/`.
- Backup runtime tidak di-commit.

## Alur minimum per fitur

1. **Audit upstream (read-only)** — periksa source/config yang benar-benar aktif; kumpulkan file utama, resource, dependency, konfigurasi, dan titik integrasi yang diperlukan.
2. **Review audit** — tentukan source yang menjadi milik K41 dan dependency yang tetap disediakan upstream.
3. **Ekstraksi/penyiapan** — script terpisah mengambil source/resource yang dipilih ke namespace K41. Audit tidak boleh melakukan operasi tulis.
4. **Implementasi/integrasi** — lakukan perubahan minimum agar modul K41 digunakan oleh lingkungan Quickshell yang ada.
5. **Verifikasi** — periksa file hasil, dependency, konfigurasi, pemuatan QML, dan perilaku fitur yang relevan.
6. **Cleanup upstream (bila diperlukan)** — hanya setelah migrasi terverifikasi dan diterima; hapus hanya source milik fitur yang terbukti tidak lagi digunakan.

Jangan membuat bootstrap, service, updater, framework installer, atau runtime K41 mandiri sebelum ada kebutuhan nyata.

## Siklus perubahan

1. Periksa branch, file terkait, konfigurasi, dan implementasi upstream.
2. Tetapkan scope dan acceptance sebelum mengubah source.
3. Periksa isi dan SHA file sebelum menulis ke GitHub.
4. Buat perubahan kecil dan verifikasi hasil write dengan membaca ulang file.
5. Jalankan test statis/fixture/CI yang dapat dilakukan tanpa tindakan manual pengguna.
6. Pengujian runtime hanya boleh diklaim jika benar-benar dijalankan dan memiliki bukti.
7. Catat perintah, hasil aktual, keterbatasan, dan keputusan pengguna.

## Protokol khusus Lock Screen

- Tampilan Lock Screen saat ini telah disetujui pengguna. Migrasi harus mempertahankan tampilan tersebut; bukan redesign.
- Audit mencakup source visual, QML, styling, animasi, aset, konfigurasi visual, resource, dependency, dan titik integrasi.
- PAM, autentikasi, password handling, fingerprint/Howdy policy, dan session-lock protocol tidak boleh diubah oleh pekerjaan visual.
- Source visual K41 dipisahkan ke modul `lockscreen`; dependency upstream yang masih dibutuhkan tetap dimiliki Caelestia.
- Cleanup source visual upstream ditunda sampai migrasi terbukti berfungsi dan diterima pengguna.
- Pengguna hanya melakukan pull/push. Assistant membuat script audit, ekstraksi, migrasi, implementasi, test, dan dokumentasi.

Dokumen rinci: [Workstream 02 — Lock Screen](02-LOCK-SCREEN.md).

## Klasifikasi hasil

Gunakan status kanonis dari [AGENTS.md](../../../AGENTS.md): PLANNED, IMPLEMENTED, TESTED, VERIFIED, COMPLETED / USER ACCEPTED, BLOCKED, dan RELEASED. Jelaskan bukti dan batas klaim untuk setiap status.

Status keseluruhan Stage 5 hanya dicatat di [docs/06-STATUS.md](../../../docs/06-STATUS.md).
