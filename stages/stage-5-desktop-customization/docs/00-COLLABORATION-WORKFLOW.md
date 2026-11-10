# Stage 5 — Alur Kolaborasi, Audit, dan Verifikasi

## Tujuan

Dokumen ini menetapkan satu alur kerja tetap antara maintainer repository (assistant melalui GitHub) dan pengguna yang menjalankan perubahan pada ThinkPad X280. Gunakan alur ini untuk seluruh workstream Stage 5 agar audit, implementasi, pengujian perangkat, dan bukti hasil tidak tercampur.

## Pembagian tanggung jawab

| Pihak | Tanggung jawab |
|---|---|
| Assistant | Memeriksa repository dan upstream; memperbarui script audit; merancang perubahan; mengimplementasikan kode/config/docs melalui GitHub; memeriksa log yang dipush; menganalisis kegagalan; memperbaiki implementasi. |
| Pengguna | Melakukan pull dari branch kerja yang disepakati; menjalankan audit/test pada X280; memeriksa laporan untuk data sensitif; commit dan push laporan; melakukan review visual/interaksi dan menyampaikan keputusan. |

Assistant tidak mengklaim bahwa perubahan telah bekerja pada perangkat hanya karena commit berhasil. Pengujian perangkat dan review pengguna adalah bukti terpisah.

## Siklus kerja kanonis

Gunakan urutan berikut untuk setiap iterasi:

1. **Inspect**
   - Periksa status branch, file terkait, konfigurasi yang dimiliki repository, dokumentasi workstream, dan implementasi/upstream yang relevan.
   - Identifikasi kebutuhan informasi dari perangkat serta risiko perubahan.
   - Jangan menganggap hasil audit sebelumnya masih berlaku jika versi, konfigurasi, atau source aktif berubah.

2. **Update audit script bila diperlukan**
   - Semua pemeriksaan perangkat yang berulang atau diperlukan untuk keputusan implementasi harus ditambahkan ke script audit Stage 5 yang relevan.
   - Untuk persiapan penghapusan Dashboard Caelestia, entry point kanonis adalah:
     `bash stages/stage-5-desktop-customization/scripts/k41-cleanup-caelestia.sh --audit`
   - Script cleanup menjalankan audit Caelestia read-only dan belum menyediakan operasi `--apply`; implementasi penghapusan baru dibuat setelah laporan X280 ditinjau.
   - Jangan meminta pengguna menjalankan kumpulan perintah audit manual jika pemeriksaan tersebut dapat dikemas secara aman ke script.
   - Audit harus read-only: tidak mengubah konfigurasi, package, service, wallpaper, session, atau state shell; tidak menjalankan reload/restart; tidak menggunakan sudo.
   - Jika pemeriksaan membutuhkan tindakan mutatif atau interaksi visual, pisahkan sebagai langkah implementasi/pengujian dan minta persetujuan eksplisit bila berisiko.

3. **Implement through GitHub**
   - Assistant memeriksa isi dan SHA file saat ini sebelum mengubahnya.
   - Lakukan perubahan kecil, fokus, dan pada branch yang disepakati (default proyek: `main`).
   - Jangan menimpa perubahan yang belum diperiksa atau menghapus artefak yang tidak terkait.
   - Setelah write, verifikasi isi file/commit melalui GitHub.
   - Sertakan instruksi pull, entry point, dan validasi yang diperlukan.

4. **Pull and execute on the X280**
   - Pengguna memastikan tidak ada perubahan lokal yang belum diamankan.
   - Sinkronkan branch:
     ```bash
     git pull --ff-only origin main
     ```
   - Jalankan hanya script/test yang disebutkan untuk iterasi tersebut, sebagai pengguna biasa kecuali dokumentasi secara eksplisit menyatakan kebutuhan privilege.
   - Jangan menjalankan audit atau installer dengan `sudo` kecuali memang diwajibkan dan telah dijelaskan.
   - Catat exit status dan output aktual. Jangan mengedit laporan hasil untuk membuatnya tampak lulus.

