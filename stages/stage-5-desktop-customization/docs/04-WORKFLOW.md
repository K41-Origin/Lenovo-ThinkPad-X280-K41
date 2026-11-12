# Workstream 04 — Workflow Standardization

**Status: DOCUMENTATION IMPLEMENTED.** Workstream ini menetapkan proses kolaborasi, audit, implementasi, testing, verifikasi, acceptance, dan handoff yang konsisten berdasarkan praktik Workstream 02 — Lock Screen dan Workstream 03 — Bottombar.

Workstream 04 adalah workstream tata kelola/proses. Dokumen ini tidak mengganti identitas Workstream 05–09, tidak mengubah urutan workstream komponen, dan tidak memulai implementasi fitur desktop atau cleanup Caelestia.

## 1. Tujuan dan prinsip

- Menjadikan proses WS02 dan WS03 sebagai standar kerja Stage 5.
- Menjaga repository GitHub sebagai sumber kanonis source, script, test, dan dokumentasi.
- Memastikan setiap perubahan memiliki scope, bukti audit, acceptance criteria, dan batas safety.
- Mengutamakan otomatisasi yang aman agar pengguna tidak perlu mengedit source atau menjalankan rangkaian perintah manual.
- Memisahkan status IMPLEMENTED, TESTED, VERIFIED, dan COMPLETED / USER ACCEPTED.
- Tidak mengklaim operasi, test, atau kondisi runtime yang tidak memiliki bukti.

## 2. Pembagian tanggung jawab

| Aktivitas | Assistant | Pengguna |
|---|---|---|
| Inspeksi repository dan upstream | Melakukan audit dan mengumpulkan bukti | Meninjau temuan penting |
| Penetapan scope dan arsitektur | Menyusun proposal dan acceptance criteria | Menyetujui keputusan yang memengaruhi desain/safety |
| Source, script, test, dokumentasi | Mengembangkan dan memelihara | Tidak perlu mengedit file |
| Pemeriksaan statis dan automated test | Menyiapkan serta menjalankan test yang tersedia | Meninjau hasil |
| Sinkronisasi Git | Menyiapkan perubahan pada repository | Melakukan `git pull` dan `git push` sesuai alur yang disepakati |
| Runtime acceptance pada X280 | Menganalisis bukti yang tersedia | Meninjau perilaku aktual perangkat |
| Penutupan workstream | Merangkum bukti, batasan, risiko, dan handoff | Memberikan acceptance atau meminta perbaikan |

Pengguna tidak diminta menulis kode, mengedit file, atau mengubah konfigurasi secara manual sebagai bagian rutin workflow.

**Batasan:** `git pull` dan `git push` hanya menyinkronkan perubahan. Keduanya tidak mengeksekusi script, melakukan deployment, atau membuktikan runtime. Bila validasi perangkat memerlukan tindakan yang belum dapat diotomatisasi secara aman, nyatakan BLOCKED / NOT VERIFIED dan jelaskan prasyaratnya. Jangan diam-diam mengalihkan pekerjaan teknis kepada pengguna.

## 3. Siklus kerja standar

### Tahap 1 — Inspeksi dan audit read-only

1. Periksa branch, HEAD, tree, file terkait, dan perubahan yang sudah ada.
2. Baca dokumen pemilik, implementasi, test, serta instruksi proyek yang relevan.
3. Audit konfigurasi dan source yang benar-benar aktif; jangan menganggap laporan lama mewakili kondisi sekarang.
4. Periksa upstream, versi, dependency, resource, API/schema, ownership, dan titik integrasi yang relevan.
5. Kumpulkan bukti dengan prosedur read-only dan sanitasi data sensitif sebelum publikasi.
6. Jangan melakukan deployment, cleanup, atau mutasi sistem selama tahap audit.

**Output:** temuan audit, bukti, asumsi, ketidakpastian, dan daftar risiko.

### Tahap 2 — Review dan desain

