# Reports

Direktori ini menyimpan arsip bukti historis yang memang dipilih untuk dipertahankan serta menjadi root output runtime lokal.

## Ownership dan layout runtime

Laporan runtime dikelompokkan berdasarkan Stage pemilik:

- `reports/stage-1-live-readiness/<category>/<timestamp>/`
- `reports/stage-2-basic-arch-install/<category>/<timestamp>/`
- `reports/stage-3-desktop-install/<category>/<timestamp>/`
- `reports/stage-4-desktop-validation/<category>/<timestamp>/`
- `reports/stage-5-desktop-customization/<workstream>/<category>/<timestamp>/`
- `reports/shared/<category>/<timestamp>/` untuk test runner dan collector lintas Stage. Test runner kanonis menulis ke `reports/shared/test-runs/<timestamp>/`.

**Status migrasi:** Stage 1–5 telah memiliki beberapa producer yang menulis ke layout Stage-scoped. Producer historis yang belum dimigrasikan tetap menggunakan `reports/<category>/`; jangan menganggap semua output sudah berpindah. Migrasi harus memperbarui producer, consumer, test, dan dokumentasi secara bersamaan.

## Policy

- Runtime-generated reports adalah artefak lokal secara default dan diabaikan Git.
- Jangan commit setiap diagnostic run. Simpan hanya bukti kecil yang telah direview dan disamarkan bila diperlukan untuk keputusan acceptance.
- Snapshot historis yang telah dikomit dipertahankan di [archive/2026-11](archive/2026-11/README.md).
- Snapshot historis bukan kondisi sistem saat ini.
- Jangan pernah menyimpan password, LUKS passphrase/recovery key, token, cookie, atau credential.
- Review hardware identifiers, serial numbers, journal excerpts, usernames, paths, dan network metadata sebelum membagikan laporan.

## AI dan maintenance

Jangan enumerate atau membaca seluruh `reports/archive/` untuk pekerjaan rutin. Akses artefak arsip tertentu hanya bila investigasi historis secara eksplisit memerlukannya.
