# Stage 5 — Alur Kolaborasi dan Verifikasi

## Tujuan

Dokumen ini menetapkan alur kerja antara maintainer repository dan pengguna ThinkPad X280 untuk implementasi, pengujian, dan verifikasi Stage 5. Setiap komponen dibangun bertahap; hasil Stage 5 menjadi fondasi teknis dan pengalaman untuk proyek lanjutan **k41-shell**.

## Pembagian tanggung jawab

| Pihak | Tanggung jawab |
|---|---|
| Assistant | Memeriksa repository dan upstream; mengimplementasikan perubahan kode/config/docs; memeriksa hasil commit; menganalisis kegagalan dan memperbaiki implementasi. |
| Pengguna | Melakukan pull; menjalankan script/test pada X280; memeriksa dampak runtime; menyampaikan hasil dan keputusan. |

Assistant tidak mengklaim perubahan bekerja pada perangkat hanya karena commit berhasil. Pengujian perangkat dan review pengguna adalah bukti terpisah.

## Source of truth dan lokasi kerja

- Repository GitHub adalah sumber kanonis untuk source, installer, dokumentasi, dan test yang direview.
- Direktori `~/.config/quickshell/` pada laptop adalah lokasi source/runtime Quickshell yang digunakan untuk menjalankan hasil Stage 5.
- Untuk integrasi saat ini, Caelestia aktif berada di `~/.config/quickshell/caelestia/`. Kode K41 disimpan terpisah di namespace milik K41, contohnya `modules/k41dock/K41Dock.qml`; jangan menimpa file upstream yang tidak perlu.
- Template source setiap workstream disimpan di repository pada `workstreams/<id>/config/quickshell/...` dan dideploy ke lokasi runtime melalui script workstream.
- Jangan menjadikan perubahan manual pada laptop sebagai satu-satunya salinan. Setelah perubahan diterima, sinkronkan kembali source dan dokumentasinya ke repository.
- Backup konfigurasi/source dan log instalasi disimpan di bawah `~/.local/state/k41/backups/` atau lokasi yang dinyatakan oleh installer. Jangan commit backup runtime atau data sensitif.

## Siklus kerja

1. **Inspect**
   - Periksa branch, file terkait, konfigurasi, dokumentasi, dan implementasi upstream.
   - Identifikasi risiko perubahan dan pertahankan pekerjaan lokal yang tidak terkait.
2. **Design**
   - Tetapkan tujuan, interface, ownership, lokasi source/runtime, acceptance criteria, dan rollback.
   - Rancang komponen K41 agar dapat dipisahkan dari upstream dan berpotensi diekstrak ke k41-shell.
3. **Implement through GitHub**
   - Periksa isi dan SHA file sebelum mengubahnya.
   - Simpan source kanonis, installer, test, dan dokumentasi di repository.
   - Lakukan perubahan kecil dan fokus pada branch `main`; verifikasi setiap write melalui GitHub.
4. **Deploy and test on X280**
   - Pastikan perubahan lokal pengguna aman.
   - Sinkronkan: `git pull --ff-only origin main`.
   - Jalankan hanya script/test yang ditentukan, tanpa sudo kecuali ada alasan teknis yang dijelaskan.
   - Jalankan `--check` sebelum `--install` bila installer mendukung mode tersebut.
   - Catat exit status dan output aktual.
5. **Verify and iterate**
   - Hubungkan hasil pengujian dengan commit/script yang diuji.
   - Laporkan bukti, ketidakpastian, risiko, dan langkah berikutnya.
   - Review visual/interaksi dilakukan pengguna bila acceptance memerlukannya; screenshot bukan acceptance gate.

## Script Caelestia

Audit dan cleanup adalah dua script terpisah:

- Audit read-only: `bash stages/stage-5-desktop-customization/scripts/k41-audit-caelestia.sh`
- Cleanup Dashboard: `bash stages/stage-5-desktop-customization/scripts/k41-cleanup-caelestia.sh`

Cleanup menetapkan `dashboard.enabled=false` pada konfigurasi Caelestia yang relevan. Script berjalan tanpa argumen, menolak root, memvalidasi JSON, membuat backup bertimestamp, dan tidak menghapus source QML upstream, halaman Nexus, package, atau service.

## Klasifikasi hasil

Gunakan status proyek kanonis dari [AGENTS.md](../../../AGENTS.md):

- **PLANNED** — belum diimplementasikan.
- **IMPLEMENTED** — perubahan telah dibuat di repository.
- **TESTED** — test yang disebutkan telah benar-benar dijalankan; cantumkan hasilnya.
- **VERIFIED** — perilaku telah dikonfirmasi dengan bukti yang sesuai, termasuk pengujian perangkat bila diperlukan.
- **COMPLETED / USER ACCEPTED** — pengguna telah menerima dan menutup workstream; jangan memperluas klaim teknis di luar scope yang diterima.
- **RELEASED** — masuk ke rilis yang ditetapkan.

Commit sukses hanya membuktikan perubahan tersimpan di GitHub, bukan acceptance runtime.

## Penutupan iterasi

Setiap laporan kemajuan menyebutkan file/commit yang berubah, pemeriksaan yang benar-benar dijalankan, hasil aktual, risiko yang tersisa, dan acceptance yang belum terpenuhi. Status keseluruhan Stage 5 hanya dicatat di [status proyek](../../../docs/06-STATUS.md).