1. Tinjau hasil audit dan pastikan fakta terpisah dari hipotesis.
2. Tentukan scope, non-goals, ownership K41/upstream, dependency, dan interface.
3. Pilih solusi paling sederhana yang memenuhi kebutuhan; hindari duplikasi fitur atau framework tanpa kebutuhan nyata.
4. Tetapkan file yang akan dibuat/diubah, target runtime, preflight, backup, rollback, serta strategi kegagalan.
5. Susun acceptance criteria yang dapat diuji.
6. Minta keputusan pengguna hanya untuk ambiguitas yang memengaruhi arsitektur, safety, atau hasil desain.

**Output:** rencana implementasi dan acceptance criteria yang disepakati.

### Tahap 3 — Penyiapan source K41

1. Simpan source milik K41 pada lokasi ownership yang jelas di repository.
2. Pisahkan source K41 dari source upstream dan runtime Caelestia.
3. Ambil hanya source/resource yang diperlukan; pertahankan dependency upstream yang memang masih dibutuhkan.
4. Jangan mengubah file package-owned atau menghapus source upstream tanpa bukti bahwa target tidak lagi digunakan.
5. Periksa diff dan SHA file sebelum menulis perubahan ke GitHub.

**Output:** source canonical K41 dan peta dependency/interface.

### Tahap 4 — Implementasi dan integrasi

1. Buat perubahan kecil dan terisolasi sesuai desain yang disetujui.
2. Pisahkan audit read-only dari script yang melakukan penyiapan, deployment, atau cleanup.
3. Validasi target dan kondisi awal melalui preflight; gagal secara tertutup bila target ambigu atau tidak aman.
4. Batasi privilege dan cakupan file yang dapat diubah.
5. Buat backup sebelum perubahan runtime yang relevan.
6. Terapkan perubahan secara idempotent bila memungkinkan.
7. Verifikasi hasil pascaperubahan dan sediakan rollback yang sesuai.
8. Jangan membuat service, updater, bootstrap, atau runtime mandiri tanpa kebutuhan yang terbukti.

**Output:** implementasi, mekanisme deployment, backup/rollback, dan bukti perubahan.

### Tahap 5 — Testing dan verifikasi

Lakukan pemeriksaan yang relevan dengan perubahan, sekurang-kurangnya mempertimbangkan:

1. Syntax dan lint (misalnya `bash -n` dan ShellCheck untuk Bash).
2. Automated tests/fixtures untuk kondisi normal, error, idempotensi, rollback, dan input ambigu.
3. Validasi path, permission, dependency, konfigurasi, serta integrasi.
4. CI/regression suite yang tersedia.
5. Runtime verification pada ThinkPad X280 bila perilaku perangkat menjadi bagian acceptance.

Setiap hasil harus menyebutkan perintah/metode, hasil aktual, dan batas cakupan. Syntax check atau fixture tidak membuktikan runtime; file yang tersedia tidak membuktikan deployment; exit code sukses saja tidak membuktikan seluruh fungsi.

**Output:** catatan test dan bukti verifikasi, termasuk hal yang belum dapat diuji.

### Tahap 6 — Review dan acceptance

1. Review ulang diff, file hasil, dokumentasi, link/path, dan konsistensi status.
2. Periksa apakah acceptance criteria terpenuhi.
3. Catat defect, risiko tersisa, keterbatasan, dan pekerjaan lanjutan.
4. Minta pengguna meninjau hasil yang memerlukan penilaian desain atau perilaku perangkat.
5. Tutup workstream hanya setelah pengguna secara eksplisit menerima hasil atau menyetujui pengecualian yang dicatat.

**Output:** keputusan acceptance atau daftar perbaikan yang masih terbuka.

### Tahap 7 — Dokumentasi dan handoff

1. Perbarui dokumen pemilik workstream; hindari menyalin detail yang sama ke banyak dokumen.
2. Perbarui `docs/06-STATUS.md` jika status/prioritas berubah.
3. Perbarui indeks atau dokumen lintas-workstream hanya jika diperlukan.
4. Catat file yang berubah, commit, test yang benar-benar dijalankan, bukti, keterbatasan, risiko, dan langkah berikutnya.
5. Siapkan handoff yang menyebutkan dependency atau keputusan yang masih terbuka.