5. **Review and push reports**
   - Laporan runtime Stage 5 berada di bawah `reports/stage-5-desktop-customization/`.
   - Untuk pre-audit penghapusan Dashboard, script cleanup menghasilkan direktori bertimestamp di:
     `reports/stage-5-desktop-customization/caelestia-audit/<timestamp>/`
   - Pastikan laporan memuat `summary.txt`, `run.log`, `config-snapshot.json`, `source-inventory.txt`, `dashboard-config-inventory.json`, `dashboard-source-references.txt`, dan `dashboard-keybinds.json`.
   - Periksa `summary.txt`, `run.log`, `config-snapshot.json`, `dashboard-config-inventory.json`, `dashboard-source-references.txt`, dan `dashboard-keybinds.json` (sesuai artefak yang dibuat).
   - Sebelum commit, periksa seluruh laporan untuk username, path pribadi, hostname, alamat jaringan, token, credential, informasi lokasi, atau data sensitif lain. Redaksi otomatis bukan jaminan bahwa semua informasi sensitif terhapus.
   - Jangan push laporan yang mengandung secret atau data pribadi. Jika ragu, jangan commit; laporkan masalahnya dan minta bantuan untuk memperbaiki sanitasi collector.
   - Stage hanya direktori laporan yang relevan, bukan seluruh `reports/` atau perubahan lain:
     ```bash
     git status --short
     git add reports/stage-5-desktop-customization/caelestia-audit/<timestamp>/
     git diff --cached --stat
     git diff --cached
     git commit -m "test(stage-5): add Caelestia audit report"
     git push origin main
     ```
   - Ganti `<timestamp>` dengan nama direktori aktual yang dibuat script. Pastikan branch yang dipush sesuai branch kerja.

6. **Verify and iterate**
   - Assistant memeriksa laporan yang telah dipush dan menghubungkannya dengan versi script/commit yang menghasilkan laporan.
   - Hasil analisis menyebutkan temuan, bukti, ketidakpastian, dan tindakan berikutnya.
   - Jika dibutuhkan, assistant memperbarui script atau implementasi melalui GitHub, lalu siklus diulang.
   - Pengguna melakukan review visual/interaksi langsung pada X280 bila acceptance memerlukannya; screenshot bukan syarat kecuali workstream secara eksplisit mengubah kebijakan tersebut.

## Kontrak script audit

Script audit Stage 5 harus mengikuti prinsip berikut:

- **Read-only by default:** tidak melakukan perubahan sistem atau konfigurasi.
- **No privilege escalation:** menolak berjalan sebagai root bila audit tidak memerlukan root.
- **Fail clearly:** prasyarat dan kegagalan dicatat dengan status/exit code yang dapat dipahami.
- **Bounded execution:** command yang berpotensi menunggu harus memiliki timeout yang wajar.
- **Privacy-aware:** hindari mengumpulkan data yang tidak relevan; redaksi path dan informasi sensitif; jangan mengumpulkan credential, private key, token, atau isi file rahasia.
- **Reviewable output:** simpan laporan bertimestamp dan ringkasan status.
- **No false success:** kegagalan pemeriksaan tidak boleh disamarkan sebagai keberhasilan; pengecualian harus dijelaskan.
- **No automatic upload:** script hanya membuat laporan lokal. Pengguna memeriksa dan melakukan commit/push secara sadar.

Setiap penambahan pemeriksaan harus menyebutkan alasan, sumber data, dampak privasi, kemungkinan false positive, dan cara membaca hasilnya.

## Klasifikasi hasil

Gunakan status proyek kanonis dari [AGENTS.md](../../../AGENTS.md):

- **PLANNED** — belum diimplementasikan.
- **IMPLEMENTED** — perubahan telah dibuat di repository.
- **TESTED** — test yang disebutkan telah benar-benar dijalankan; cantumkan hasilnya.
- **VERIFIED** — perilaku telah dikonfirmasi dengan bukti yang sesuai, termasuk pengujian perangkat bila diperlukan.
- **RELEASED** — masuk ke rilis yang ditetapkan.

Commit sukses hanya membuktikan perubahan tersimpan di GitHub. Audit selesai hanya membuktikan pemeriksaan yang tercantum dalam laporan telah dijalankan. Keduanya tidak otomatis membuktikan acceptance runtime.

## Penutupan setiap iterasi

Setiap laporan kemajuan harus menyebutkan:

1. File/commit yang berubah.
2. Pemeriksaan statis yang benar-benar dijalankan dan hasilnya.
3. Script/test yang harus dijalankan pengguna.
4. Lokasi laporan yang diharapkan.
5. Temuan dan risiko yang belum terselesaikan.
6. Acceptance yang sudah dan belum terpenuhi.

Status keseluruhan Stage 5 tetap dicatat hanya di [status proyek](../../../docs/06-STATUS.md). Dokumen ini adalah prosedur kerja, bukan salinan status atau riwayat implementasi.
