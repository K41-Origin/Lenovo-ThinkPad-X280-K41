# Stage 5 — Alur Kolaborasi dan Verifikasi

## Tujuan

Dokumen ini menetapkan alur kerja Stage 5. Dokumen ini adalah standar kolaborasi dan siklus perubahan lintas-workstream Stage 5; bukan workstream bernomor tersendiri. Hasil yang relevan menjadi fondasi **K41-dots**, kumpulan modul Quickshell milik K41, bukan shell mandiri pada tahap ini. Workstream 01 — Boot Experience dikecualikan dari K41-dots dan memiliki alur audit/implementasi tersendiri: Plymouth adalah satu-satunya renderer boot, 100% tanpa QML/Quickshell.

## Pembagian tanggung jawab

| Pihak | Tanggung jawab |
|---|---|
| Assistant | Memeriksa repository dan upstream; membuat serta memelihara source, script audit/migrasi/implementasi, test, dan dokumentasi; memverifikasi perubahan GitHub; melaporkan bukti, batasan, dan risiko. |
| Pengguna | Hanya melakukan `git pull` dan `git push` untuk sinkronisasi perubahan sesuai alur yang disepakati. |

Pengguna tidak diminta mengedit file, menulis kode, menjalankan perintah manual, atau mengubah konfigurasi secara manual.

**Batasan penting:** pull/push Git tidak mengeksekusi script dan tidak memverifikasi perilaku runtime pada laptop. Untuk pekerjaan yang memerlukan eksekusi lokal, desain otomatisasi harus ditentukan terlebih dahulu dan tidak boleh diam-diam menambahkan langkah manual kepada pengguna. Jika validasi tidak dapat dilakukan dalam batasan ini, laporkan sebagai BLOCKED/NOT VERIFIED dengan alasan teknis yang jelas. Jangan mengklaim hasil yang tidak memiliki bukti.

## Source dan runtime

- Repository adalah sumber kanonis source yang direview, script, test, dan dokumentasi.
- Runtime utama modul yang diimpor Caelestia berada di `~/.config/quickshell/caelestia/k41/modules/<feature>/`; sibling `~/.config/quickshell/k41/modules/<feature>/` adalah compatibility mirror.
- Contoh WS02 Lock Screen: overlay aktif `~/.config/quickshell/caelestia/modules/lock/`, dengan mirror di kedua namespace K41; detail ada di dokumen WS02.
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

## Protokol khusus Boot Experience (Workstream 01)

- Status saat ini: **PAUSED — INVESTIGATION PENDING**. Implementasi Plymouth-only tersedia, tetapi splash tidak terlihat pada boot aktual; penyebab belum VERIFIED.
- Audit repository dan perangkat harus read-only sebelum implementasi. Gunakan collector `workstreams/01-boot-experience/scripts/k41-audit-boot-experience.sh`.
- Boot splash/animasi wajib 100% Plymouth; QML/Quickshell/qs tidak boleh menjadi dependency atau proses boot.
- Review mencakup firmware/bootloader, EFI mount, kernel cmdline, initramfs/UKI, Plymouth, systemd units, LUKS/TPM metadata ringkas, TTY/login, serta journal. Jangan mengumpulkan secret.
- Pisahkan perubahan visual Plymouth dari perubahan TPM/LUKS, bootloader, autologin, dan enkripsi. Tidak ada operasi mutasi sebelum bukti perangkat dan rencana rollback direview.
- Test statis tidak membuktikan boot fisik, unlock LUKS, recovery, atau Secure Boot. Jangan klaim VERIFIED tanpa bukti pada ThinkPad X280.
- Artefak QML/installer Quickshell boot splash legacy telah dihapus setelah referensi deployment dan test dimigrasikan.
- Dokumen rinci: [Workstream 01 — Boot Experience](01-BOOT-EXPERIENCE.md).

## Protokol khusus Lock Screen

- Desain Floating Password Card telah disetujui pengguna; jangan redesign.
- Status: **COMPLETED / USER ACCEPTED (12 November 2026)**. Cakupan proses dan batas bukti tercatat pada dokumen pemilik. Penerimaan pengguna tidak mengubah bukti runtime yang belum tersedia menjadi VERIFIED.
- Audit mencakup source visual, QML, styling, animasi, aset, konfigurasi visual, resource, dependency, dan titik integrasi.
- PAM, autentikasi, password handling, fingerprint/Howdy policy, dan session-lock protocol tidak boleh diubah oleh pekerjaan visual.
- Source visual K41 dipisahkan ke `workstreams/02-lock-screen/modules/lockscreen/`; deployment, cleanup, dan batas validasinya dirangkum pada dokumen pemilik Workstream 02.
- TTY2 fallback telah terbukti dipicu karena readiness marker lock tidak muncul selama 75 detik. Source helper lama memiliki nested retry bug yang dapat melebihi timeout; helper baru dengan bounded deadline dan updater ber-backup sudah diimplementasikan. Penyebab branch yang benar-benar berjalan pada boot gagal masih perlu dikonfirmasi dari backup helper lokal dan log runtime.
- Jangan mengubah PAM, password handling, fingerprint/Howdy policy, atau session-lock protocol selama diagnosis.

Dokumen rinci: [Workstream 02 — Lock Screen](02-LOCK-SCREEN.md).

## Klasifikasi hasil

Gunakan status kanonis dari [AGENTS.md](../../../AGENTS.md): PLANNED, IMPLEMENTED, TESTED, VERIFIED, COMPLETED / USER ACCEPTED, BLOCKED, dan RELEASED. Jelaskan bukti dan batas klaim untuk setiap status.

Status keseluruhan Stage 5 hanya dicatat di [docs/06-STATUS.md](../../../docs/06-STATUS.md).


## Protokol khusus Topbar — Workstream 04

- Status awal: **PLANNED — DOCUMENTATION READY; AUDIT NOT STARTED**. Urutan, status, dan prioritas kanonis berada di [docs/06-STATUS.md](../../../docs/06-STATUS.md).
- Ikuti pola Workstream 02 dan 03: audit read-only → review bukti → spesifikasi dan persetujuan desain → implementasi/deployment terpisah → automated tests → runtime verification → acceptance/handoff.
- Jangan menggabungkan audit dengan deployment. Audit tidak boleh mengubah runtime, package, konfigurasi, service, atau Git metadata checkout.
- Audit wajib memeriksa source/config yang benar-benar aktif, versi Quickshell/Caelestia/Hyprland/Qt, API QML, panel/bar yang sudah berjalan, tray/status providers, monitor/scaling, fullscreen/fokus, dan titik integrasi.
- Elemen Topbar, sumber data, alignment, ukuran, visibility, interaksi, serta perilaku multi-monitor harus disepakati sebelum implementasi. Jangan menebak status atau menambahkan widget hanya karena tersedia upstream.
- Implementasi harus memisahkan source K41 dari upstream dan mengubah host seminimal mungkin. Preflight, backup, checksum/manifest, staging, verifikasi, logging, idempotensi, fail-closed, dan rollback ditentukan berdasarkan target aktual.
- Test fixture/mock tidak menggantikan verifikasi QML/runtime pada ThinkPad X280. Pengguna melakukan review visual/interaksi langsung; screenshot bukan acceptance gate.
- Tidak ada cleanup Caelestia luas dalam WS04. Cleanup tetap milik Workstream 08 dan dikerjakan terakhir.
- Dokumen pemilik: [Workstream 04 — Topbar](04-TOPBAR.md). Nama script dan path final ditetapkan setelah audit, bukan diasumsikan sebelumnya.
