# Reports

Direktori ini menyimpan arsip bukti historis yang memang dipilih untuk dipertahankan serta menjadi root output runtime lokal.

## Ownership dan layout runtime

Laporan runtime baru sebaiknya dikelompokkan berdasarkan Stage pemilik:

- `reports/stage-1-live-readiness/<category>/<timestamp>/`
- `reports/stage-2-basic-arch-install/<category>/<timestamp>/`
- `reports/stage-3-desktop-install/<category>/<timestamp>/`
- `reports/stage-4-desktop-validation/<category>/<timestamp>/`
- `reports/stage-5-desktop-customization/<workstream>/<category>/<timestamp>/`
- `reports/shared/<category>/<timestamp>/` untuk test runner dan collector lintas Stage.

**Status migrasi:** skrip yang ada masih menulis ke path `reports/<category>/` historis. Path tersebut dipertahankan untuk kompatibilitas sampai setiap producer dimigrasikan dan test-nya diperbarui. Jangan menganggap layout Stage-scoped sudah diterapkan ke semua producer.

## Policy

- Runtime-generated reports adalah artefak lokal secara default dan diabaikan Git.
- Jangan commit setiap diagnostic run. Simpan hanya bukti kecil yang telah direview dan disamarkan bila diperlukan untuk keputusan acceptance.
- Snapshot historis yang telah dikomit dipertahankan di [archive/2026-11](archive/2026-11/README.md).
- Snapshot historis bukan kondisi sistem saat ini.
- Jangan pernah menyimpan password, LUKS passphrase/recovery key, token, cookie, atau credential.
- Review hardware identifiers, serial numbers, journal excerpts, usernames, paths, dan network metadata sebelum membagikan laporan.

## AI dan maintenance

Jangan enumerate atau membaca seluruh `reports/archive/` untuk pekerjaan rutin. Akses artefak arsip tertentu hanya bila investigasi historis secara eksplisit memerlukannya.