**Output:** dokumentasi konsisten dan handoff yang dapat ditindaklanjuti.

## 4. Protokol perubahan GitHub

- Gunakan branch `main` sesuai kebijakan repository saat ini.
- Sebelum write, periksa isi file dan SHA terkini.
- Jangan menimpa perubahan yang tidak terkait.
- Buat perubahan sekecil mungkin dan fokus pada scope.
- Setelah write, fetch/read ulang setiap file yang diubah untuk memastikan konten aktual.
- Catat commit SHA dan tautan file/commit bila tersedia.
- Jangan merge PR, membuat release/tag, atau melakukan tindakan consequential lain tanpa izin eksplisit.
- Jika write gagal atau hasil verifikasi berbeda, hentikan rangkaian perubahan dan audit kondisi repository sebelum mencoba kembali.

## 5. Safety, privasi, dan rollback

- Operasi disk destruktif memerlukan izin eksplisit dan identifikasi target yang terverifikasi.
- Audit harus read-only; operasi mutasi harus dipisahkan dan memiliki preflight.
- Jangan menjalankan remote script langsung melalui pipe ke shell.
- Jangan menonaktifkan signature/integrity verification.
- Jangan menyimpan password, passphrase, recovery key, token, cookie, atau credential.
- Laporan runtime disimpan privat secara default; hanya salinan yang sudah ditinjau dan disanitasi yang boleh dipublikasikan.
- Sanitasi otomatis tidak menjamin semua data sensitif terhapus; review laporan tetap wajib.
- Backup runtime tidak di-commit.
- Rollback harus dibatasi pada file/setting yang diubah oleh operasi terkait dan tidak boleh menghapus pekerjaan pengguna yang tidak terkait.

## 6. Status dan aturan pelaporan

Gunakan definisi kanonis dari `AGENTS.md`:

- **PLANNED:** belum diimplementasikan.
- **IMPLEMENTED:** perubahan/kode tersedia di repository.
- **TESTED:** test yang disebutkan benar-benar dijalankan.
- **VERIFIED:** perilaku dibuktikan dengan metode yang sesuai.
- **COMPLETED / USER ACCEPTED:** pengguna secara eksplisit menerima dan menutup scope; tidak otomatis berarti seluruh perilaku teknis VERIFIED.
- **BLOCKED:** prasyarat menghalangi pekerjaan.
- **RELEASED:** masuk ke rilis yang ditetapkan.
- **NOT TESTED:** belum ada pengujian memadai.

Jangan menaikkan status hanya karena file dibuat, test ditulis, atau pengguna menerima scope. Laporkan status tiap aspek secara terpisah bila tingkat buktinya berbeda.

## 7. Acceptance criteria Workstream 04

Workstream 04 dianggap selesai ketika:

- Workflow tujuh tahap terdokumentasi.
- Pembagian tanggung jawab dan batas sinkronisasi Git jelas.
- Protokol audit, perubahan GitHub, testing, safety, privasi, dan rollback tercatat.
- Definisi status dan aturan klaim hasil konsisten dengan `AGENTS.md`.
- Indeks Stage 5 dan status proyek menunjuk ke dokumen ini.
- Perubahan dokumentasi telah dibaca ulang dari GitHub.

Workstream 04 hanya menetapkan standar proses. Tidak ada perubahan runtime, deployment desktop, atau cleanup Caelestia yang termasuk acceptance WS04.

## 8. Dokumen terkait

- [Stage 5 — Desktop Customization](README.md)
- [Alur Kolaborasi dan Verifikasi Stage 5](00-COLLABORATION-WORKFLOW.md)
- [Workstream 02 — Lock Screen](02-LOCK-SCREEN.md)
- [Workstream 03 — Bottombar](03-BOTTOMBAR.md)
- [Status Proyek](../../../docs/06-STATUS.md)
- [Instruksi AI dan safety](../../../AGENTS.md)
