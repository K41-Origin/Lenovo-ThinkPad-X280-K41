# Stage 5 — Alur Kolaborasi dan Verifikasi

## Tujuan

Dokumen ini menetapkan alur kerja antara maintainer repository dan pengguna ThinkPad X280 untuk implementasi, pengujian, dan verifikasi Stage 5.

## Pembagian tanggung jawab

| Pihak | Tanggung jawab |
|---|---|
| Assistant | Memeriksa repository dan upstream; mengimplementasikan perubahan kode/config/docs; memeriksa hasil commit; menganalisis kegagalan dan memperbaiki implementasi. |
| Pengguna | Melakukan pull; menjalankan script/test pada X280; memeriksa dampak runtime; menyampaikan hasil dan keputusan. |

Assistant tidak mengklaim perubahan bekerja pada perangkat hanya karena commit berhasil. Pengujian perangkat dan review pengguna adalah bukti terpisah.

## Siklus kerja

1. **Inspect**
   - Periksa branch, file terkait, konfigurasi, dokumentasi, dan implementasi upstream.
   - Identifikasi risiko perubahan dan pertahankan pekerjaan lokal yang tidak terkait.
2. **Implement through GitHub**
   - Periksa isi dan SHA file sebelum mengubahnya.
   - Lakukan perubahan kecil dan fokus pada branch `main`.
   - Verifikasi setiap write melalui GitHub.
3. **Pull and execute on X280**
   - Pastikan perubahan lokal pengguna aman.
   - Sinkronkan: `git pull --ff-only origin main`.
   - Jalankan hanya script/test yang ditentukan, tanpa sudo kecuali ada alasan teknis yang dijelaskan.
   - Catat exit status dan output aktual.
4. **Verify and iterate**
   - Hubungkan hasil pengujian dengan commit/script yang diuji.
   - Laporkan bukti, ketidakpastian, risiko, dan langkah berikutnya.
   - Review visual/interaksi dilakukan pengguna bila acceptance memerlukannya; screenshot bukan acceptance gate.

## Script Caelestia

Audit dan cleanup adalah dua script terpisah:

- Audit read-only: `bash stages/stage-5-desktop-customization/scripts/k41-audit-caelestia.sh`
- Cleanup Dashboard: `bash stages/stage-5-desktop-customization/scripts/k41-cleanup-caelestia.sh`

Script cleanup tidak memiliki opsi/mode. Script tersebut menghapus properti konfigurasi Dashboard dari file `shell.json` dan direktori source `modules/dashboard`; script menolak berjalan sebagai root, menolak argumen, symlink, dan source checkout Git yang memiliki perubahan lokal. Jangan menghapus atau menimpa perubahan pengguna yang tidak terkait.

## Klasifikasi hasil

Gunakan status proyek kanonis dari [AGENTS.md](../../../AGENTS.md):

- **PLANNED** — belum diimplementasikan.
- **IMPLEMENTED** — perubahan telah dibuat di repository.
- **TESTED** — test yang disebutkan telah benar-benar dijalankan; cantumkan hasilnya.
- **VERIFIED** — perilaku telah dikonfirmasi dengan bukti yang sesuai, termasuk pengujian perangkat bila diperlukan.
- **RELEASED** — masuk ke rilis yang ditetapkan.

Commit sukses hanya membuktikan perubahan tersimpan di GitHub, bukan acceptance runtime.

## Penutupan iterasi

Setiap laporan kemajuan menyebutkan file/commit yang berubah, pemeriksaan yang benar-benar dijalankan, hasil aktual, risiko yang tersisa, dan acceptance yang belum terpenuhi. Status keseluruhan Stage 5 hanya dicatat di [status proyek](../../../docs/06-STATUS.md).
