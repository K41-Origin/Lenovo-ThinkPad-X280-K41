# Reports

Direktori ini menyimpan arsip bukti historis yang dipilih untuk dipertahankan serta menjadi root output runtime lokal.

## Ownership dan layout runtime

Laporan runtime dikelompokkan berdasarkan Stage pemilik:

- `reports/stage-1-live-readiness/<category>/<timestamp>/`
- `reports/stage-2-basic-arch-install/<category>/<timestamp>/`
- `reports/stage-3-desktop-install/<category>/<timestamp>/`
- `reports/stage-4-desktop-validation/<category>/<timestamp>/`
- `reports/stage-5-desktop-customization/<workstream-or-category>/<category>/<timestamp>/`
- `reports/stage-6-hardware-optimization/<category>/<timestamp>/`
- `reports/shared/<category>/<timestamp>/` untuk test runner dan collector lintas Stage, termasuk boot audit lintas Stage. Test runner kanonis menulis ke `reports/shared/test-runs/<timestamp>/`; boot audit menulis ke `reports/shared/boot-audit/<timestamp>/`.

**Status migrasi:** Stage 1–6 telah memiliki beberapa producer yang menulis ke layout Stage-scoped. Producer historis yang belum dimigrasikan tetap menggunakan `reports/<category>/`; jangan menganggap semua output sudah berpindah. Migrasi harus memperbarui producer, consumer, test, dan dokumentasi secara bersamaan.

## Policy

- Runtime-generated reports tetap lokal dan diabaikan Git secara default.
- **Pengecualian:** `reports/stage-5-desktop-customization/caelestia-audit/` diizinkan masuk Git karena laporan ini menjadi bukti kerja kolaboratif untuk implementasi taskbar/dock Stage 5.
- Sebelum commit, periksa `summary.txt`, `config-snapshot.json`, `monitor-runtime.json`, `source-inventory.txt`, dan `run.log`. Pastikan tidak ada token, credential, serial number, identitas perangkat yang tidak diperlukan, lokasi pribadi, atau informasi sensitif lainnya.
- Jangan commit semua diagnostic run tanpa seleksi. Commit hanya laporan yang relevan dengan investigasi/acceptance dan sudah ditinjau.
- Snapshot historis yang telah dikomit dipertahankan di [archive/2026-11](archive/2026-11/README.md).
- Snapshot historis bukan kondisi sistem saat ini.
- Jangan pernah menyimpan password, LUKS passphrase/recovery key, token, cookie, atau credential.
- Review hardware identifiers, serial numbers, journal excerpts, usernames, paths, dan network metadata sebelum membagikan laporan.

## AI dan maintenance

Jangan enumerate atau membaca seluruh `reports/archive/` untuk pekerjaan rutin. Akses artefak arsip tertentu hanya bila investigasi historis secara eksplisit memerlukannya.
